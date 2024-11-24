import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // For JSON decoding
import 'package:http/http.dart' as http; // For API calls

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isSignup = false;
  String? _selectedRole;
  String? _villageName;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _farmerCertificateController = TextEditingController();
  final TextEditingController _gatSurveyController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  String? _state;
  String? _district;
  String? _taluka;
  List<String> _villages = [];

  Future<void> _fetchLocationData(String pincode) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.postalpincode.in/pincode/$pincode'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty && data[0]['Status'] == 'Success') {
          final postOffices = data[0]['PostOffice'];
          setState(() {
            _state = postOffices[0]['State'];
            _district = postOffices[0]['District'];
            _taluka = postOffices[0]['Block'];
            _villages = postOffices.map<String>((office) => office['Name'] as String).toList();
          });
        } else {
          throw Exception('Invalid or empty response for pincode');
        }
      } else {
        throw Exception('Failed to load location data');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching location data: $e')),
      );
    }
  }

  void _handleSignup() async {
    try {
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
          'username': _usernameController.text.trim(),
          'email': user.email,
          'role': _selectedRole,
          if (_selectedRole == 'farmer') ...{
            'phoneNumber': _phoneNumberController.text.trim(),
            'farmerCertificateNumber': _farmerCertificateController.text.trim(),
            'address': _addressController.text.trim(),
            'district': _district,
            'state': _state,
            'taluka': _taluka,
            'village': _villageName,
            'GATSurveyNumber': _gatSurveyController.text.trim(),
          }
        });

        Navigator.pushReplacementNamed(context, '/farmer_home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: $e')),
      );
    }
  }

  void _handleLogin() async {
    try {
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = userCredential.user;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
        if (doc.exists) {
          final role = doc.data()?['role'];
          if (role == 'farmer') {
            Navigator.pushReplacementNamed(context, '/farmer_home');
          } else if (role == 'retailer') {
            Navigator.pushReplacementNamed(context, '/retailer_home');
          } else if (role == 'transport_provider') {
            Navigator.pushReplacementNamed(context, '/transport_home');
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignup ? 'Signup' : 'Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Image.asset('assets/logo1.png', height: 100),
              const SizedBox(height: 20),
              _buildInputField(
                controller: _emailController,
                labelText: 'Email',
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: _passwordController,
                labelText: 'Password',
                obscureText: true,
              ),
              const SizedBox(height: 10),
              if (_isSignup) ...[
                DropdownButton<String>(
                  hint: const Text('Select Role'),
                  value: _selectedRole,
                  items: ['farmer', 'retailer', 'transport_provider']
                      .map((role) => DropdownMenuItem(
                    value: role,
                    child: Text(role[0].toUpperCase() + role.substring(1)),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value;
                    });
                  },
                ),
                if (_selectedRole == 'farmer') ...[
                  _buildInputField(
                    controller: _usernameController,
                    labelText: 'Username',
                  ),
                  _buildInputField(
                    controller: _phoneNumberController,
                    labelText: 'Phone Number',
                  ),
                  _buildInputField(
                    controller: _farmerCertificateController,
                    labelText: 'Farmer Certificate Number',
                  ),
                  _buildInputField(
                    controller: _addressController,
                    labelText: 'Address',
                  ),
                  _buildInputField(
                    controller: _pincodeController,
                    labelText: 'Pincode',
                    onChanged: (value) {
                      if (value.length == 6) {
                        _fetchLocationData(value);
                      }
                    },
                  ),
                  if (_state != null) Text('State: $_state'),
                  if (_district != null) Text('District: $_district'),
                  if (_taluka != null) Text('Taluka: $_taluka'),
                  _buildVillageDropdown(),
                  _buildInputField(
                    controller: _gatSurveyController,
                    labelText: 'GAT Survey Number',
                  ),
                ]
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSignup ? _handleSignup : _handleLogin,
                child: Text(_isSignup ? 'Signup' : 'Login'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSignup = !_isSignup;
                  });
                },
                child: Text(_isSignup ? 'Already have an account? Login' : 'Don\'t have an account? Signup'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String labelText,
    bool obscureText = false,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: labelText),
    );
  }

  Widget _buildVillageDropdown() {
    return DropdownButton<String>(
      hint: const Text('Select or Enter Village'),
      value: _villageName,
      items: _villages
          .map((village) => DropdownMenuItem(
        value: village,
        child: Text(village),
      ))
          .toList(),
      onChanged: (value) {
        setState(() {
          _villageName = value;
        });
      },
    );
  }
}
