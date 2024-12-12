import 'package:farmconnect/pages/chat_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';

class ProductDetailsPage extends StatefulWidget {
  final String productId;

  const ProductDetailsPage({super.key, required this.productId});

  @override
  _ProductDetailsPageState createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  TextEditingController bidController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  User? currentUser = FirebaseAuth.instance.currentUser;
  String? farmerId;
  double? currentBid;
  String? status;
  String? strCurrentBid;
  List<dynamic> productImages = [];
  List<dynamic> productVideos = [];
  bool showAllMedia = false;
  bool isPriceFieldVisible = false; // For showing price field
  double? retailPrice;
  double? startingBid;
  int? minQuantity;
  bool isCheckButtonClicked = false; // Flag to track if the "Check" button is clicked

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
  }

  Future<void> _fetchProductDetails() async {
    try {
      DocumentSnapshot productSnapshot = await FirebaseFirestore.instance
          .collection('Products')
          .doc(widget.productId)
          .get();

      if (productSnapshot.exists) {
        setState(() {
          farmerId = productSnapshot['farmerId'];
          currentBid = productSnapshot['currentBid']?.toDouble() ??
              productSnapshot['startingBid']?.toDouble();
          status = productSnapshot['status'] ?? 'unknown';
          productImages = productSnapshot['productImages'] ?? [];
          productVideos = productSnapshot['productVideos'] ?? [];
          retailPrice = productSnapshot['retailPrice']?.toDouble();
          startingBid = productSnapshot['startingBid']?.toDouble();
          minQuantity = productSnapshot['minQuantity']?.toInt();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching product details: $e')),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} ${_formatTime(dateTime)}';
  }

  Future<void> _checkQuantityAndPrice() async {
    int? enteredQuantity = int.tryParse(quantityController.text);

    if (enteredQuantity == null || enteredQuantity <= 0) {
      _showAlert('Invalid Quantity', 'Please enter a valid quantity.');
      setState(() {
        isCheckButtonClicked = false;
      });
      return;
    }

    if (enteredQuantity < minQuantity!) {
      setState(() {
        isPriceFieldVisible = false;
        isCheckButtonClicked = true;
      });
      _showAlert(
        'Retail Price',
        'Quantity is less than the minimum quantity. Default retail price is ₹${retailPrice?.toStringAsFixed(2)}.',
      );
    } else {
      setState(() {
        isPriceFieldVisible = true;
        isCheckButtonClicked = true;
      });
    }
  }
  String _formatDate(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month
        .toString().padLeft(2, '0')}/${dateTime.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour == 0
        ? 12
        : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }


  Future<void> _placeBid() async {
    if (status != 'active') {
      _showAlert('Bidding Not Allowed', 'Bidding is not allowed. The auction is not active.');
      return;
    }

    int? quantity = int.tryParse(quantityController.text);

    if (quantity == null || quantity <= 0) {
      _showAlert('Invalid Input', 'Please enter a valid quantity.');
      return;
    }

    double? bidAmount;
    if (isPriceFieldVisible) {
      bidAmount = double.tryParse(bidController.text);
      if (bidAmount == null || bidAmount < startingBid!) {
        _showAlert('Invalid Bid', 'Entered price must be greater than the starting bid of ₹${startingBid?.toStringAsFixed(2)}.');
        return;
      }
    } else {
      bidAmount = retailPrice; // Default retail price if quantity < minQuantity
    }

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Get the available quantity of the product from the Products collection
      DocumentSnapshot productSnapshot = await firestore.collection('Products').doc(widget.productId).get();
      if (!productSnapshot.exists) {
        throw Exception('Product does not exist.');
      }

      int availableQuantity = productSnapshot.get('availableQuantity') ?? 0;
      if (quantity > availableQuantity) {
        _showAlert('Quantity Unavailable', 'This much quantity is not available. Only $availableQuantity items are available.');
        return;
      }

      // Check if the user has already placed a bid on this product
      QuerySnapshot bidSnapshot = await firestore
          .collection('Bids')
          .where('productId', isEqualTo: widget.productId)
          .where('retailerId', isEqualTo: currentUser?.uid)
          .get();



      double? lastBidAmount;
      if (bidSnapshot.docs.isNotEmpty) {
        DocumentSnapshot existingBid = bidSnapshot.docs.first;
        String existingStatus = existingBid.get('status') ?? '';
        lastBidAmount = existingBid.get('bidAmount')?.toDouble();

        if (existingStatus == 'pending') {
          // Prevent further bidding if the status is 'pending'
          _showAlert('Action Required', 'Your last bid is accepted by the farmer. Please accept or reject it.');
          return;
        }

        if (existingStatus == 'offered') {
          // Check if the new bid amount is greater than the last bid amount
          if (bidAmount! <= lastBidAmount!) {
            _showAlert('Invalid Bid', 'Your new bid amount must be greater than the last bid amount of ₹${lastBidAmount.toStringAsFixed(2)}.');
            return;
          }
        }
      }

      // Calculate final total price
      double finalPrice = (quantity < minQuantity!) ? (retailPrice! * quantity) : (bidAmount! * quantity);

      // Show confirmation dialog
      bool confirm = await _showConfirmationDialog(quantity, bidAmount, finalPrice);

      if (!confirm) return;

      // Place or update the bid after confirmation
      if (bidSnapshot.docs.isNotEmpty && bidSnapshot.docs.first.get('status') == 'offered') {
        // Update the existing bid if the status is 'offered'
        DocumentSnapshot existingBid = bidSnapshot.docs.first;
        await firestore.collection('Bids').doc(existingBid.id).update({
          'bidAmount': bidAmount,
          'quantity': quantity,
          'timestamp': FieldValue.serverTimestamp(),
        });
        _showAlert('Success', 'Bid updated successfully!');
      } else {
        // Create a new bid
        await firestore.collection('Bids').add({
          'productId': widget.productId,
          'retailerId': currentUser?.uid,
          'bidAmount': bidAmount,
          'quantity': quantity,
          'status': 'offered',
          'timestamp': FieldValue.serverTimestamp(),
        });
        _showAlert('Success', 'Bid placed successfully!');
        _finalizeBid(quantity, bidAmount!);
      }
    } catch (e) {
      _showAlert('Error', 'Error placing bid: ${e.toString()}');
    }
  }

  Future<bool> _showConfirmationDialog(int quantity, double? bidAmount, double finalPrice) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissing the dialog by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Your Bid'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                Text('Quantity: $quantity'),
                Text('Price per unit: ₹${bidAmount?.toStringAsFixed(2) ?? retailPrice?.toStringAsFixed(2)}'),
                Text('Total Price: ₹${finalPrice.toStringAsFixed(2)}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              child: const Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ??
        false;
  }


  Future<void> _finalizeBid(int quantity, double bidAmount) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;

      await firestore.collection('Bids').add({
        'productId': widget.productId,
        'retailerId': currentUser?.uid,
        'bidAmount': bidAmount,
        'quantity': quantity,
        'status': 'offered',
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        currentBid = bidAmount;
      });

      _showAlert('Success', 'Bid placed successfully!');
    } catch (e) {
      _showAlert('Error', 'Error finalizing bid: ${e.toString()}');
    }
  }




  Future<void> _showAlert(String title, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      // Prevent dismissing the alert by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }


  void _chatWithFarmer(BuildContext context) {
    if (farmerId != null && currentUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            currentUserId: currentUser!.uid,
            targetUserId: farmerId!,
            targetUserName: 'Farmer', // Replace with the farmer's name if available
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start chat. Farmer information is missing.')),
      );
    }
  }


  Widget _buildMediaSection() {
    List<Widget> mediaWidgets = [];

    if (productImages.isNotEmpty) {
      mediaWidgets.addAll(
        productImages.map(
              (imageUrl) => _buildMediaItem(imageUrl, isImage: true),
        ),
      );
    }

    if (productVideos.isNotEmpty) {
      mediaWidgets.addAll(
        productVideos.map(
              (videoUrl) => _buildMediaItem(videoUrl, isImage: false),
        ),
      );
    }

    if (!showAllMedia && mediaWidgets.length > 4) {
      mediaWidgets = mediaWidgets.sublist(0, 4);
      mediaWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              showAllMedia = true;
            });
          },
          child: Container(
            color: Colors.grey[300],
            width: double.infinity,
            height: 300,
            child: const Center(
              child: Text(
                '+ Show More',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ),
        ),
      );
    }

    if (mediaWidgets.isEmpty) {
      return const Center(child: Text('No media available.'));
    }

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8.0,
        runSpacing: 8.0,
        children: mediaWidgets,
      ),
    );
  }

  Widget _buildMediaItem(String url, {required bool isImage}) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey),
      ),
      child: isImage
          ? ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.error),
        ),
      )
          : ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildVideoPlayer(url),
      ),
    );
  }

  Widget _buildVideoPlayer(String videoUrl) {
    VideoPlayerController controller = VideoPlayerController.network(videoUrl);

    return FutureBuilder(
      future: controller.initialize(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Widget buildProductDetail(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }


  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('Products')
            .doc(widget.productId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Error loading product details'));
          }

          var productData = snapshot.data!.data() as Map<String, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          width: double.infinity,
                          height: 170,
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            border: Border.all(color: Colors.blue, width: 1),
                          ),
                          child: _buildMediaSection(),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            productData['productName'] ?? '',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Current Bid',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '₹$currentBid',
                              style: const TextStyle(
                                fontSize: 24,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(thickness: 1, height: 10),
                        DefaultTabController(
                          length: 2,
                          child: Column(
                            children: [
                              const TabBar(
                                labelColor: Colors.black,
                                unselectedLabelColor: Colors.grey,
                                indicatorColor: Colors.green,
                                tabs: [
                                  Tab(text: 'Product Details'),
                                  Tab(text: 'Bidding Details'),
                                ],
                              ),
                              SizedBox(
                                height: 300,
                                child: TabBarView(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment
                                            .start,
                                        children: [
                                          buildProductDetail('Description',
                                              productData['description'] ?? ''),
                                          buildProductDetail(
                                              'Status', status ?? 'unknown'),
                                          buildProductDetail(
                                            'Start Date',
                                            productData['timestamp'] != null
                                                ? _formatDateTime(
                                                productData['timestamp'] is Timestamp
                                                    ? (productData['timestamp'] as Timestamp)
                                                    .toDate()
                                                    : DateTime.parse(
                                                    productData['timestamp']))
                                                : 'N/A',
                                          ),
                                          buildProductDetail(
                                            'End Date & Time',
                                            productData['bidEndTime'] != null
                                                ? _formatDateTime(
                                                productData['bidEndTime'] is Timestamp
                                                    ? (productData['bidEndTime'] as Timestamp)
                                                    .toDate()
                                                    : DateTime.parse(
                                                    productData['bidEndTime']))
                                                : 'N/A',
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment
                                            .start,
                                        children: [
                                          buildProductDetail(
                                              'Category',productData['category']),
                                          buildProductDetail('Available Quantity',
                                              '${productData['availableQuantity']}'),
                                          buildProductDetail(
                                              'Minimum Quantity to bid', '${productData['minQuantity']}'),
                                          buildProductDetail(
                                              'Retail Price','${productData['retailPrice']}'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Enter quantity',
                          border: OutlineInputBorder(),
                        ),

                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _checkQuantityAndPrice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text('Check'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (isPriceFieldVisible)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: bidController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Enter your bid amount',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),

                    ],
                  ),

                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isCheckButtonClicked ? _placeBid : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCheckButtonClicked ? Colors.blue : Colors.grey,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Text(
                          'Place Bid',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _chatWithFarmer(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Text(
                          "Chat with Farmer",
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _calculateTotalAmount() {
    int? quantity = int.tryParse(quantityController.text);
    double? price = isPriceFieldVisible
        ? double.tryParse(bidController.text)
        : retailPrice;
    if (quantity == null || price == null) return '0.00';
    return (quantity * price).toStringAsFixed(2);
  }
}