import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isSignup = false;
  String? _selectedRole;
  String? _selectedState;
  String? _selectedDistrict;
  String? _selectedTaluka;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _farmerCertificateController = TextEditingController();
  final TextEditingController _gatSurveyController = TextEditingController();

  final Map<String, List<String>> states = {
    'Maharashtra': ['Pune', 'Mumbai', 'Nagpur'],
    'Gujarat': ['Ahmedabad', 'Surat', 'Rajkot'],
    'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai'],
  };

  final Map<String, List<String>> talukas = {
    'Pune': ['Taluka 1', 'Taluka 2'],
    'Mumbai': ['Taluka 3', 'Taluka 4'],
    'Nagpur': ['Taluka 5', 'Taluka 6'],
    'Ahmedabad': ['Taluka 7', 'Taluka 8'],
    'Surat': ['Taluka 9', 'Taluka 10'],
    'Rajkot': ['Taluka 11', 'Taluka 12'],
    'Chennai': ['Taluka 13', 'Taluka 14'],
    'Coimbatore': ['Taluka 15', 'Taluka 16'],
    'Madurai': ['Taluka 17', 'Taluka 18'],
  };

  void _redirectToHomePage(String role) {
    if (role == 'farmer') {
      Navigator.pushReplacementNamed(context, '/farmer_home');
    } else if (role == 'retailer') {
      Navigator.pushReplacementNamed(context, '/retailer_home');
    } else if (role == 'transport_provider') {
      Navigator.pushReplacementNamed(context, '/transporter_home');
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
            'farmerCertificateNumber': _farmerCertificateController.text.trim(),
            'address': _addressController.text.trim(),
            'district': _selectedDistrict,
            'state': _selectedState,
            'taluka': _selectedTaluka,
            'GATSurveyNumber': _gatSurveyController.text.trim(),
          } else if (_selectedRole == 'retailer' || _selectedRole == 'transport_provider') ...{
            'address': _addressController.text.trim(),
            'district': _selectedDistrict,
            'state': _selectedState,
            'taluka': _selectedTaluka,
          }
        });

        _redirectToHomePage(_selectedRole!);
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
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
        final String role = userDoc['role'];
        _redirectToHomePage(role);
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
              Image.asset('assets/logo1.png', height: 100), // Add your logo here
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
                if (_selectedRole != null) ...[
                  _buildInputField(
                    controller: _usernameController,
                    labelText: 'Username',
                  ),
                  if (_selectedRole == 'farmer') ...[
                    _buildInputField(
                      controller: _farmerCertificateController,
                      labelText: 'Farmer Certificate Number',
                    ),
                    _buildInputField(
                      controller: _addressController,
                      labelText: 'Address',
                    ),
                    _buildDropdown(
                      hint: 'Select State',
                      value: _selectedState,
                      items: states.keys.toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedState = value;
                          _selectedDistrict = null;
                          _selectedTaluka = null;
                        });
                      },
                    ),
                    if (_selectedState != null) ...[
                      _buildDropdown(
                        hint: 'Select District',
                        value: _selectedDistrict,
                        items: states[_selectedState]!,
                        onChanged: (value) {
                          setState(() {
                            _selectedDistrict = value;
                            _selectedTaluka = null;
                          });
                        },
                      ),
                    ],
                    if (_selectedDistrict != null) ...[
                      _buildDropdown(
                        hint: 'Select Taluka',
                        value: _selectedTaluka,
                        items: talukas[_selectedDistrict]!,
                        onChanged: (value) {
                          setState(() {
                            _selectedTaluka = value;
                          });
                        },
                      ),
                    ],
                    _buildInputField(
                      controller: _gatSurveyController,
                      labelText: 'GAT Survey Number',
                    ),
                  ] else if (_selectedRole == 'retailer' || _selectedRole == 'transport_provider') ...[
                    _buildInputField(
                      controller: _addressController,
                      labelText: 'Address',
                    ),
                    _buildDropdown(
                      hint: 'Select State',
                      value: _selectedState,
                      items: states.keys.toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedState = value;
                          _selectedDistrict = null;
                          _selectedTaluka = null;
                        });
                      },
                    ),
                    if (_selectedState != null) ...[
                      _buildDropdown(
                        hint: 'Select District',
                        value: _selectedDistrict,
                        items: states[_selectedState]!,
                        onChanged: (value) {
                          setState(() {
                            _selectedDistrict = value;
                            _selectedTaluka = null;
                          });
                        },
                      ),
                    ],
                    if (_selectedDistrict != null) ...[
                      _buildDropdown(
                        hint: 'Select Taluka',
                        value: _selectedTaluka,
                        items: talukas[_selectedDistrict]!,
                        onChanged: (value) {
                          setState(() {
                            _selectedTaluka = value;
                          });
                        },
                      ),
                    ],
                  ],
                ],
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
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: labelText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<String>(
        hint: Text(hint),
        value: value,
        isExpanded: true,
        underline: Container(),
        onChanged: onChanged,
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      ),
    );
  }
}
