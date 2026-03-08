import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        return await _auth.signInWithPopup(googleProvider);
      } else {
        // 1. Initialize the plugin
        await _googleSignIn.initialize();

        // 2. Authenticate the user to get the account
        final GoogleSignInAccount googleUser = await _googleSignIn
            .authenticate();

        // 3. Obtain the ID Token (Authentication)
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        // 4. Access Token is now separate. Request authorization explicitly.
        // We use the same scopes used during initialization.
        final List<String> scopes = ['email', 'profile'];
        final authClient = googleUser.authorizationClient;
        final authorization = await authClient.authorizeScopes(scopes);

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken:
              authorization.accessToken, // Access via the authorized client
          idToken: googleAuth.idToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      rethrow;
    }
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint("Email Sign-In Error: ${e.code}");
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint("Sign-Out Error: $e");
    }
  }
}
