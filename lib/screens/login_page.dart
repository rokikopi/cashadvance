import 'package:cashadvance/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cashadvance/theme/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final _employeeIdController = TextEditingController();
  final _pwController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isForgotHovered = false;
  bool _isSignUpHovered = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _checkRedirectResult();
    }
  }

  Future<void> _checkRedirectResult() async {
    try {
      // ignore: unnecessary_nullable_for_final_variable_declarations
      final UserCredential? userCredential = await FirebaseAuth.instance
          .getRedirectResult();

      if (userCredential?.user != null) {
        debugPrint(
          "Redirect sign-in successful: ${userCredential!.user!.email}",
        );
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      }
    } catch (e) {
      debugPrint("Redirect Result Error: $e");
    }
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  Future<String?> _getEmailFromEmployeeId(String employeeId) async {
    try {
      // Query Firestore to find user by employeeId
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('employeeId', isEqualTo: employeeId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final userData = snapshot.docs.first.data() as Map<String, dynamic>;
        return userData['email'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint("Error finding user by employee ID: $e");
      return null;
    }
  }

  Future<void> _handleEmailLogin() async {
    final employeeId = _employeeIdController.text.trim();
    final password = _pwController.text.trim();

    if (employeeId.isEmpty || password.isEmpty) {
      _showError("Please enter your Employee ID and password.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // First, find the email associated with this employee ID
      final email = await _getEmailFromEmployeeId(employeeId);

      if (email == null) {
        _showError("Employee ID not found. Please check and try again.");
        setState(() => _isLoading = false);
        return;
      }

      // Then sign in with email and password
      await _authService.signInWithEmail(email, password);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showError(_friendlyAuthError(e.code));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showError("An unexpected error occurred.");
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);

    try {
      await _authService.signInWithGoogle();

      if (!kIsWeb && mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
      // On web, the page will redirect on success, so no need to navigate
    } on FirebaseAuthException catch (e) {
      debugPrint("Google Login Error: $e");
      if (mounted) {
        // Firebase catches popup close immediately with this error code
        if (e.code == 'popup-closed-by-user') {
          _showError("Sign-in cancelled. Please try again.");
        } else {
          _showError("Google Sign-In failed. Please try again.");
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Google Login Error: $e");
      if (mounted) {
        // Fallback for any other errors
        if (e.toString().contains('popup') || e.toString().contains('closed')) {
          _showError("Sign-in cancelled. Please try again.");
        } else {
          _showError("Google Sign-In failed. Please try again.");
        }
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final employeeId = _employeeIdController.text.trim();

    if (employeeId.isEmpty) {
      _showError("Enter your Employee ID above to reset your password.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // First, find the email associated with this employee ID
      final email = await _getEmailFromEmployeeId(employeeId);

      if (email == null) {
        _showError("Employee ID not found. Please check and try again.");
        setState(() => _isLoading = false);
        return;
      }

      // Then send password reset email
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSuccess(
        "Password reset email sent to the email associated with this Employee ID. Check your inbox.",
      );
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyAuthError(e.code));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
        return "Incorrect employee ID or password.";
      case 'wrong-password':
        return "Incorrect password. Please try again.";
      case 'invalid-email':
        return "Please enter a valid email address.";
      case 'too-many-requests':
        return "Too many attempts. Please try again later.";
      case 'popup-closed-by-user':
        return "Sign-in cancelled. Please try again.";
      default:
        return "Authentication failed ($code).";
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.textMain,
                size: 20,
              ),
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/splash'),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Image.asset(
                        'assets/images/logo.png',
                        height: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.account_balance_wallet,
                              size: 80,
                              color: AppColors.primary,
                            ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Welcome Back",
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Log in to continue managing your finances.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildTextField(
                        label: "Employee ID",
                        icon: Icons.badge_outlined,
                        controller: _employeeIdController,
                        keyboardType: TextInputType.text,
                      ),
                      _buildTextField(
                        label: "Password",
                        icon: Icons.lock_outline,
                        controller: _pwController,
                        isPassword: true,
                        isVisible: _isPasswordVisible,
                        onToggleVisibility: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: MouseRegion(
                          onEnter: (_) =>
                              setState(() => _isForgotHovered = true),
                          onExit: (_) =>
                              setState(() => _isForgotHovered = false),
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: _handleForgotPassword,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _isForgotHovered
                                    ? AppColors.primary.withValues(alpha: 0.05)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "Forgot Password?",
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: _isForgotHovered
                                      ? AppColors.primaryHover
                                      : AppColors.primary,
                                  fontWeight: _isForgotHovered
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleEmailLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            "Log In",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[300])),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                            ),
                            child: Text(
                              "or",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey[300])),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _buildGoogleButton(),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          MouseRegion(
                            onEnter: (_) =>
                                setState(() => _isSignUpHovered = true),
                            onExit: (_) =>
                                setState(() => _isSignUpHovered = false),
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () =>
                                  Navigator.pushNamed(context, '/register'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _isSignUpHovered
                                      ? AppColors.primary.withValues(
                                          alpha: 0.08,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "Sign Up",
                                  style: GoogleFonts.inter(
                                    color: _isSignUpHovered
                                        ? AppColors.primaryHover
                                        : AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    bool isVisible = false,
    bool enabled = true,
    TextInputType? keyboardType,
    VoidCallback? onToggleVisibility,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: isPassword && !isVisible,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton(
      onPressed: _isLoading ? null : _handleGoogleLogin,
      style: OutlinedButton.styleFrom(
        fixedSize: const Size(double.infinity, 55),
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://firebasestorage.googleapis.com/v0/b/flutterbricks-public.appspot.com/o/crypto%2Fsearch%20(2).png?alt=media&token=24a918f7-3564-4290-b7e4-08ff54b3c94c',
            height: 20,
            errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata, size: 30),
          ),
          const SizedBox(width: 12),
          Text(
            "Continue with Google",
            style: GoogleFonts.inter(
              color: AppColors.textMain,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
