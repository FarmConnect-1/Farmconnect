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

    double? bidAmount = double.tryParse(bidController.text);
    int? quantity = int.tryParse(quantityController.text);

    if (bidAmount == null || bidAmount <= 0 || quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid bid or quantity!')),
      );
      return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This much quantity is not available. Only $availableQuantity items are available.')),
        );
        return;
      }

      // Check if the user has already placed a bid on this product
      QuerySnapshot bidSnapshot = await firestore
          .collection('Bids')
          .where('productId', isEqualTo: widget.productId)
          .where('retailerId', isEqualTo: currentUser?.uid)
          .get();

      if (bidSnapshot.docs.isNotEmpty) {
        DocumentSnapshot existingBid = bidSnapshot.docs.first;
        String existingStatus = existingBid.get('status') ?? '';

        if (existingStatus == 'pending') {
          // Prevent further bidding if status is 'pending'
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please accept or reject your last bid.')),
          );
          return;
        } else if (existingStatus == 'locked' || existingStatus == 'rejected') {
          // Create a new bid if status is 'locked' or 'rejected'
          await firestore.collection('Bids').add({
            'productId': widget.productId,
            'retailerId': currentUser?.uid,
            'bidAmount': bidAmount,
            'quantity': quantity,
            'status': 'offered',
            'timestamp': FieldValue.serverTimestamp(),
          });
        } else {
          // Update the existing bid
          DocumentReference existingBidRef = existingBid.reference;
          await firestore.runTransaction((transaction) async {
            DocumentReference productRef = firestore.collection('Products').doc(widget.productId);

            // Update product details if the new bid is higher than the current bid
            DocumentSnapshot productSnapshot = await transaction.get(productRef);
            if (!productSnapshot.exists) {
              throw Exception('Product does not exist.');
            }

            double? currentBidInDB = productSnapshot.get('currentBid')?.toDouble();
            if (currentBidInDB == null || bidAmount > currentBidInDB) {
              // Update the current bid in the Products collection
              transaction.update(productRef, {
                'currentBid': bidAmount,
                'highestBidder': currentUser?.uid,
              });
            }

            // Update the existing bid details
            transaction.update(existingBidRef, {
              'bidAmount': bidAmount,
              'quantity': quantity,
              'timestamp': FieldValue.serverTimestamp(),
            });
          });
        }
      } else {
        // Create a new bid if no previous bid exists
        await firestore.collection('Bids').add({
          'productId': widget.productId,
          'retailerId': currentUser?.uid,
          'bidAmount': bidAmount,
          'quantity': quantity,
          'status': 'offered',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        currentBid = bidAmount;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid placed successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error placing bid: ${e.toString()}')),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: Colors.green,
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
                            color: Colors.green[100],
                            border: Border.all(color: Colors.green, width: 1),
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
                                  Tab(text: 'Details'),
                                  Tab(text: 'History'),
                                ],
                              ),
                              SizedBox(
                                height: 300,
                                child: TabBarView(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          buildProductDetail('Description',
                                              productData['description'] ?? ''),
                                          buildProductDetail(
                                              'Status', status ?? 'unknown'),
                                        ],
                                      ),
                                    ),
                                    const Center(
                                      child: Text('No bid history available'),
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
                TextFormField(
                  controller: bidController,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Enter your bid amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Enter quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _placeBid,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green),
                  child: const Text('Place Bid'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
