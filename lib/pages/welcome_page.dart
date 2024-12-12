import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/light_green.jpg'), // Path to the background image
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Content Overlaid on Background
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Section with Logo
              Column(
                children: [
                  const SizedBox(height: 70),
                  Center(
                    child: Image.asset(
                      'assets/logo1.png', // Path to the logo image
                      height: 350, // Increased height for the logo
                    ),
                  ),
                  const SizedBox(height: 20),
                  // const Center(
                  //   child: Text(
                  //     'Welcome to FarmConnect',
                  //     style: TextStyle(
                  //       fontSize: 24,
                  //       fontWeight: FontWeight.bold,
                  //       color: Colors.green, // Green color for the title
                  //     ),
                  //   ),
                  // ),
                ],
              ),
              // Buttons Section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 60), // Increased bottom padding
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity, // Full-width buttons
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18), // Button height
                          backgroundColor: Colors.green, // Black button color
                          foregroundColor: Colors.white, // White text color
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10), // Rounded corners
                          ),
                        ),
                        onPressed: () {
                          // Navigate to Login Page
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: const Text(
                          'Login',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity, // Full-width buttons
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18), // Button height
                          backgroundColor: Colors.white, // White button background
                          foregroundColor: Colors.black, // Black text color
                          //side: const BorderSide(color: Colors.black), // Black border
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10), // Rounded corners
                          ),
                        ),
                        onPressed: () {
                          // Navigate to Sign Up Page
                          Navigator.pushReplacementNamed(context, '/signup');
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}