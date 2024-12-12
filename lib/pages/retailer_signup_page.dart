import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'retailer_home_page.dart';

class RetailerSignupPage extends StatefulWidget {
  final String username;
  final String email;
  final String phoneNumber;
  final String password;
  final String address;
  final String pincode;
  final String? state;
  final String? district;
  final String? taluka;
  final String role;

  const RetailerSignupPage({
    Key? key,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.password,
    required this.address,
    required this.pincode,
    this.state,
    this.district,
    this.taluka,
    required this.role,
  }) : super(key: key);

  @override
  _RetailerSignupPageState createState() => _RetailerSignupPageState();
}

class _RetailerSignupPageState extends State<RetailerSignupPage> {
  File? _profilePhoto;
  File? _gstDocument;
  File? _aadhaarDocument;
  File? _tradeLicenseDocument;

  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _gstController = TextEditingController();
  final TextEditingController _tradeLicenseController = TextEditingController();

  // Pick Image for Profile Photo
  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _profilePhoto = File(pickedFile.path);
      });
    }
  }

  // Upload Profile Photo from Gallery
  Future<void> _uploadProfilePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profilePhoto = File(pickedFile.path);
      });
    }
  }

  // Pick File for GST Document
  Future<void> _pickGstDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        _gstDocument = File(result.files.single.path!);
      });
    }
  }

  // Pick File for Aadhaar Document
  Future<void> _pickAadhaarDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        _aadhaarDocument = File(result.files.single.path!);
      });
    }
  }

  // Pick File for Trade License Document
  Future<void> _pickTradeLicenseDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        _tradeLicenseDocument = File(result.files.single.path!);
      });
    }
  }

  // Validate Aadhaar Number (must be 12 digits)
  bool _isValidAadhaar(String aadhaar) {
    final aadhaarRegex = RegExp(r"^\d{12}$");
    return aadhaarRegex.hasMatch(aadhaar);
  }

  // Upload files to Firebase Storage and get URLs
  Future<String?> _uploadFileToFirebase(File file, String folderName) async {
    try {
      String fileName = path.basename(file.path);
      Reference storageRef = FirebaseStorage.instance.ref().child('$folderName/$fileName');
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading file: $e')),
      );
      return null;
    }
  }

  // Save Data to Firestore
  Future<void> _saveData({bool skip = false}) async {
    String aadhaar = _aadhaarController.text.trim();

    // Validate Aadhaar field
    if (aadhaar.isEmpty || !_isValidAadhaar(aadhaar)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aadhaar Number must be 12 digits')),
      );
      return;
    }

    // Upload the profile photo if available
    String? profilePhotoUrl;
    if (_profilePhoto != null) {
      profilePhotoUrl = await _uploadFileToFirebase(_profilePhoto!, 'profile_photos');
    }

    // Save other data to Firestore
    try {
      await FirebaseFirestore.instance.collection('Users').add({
        'username': widget.username,
        'email': widget.email,
        'phoneNumber': widget.phoneNumber,
        'address': widget.address,
        'pincode': widget.pincode,
        'state': widget.state,
        'district': widget.district,
        'taluka': widget.taluka,
        'aadhaar': aadhaar,
        'gst': _gstController.text,
        'tradeLicense': _tradeLicenseController.text,
        'profilePhotoUrl': profilePhotoUrl,
        'role': widget.role,
      });

      // After saving, navigate to Retailer Home Page and send all the data
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RetailerHome(
            username: widget.username,
            email: widget.email,
          ),
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign Up successful!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving data: $e')),
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 15),

                  // Profile Photo Input
                  const Text('Profile Photo (Optional)', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _uploadProfilePhoto,
                    child: CircleAvatar(
                      backgroundColor: Colors.grey[300],
                      radius: 55,
                      backgroundImage: _profilePhoto != null
                          ? FileImage(_profilePhoto!)
                          : const AssetImage('assets/default_profile.png') as ImageProvider,
                      child: _profilePhoto == null
                          ? const Icon(Icons.add_photo_alternate_rounded, color: Colors.grey, size: 30)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // "or" Text and "Take Picture" Button below the CircleAvatar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('or', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickProfilePhoto,
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        label: const Text(
                          'Take Picture',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Aadhaar Card Input Field
                  const Text('Aadhaar Card (Mandatory)', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _aadhaarController,
                    decoration: InputDecoration(
                      labelText: 'Enter Aadhaar Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[300],
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),

                  // GST Registration Input Field
                  const Text('GST Registration (Optional)', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _gstController,
                    decoration: InputDecoration(
                      labelText: 'Enter GST Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Trade License Input Field
                  const Text('Trade License (Optional)', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tradeLicenseController,
                    decoration: InputDecoration(
                      labelText: 'Enter Trade License Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _saveData(skip: false),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(
                    value: 1.0,
                    backgroundColor: Colors.white,
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}