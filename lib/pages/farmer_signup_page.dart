import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

import 'farmer_home_page.dart'; // Import the Farmer Home Page

class FarmerSignupPage extends StatefulWidget {
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

  const FarmerSignupPage({
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
  _FarmerSignupPageState createState() => _FarmerSignupPageState();
}

class _FarmerSignupPageState extends State<FarmerSignupPage> {
  File? _profilePhoto;
  File? _khasraDocument;
  File? _aadhaarDocument;
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _khasraController = TextEditingController();
  bool _isLoading = false;

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

  // Pick File for Khasra Nakal
  Future<void> _pickKhasraDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        _khasraDocument = File(result.files.single.path!);
      });
    }
  }

  // Save Data (All fields or partial fields depending on Skip for Now)
  Future<void> _saveData({bool skip = false}) async {
    // Validate required fields
    String aadhaar = _aadhaarController.text.trim();
    String khasra = _khasraController.text.trim();

    if (!skip) {
      if (aadhaar.isEmpty || khasra.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all the required fields')),
        );
        return;
      }

      // Check if Aadhaar is 12 digits long
      if (aadhaar.length != 12) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aadhaar Number must be 12 digits')),
        );
        return;
      }
    }

    // Set loading state
    setState(() {
      _isLoading = true;
    });

    try {
      // Create user with Firebase Authentication
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: widget.email,
        password: widget.password,
      );

      // Get the newly created user
      User? user = userCredential.user;

      if (user != null) {
        String profilePhotoUrl = '';

        // Upload profile photo to Firebase Storage if selected
        if (_profilePhoto != null) {
          try {
            final storageRef = FirebaseStorage.instance
                .ref()
                .child('profile_photos')
                .child(path.basename(_profilePhoto!.path));
            final uploadTask = storageRef.putFile(_profilePhoto!);
            final snapshot = await uploadTask.whenComplete(() => null);
            profilePhotoUrl = await snapshot.ref.getDownloadURL();
          } catch (e) {
            print('Error uploading profile photo: $e');
          }
        }

        // Create a document in Firestore with the user's UID
        final userDocRef = FirebaseFirestore.instance.collection('Users').doc(user.uid);

        await userDocRef.set({
          'username': widget.username,
          'email': widget.email,
          'phoneNumber': widget.phoneNumber,
          'address': widget.address,
          'pincode': widget.pincode,
          'state': widget.state,
          'district': widget.district,
          'taluka': widget.taluka,
          'aadhaar': aadhaar,
          'khasra': khasra,
          'role': widget.role,
          'profilePhotoUrl': profilePhotoUrl,
        });

        // Navigate to Farmer Home Page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => FarmerHomePage(
              username: widget.username,
              email: widget.email,
            ),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign Up successful!')),
        );
      }
    } catch (e) {
      // Handle signup errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: ${e.toString()}')),
      );
    } finally {
      // Reset loading state
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
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
                  // Profile Photo Input
                  const SizedBox(height: 8),
                  const Text('Profile Photo (Optional)', style: TextStyle(color: Colors.black, fontSize: 16)),
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

                  // "or" Text and "Take Picture" Button
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
                  const Text('Aadhaar Card', style: TextStyle(fontSize: 16)),
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

                  // Khasra Nakal Input Field
                  const Text('Khasra Nakal Document', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _khasraController,
                    decoration: InputDecoration(
                      labelText: 'Enter Khasra Nakal Number',
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
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
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