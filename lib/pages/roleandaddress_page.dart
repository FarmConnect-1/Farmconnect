import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For JSON decoding
import 'farmer_signup_page.dart';
import 'retailer_signup_page.dart';
import 'transporter_signup_page.dart';

class RoleAndAddressPage extends StatefulWidget {
  final String name;
  final String email;
  final String phoneNumber;
  final String password;

  const RoleAndAddressPage({
    Key? key,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.password,
  }) : super(key: key);

  @override
  _RoleAndAddressPageState createState() => _RoleAndAddressPageState();
}

class _RoleAndAddressPageState extends State<RoleAndAddressPage> {
  final Map<String, String> roleMapping = {
    'Farmer': 'farmer',
    'Retailer': 'retailer',
    'Transporter': 'transporter',
  };

  String? _selectedRole;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  String? _state, _district, _taluka;
  String? _villageName;
  List<String> _villages = [];
  List<String> _talukas = []; // List to store talukas

  bool _isLoading = false;  // Loading indicator for data fetching

  // Fetch location details based on pincode using an API
  Future<void> _fetchLocationData(String pincode) async {
    setState(() {
      _isLoading = true; // Show loading indicator while fetching data
    });

    final url = 'https://api.postalpincode.in/pincode/$pincode'; // Example for India

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty && data[0]['Status'] == 'Success') {
          final postOffices = data[0]['PostOffice'];

          // Remove duplicates dynamically
          setState(() {
            _state = postOffices[0]['State'];
            _district = postOffices[0]['District'];
            _taluka = postOffices[0]['Block'];

            // Remove duplicates for Taluka
            _talukas = postOffices
                .map<String>((office) => office['Block'] as String)
                .toSet() // Convert to a set to remove duplicates
                .toList(); // Convert back to list

            // Remove duplicates for Villages
            _villages = postOffices
                .map<String>((office) => office['Name'] as String)
                .toSet() // Convert to a set to remove duplicates
                .toList(); // Convert back to list

            _isLoading = false; // Hide loading indicator
          });
        } else {
          throw Exception('Invalid or empty response for pincode');
        }
      } else {
        throw Exception('Failed to load location data');
      }
    } catch (e) {
      setState(() {
        _isLoading = false; // Hide loading indicator in case of an error
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching location data: $e')),
      );
    }
  }

  void _goToNextRolePage() {
    // Validate all fields
    if (_addressController.text.isEmpty || _pincodeController.text.isEmpty || _selectedRole == null || _taluka == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are mandatory!')),
      );
      return;
    }

    // Validate that the pincode is 6 digits long
    if (_pincodeController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit pincode')),
      );
      return;
    }

    // Determine which page to navigate to based on the selected role
    if (_selectedRole == 'Farmer') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FarmerSignupPage(
            username: widget.name,
            email: widget.email,
            phoneNumber: widget.phoneNumber,
            password: widget.password,
            address: _addressController.text.trim(),
            pincode: _pincodeController.text.trim(),
            state: _state,
            district: _district,
            taluka: _taluka,
            role: _selectedRole!, // Pass role to FarmerSignupPage
          ),
        ),
      );
    } else if (_selectedRole == 'Retailer') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RetailerSignupPage(
            username: widget.name,
            email: widget.email,
            phoneNumber: widget.phoneNumber,
            password: widget.password,
            address: _addressController.text.trim(),
            pincode: _pincodeController.text.trim(),
            state: _state,
            district: _district,
            taluka: _taluka,
            role: _selectedRole!, // Pass role to RetailerSignupPage
          ),
        ),
      );
    } else if (_selectedRole == 'Transporter') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TransporterSignupPage(
            username: widget.name,
            email: widget.email,
            phoneNumber: widget.phoneNumber,
            password: widget.password,
            address: _addressController.text.trim(),
            pincode: _pincodeController.text.trim(),
            state: _state,
            district: _district,
            taluka: _taluka,
            role: _selectedRole!, // Pass role to TransporterSignupPage
          ),
        ),
      );
    }
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
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  Center(
                    child: Image.asset('assets/logo1.png', height: 125),
                  ),
                  _buildInputField(
                    controller: _addressController,
                    labelText: 'Address',
                  ),
                  const SizedBox(height: 15),
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
                  const SizedBox(height: 15),
                  _buildTalukaDropdown(),  // Add Taluka dropdown before Village dropdown
                  const SizedBox(height: 15),
                  _buildVillageDropdown(),  // Village dropdown
                  const SizedBox(height: 15),
                  _buildDropdown(
                    value: _selectedRole,
                    hintText: 'Select Role',
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value;
                      });
                    },
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
                    onPressed: _goToNextRolePage,
                    child: const Text(
                      'Next',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(
                    value: 0.66, // Represents 66% progress
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
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
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

  Widget _buildDropdown({
    required String? value,
    required String hintText,
    required Function(String?)? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 20),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black,
          width: 0.75,
        ),
      ),
      child: DropdownButton<String>(
        value: value,
        hint: Text(
          hintText,
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        isExpanded: true,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.green),
        dropdownColor: Colors.grey[300],
        items: roleMapping.keys
            .map((role) => DropdownMenuItem<String>(
          value: role,
          child: Text(
            role,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ))
            .toList(),
        onChanged: onChanged,
        underline: const SizedBox(),
      ),
    );
  }

  Widget _buildVillageDropdown() {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 20),  // Match padding to input fields
      decoration: BoxDecoration(
        color: Colors.grey[300], // Match background color to input fields
        borderRadius: BorderRadius.circular(10),  // Match border radius to input fields
        border: Border.all(
          color: Colors.black,  // Border color to match input fields
          width: 0.75,  // Border width to match input fields
        ),
      ),
      child: DropdownButton<String>(
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
        icon: const Icon(Icons.arrow_drop_down, color: Colors.green), // Arrow color change
        isExpanded: true, // Make dropdown expand to fill width
        underline: const SizedBox(), // Remove underline to make it cleaner
      ),
    );
  }

  Widget _buildTalukaDropdown() {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 20), // Match padding to input fields
      decoration: BoxDecoration(
        color: Colors.grey[300], // Match background color to input fields
        borderRadius: BorderRadius.circular(10), // Match border radius to input fields
        border: Border.all(
          color: Colors.black, // Border color to match input fields
          width: 0.75, // Border width to match input fields
        ),
      ),
      child: DropdownButton<String>(
        hint: const Text('Select Taluka'),
        value: _taluka,
        items: _talukas
            .map((taluka) => DropdownMenuItem<String>(
          value: taluka,
          child: Text(taluka),
        ))
            .toList(),
        onChanged: (value) {
          setState(() {
            // Make sure to only update the taluka value if it is in the list
            if (_talukas.contains(value)) {
              _taluka = value;
            } else {
              _taluka = null; // Reset to null if invalid value is selected
            }
          });
        },
        icon: const Icon(Icons.arrow_drop_down, color: Colors.green), // Arrow color change
        isExpanded: true, // Make dropdown expand to fill width
        underline: const SizedBox(), // Remove underline to make it cleaner
      ),
    );
  }
}