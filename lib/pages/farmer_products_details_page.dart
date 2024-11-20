import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class FarmerProductDetailsPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const FarmerProductDetailsPage({
    super.key,
    required this.productId,
    required this.productData,
  });

  @override
  _FarmerProductDetailsPageState createState() =>
      _FarmerProductDetailsPageState();
}

class _FarmerProductDetailsPageState extends State<FarmerProductDetailsPage> {
  bool _isLoading = false;
  File? _imageFile;
  XFile? _pickedFile; // For web compatibility
  List<String> productImages = [];
  List<String> productVideos = [];
  String highestBidderName = 'Loading...'; // To store the highest bidder's name
  List<Map<String, dynamic>> bidsWithRetailerNames =
  []; // List to store bids and retailer names

  @override
  void initState() {
    super.initState();
    _loadProductMedia();
    _loadHighestBidder();
    _loadBids(); // Load bids on page load
  }

  // Function to load the images and videos from Firestore
  Future<void> _loadProductMedia() async {
    DocumentSnapshot productSnapshot = await FirebaseFirestore.instance
        .collection('Products')
        .doc(widget.productId)
        .get();

    if (productSnapshot.exists) {
      setState(() {
        productImages =
        List<String>.from(productSnapshot['productImages'] ?? []);
        productVideos =
        List<String>.from(productSnapshot['productVideos'] ?? []);
      });
    }
  }

  // Function to load highest bidder's name
  Future<void> _loadHighestBidder() async {
    String? highestBidderUid = widget.productData['highestBidder'];
    if (highestBidderUid != null && highestBidderUid.isNotEmpty) {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(highestBidderUid)
          .get();
      if (userSnapshot.exists) {
        setState(() {
          highestBidderName = userSnapshot['username'] ?? 'No Name';
        });
      } else {
        setState(() {
          highestBidderName =
          'User not found'; // In case the user no longer exists
        });
      }
    } else {
      setState(() {
        highestBidderName = 'No bids yet';
      });
    }
  }

  // Function to load bids and retailer names
  Future<void> _loadBids() async {
    try {
      QuerySnapshot bidSnapshot = await FirebaseFirestore.instance
          .collection('Bids')
          .where('productId', isEqualTo: widget.productId)
          .get();

      List<Map<String, dynamic>> loadedBids = [];

      for (var doc in bidSnapshot.docs) {
        Map<String, dynamic> bidData = doc.data() as Map<String, dynamic>;
        DocumentSnapshot retailerSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .doc(bidData['retailerId'])
            .get();

        String retailerName = retailerSnapshot.exists
            ? retailerSnapshot['username'] ?? 'Unknown'
            : 'Retailer not found';

        loadedBids.add({
          'bidAmount': bidData['bidAmount'],
          'retailerName': retailerName,
          'timestamp': bidData['timestamp'],
          'retailerId': bidData['retailerId'], // Added retailerId
        });
      }

      setState(() {
        bidsWithRetailerNames = loadedBids;
      });
    } catch (e) {
      print('Error loading bids: $e');
    }
  }

