import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cashadvance/theme/constants.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '149500606282-bv0krkbqdji6pps6mt8mqkfhdo4p2d1d.apps.googleusercontent.com',
    scopes: ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
  );

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

  // Hover state for the login link
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
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final String displayName = googleUser.displayName ?? "";
      List<String> nameParts = displayName.split(" ");

      setState(() {
        _fNameController.text = nameParts.first;
        _lNameController.text = nameParts.length > 1
            ? nameParts.sublist(1).join(" ")
            : "";
        _emailController.text = googleUser.email;
        _pwController.text = "GOOGLE_USER_EXTERNAL";
        _confirmPwController.text = "GOOGLE_USER_EXTERNAL";
        _isGoogleUser = true;
        _isLoading = false;
      });

      _showSuccess("Google details imported.");
    } catch (e) {
      setState(() => _isLoading = false);
      _showError("Google Error: $e");
    }
  }

  Future<void> _submitRegistration() async {
    if (!_isGoogleUser && (_pwController.text != _confirmPwController.text)) {
      _showError("Passwords do not match!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential;

      if (!_isGoogleUser) {
        userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _pwController.text.trim(),
            );
      } else {
        final googleUser = await _googleSignIn.signIn();
        final googleAuth = await googleUser?.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth?.accessToken,
          idToken: googleAuth?.idToken,
        );

        userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
      }

      final String uid = userCredential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'firstName': _fNameController.text.trim(),
        'lastName': _lNameController.text.trim(),
        'email': _emailController.text.trim(),
        'employeeId': _empIdController.text.trim(),
        'department': _deptController.text.trim(),
        'position': _posController.text.trim(),
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSuccess("Account created successfully!");
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
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
                  const SizedBox(height: 10),
                  Text(
                    "Join us to manage your finances smarter.",
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
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

                  // Updated Log In Link with Shadow/Hover Effects
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
                              boxShadow: _isLoginHovered
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              "Log In",
                              style: GoogleFonts.inter(
                                color: _isLoginHovered
                                    ? AppColors.primaryHover
                                    : AppColors.primary,
                                fontWeight: _isLoginHovered
                                    ? FontWeight.w800
                                    : FontWeight.bold,
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
