import 'package:flutter/material.dart';
import 'dart:async';
import 'landing.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin { //act as a vsync provider for animations
  late AnimationController _controller;// animation timing
  late Animation<Offset> _slideAnimation;// Moves the image vertically
  late Animation<double> _rotationAnimation;// Rotates the image.

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0.0, -1.5),// Starts above 1.5 above the screen (angle icon , bottom/top icon)
      end: Offset.zero, // ends at the original position
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _rotationAnimation = Tween<double>(
      begin: -1.0, //Starts rotated counterclockwise by 1 full turn
      end: 0.0, // no rotation
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward(); //Starts the animation as soon as the screen loads

    Timer(Duration(seconds: 3), () { //After 3 seconds, navigates to LandingScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LandingScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6E7D8),
      body: Center(
          child: SlideTransition(
            position: _slideAnimation,
            child: RotationTransition(
              turns: _rotationAnimation,
              child: Image.asset(
                'images/logoSB.png',
                width: 250,
                height: 250,
              ),
            ),
          ),
        ),
    );
  }
}
