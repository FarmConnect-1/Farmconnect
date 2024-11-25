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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _selectedCategory;
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController startingBidController = TextEditingController();
  final TextEditingController totalQuantityController = TextEditingController();
  final TextEditingController minQuantityController = TextEditingController();
  final TextEditingController retailPriceController = TextEditingController();
  DateTime? _bidEndTime;
  final List<File> _imageFiles = [];
  File? _videoFile;
  bool _isLoading = false;
  final List<String> _imageUrls = [];
  String? _videoUrl;

  Future<void> _takePicture() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
      });
      File imageFile = File(pickedFile.path);
      try {
        String? imageUrl = await _uploadFile(imageFile, 'Images');
        if (imageUrl != null) {
          setState(() {
            _imageFiles.add(imageFile);
            _imageUrls.add(imageUrl);
          });
        }
      } catch (e) {
        print('Error uploading image: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _recordVideo() async {
    final pickedFile = await ImagePicker().pickVideo(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
      });
      _videoFile = File(pickedFile.path);
      try {
        _videoUrl = await _uploadFile(_videoFile!, 'Videos');
      } catch (e) {
        print('Error uploading video: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String?> _uploadFile(File file, String folder) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageRef = FirebaseStorage.instance.ref().child('$folder/$fileName');
      await storageRef.putFile(file);
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate() || _imageFiles.isEmpty || _bidEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        await FirebaseFirestore.instance.collection('Products').add({
          'farmerId': user.uid,
          'productName': productNameController.text.trim(),
          'category': _selectedCategory,
          'description': descriptionController.text.trim(),
          'startingBid': double.parse(startingBidController.text.trim()),
          'totalQuantity': int.parse(totalQuantityController.text.trim()),
          'minQuantity': int.parse(minQuantityController.text.trim()),
          'retailPrice': double.parse(retailPriceController.text.trim()),
          'availableQuantity': int.parse(totalQuantityController.text.trim()),
          'currentBid': 0,
          'highestBidder': '',
          'status': 'active',
          'productImages': _imageUrls,
          'productVideos': _videoUrl != null ? [_videoUrl!] : [],
          'bidEndTime': _bidEndTime,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );

        _resetForm();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding product: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _resetForm() {
    productNameController.clear();
    descriptionController.clear();
    startingBidController.clear();
    totalQuantityController.clear();
    minQuantityController.clear();
    retailPriceController.clear();
    _imageFiles.clear();
    _imageUrls.clear();
    _videoFile = null;
    _bidEndTime = null;

    Navigator.of(context).pushNamedAndRemoveUntil('/farmer_home', (route) => false);
  }

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
          _bidEndTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
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
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                TextFormField(
                  controller: productNameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                  validator: (value) => value == null || value.isEmpty ? 'Enter product name' : null,
                ),
                DropdownButtonFormField<String>(
                  hint: const Text('Select Category'),
                  value: _selectedCategory,
                  items: ['grains', 'veges', 'fruits']
                      .map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category[0].toUpperCase() + category.substring(1)),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  validator: (value) => value == null ? 'Select a category' : null,
                ),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (value) => value == null || value.isEmpty ? 'Enter description' : null,
                ),
                TextFormField(
                  controller: startingBidController,
                  decoration: const InputDecoration(labelText: 'Starting Bid'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter starting bid';
                    if (double.tryParse(value) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                TextFormField(
                  controller: totalQuantityController,
                  decoration: const InputDecoration(labelText: 'Total Quantity'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter total quantity';
                    if (int.tryParse(value) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                TextFormField(
                  controller: minQuantityController,
                  decoration: const InputDecoration(labelText: 'Minimum Quantity'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter minimum quantity';
                    if (int.tryParse(value) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                TextFormField(
                  controller: retailPriceController,
                  decoration: const InputDecoration(
                      labelText: 'Retail Price (when quantity < min quantity)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter retail price';
                    if (double.tryParse(value) == null) return 'Enter a valid price';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: _takePicture, child: const Text('Take Picture')),
                const SizedBox(height: 10),
                if (_imageFiles.isNotEmpty)
                  SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _imageFiles.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.file(_imageFiles[index]),
                      ),
                    ),
                  ),
                ElevatedButton(onPressed: _recordVideo, child: const Text('Record Video')),
                const SizedBox(height: 10),
                if (_videoFile != null) const Text('Video Recorded'),
                ElevatedButton(
                  onPressed: () => _pickEndTime(context),
                  child: const Text('Select Bid End Time'),
                ),
                const SizedBox(height: 10),
                if (_bidEndTime != null) Text('Bid End Time: $_bidEndTime'),
                const SizedBox(height: 20),
                if (_isLoading) const CircularProgressIndicator(),
                ElevatedButton(
                  onPressed: _isLoading ? null : _addProduct,
                  child: const Text('Add Product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}