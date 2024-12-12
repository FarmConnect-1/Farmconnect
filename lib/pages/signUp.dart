import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'roleandaddress_page.dart'; // Import the next page
import 'package:path/path.dart' as path;

class SignUp extends StatelessWidget {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _reenterPasswordController = TextEditingController(); // Re-enter password controller

  // Function to validate email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    return emailRegex.hasMatch(email);
  }

  // Function to validate phone number (for India)
  bool _isValidPhoneNumber(String phoneNumber) {
    final phoneRegex = RegExp(r"^[6-9]\d{9}$");
    return phoneRegex.hasMatch(phoneNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/light_green.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 50),
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/welcome_page');
                      },
                    ),
                  ),
                  Center(
                    child: Image.asset('assets/logo1.png', height: 125),
                  ),
                  const Center(
                    child: Text(
                      'Hello! Sign Up to get started',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildInputField(
                    controller: _nameController,
                    labelText: 'Full Name',
                  ),
                  const SizedBox(height: 15),
                  _buildInputField(
                    controller: _emailController,
                    labelText: 'Email',
                  ),
                  const SizedBox(height: 15),
                  _buildInputField(
                    controller: _phoneNumberController,
                    labelText: 'Phone Number',
                  ),
                  const SizedBox(height: 15),
                  _buildInputField(
                    controller: _passwordController,
                    labelText: 'Password',
                    obscureText: true,
                  ),
                  const SizedBox(height: 15),
                  _buildInputField(
                    controller: _reenterPasswordController,
                    labelText: 'Re-enter Password',
                    obscureText: true,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      // Validate inputs
                      String name = _nameController.text.trim();
                      String email = _emailController.text.trim();
                      String phoneNumber = _phoneNumberController.text.trim();
                      String password = _passwordController.text.trim();
                      String reenteredPassword = _reenterPasswordController.text.trim();

                      // Check if fields are empty
                      if (name.isEmpty || email.isEmpty || phoneNumber.isEmpty || password.isEmpty || reenteredPassword.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All fields are mandatory!')),
                        );
                        return;
                      }

                      // Validate email format
                      if (!_isValidEmail(email)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid email address')),
                        );
                        return;
                      }

                      // Validate phone number
                      if (!_isValidPhoneNumber(phoneNumber)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
                        );
                        return;
                      }

                      // Add '+91' to phone number before saving
                      phoneNumber = '+91' + phoneNumber;

                      // Check if passwords match
                      if (password != reenteredPassword) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Passwords do not match')),
                        );
                        return;
                      }

                      // Navigate to the next page and pass the collected data
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RoleAndAddressPage(
                            name: name,
                            email: email,
                            phoneNumber: phoneNumber,
                            password: password,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Next',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text.rich(
                      TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(color: Colors.black),
                        children: [
                          TextSpan(
                            text: 'Log in now',
                            style: TextStyle(color: Color(0xFF006400)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Fixed progress bar at the bottom
                  const LinearProgressIndicator(
                    value: 0.33, // Represents 33% progress
                    backgroundColor: Colors.white,
                    color: Colors.green, // Progress bar color
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String labelText,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.grey[300],
      ),
    );
  }
}