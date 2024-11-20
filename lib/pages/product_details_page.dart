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
  User? currentUser = FirebaseAuth.instance.currentUser;
  String? farmerId;
  double? currentBid;
  String? status;
  List<dynamic> productImages = []; // Ensure this is initialized as an empty list
  List<dynamic> productVideos = []; // Ensure this is initialized as an empty list
  bool showAllMedia = false; // Flag to control media display

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
  }

  // Fetch the product details, including media URLs
  Future<void> _fetchProductDetails() async {
    try {
      DocumentSnapshot productSnapshot = await FirebaseFirestore.instance
          .collection('Products')
          .doc(widget.productId)
          .get();

      if (productSnapshot.exists) {
        setState(() {
          farmerId = productSnapshot['farmerId']; // Get farmer ID
          currentBid = productSnapshot['currentBid']?.toDouble() ?? productSnapshot['startingBid']?.toDouble(); // Set current bid
          status = productSnapshot['status'] ?? 'unknown'; // Get status
          productImages = productSnapshot['productImages'] ?? []; // Get product images
          productVideos = productSnapshot['productVideos'] ?? []; // Get product videos
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching product details: $e')),
      );
    }
  }

  // Function to place a bid
  Future<void> _placeBid() async {
    if (status != 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bidding is not allowed. The auction is not active.')),
      );
      return;
    }

    double bidAmount = double.tryParse(bidController.text) ?? 0;
    if (bidAmount > 0) {
      try {
        if (bidAmount > (currentBid ?? 0)) {
          FirebaseFirestore firestore = FirebaseFirestore.instance;

          // Start a Firestore transaction to ensure both collections are updated atomically
          await firestore.runTransaction((transaction) async {
            // Update the Bids collection
            transaction.set(
              firestore.collection('Bids').doc(),
              {
                'productId': widget.productId,
                'retailerId': currentUser?.uid,
                'bidAmount': bidAmount,
                'timestamp': FieldValue.serverTimestamp(),
              },
            );

            // Update the Products collection
            DocumentReference productRef = firestore.collection('Products').doc(widget.productId);
            transaction.update(productRef, {
              'currentBid': bidAmount,
              'highestBidder': currentUser?.uid, // Optionally store the highest bidder
            });
          });

          // Update local state
          setState(() {
            currentBid = bidAmount;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bid placed successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bid must be higher than the current bid!')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error placing bid: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid bid amount!')),
      );
    }
  }

  // Function to navigate to chat page
  void _chatWithFarmer(BuildContext context) {
    if (farmerId != null) {
      Navigator.pushNamed(context, '/chat', arguments: {'farmerId': farmerId});
    }
  }

  // Widget to display media (images and videos)
  Widget _buildMediaSection() {
    List<Widget> mediaWidgets = [];

    if (productImages.isNotEmpty) {
      mediaWidgets.addAll(productImages.map((imageUrl) => _buildMediaItem(imageUrl, isImage: true)).toList());
    }

    if (productVideos.isNotEmpty) {
      mediaWidgets.addAll(productVideos.map((videoUrl) => _buildMediaItem(videoUrl, isImage: false)).toList());
    }

    // Limit initial display to 4 items and add Show More button if necessary
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
            width: 100,
            height: 100,
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

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: mediaWidgets,
    );
  }

  // Widget to build a single media item (either image or video)
  Widget _buildMediaItem(String url, {required bool isImage}) {
    return Container(
      width: 100,
      height: 100,
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
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
        ),
      )
          : ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildVideoPlayer(url),
      ),
    );
  }

  // Widget to build a video player
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('Products').doc(widget.productId).get(),
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productData['productName'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Description: ${productData['description']}'),
                  const SizedBox(height: 10),
                  Text('Current Bid: \$${currentBid ?? productData['startingBid']}'),
                  const SizedBox(height: 10),
                  Text('Status: ${status ?? 'Unknown'}'), // Display the status
                  const SizedBox(height: 20),
                  // Media Section
                  const Text(
                    'Media:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildMediaSection(),
                  const SizedBox(height: 20),
                  // Place Bid Section
                  TextField(
                    controller: bidController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Enter your bid amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _placeBid,
                    child: const Text('Place Bid'),
                  ),
                  const SizedBox(height: 10),
                  // Chat with Farmer Button
                  ElevatedButton(
                    onPressed: () => _chatWithFarmer(context),
                    child: const Text('Chat with Farmer'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}