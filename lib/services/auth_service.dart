import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stable constructor for version 6.2.1
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Handles Google Sign-In for both Web and Mobile.
  /// Includes a fix to initialize a Firestore document to prevent "stuck" loading.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential userCredential;

      if (kIsWeb) {
        // --- WEB POPUP LOGIC ---
        GoogleAuthProvider googleProvider = GoogleAuthProvider();

        // select_account ensures the popup doesn't just "flash" and disappear
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        // Ensure persistence is local so the session stays after closing the tab
        await _auth.setPersistence(Persistence.LOCAL);

        // This opens the separate window.
        userCredential = await _auth.signInWithPopup(googleProvider);
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

        userCredential = await _auth.signInWithCredential(credential);
      }

      // --- THE FIX: INITIALIZE FIRESTORE DOCUMENT ---
      // This ensures UserRoleGate in main.dart doesn't hang waiting for a doc that isn't there.
      if (userCredential.user != null) {
        await _initializeUserDocument(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      // If you see "cross-origin-opener-policy", it's a browser header issue
      rethrow;
    }
  }

  /// Helper method to ensure a Firestore document exists for the user.
  /// We use merge: true so we don't overwrite existing user data (like isAdmin status).
  Future<void> _initializeUserDocument(User user) async {
    final userDoc = _db.collection('users').doc(user.uid);

    // We only set the bare essentials.
    // Your RegisterPage will eventually fill in the rest.
    await userDoc.set({
      'uid': user.uid,
      'email': user.email,
      'lastLogin': FieldValue.serverTimestamp(),
      // We do NOT set isAdmin here to avoid overwriting an existing admin's status
    }, SetOptions(merge: true));
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