  // Function to take a new picture
  Future<void> _takePicture() async {
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _isLoading = true; // Set loading state while uploading
      });

      try {
        String? downloadUrl;
        if (kIsWeb) {
          _pickedFile = pickedFile;
          downloadUrl = await _uploadFile(_pickedFile, 'product_images');
        } else {
          _imageFile = File(pickedFile.path);
          downloadUrl = await _uploadFile(_imageFile!, 'product_images');
        }

        if (downloadUrl != null) {
          setState(() {
            productImages.add(downloadUrl!); // Add new image URL to the list
          });
          await _updateProductImages(); // Update Firestore with the new image list
        }
      } catch (e) {
        print('Error taking picture: $e');
      } finally {
        setState(() {
          _isLoading = false; // Reset loading state
        });
      }
    }
  }

  // Function to upload file to Firebase Storage
  Future<String?> _uploadFile(var file, String folder) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageRef =
      FirebaseStorage.instance.ref().child('$folder/$fileName');

      if (kIsWeb) {
        await storageRef.putData(await (file as XFile).readAsBytes());
      } else {
        await storageRef.putFile(file as File);
      }

      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  // Function to update Firestore with the new image URL
  Future<void> _updateProductImages() async {
    try {
      // Retrieve the current images from Firestore to ensure correct state update
      DocumentSnapshot productSnapshot = await FirebaseFirestore.instance
          .collection('Products')
          .doc(widget.productId)
          .get();

      List<String> currentImages =
      List<String>.from(productSnapshot['productImages'] ?? []);
      currentImages.addAll(productImages);

      await FirebaseFirestore.instance
          .collection('Products')
          .doc(widget.productId)
          .update({
        'productImages': currentImages.toSet().toList(), // Use a set to avoid duplicates
      });

      setState(() {
        productImages = currentImages; // Update local state with the new list
      });
    } catch (e) {
      print('Error updating product images: $e');
    }
  }

  // Function to display the product images
  Widget _displayProductImages() {
    if (productImages.isEmpty) {
      return const Center(child: Text('No images uploaded'));
    }
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: productImages.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.network(
              productImages[index],
              height: 100,
              width: 100,
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }

  // Function to display bids along with retailer names and Lock button
  Widget _displayBids() {
    if (bidsWithRetailerNames.isEmpty) {
      return const Center(child: Text('No bids available'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: bidsWithRetailerNames.map((bid) {
        return Card(
          child: ListTile(
            title: Text('Bid: \$${bid['bidAmount']}'),
            subtitle: Text('Retailer: ${bid['retailerName']}'),
            trailing: ElevatedButton(
              onPressed: () {
                _confirmLockBid(bid['retailerId'], bid['bidAmount']);
              },
              child: const Text('Lock'),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Function to confirm lock bid
  void _confirmLockBid(String retailerId, double bidAmount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Lock'),
          content: const Text(
              'Are you sure you want to lock this bid and close the bidding?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _lockBid(retailerId, bidAmount);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  // Function to lock the bid and close the bidding
  Future<void> _lockBid(String retailerId, double bidAmount) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Update the product document in Firestore
      await FirebaseFirestore.instance
          .collection('Products')
          .doc(widget.productId)
          .update({
        'status': 'closed',
        'highestBidder': retailerId,
        'currentBid': bidAmount,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bidding has been closed and bid is locked.')),
      );

      // Optionally, you can refresh the highest bidder name
      _loadHighestBidder();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error locking bid: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> product = widget.productData;
    double currentBid = product['currentBid'] is int
        ? (product['currentBid'] as int).toDouble()
        : product['currentBid'] ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product: ${product['productName']}',
                style:
                const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text('Description: ${product['description']}'),
              const SizedBox(height: 20),
              Text('Current Bid: \$${currentBid.toStringAsFixed(2)}'),
              const SizedBox(height: 20),
              Text('Highest Bidder: $highestBidderName'),
              const SizedBox(height: 20),
              const Text(
                'Product Images:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              _displayProductImages(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _takePicture,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Upload Image'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bids:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              _displayBids(),
              const SizedBox(height: 20),
              // Remove the 'Stop Bidding and Lock' button since bids can be locked individually
              ElevatedButton(
                onPressed: _isLoading ? null : _deleteProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  Colors.red, // Red color to indicate danger action
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Delete Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Function to delete product and related data from Firestore and Firebase Storage
  Future<void> _deleteProduct() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Delete product images from Firebase Storage
      for (String imageUrl in productImages) {
        FirebaseStorage.instance.refFromURL(imageUrl).delete();
      }

      // Delete product videos from Firebase Storage
      for (String videoUrl in productVideos) {
        FirebaseStorage.instance.refFromURL(videoUrl).delete();
      }

      // Delete all related bids from Firestore
      QuerySnapshot bidSnapshot = await FirebaseFirestore.instance
          .collection('Bids')
          .where('productId', isEqualTo: widget.productId)
          .get();

      for (var doc in bidSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete the product document from Firestore
      await FirebaseFirestore.instance
          .collection('Products')
          .doc(widget.productId)
          .delete();

      // Show success message and redirect back
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully')),
      );

      Navigator.of(context).pop(); // Go back after deletion
    } catch (e) {
      print('Error deleting product: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting product: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
