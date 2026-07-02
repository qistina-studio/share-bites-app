import 'package:flutter/material.dart';
import 'signup.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6E7D8),
        body: SafeArea(
          //SafeArea ensures content is not hidden by notches/status bars.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, // puts space between top, middle, and bottom elements.
            children: [
              Center(
                child: Padding(
                  padding: EdgeInsets.all(50.0),
                  child: Text(
                    'Eat smart. Share more. Waste less.',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFCE1A00),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              Expanded( // allows the image to take up the remaining vertical space
                child: Center(
                  child: Image.asset(
                    "images/LogoSB.png",
                    width: 300,
                    height: 300,
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 50.0, vertical: 50),
                child: SizedBox(
                  width: 120,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignUpScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFF6E7D8),
                      padding: EdgeInsets.symmetric(vertical: 25),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      'Join Now',
                      style: TextStyle(fontSize: 15, color: Color(0xFFCE1A00)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}
