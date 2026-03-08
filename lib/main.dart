import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; // Required for usePathUrlStrategy
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'screens/splash_page.dart';
import 'screens/home_page.dart';
import 'screens/admin_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Patching URL strategy to remove the '#' which can interfere with popups/redirects
  usePathUrlStrategy();

  // Initializing Firebase with your generated options
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
      // Defined routes
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
  // Create a single instance to prevent unnecessary stream re-subscriptions
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading while checking authentication status
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is logged in, move to the Role Gate
        if (snapshot.hasData && snapshot.data != null) {
          return UserRoleGate(uid: snapshot.data!.uid);
        }

        // Otherwise, show the Splash/Login page
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

          // Simple conditional navigation based on Firestore 'isAdmin' field
          if (isAdmin) {
            return const AdminPage();
          } else {
            return const HomePage();
          }
        }

        // If data doesn't exist yet (e.g., first-time login), default to Splash
        return const SplashPage();
      },
    );
  }
}
