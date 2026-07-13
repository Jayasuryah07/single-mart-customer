import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }
  runApp(const SingleMartApp());
}

class SingleMartApp extends StatelessWidget {
  const SingleMartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SingleMart',
      debugShowCheckedModeBanner: false,
      
      // Global Theme Configs (Modern White/Light Theme)
      themeMode: ThemeMode.light,
      theme: AppTheme.lightTheme,
      
      home: const SplashScreen(),
    );
  }
}
