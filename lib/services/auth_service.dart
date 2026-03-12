import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stable constructor for version 6.2.1
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // --- WEB POPUP LOGIC ---
        GoogleAuthProvider googleProvider = GoogleAuthProvider();

        // select_account ensures the popup doesn't just "flash" and disappear
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        // Ensure persistence is local so the session stays after closing the tab
        await _auth.setPersistence(Persistence.LOCAL);

        // This opens the separate window.
        // Execution waits here until the popup is closed or finished.
        return await _auth.signInWithPopup(googleProvider);
      } else {
        // --- MOBILE LOGIC ---
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      // If you see "cross-origin-opener-policy", it's a browser header issue
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
