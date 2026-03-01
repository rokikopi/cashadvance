import 'package:cashadvance/screens/login_page.dart';
import 'package:cashadvance/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cashadvance/theme/constants.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

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
      // We sign out first to ensure a fresh Google picker
      await authService.signOut();

      final userCredential = await authService.signInWithGoogle();

      if (userCredential == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final user = userCredential.user;
      List<String> nameParts = (user?.displayName ?? "").split(" ");

      setState(() {
        _fNameController.text = nameParts.first;
        _lNameController.text = nameParts.length > 1
            ? nameParts.sublist(1).join(" ")
            : "";
        _emailController.text = user?.email ?? "";
        _pwController.text = "GOOGLE_USER_AUTH";
        _confirmPwController.text = "GOOGLE_USER_AUTH";
        _isGoogleUser = true;
        _isLoading = false;
      });

      _showSuccess(
        "Google details imported. Please complete the remaining fields.",
      );
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError("Google Error: $e");
    }
  }

  Future<void> _submitRegistration() async {
    // 1. Validation
    if (!_isGoogleUser && (_pwController.text != _confirmPwController.text)) {
      _showError("Passwords do not match!");
      return;
    }

    if (_empIdController.text.isEmpty || _deptController.text.isEmpty) {
      _showError("Please fill in all employee details.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? uid;
      if (!_isGoogleUser) {
        // Create new account for Email/PW users
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _pwController.text.trim(),
            );
        uid = userCredential.user?.uid;
      } else {
        // Use existing UID for Google users already authenticated via autofill
        uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          throw Exception("Session expired. Please re-authenticate.");
        }
      }

      // 2. Save/Update profile in Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'firstName': _fNameController.text.trim(),
        'lastName': _lNameController.text.trim(),
        'email': _emailController.text.trim(),
        'employeeId': _empIdController.text.trim(),
        'department': _deptController.text.trim(),
        'position': _posController.text.trim(),
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSuccess("Registration Complete!");

      // 3. AUTO-REDIRECT LOGIC
      // Since RegisterPage was pushed from LoginPage, we need to clear both.
      // Navigator.popUntil removes all pages until it hits the root (AuthGate).
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
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
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 80,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
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
                      onPressed: _submitRegistration,
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
                        onEnter: (_) => setState(() => _isLoginHovered = true),
                        onExit: (_) => setState(() => _isLoginHovered = false),
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _isLoginHovered
                                  ? AppColors.primary.withValues(alpha: 0.08)
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
      onPressed: _handleGoogleAutofill,
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
