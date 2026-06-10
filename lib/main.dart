import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/splash_screen.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();

  final sessionService = SessionService();
  await sessionService.init();

  runApp(const VesakGOApp());
}

class VesakGOApp extends StatelessWidget {
  const VesakGOApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VesakGO',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
