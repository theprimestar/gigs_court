import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final hasConnection = await _checkNetwork();
    if (!hasConnection) {
      setState(() {
        _errorMessage = 'No internet connection. Please check your network.';
      });
      return;
    }

    _navigateNext();
  }

  Future<bool> _checkNetwork() async {
    try {
      final result = await Future.any([
        Future.delayed(const Duration(seconds: 5)),
        Future.delayed(const Duration(milliseconds: 500), () => true),
      ]);
      return result == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _navigateNext() async {
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Check if profile exists in Firestore
      try {
        final doc = await FirebaseFirestore.instance
            .collection('profiles')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          Navigator.of(context).pushReplacementNamed('/profile-setup');
        }
      } catch (_) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    } else {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F71),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                );
              },
              child: Text(
                'GigsCourt',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your Service, Your Court',
              style: TextStyle(
                fontSize: 14,
                color: textColor.withValues(alpha: 0.7),
                letterSpacing: 0.8,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
