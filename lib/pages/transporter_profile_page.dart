import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class TransporterProfilePage extends StatefulWidget {
  const TransporterProfilePage({super.key});

  @override
  _TransporterProfilePageState createState() => _TransporterProfilePageState();
}

class _TransporterProfilePageState extends State<TransporterProfilePage> {
  String? _availabilityStatus;
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _truckNameController = TextEditingController();
  final TextEditingController _truckNumberController = TextEditingController();
  final TextEditingController _truckCapacityController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _ownerContactController = TextEditingController();
  File? _truckImageFile;
  String? _truckImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadTransporterDetails();
  }

  // Function to load transporter details
  Future<void> _loadTransporterDetails() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot transporterData =
      await FirebaseFirestore.instance.collection('Transport').doc(user.uid).get();
      if (transporterData.exists) {
        setState(() {
          _availabilityStatus = transporterData['availability'];
          _priceController.text = transporterData['price'].toString();
          _truckNameController.text = transporterData['truckName'] ?? '';
          _truckNumberController.text = transporterData['truckNumber'] ?? '';
          _truckCapacityController.text = transporterData['truckCapacity'] ?? '';
          _ownerNameController.text = transporterData['ownerName'] ?? '';
          _ownerContactController.text = transporterData['ownerContact'] ?? '';
          _truckImageUrl = transporterData['truckImageUrl'];
        });
      }
    }
  }

  // Function to update availability, price, and truck details
  Future<void> _updateTransporterDetails() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (_truckImageFile != null) {
        _truckImageUrl = await _uploadTruckImage(user.uid);
      }

      await FirebaseFirestore.instance.collection('Transport').doc(user.uid).set({
        'providerId': user.uid,
        'availability': _availabilityStatus,
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'truckName': _truckNameController.text.trim(),
        'truckNumber': _truckNumberController.text.trim(),
        'truckCapacity': _truckCapacityController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'ownerContact': _ownerContactController.text.trim(),
        'truckImageUrl': _truckImageUrl,
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Details updated successfully!')),
      );
    }
  }

  // Function to upload truck image to Firebase Storage
  Future<String?> _uploadTruckImage(String uid) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child('truck_images/$uid.jpg');
      final uploadTask = storageRef.putFile(_truckImageFile!);
      final snapshot = await uploadTask.whenComplete(() => {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Function to pick an image from the gallery
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _truckImageFile = File(pickedFile.path);
      });
    }
  }

  // Function to set availability status
  void _setAvailability(String status) {
    setState(() {
      _availabilityStatus = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transporter Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text(
                'Manage Your Transport Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // Availability buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () => _setAvailability('available'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _availabilityStatus == 'available' ? Colors.green : Colors.grey,
                    ),
                    child: const Text('Available'),
                  ),
                  ElevatedButton(
                    onPressed: () => _setAvailability('unavailable'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _availabilityStatus == 'unavailable' ? Colors.red : Colors.grey,
                    ),
                    child: const Text('Unavailable'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Edit transport price
              TextField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Transport Price',
                  hintText: 'Enter your transport price',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              // Truck details
              TextField(
                controller: _truckNameController,
                decoration: const InputDecoration(
                  labelText: 'Truck Name',
                  hintText: 'Enter your truck name',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _truckNumberController,
                decoration: const InputDecoration(
                  labelText: 'Truck Number',
                  hintText: 'Enter your truck number',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _truckCapacityController,
                decoration: const InputDecoration(
                  labelText: 'Truck Capacity',
                  hintText: 'Enter your truck capacity',
                ),
              ),
              const SizedBox(height: 20),
              // Owner details
              TextField(
                controller: _ownerNameController,
                decoration: const InputDecoration(
                  labelText: 'Owner Name',
                  hintText: 'Enter owner name',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ownerContactController,
                decoration: const InputDecoration(
                  labelText: 'Owner Contact',
                  hintText: 'Enter owner contact number',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              // Truck image section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text('Upload Truck Image'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Display truck image
              _truckImageFile != null
                  ? Image.file(
                _truckImageFile!,
                height: 150,
                width: 150,
              )
                  : _truckImageUrl != null
                  ? Image.network(
                _truckImageUrl!,
                height: 150,
                width: 150,
              )
                  : const Text('No image selected'),
              const SizedBox(height: 20),
              // Save button
              ElevatedButton(
                onPressed: _updateTransporterDetails,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                child: const Text('Save Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}