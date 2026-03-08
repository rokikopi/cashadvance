import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Use the .instance getter for the GoogleSignIn plugin
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();

        // Ensures the user is asked to select their account every time
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        // FIX: Switch to Redirect to bypass the COOP "window.closed" block
        // Execution will stop here as the browser navigates to Google
        await _auth.signInWithRedirect(googleProvider);

        // Because of the redirect, this return is technically never reached
        // until the app reloads and the AuthGate takes over.
        return null;
      } else {
        // Mobile Logic (Android/iOS)
        // 1. Initialize the plugin
        await _googleSignIn.initialize();

        // 2. Authenticate the user to get the account
        final GoogleSignInAccount googleUser = await _googleSignIn
            .authenticate();

        // 3. Obtain the ID Token
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        // 4. Handle Access Token authorization explicitly
        final List<String> scopes = ['email', 'profile'];
        final authClient = googleUser.authorizationClient;
        final authorization = await authClient.authorizeScopes(scopes);

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: authorization.accessToken,
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
      // On Web, GoogleSignIn.signOut is often unnecessary with Redirect flow,
      // but we keep the platform check for safety.
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint("Sign-Out Error: $e");
    }
  }
}
