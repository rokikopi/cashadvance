import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Centralize the GoogleSignIn configuration here
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '149500606282-bv0krkbqdji6pps6mt8mqkfhdo4p2d1d.apps.googleusercontent.com'
        : null,
    scopes: ['email', 'profile'],
  );

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        // Fix: Use await but don't return the result of signInWithRedirect
        // because it returns Future<void>.
        await _auth.signInWithRedirect(googleProvider);
        return null;
      } else {
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
      rethrow;
    }
  }

  /// NEW: Call this in your login page's initState to catch the user after redirect
  Future<UserCredential?> handleRedirectResult() async {
    if (kIsWeb) {
      try {
        return await _auth.getRedirectResult();
      } catch (e) {
        debugPrint("Error handling redirect: $e");
        return null;
      }
    }
    return null;
  }

  // Standard Email/Password Sign In
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
      // Sign out from Google (important to clear the session so the picker shows up next time)
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      // Sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      debugPrint("Sign-Out Error: $e");
    }
  }
}
