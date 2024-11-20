import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  _AddProductPageState createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController startingBidController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(); // New controller for quantity
  DateTime? _bidEndTime;
  List<File> _imageFiles = []; // List to store selected images
  File? _videoFile;
  bool _isLoading = false; // State to manage loading bar
  List<String> _imageUrls = []; // Store the uploaded image URLs
  String? _videoUrl; // Store the uploaded video URL

  // Function to take a new picture and upload immediately
  Future<void> _takePicture() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _isLoading = true; // Show loading while uploading the image
      });
      File imageFile = File(pickedFile.path);
      try {
        String? imageUrl = await _uploadFile(imageFile, 'Images'); // Upload the image immediately
        if (imageUrl != null) {
          setState(() {
            _imageFiles.add(imageFile); // Add image to the list for preview
            _imageUrls.add(imageUrl); // Add uploaded image URL to the list
          });
        }
      } catch (e) {
        print('Error uploading image: $e');
      } finally {
        setState(() {
          _isLoading = false; // Hide loading after upload
        });
      }
    }
  }

  // Function to record a new video and upload immediately
  Future<void> _recordVideo() async {
    final pickedFile = await ImagePicker().pickVideo(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _isLoading = true; // Show loading while uploading the video
      });
      _videoFile = File(pickedFile.path);
      try {
        _videoUrl = await _uploadFile(_videoFile!, 'Videos'); // Upload the video immediately
      } catch (e) {
        print('Error uploading video: $e');
      } finally {
        setState(() {
          _isLoading = false; // Hide loading after upload
        });
      }
    }
  }

  // Function to upload file to Firebase Storage
  Future<String?> _uploadFile(File file, String folder) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageRef = FirebaseStorage.instance.ref().child('$folder/$fileName');
      await storageRef.putFile(file);
      return await storageRef.getDownloadURL(); // Return the download URL
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  // Function to add the product to Firestore
  Future<void> _addProduct() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _isLoading = true; // Show loading while adding the product
      });

      // Add the product to the Firestore database
      try {
        await FirebaseFirestore.instance.collection('Products').add({
          'farmerId': user.uid,
          'productName': productNameController.text.trim(),
          'description': descriptionController.text.trim(),
          'startingBid': double.tryParse(startingBidController.text.trim()) ?? 0,
          'currentBid': 0,
          'highestBidder': '',
          'status': 'active',
          'quantity': int.tryParse(quantityController.text.trim()) ?? 0, // Save the quantity
          'productImages': _imageUrls, // Save all uploaded image URLs
          'productVideos': _videoUrl != null ? [_videoUrl!] : [], // Save the video URL if exists
          'bidEndTime': _bidEndTime,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );

        // Reset form fields after submission
        productNameController.clear();
        descriptionController.clear();
        startingBidController.clear();
        quantityController.clear(); // Clear quantity after submission
        _imageFiles.clear();
        _imageUrls.clear();
        _videoFile = null;
        _bidEndTime = null;

        // Redirect to farmer home page after successful product addition
        Navigator.of(context).pushNamedAndRemoveUntil('/farmer_home', (route) => false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding product: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false; // Hide loading after adding the product
        });
      }
    }
  }

  // Function to pick end time for the bid
  Future<void> _pickEndTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _bidEndTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Product'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              TextField(
                controller: productNameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: startingBidController,
                decoration: const InputDecoration(labelText: 'Starting Bid'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: quantityController, // Quantity input field
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _takePicture, // Farmer takes a new picture using the camera
                child: const Text('Take Picture'),
              ),
              const SizedBox(height: 10),
              // Display selected images
              if (_imageFiles.isNotEmpty)
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageFiles.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Image.file(
                          _imageFiles[index],
                          width: 150,
                          height: 150,
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _recordVideo, // Farmer records a new video using the camera
                child: const Text('Record Video'),
              ),
              if (_videoFile != null)
                const Text('Video recorded'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _pickEndTime(context), // Pick end time for the bid
                child: const Text('Pick Bid End Time'),
              ),
              if (_bidEndTime != null)
                Text('Bid End Time: ${_bidEndTime.toString()}'),
              const SizedBox(height: 20),
              _isLoading // Show loading indicator while uploading or adding product
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _addProduct, // Add the product to Firestore
                child: const Text('Add Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}