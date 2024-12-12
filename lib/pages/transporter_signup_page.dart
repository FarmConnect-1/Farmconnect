import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'transporter_home_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class TransporterSignupPage extends StatefulWidget {
  final String username;
  final String email;
  final String phoneNumber;
  final String password;
  final String address;
  final String pincode;
  final String? state;
  final String? district;
  final String? taluka;
  final String role; // Role passed from previous page

  const TransporterSignupPage({
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
  _TransporterSignupPageState createState() => _TransporterSignupPageState();
}

class _TransporterSignupPageState extends State<TransporterSignupPage> {
  final TextEditingController _businessRegController = TextEditingController();
  File? _businessRegDocument;
  File? _profilePhoto;

  // Pick File for Business Registration Certificate
  Future<void> _pickBusinessRegDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        _businessRegDocument = File(result.files.single.path!);
      });
    }
  }

  // Pick Image for Profile Photo
  Future<void> _uploadProfilePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profilePhoto = File(pickedFile.path);
      });
    }
  }

  // Pick Image for Profile Photo using Camera
  Future<void> _takeProfilePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _profilePhoto = File(pickedFile.path); // Update the profile photo with the taken picture
      });
    }
  }

  // Save Data to Firebase (Profile Picture in Storage and other data in Firestore)
  Future<void> _saveData() async {
    String? profilePhotoUrl;

    // If Profile Photo is provided, upload it to Firebase Storage
    if (_profilePhoto != null) {
      profilePhotoUrl = await _uploadFileToFirebase(_profilePhoto!, 'profile_photos');
    }

    // Saving data to Firestore
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
        'role': widget.role,
        'businessRegNumber': _businessRegController.text.trim(), // Save Business Registration Number
        'profilePhotoUrl': profilePhotoUrl,
      });

      // After saving, navigate to Transporter Home Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TransporterHomePage(
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

  // Helper method to upload a file to Firebase Storage
  Future<String> _uploadFileToFirebase(File file, String folderName) async {
    try {
      final storageReference = FirebaseStorage.instance.ref().child('$folderName/${path.basename(file.path)}');
      final uploadTask = storageReference.putFile(file);
      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw 'Error uploading file: $e';
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
                        Navigator.pop(context); // Go back to the previous page
                      },
                    ),
                  ),
                  Center(
                    child: Image.asset('assets/logo1.png', height: 125),
                  ),
                  // Profile Photo Input
                  const Text('Profile Photo', style: TextStyle(fontSize: 16)),
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
                  // "Take Picture" Button below the CircleAvatar, with "or" text
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('or', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _takeProfilePhoto,
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        label: const Text('Take Picture', style: TextStyle(color: Colors.white)),
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

                  // Business Registration Number Input Field
                  const Text('Business Registration Number', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _businessRegController,
                    decoration: InputDecoration(
                      labelText: 'Enter Business Registration Number',
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
                      onPressed: _saveData,
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
                    value: 1.0, // Represents 100% progress
                    backgroundColor: Colors.grey,
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
}