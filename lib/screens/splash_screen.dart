import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.celebration,
                size: 80,
                color: AppTheme.gold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'VesakGO',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.gold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'සුබ වෙසක් පොහොය දිනයක් වේවා!',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
