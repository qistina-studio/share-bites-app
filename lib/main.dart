import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:share_bites/splash.dart';
import 'package:share_bites/landing.dart';
import 'package:share_bites/login.dart';
import 'package:share_bites/signup.dart';
import 'package:share_bites/home.dart';
import 'firebase_options.dart';

//Flutter initializes and Firebase is configured
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget { //doesn't need to maintain any state; it just returns the app structure.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp( //Root widget that provides Material Design
      title: 'Share Bites',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: const Color(0xFFF6E7D8),
      ),
      // Define named routes for navigation
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/landing': (context) => const LandingScreen(),
        '/signup': (context) => const SignUpScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}