import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tflite_flutter/tflite_flutter.dart'; // Import TensorFlow Lite Flutter package
import 'package:image/image.dart' as img; // For additional image processing


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AddProductPage(),
    );
  }
}

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
  bool _isLoading = false;
  final List<File> _imageFiles = [];
  final List<String> _imageUrls = []; // Added this
  File? _videoFile;
  String? _videoUrl; // Added this
  final Map<String, List<String>> subCategoryOptions = {
    'Fruits': ['Apple', 'Banana', 'Grapes', 'Papaya', 'Mango'],
    'Veggies': ['Tomato', 'Ladyfinger', 'Onion'],
    'Grains': ['Wheat', 'Rice', 'Barley'],
  };
  String? _predictionResult;


  @override
  void initState() {
    super.initState();
    _loadModel();
  }
  String? _selectedSubcategory;

  late Interpreter _interpreterA;
  late Interpreter _interpreterB;
  bool _isModelALoaded = false;
  bool _isModelBLoaded = false;

  Future<void> _loadModel() async {
    try {
      _interpreterA = await Interpreter.fromAsset("assets/model_unquant_a.tflite");
      setState(() {
        _isModelALoaded = true;
      });
      print("Model A loaded successfully.");
    } catch (e) {
      setState(() {
        _isModelALoaded = false;
      });
      print("Error loading Model A: $e");
    }

    try {
      _interpreterB = await Interpreter.fromAsset("assets/model_unquant_b.tflite");
      setState(() {
        _isModelBLoaded = true;
      });
      print("Model B loaded successfully.");
    } catch (e) {
      setState(() {
        _isModelBLoaded = false;
      });
      print("Error loading Model B: $e");
    }
  }


  Future<void> _predictImage(File image) async {
    Interpreter selectedInterpreter;

    // Choose interpreter based on subcategory
    if (_selectedSubcategory == 'Apple') {
      if (!_isModelALoaded) {
        setState(() {
          _predictionResult = "Model A not loaded. Please try again later.";
        });
        return;
      }
      selectedInterpreter = _interpreterA;
    } else if (_selectedSubcategory == 'Banana') {
      if (!_isModelBLoaded) {
        setState(() {
          _predictionResult = "Model B not loaded. Please try again later.";
        });
        return;
      }
      selectedInterpreter = _interpreterB;
    } else {
      // Default to Model A for other subcategories
      if (!_isModelALoaded) {
        setState(() {
          _predictionResult = "Model A not loaded. Please try again later.";
        });
        return;
      }
      selectedInterpreter = _interpreterA;
    }

    try {
      print("Starting prediction...");

      // Decode the image
      final decodedImage = img.decodeImage(await image.readAsBytes());
      if (decodedImage == null) {
        throw Exception("Failed to decode image.");
      }

      // Resize the image to 224x224 (as expected by the model)
      final resizedImage = img.copyResize(decodedImage, width: 224, height: 224);

      // Prepare the image as input tensor
      final input = List.generate(
        224,
            (y) => List.generate(
          224,
              (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [
              (img.getRed(pixel) / 255.0),   // Red channel
              (img.getGreen(pixel) / 255.0), // Green channel
              (img.getBlue(pixel) / 255.0),  // Blue channel
            ];
          },
        ),
      );

      // Reshape the input into the expected format: [1, 224, 224, 3]
      final inputTensor = [input];

      // Prepare the output buffer
      var output = List.filled(1 * 2, 0.0).reshape([1, 2]);

      // Run inference using the selected interpreter
      selectedInterpreter.run(inputTensor, output);

      // Process the result
      final confidenceList = (output[0] as List).map((e) => e as double).toList();
      final maxConfidenceIndex = confidenceList.indexWhere(
            (value) => value == confidenceList.reduce((a, b) => a > b ? a : b),
      );
      if(maxConfidenceIndex == 0){
        setState(() {
          _predictionResult =
              (confidenceList[maxConfidenceIndex] * 5).toStringAsFixed(2);
        });
      }
      else{
        setState(() {
          _predictionResult =
              (5 - confidenceList[maxConfidenceIndex] * 5).toStringAsFixed(2);
        });
      }



      print("Prediction completed successfully.");
    } catch (e) {
      print("Error during prediction: $e");
      setState(() {
        _predictionResult = "Error during prediction: $e";
      });
    }
  }

  DropdownButtonFormField<String> _buildSubcategoryDropdown() {
    return DropdownButtonFormField<String>(
      hint: const Text('Select Subcategory'),
      value: _selectedSubcategory,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey[300],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: subCategoryOptions[_selectedCategory]!
          .map((subcategory) => DropdownMenuItem(
        value: subcategory,
        child: Text(subcategory),
      ))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedSubcategory = value;
        });
      },
      validator: (value) =>
      value == null ? 'Select a subcategory' : null,
    );
  }


  // Method to pick an image from the gallery
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _imageFiles.add(File(pickedFile.path));
      });
    }
  }


  // Method to take a picture with the camera
  Future<void> _takePicture() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
      });
      File imageFile = File(pickedFile.path);
      try {
        // Call predictImage to get prediction result
        await _predictImage(imageFile);

        String? imageUrl = await _uploadFile(imageFile, 'Images');
        if (imageUrl != null) {
          setState(() {
            _imageFiles.add(imageFile);
            _imageUrls.add(imageUrl);
          });
        }
      } catch (e) {
        print('Error uploading image or predicting: $e');
        setState(() {
          _predictionResult = 'Error during image processing: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Method to record a video
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

  // Method to upload a file to Firebase Storage
  Future<String?> _uploadFile(File file, String folder) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      var ref = FirebaseStorage.instance.ref('$folder/$fileName');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  // Method to pick a bid end time
  Future<void> _pickEndTime() async {
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

  // Method to add a product to Firestore
  Future<void> _addProduct() async {
    if (!_formKey.currentState!.validate() || _bidEndTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')),
            );
            return;
          }
        }
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);

        final collection = FirebaseFirestore.instance.collection('Products');
        await collection.add({
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
          'bidEndTime': _bidEndTime!.toIso8601String(),
          'timestamp': FieldValue.serverTimestamp(),
          'location': GeoPoint(position.latitude, position.longitude),
          'quality' : _predictionResult,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );

        _resetForm();
      } catch (e) {
        print('Error adding product to Firestore: $e');
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
  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Images',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (_predictionResult != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Prediction: Good with $_predictionResult /5',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (_imageFiles.isNotEmpty)
                ..._imageFiles.map(
                      (file) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            file,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _imageFiles.remove(file);
                              });
                            },
                            child: const Icon(
                              Icons.close,
                              color: Colors.red,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              GestureDetector(
                onTap: _takePicture,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[300],
                  ),
                  child: const Center(
                    child: Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.grey[100],
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop(); // Navigate to the previous page
                  },
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Add Product',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        hint: const Text('Select Category'),
                        value: _selectedCategory,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[300],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: ['Grains', 'Veggies', 'Fruits']
                            .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                        validator: (value) =>
                        value == null ? 'Select a category' : null,
                      ),
                      if (_selectedCategory != null &&
                          subCategoryOptions[_selectedCategory!]!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: _buildSubcategoryDropdown(),
                        ),

                      const SizedBox(height: 20),
                      TextFormField(
                        controller: productNameController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[300],
                          labelText: 'Product Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) =>
                        value == null || value.isEmpty
                            ? 'Enter product name'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildImageSection(),
                          const SizedBox(height: 20),

                          const SizedBox(height: 20),
                          TextFormField(
                            controller: descriptionController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey[300],
                              labelText: 'Description',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (value) =>
                            value == null || value.isEmpty ? 'Enter description' : null,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: startingBidController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey[300],
                                labelText: 'Starting Bid',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter starting bid';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: TextFormField(
                              controller: retailPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey[300],
                                labelText: 'Retail Price',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter retail price';
                                }
                                if (double.tryParse(value) == null) {
                                  return 'Enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: totalQuantityController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey[300],
                                labelText: 'Total Quantity',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter total quantity';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'Enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: TextFormField(
                              controller: minQuantityController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey[300],
                                labelText: 'Min. Quantity',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter minimum quantity';
                                }
                                if (int.tryParse(value) == null) {
                                  return 'Enter a valid number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _pickEndTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 15, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _bidEndTime == null
                                ? 'Select Bid End Time'
                                : 'Bid End Time: ${_bidEndTime.toString().substring(0, 16)}',
                            style: TextStyle(
                              fontSize: 16,
                              color: _bidEndTime == null
                                  ? Colors.black54
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        ElevatedButton(
                          onPressed: _addProduct,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Add Product',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}