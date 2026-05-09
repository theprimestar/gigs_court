import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/verify_email_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  runApp(const GigsCourtApp());
}

class GigsCourtApp extends StatelessWidget {
  const GigsCourtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GigsCourt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF1A1F71),
        scaffoldBackgroundColor: const Color(0xFFF8F9FC),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1A1F71),
        scaffoldBackgroundColor: const Color(0xFF0F1221),
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/auth': (context) => const AuthScreen(),
        '/verify-email': (context) => const VerifyEmailScreen(),
        '/profile-setup': (context) =>
            const _Placeholder(label: 'Profile Setup'),
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String label;
  const _Placeholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(label)),
    );
  }
}
