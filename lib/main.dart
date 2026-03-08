import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for persistence
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/splash_page.dart';
import 'screens/home_page.dart';
import 'screens/admin_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Patching URL strategy to remove the '#'
  usePathUrlStrategy();

  // Initializing Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // CRITICAL FIX: Ensure the login persists across page reloads on Web
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

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
      routes: {
        '/': (context) => const AuthGate(),
        '/login': (context) => const SplashPage(),
      },
      initialRoute: '/',
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // 1. Handle Initialization/Loading State
        // This prevents the "flash" of the login screen while Firebase is checking the session
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF2E5BFF)),
            ),
          );
        }

        // 2. If the user is authenticated, check their role in Firestore
        if (snapshot.hasData && snapshot.data != null) {
          return UserRoleGate(uid: snapshot.data!.uid);
        }

        // 3. If no user is found, default to the Splash/Login Page
        return const SplashPage();
      },
    );
  }
}

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final bool isAdmin = data['isAdmin'] ?? false;

          if (isAdmin) {
            return const AdminPage();
          } else {
            return const HomePage();
          }
        }

        // IMPORTANT: If user exists in Auth but not in Firestore (e.g., halfway through RegisterPage)
        // we stay on the Splash/Login context so they can complete registration
        return const SplashPage();
      },
    );
  }
}
