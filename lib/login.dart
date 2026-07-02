import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'signup.dart';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String loginError = "";
  void sendPasswordReset() async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent!')),
      );
    } catch (e) {
      setState(() {
        loginError = 'Failed to send reset email';
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF6E7D8),
      appBar: AppBar(
        backgroundColor: Color(0xFF8F1402),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => SignUpScreen()),
            );
          },
        ),
        title: Row(
          children: [
            Icon(Icons.restaurant, color: Colors.white),
            SizedBox(width: 8),
            Text('Share Bites', style: TextStyle(color: Colors.white),),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Login",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),
                  TextFormField(
                    maxLength: 30,
                    decoration: InputDecoration(
                      hintText: "Enter your email address here",
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    controller: email,
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Please enter an email address!';
                      final emailRegex = RegExp(
                        r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
                      );
                      if (!emailRegex.hasMatch(value))
                        return 'Please enter a valid email address';
                      return null;
                    },
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: "Enter your password here",
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true, //hides the password when typed
                    controller: password,
                    validator: (value) =>
                    value == null || value.isEmpty
                        ? 'Please enter your password!'
                        : null,
                  ),
                  SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: sendPasswordReset,
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(color: Color(0xFFCE1A00)),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF8F1402),
                    ),
                    child: Text(
                      'Login',
                      style: TextStyle(color: Colors.white),
                    ),
                    // validate login
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        setState(() {
                          loginError = "";
                        });
                        try {
                          await FirebaseAuth.instance.signInWithEmailAndPassword(
                            email: email.text.trim(),
                            password: password.text,
                          );
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => HomeScreen()),
                          );
                        } on FirebaseAuthException catch (e) {
                          setState(() {
                            if (e.code == 'user-not-found') {
                              loginError = 'Invalid email! Please try again.';
                            } else if (e.code == 'wrong-password') {
                              loginError = 'Incorrect password! Please try again.';
                            } else {
                              loginError = 'Login failed. Please try again.';
                            }
                          });
                        } catch (e) {
                          setState(() {
                            loginError = 'Unexpected error. Please try again.';
                          });
                        }
                      }
                    },
                  ),
                  SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SignUpScreen(),
                            ),
                          );
                        },
                        child: Text(
                          "Sign up",
                          style: TextStyle(
                            color: Color(0xFFCE1A00),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  if (loginError.isNotEmpty)
                    Text(
                      loginError,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
