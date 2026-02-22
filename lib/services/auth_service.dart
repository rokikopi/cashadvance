import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  // Create a singleton or an instance to use across the app
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Get the current user
  User? get currentUser => _auth.currentUser;

  // 2. Stream of auth changes (to know if logged in/out)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 3. The Sign-In Function
  Future<UserCredential?> signInWithGoogle() async {
    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();

      if (kIsWeb) {
        // Optimized for your Web App
        return await _auth.signInWithPopup(googleProvider);
      } else {
        // Placeholder if you ever expand to mobile
        throw UnimplementedError("Mobile sign-in logic goes here");
      }
    } catch (e) {
      print("Auth Service Error: $e");
      return null;
    }
  }

  // 4. Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}