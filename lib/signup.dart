import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'landing.dart';
import 'login.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  var name = TextEditingController();
  var email = TextEditingController();
  var phone = TextEditingController();
  var password = TextEditingController();
  var confirmPassword = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var error = "";

  // Country code dropdown
  String selectedCountryCode = '+60'; // Default to Malaysia

  // list of country codes
  final List<Map<String, String>> countryCodes = [
    // Southeast Asia
    {'code': '+60', 'name': 'Malaysia'},
    {'code': '+65', 'name': 'Singapore'},
    {'code': '+62', 'name': 'Indonesia'},
    {'code': '+66', 'name': 'Thailand'},
    {'code': '+63', 'name': 'Philippines'},
    {'code': '+84', 'name': 'Vietnam'},
    {'code': '+95', 'name': 'Myanmar'},
    {'code': '+856', 'name': 'Laos'},
    {'code': '+855', 'name': 'Cambodia'},
    {'code': '+673', 'name': 'Brunei'},

    // East Asia
    {'code': '+86', 'name': 'China'},
    {'code': '+852', 'name': 'Hong Kong'},
    {'code': '+853', 'name': 'Macau'},
    {'code': '+886', 'name': 'Taiwan'},
    {'code': '+81', 'name': 'Japan'},
    {'code': '+82', 'name': 'South Korea'},
    {'code': '+850', 'name': 'North Korea'},

    // South Asia
    {'code': '+91', 'name': 'India'},
    {'code': '+92', 'name': 'Pakistan'},
    {'code': '+880', 'name': 'Bangladesh'},
    {'code': '+94', 'name': 'Sri Lanka'},
    {'code': '+977', 'name': 'Nepal'},
    {'code': '+975', 'name': 'Bhutan'},
    {'code': '+960', 'name': 'Maldives'},
    {'code': '+93', 'name': 'Afghanistan'},

    // Middle East
    {'code': '+971', 'name': 'UAE'},
    {'code': '+966', 'name': 'Saudi Arabia'},
    {'code': '+974', 'name': 'Qatar'},
    {'code': '+965', 'name': 'Kuwait'},
    {'code': '+973', 'name': 'Bahrain'},
    {'code': '+968', 'name': 'Oman'},
    {'code': '+964', 'name': 'Iraq'},
    {'code': '+962', 'name': 'Jordan'},
    {'code': '+961', 'name': 'Lebanon'},
    {'code': '+963', 'name': 'Syria'},
    {'code': '+967', 'name': 'Yemen'},
    {'code': '+98', 'name': 'Iran'},
    {'code': '+972', 'name': 'Israel'},
    {'code': '+970', 'name': 'Palestine'},
    {'code': '+90', 'name': 'Turkey'},

    // Africa
    {'code': '+20', 'name': 'Egypt'},
    {'code': '+27', 'name': 'South Africa'},
    {'code': '+234', 'name': 'Nigeria'},
    {'code': '+254', 'name': 'Kenya'},
    {'code': '+233', 'name': 'Ghana'},
    {'code': '+255', 'name': 'Tanzania'},
    {'code': '+256', 'name': 'Uganda'},
    {'code': '+251', 'name': 'Ethiopia'},
    {'code': '+212', 'name': 'Morocco'},
    {'code': '+213', 'name': 'Algeria'},
    {'code': '+216', 'name': 'Tunisia'},
    {'code': '+218', 'name': 'Libya'},
    {'code': '+249', 'name': 'Sudan'},

    // Europe
    {'code': '+44', 'name': 'United Kingdom'},
    {'code': '+33', 'name': 'France'},
    {'code': '+49', 'name': 'Germany'},
    {'code': '+39', 'name': 'Italy'},
    {'code': '+34', 'name': 'Spain'},
    {'code': '+31', 'name': 'Netherlands'},
    {'code': '+41', 'name': 'Switzerland'},
    {'code': '+43', 'name': 'Austria'},
    {'code': '+32', 'name': 'Belgium'},
    {'code': '+46', 'name': 'Sweden'},
    {'code': '+47', 'name': 'Norway'},
    {'code': '+45', 'name': 'Denmark'},
    {'code': '+358', 'name': 'Finland'},
    {'code': '+48', 'name': 'Poland'},
    {'code': '+420', 'name': 'Czech Republic'},
    {'code': '+7', 'name': 'Russia'},
    {'code': '+380', 'name': 'Ukraine'},
    {'code': '+30', 'name': 'Greece'},
    {'code': '+351', 'name': 'Portugal'},
    {'code': '+353', 'name': 'Ireland'},

    // Americas
    {'code': '+1', 'name': 'USA/Canada'},
    {'code': '+52', 'name': 'Mexico'},
    {'code': '+55', 'name': 'Brazil'},
    {'code': '+54', 'name': 'Argentina'},
    {'code': '+56', 'name': 'Chile'},
    {'code': '+57', 'name': 'Colombia'},
    {'code': '+51', 'name': 'Peru'},
    {'code': '+58', 'name': 'Venezuela'},

    // Oceania
    {'code': '+61', 'name': 'Australia'},
    {'code': '+64', 'name': 'New Zealand'},
    {'code': '+679', 'name': 'Fiji'},
    {'code': '+675', 'name': 'Papua New Guinea'},
  ];

  void showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Congratulations!"),
          content: Text("You've registered an account successfully."),
          actions: [
            TextButton(
              child: Text("OK", style: TextStyle(color: Colors.green, fontSize: 20)),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
            ),
          ],
        );
      },
    );
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
              MaterialPageRoute(builder: (context) => LandingScreen()),
            );
          },
        ),
        title: Row(
          children: [
            Icon(Icons.restaurant, color: Colors.white),
            SizedBox(width: 8),
            Text('Share Bites', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView( // make scrollable avoid overflow
              child: Column(
                children: [
                  Text(
                    "Sign Up",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),

                  // Name Field
                  TextFormField(
                    decoration: InputDecoration( //defines the visual styling for text input fields
                      hintText: "Enter your name",
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    controller: name,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name!';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),

                  // Email Field
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: "Enter your email address",
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    controller: email,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an email address!';
                      } else if (!RegExp(
                        r'^[\w-]+(\.[\w-]+)*@[\w-]+(\.[\w-]+)+$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),

                  // Phone Number Label
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Phone Number',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),

                  // Phone Number Field with Country Code Dropdown
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Country Code Dropdown
                      Container(
                        width: 80,
                        child: DropdownButtonFormField<String>(
                          value: selectedCountryCode,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                          ),
                          isExpanded: true,
                          menuMaxHeight: 300,
                          items: countryCodes.map((country) {
                            return DropdownMenuItem<String>(
                              value: country['code'],
                              child: Text(
                                '${country['name']} ${country['code']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedCountryCode = value!;
                            });
                          },
                          selectedItemBuilder: (BuildContext context) {
                            return countryCodes.map((country) {
                              return Center(
                                child: Text(
                                  country['code']!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF8F1402),
                                  ),
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      SizedBox(width: 12),

                      // Phone Number Input
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            hintText: "Enter phone number",
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: Icon(Icons.phone_android, color: Colors.grey.shade600),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade400),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Color(0xFF8F1402), width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.red, width: 1),
                            ),
                          ),
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(fontSize: 15),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your phone number!';
                            }
                            if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                              return 'Enter only numbers (no spaces or dashes)';
                            }
                            if (value.length < 7 || value.length > 15) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Helper text showing full number
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.grey.shade600),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              phone.text.isEmpty
                                  ? 'Your full number will be: $selectedCountryCode 123456789'
                                  : 'Your full number: $selectedCountryCode ${phone.text}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // Password Field
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: "Enter your password",
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    obscureText: true,
                    controller: password,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password!';
                      } else if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      //if (!value.contains(RegExp(r'[0-9]'))) {
                      //       return 'Password must contain at least one number';
                      //     }
                      //if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                       // return 'Password must contain at least one special character';
                      //}
                      // OR
                      //final strongPasswordRegex = RegExp(
                      //     r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$'
                      //   );
                      //
                      //   if (!strongPasswordRegex.hasMatch(value)) {
                      //     return 'Password must be 8+ chars with uppercase, lowercase, number, and special character';
                      //   }
                      return null;
                    },
                  ),
                  SizedBox(height: 20),

                  // Confirm Password Field
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: "Confirm your password",
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                    obscureText: true,
                    controller: confirmPassword,
                    validator: (value) {
                      if (value != password.text) {
                        return 'Passwords do not match!';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 30),

                  // Create Account Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF8F1402),
                    ),
                    child: Text(
                      'Create New Account',
                      style: TextStyle(color: Colors.white),
                    ),
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        try {
                          // Combine country code with phone number
                          String fullPhoneNumber = selectedCountryCode + phone.text.trim();

                          // Create user with email/password
                          final credential = await FirebaseAuth.instance
                              .createUserWithEmailAndPassword(
                            email: email.text.trim(),
                            password: password.text,
                          );

                          await credential.user?.updateDisplayName(
                            name.text.trim(),
                          );
                          await credential.user?.reload();

                          // Save to Firestore with full phone number
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(credential.user!.uid)
                              .set({
                            'uid': credential.user!.uid,
                            'name': name.text.trim(),
                            'email': email.text.trim(),
                            'phone': fullPhoneNumber,
                            'countryCode': selectedCountryCode,
                          });

                          showSuccessDialog(context);
                        } catch (e) {
                          print('Error: $e');
                          setState(() {
                            error = e.toString();
                          });
                        }
                      }
                    },
                  ),
                  SizedBox(height: 15),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoginScreen(),
                            ),
                          );
                        },
                        child: Text(
                          "Log in",
                          style: TextStyle(
                            color: Color(0xFFCE1A00),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Error Message
                  if (error.isNotEmpty)
                    Text(
                      error,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
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