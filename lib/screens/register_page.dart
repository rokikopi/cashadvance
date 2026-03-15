import 'package:cashadvance/screens/login_page.dart';
import 'package:cashadvance/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cashadvance/theme/constants.dart';
import 'package:flutter/foundation.dart';

class RegisterPage extends StatefulWidget {
  final User? socialUser;
  const RegisterPage({super.key, this.socialUser});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _fNameController = TextEditingController();
  final _lNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _empIdController = TextEditingController();
  final _deptController = TextEditingController();
  final _posController = TextEditingController();
  final _pwController = TextEditingController();
  final _confirmPwController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isGoogleUser = false;
  bool _isLoginHovered = false;

  @override
  void initState() {
    super.initState();
    if (widget.socialUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyGoogleData(widget.socialUser!);
      });
    }
    if (kIsWeb) {
      _checkRedirectResult();
    }
  }

  Future<void> _checkRedirectResult() async {
    setState(() => _isLoading = true);
    try {
      // ignore: unnecessary_nullable_for_final_variable_declarations
      final UserCredential? userCredential = await FirebaseAuth.instance
          .getRedirectResult();
      if (userCredential?.user != null) {
        _applyGoogleData(userCredential!.user!);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Registration Redirect Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyGoogleData(User user) {
    List<String> nameParts = (user.displayName ?? "").split(" ");
    setState(() {
      _fNameController.text = nameParts.first;
      _lNameController.text = nameParts.length > 1
          ? nameParts.sublist(1).join(" ")
          : "";
      _emailController.text = user.email ?? "";
      _pwController.text = "GOOGLE_USER_AUTH";
      _confirmPwController.text = "GOOGLE_USER_AUTH";
      _isGoogleUser = true;
      _isLoading = false;
    });
    _showSuccess("Google account linked. Please provide employee details.");
  }

  @override
  void dispose() {
    _fNameController.dispose();
    _lNameController.dispose();
    _emailController.dispose();
    _empIdController.dispose();
    _deptController.dispose();
    _posController.dispose();
    _pwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleAutofill() async {
    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final UserCredential? userCredential = await authService
          .signInWithGoogle();

      if (userCredential?.user != null) {
        _applyGoogleData(userCredential!.user!);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Google Error: $e");
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
      debugPrint("Google Error: $e");
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

  Future<void> _submitRegistration() async {
    if (_fNameController.text.trim().isEmpty ||
        _lNameController.text.trim().isEmpty) {
      _showError("Please enter your full name.");
      return;
    }
    if (!_isGoogleUser && (_pwController.text != _confirmPwController.text)) {
      _showError("Passwords do not match!");
      return;
    }
    if (_empIdController.text.trim().isEmpty ||
        _deptController.text.trim().isEmpty) {
      _showError("Please fill in all employee details.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? uid;
      if (!_isGoogleUser) {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _pwController.text.trim(),
            );
        uid = userCredential.user?.uid;
      } else {
        uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          throw Exception("Session expired. Please re-authenticate.");
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'firstName': _fNameController.text.trim(),
        'lastName': _lNameController.text.trim(),
        'email': _emailController.text.trim(),
        'employeeId': _empIdController.text.trim(),
        'department': _deptController.text.trim(),
        'position': _posController.text.trim(),
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      _showSuccess("Registration Complete!");

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      _showError(e.toString());
      if (mounted) setState(() => _isLoading = false);
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
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: Column(
                    children: [
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
                        "Create Account",
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildTextField(
                        label: "First Name",
                        icon: Icons.person_outline,
                        controller: _fNameController,
                        enabled: !_isGoogleUser,
                      ),
                      _buildTextField(
                        label: "Last Name",
                        icon: Icons.person_outline,
                        controller: _lNameController,
                        enabled: !_isGoogleUser,
                      ),
                      _buildTextField(
                        label: "Email",
                        icon: Icons.email_outlined,
                        controller: _emailController,
                        enabled: !_isGoogleUser,
                      ),
                      _buildTextField(
                        label: "Employee ID",
                        icon: Icons.badge_outlined,
                        controller: _empIdController,
                      ),
                      _buildTextField(
                        label: "Department",
                        icon: Icons.business_outlined,
                        controller: _deptController,
                      ),
                      _buildTextField(
                        label: "Position",
                        icon: Icons.work_outline,
                        controller: _posController,
                      ),
                      if (!_isGoogleUser) ...[
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
                        _buildTextField(
                          label: "Confirm Password",
                          icon: Icons.lock_reset_outlined,
                          controller: _confirmPwController,
                          isPassword: true,
                          isVisible: _isConfirmPasswordVisible,
                          onToggleVisibility: () => setState(
                            () => _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitRegistration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            "Sign Up",
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (!_isGoogleUser) ...[
                        const SizedBox(height: 15),
                        _buildGoogleButton(),
                      ],
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          MouseRegion(
                            onEnter: (_) =>
                                setState(() => _isLoginHovered = true),
                            onExit: (_) =>
                                setState(() => _isLoginHovered = false),
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginPage(),
                                  ),
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _isLoginHovered
                                      ? AppColors.primary.withValues(
                                          alpha: 0.08,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "Log In",
                                  style: GoogleFonts.inter(
                                    color: _isLoginHovered
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
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
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
    VoidCallback? onToggleVisibility,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: isPassword && !isVisible,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: enabled ? AppColors.primary : Colors.grey,
            size: 20,
          ),
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
          fillColor: enabled ? Colors.grey[50] : Colors.grey[200],
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
      onPressed: _isLoading ? null : _handleGoogleAutofill,
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
