import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ADD THIS
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/splash_page.dart';
import 'screens/home_page.dart';
import 'screens/admin_page.dart'; // ADD THIS

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CashAdvance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E5BFF)),
        useMaterial3: true,
      ),
      // Set up named routes so your logout button works correctly
      routes: {
        '/': (context) => const AuthGate(),
        '/login': (context) => const SplashPage(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If a user is logged in, we now need to check their role
        if (snapshot.hasData) {
          return UserRoleGate(uid: snapshot.data!.uid);
        }

        return const SplashPage();
      },
    );
  }
}

/// This widget checks the Firestore 'users' collection for the isAdmin flag
class UserRoleGate extends StatelessWidget {
  final String uid;
  const UserRoleGate({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        // While checking Firestore
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If the document exists, check the isAdmin field
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final bool isAdmin = data['isAdmin'] ?? false;

          if (isAdmin) {
            return const AdminPage();
          } else {
            return const HomePage();
          }
        }

        // Fallback if user document is missing (e.g., deleted from DB but still logged in)
        return const SplashPage();
      },
    );
  }
}
