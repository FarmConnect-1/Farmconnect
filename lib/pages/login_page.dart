import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final FocusNode _identifierFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  bool _isOtpMode = true; // Start with OTP login by default
  String? _verificationId;

  Future<void> _navigateToHome(User user) async {
    try {
      // Fetch user data from Firestore
      final doc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
      if (!doc.exists) {
        throw 'User data not found in database.';
      }

      // Get the user's role
      final role = doc.data()?['role'];
      if (role == 'farmer') {
        Navigator.pushReplacementNamed(context, '/farmer_home');
      } else if (role == 'retailer') {
        Navigator.pushReplacementNamed(context, '/retailer_home');
      } else if (role == 'transporter') {
        Navigator.pushReplacementNamed(context, '/transporter_home');
      } else {
        throw 'Invalid or missing role for the user.';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navigation failed: $e')),
      );
    }
  }

  Future<void> _checkPhoneNumberAndSendOtp() async {
    try {
      String phoneNumber = _identifierController.text.trim();

      if (phoneNumber.isEmpty) {
        throw 'Phone number cannot be empty.';
      }

      if (!RegExp(r'^[0-9]{10}$').hasMatch(phoneNumber)) {
        throw 'Please enter a valid 10-digit phone number.';
      }

      // Add country code (India)
      phoneNumber = '+91$phoneNumber';

      final querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw 'Phone number not found. Please sign up first.';
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          final userCredential = await _auth.signInWithCredential(credential);
          if (userCredential.user != null) {
            _navigateToHome(userCredential.user!);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          throw 'Verification failed: ${e.message}';
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OTP sent to $phoneNumber')),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _verifyOtp() async {
    try {
      if (_verificationId == null) throw 'Verification ID is null.';

      if (_otpController.text.trim().isEmpty) {
        throw 'OTP cannot be empty.';
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        _navigateToHome(userCredential.user!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP verification failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleEmailPasswordLogin() async {
    try {
      final identifier = _identifierController.text.trim();
      final password = _passwordController.text.trim();

      if (identifier.isEmpty) throw 'Username or email cannot be empty.';
      if (password.isEmpty) throw 'Password cannot be empty.';

      String email;

      // Check if the identifier is a username
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('username', isEqualTo: identifier)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        email = querySnapshot.docs.first['email'];
      } else if (RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(identifier)) {
        email = identifier;
      } else {
        throw 'Invalid username or email format.';
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        _navigateToHome(userCredential.user!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  void _toggleLoginMode() {
    setState(() {
      _isOtpMode = !_isOtpMode;

      // Clear all input fields and remove focus
      _identifierController.clear();
      _passwordController.clear();
      _otpController.clear();
      _identifierFocusNode.unfocus();
      _passwordFocusNode.unfocus();
      _otpFocusNode.unfocus();
      _verificationId = null; // Reset OTP state
    });
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
                  //const SizedBox(height: 15),
                  const Center(
                    child: Text(
                      'Welcome back! Glad to see you, Again!',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildInputField(
                    controller: _identifierController,
                    labelText: _isOtpMode
                        ? 'Enter your phone number'
                        : 'Enter your username or email',
                    focusNode: _identifierFocusNode,
                  ),
                  const SizedBox(height: 15),
                  if (_isOtpMode && _verificationId != null)
                    _buildInputField(
                      controller: _otpController,
                      labelText: 'Enter OTP',
                      focusNode: _otpFocusNode,
                    ),
                  if (!_isOtpMode)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildInputField(
                          controller: _passwordController,
                          labelText: 'Enter your password',
                          obscureText: true,
                          focusNode: _passwordFocusNode,
                        ),
                        TextButton(
                          onPressed: () {
                            // Forgot Password logic can be added here
                          },
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: Color(0xFF006400)),
                          ),
                        ),
                      ],
                    ),
                  if (_isOtpMode && _verificationId != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _checkPhoneNumberAndSendOtp,
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Resend OTP',
                          style: TextStyle(color: Color(0xFF006400)),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isOtpMode
                        ? (_verificationId == null
                        ? _checkPhoneNumberAndSendOtp
                        : _verifyOtp)
                        : _handleEmailPasswordLogin,
                    child: Text(
                      _isOtpMode
                          ? (_verificationId == null ? 'Send OTP' : 'Verify OTP')
                          : 'Login',
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: IntrinsicWidth(
                      child: TextButton(
                        onPressed: _toggleLoginMode,
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          _isOtpMode
                              ? 'Use Email/Password Login'
                              : 'Use Phone Number Login',
                          style: const TextStyle(color: Color(0xFF006400)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Center(
                      child: IntrinsicWidth(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/signup');
                          },
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text.rich(
                            TextSpan(
                              text: 'Don’t have an account? ',
                              style: TextStyle(color: Colors.black),
                              children: [
                                TextSpan(
                                  text: 'Sign Up Now',
                                  style: TextStyle(color: Color(0xFF006400)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                  )
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
    FocusNode? focusNode,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      focusNode: focusNode,
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