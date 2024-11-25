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
  TextEditingController quantityController = TextEditingController(); // New quantity controller
  User? currentUser = FirebaseAuth.instance.currentUser;
  String? farmerId;
  double? currentBid;
  String? status;
  String? strCurrentBid;
  List<dynamic> productImages = [];
  List<dynamic> productVideos = [];
  bool showAllMedia = false;

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
          currentBid = productSnapshot['currentBid']?.toDouble() ?? productSnapshot['startingBid']?.toDouble();
          status = productSnapshot['status'] ?? 'unknown';
          productImages = productSnapshot['productImages'] ?? [];
          productVideos = productSnapshot['productVideos'] ?? [];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching product details: $e')),
      );
    }
  }

  Future<void> _placeBid() async {
    if (status != 'active') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bidding is not allowed. The auction is not active.')),
      );
      return;
    }

    double bidAmount = double.tryParse(bidController.text) ?? 0;
    int quantity = int.tryParse(quantityController.text) ?? 0;
    if (bidAmount > 0 && quantity > 0) {
      try {
        if (bidAmount > (currentBid ?? 0)) {
          FirebaseFirestore firestore = FirebaseFirestore.instance;

          await firestore.runTransaction((transaction) async {
            transaction.set(
              firestore.collection('Bids').doc(),
              {
                'productId': widget.productId,
                'retailerId': currentUser?.uid,
                'bidAmount': bidAmount,
                'quantity': quantity,
                'timestamp': FieldValue.serverTimestamp(),
              },
            );

            DocumentReference productRef = firestore.collection('Products').doc(widget.productId);
            transaction.update(productRef, {
              'currentBid': bidAmount,
              'highestBidder': currentUser?.uid,
            });
          });

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
        const SnackBar(content: Text('Invalid bid or quantity!')),
      );
    }
  }

  void _chatWithFarmer(BuildContext context) {
    if (farmerId != null) {
      Navigator.pushNamed(context, '/chat', arguments: {'farmerId': farmerId});
    }
  }

  Widget _buildMediaSection() {
    List<Widget> mediaWidgets = [];

    // Add product images to mediaWidgets
    if (productImages.isNotEmpty) {
      mediaWidgets.addAll(
        productImages.map(
              (imageUrl) => _buildMediaItem(imageUrl, isImage: true),
        ),
      );
    }

    // Add product videos to mediaWidgets
    if (productVideos.isNotEmpty) {
      mediaWidgets.addAll(
        productVideos.map(
              (videoUrl) => _buildMediaItem(videoUrl, isImage: false),
        ),
      );
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

// Widget to build a single media item (either image or video)
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
        backgroundColor: Colors.green,
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
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.only(top: 3,bottom: 3),
                          width: double.infinity,
                          height: 170,
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            border: Border.all(color: Colors.green, width: 1),
                          ),
                          child: _buildMediaSection(),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            productData['productName'],
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
                            Text(
                              'Current Bid',
                              style: TextStyle(fontSize: 24,fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '₹$currentBid',
                              style: TextStyle(fontSize: 24, color: Colors.red,fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),

                        Divider(thickness: 1, height: 10),
                        DefaultTabController(
                          length: 2,
                          child: Column(
                            children: [
                              TabBar(
                                labelColor: Colors.black,
                                unselectedLabelColor: Colors.grey,
                                indicatorColor: Colors.green,
                                tabs: [
                                  Tab(text: "Description"),
                                  Tab(text: "Product Details"),
                                ],
                              ),
                              Container(
                                height: 250,
                                child: TabBarView(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          buildProductDetail('Description', 'description'),
                                        ],
                                      ),
                                    ),

                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          buildProductDetail('Status', '${status ?? 'Unknown'}')
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Bid and Quantity Input Section
                        // Bid and Quantity Input Section
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: bidController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Enter your bid amount',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: quantityController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Enter quantity',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            border: Border.all(color: Colors.green, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Total Amount:",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "₹ 0",
                                style: TextStyle(
                                  fontSize: 22,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
                SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _placeBid,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              child: Text(
                                "Place your bid",
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                // Action for chat with farmer
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildProductDetail(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}