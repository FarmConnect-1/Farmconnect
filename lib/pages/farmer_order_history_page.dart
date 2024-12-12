import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Import intl for date formatting

class FarmerOrderHistoryPage extends StatelessWidget {
  const FarmerOrderHistoryPage({super.key});

  // Fetch orders related to the logged-in farmer
  Stream<QuerySnapshot> _fetchFarmerOrders() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return FirebaseFirestore.instance
          .collection('Orders') // Fetch from Orders collection
          .where('farmerId', isEqualTo: user.uid) // Match farmer's UID
          .snapshots();
    }
    return const Stream.empty(); // Return empty if no user is logged in
  }


  // Fetch product details based on productId
  Future<DocumentSnapshot?> _fetchProductDetails(String productId) async {
    try {
      final productDoc = await FirebaseFirestore.instance
          .collection('Products') // Access Products collection
          .doc(productId) // Match the product ID
          .get();

      if (productDoc.exists) {
        return productDoc;
      }
    } catch (e) {
      debugPrint('Error fetching product details: $e');
    }
    return null; // Return null on failure
  }

  // Fetch bid details based on bidId
  Future<DocumentSnapshot?> _fetchBidDetails(String bidId) async {
    try {
      final bidDoc = await FirebaseFirestore.instance
          .collection('Bids') // Access Bids collection
          .doc(bidId) // Match the bid ID
          .get();

      if (bidDoc.exists) {
        return bidDoc;
      }
    } catch (e) {
      debugPrint('Error fetching bid details: $e');
    }
    return null; // Return null on failure
  }

  Future<String?> _fetchRetailerUsername(String retailerId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users') // Access Users collection
          .doc(retailerId) // Match the retailer ID
          .get();

      if (userDoc.exists) {
        return userDoc['username']; // Return the username field
      }
    } catch (e) {
      debugPrint('Error fetching retailer username: $e');
    }
    return 'Unknown Retailer'; // Default value if retailer not found
  }

  // Format Firestore Timestamp into a human-readable string
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final DateTime dateTime = timestamp.toDate();
    return DateFormat('dd MMMM, yyyy').format(dateTime); // Example: 04 December, 2023
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.green,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.green,
        ),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green)
            .copyWith(secondary: Colors.greenAccent),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Order History'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context); // Navigate back to the home page
            },
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _fetchFarmerOrders(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error fetching orders'));
            }

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final order = snapshot.data!.docs[index];
                  final productId = order['productID']; // Get productId from order
                  final bidId = order['bidId'];// Get bidId from order
                  final retailerId = order['retailerId'];

                  return Card(
                    margin: const EdgeInsets.all(10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                    child: FutureBuilder<DocumentSnapshot?>(
                      future: _fetchProductDetails(productId),
                      builder: (context, productSnapshot) {
                        if (productSnapshot.connectionState == ConnectionState.waiting) {
                          return Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (productSnapshot.hasError || productSnapshot.data == null) {
                          return const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(
                              child: Text('Error fetching product details.'),
                            ),
                          );
                        }

                        final productData = productSnapshot.data!.data() as Map<String, dynamic>;
                        final imageUrl = (productData['productImages'] is List &&
                            productData['productImages'].isNotEmpty)
                            ? productData['productImages'].first
                            : null;

                        return Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Image
                                  imageUrl != null
                                      ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      imageUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[300],
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.red,
                                            ),
                                          ),
                                    ),
                                  )
                                      : Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.green,
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  // Product and Order Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Product Name
                                        Text(
                                          productData['productName'] ?? 'Unknown Product',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Product Additional Info
                                        Text(
                                          'Category: ${productData['category'] ?? 'N/A'}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        FutureBuilder<String?>(
                                          future: _fetchRetailerUsername(retailerId),
                                          builder: (context, retailerSnapshot) {
                                            if (retailerSnapshot.connectionState ==
                                                ConnectionState.waiting) {
                                              return const Text(
                                                'Fetching Retailer...',
                                                style: TextStyle(color: Colors.grey),
                                              );
                                            }

                                            if (retailerSnapshot.hasError ||
                                                retailerSnapshot.data == null) {
                                              return const Text(
                                                'Unknown Retailer',
                                                style: TextStyle(color: Colors.red),
                                              );
                                            }

                                            return Text(
                                              'Retailer: ${retailerSnapshot.data}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black54,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // ExpansionTile for bid details
                              const SizedBox(height: 8),
                              ExpansionTile(
                                title: const Text(
                                  'View Bid Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                                children: [
                                  FutureBuilder<DocumentSnapshot?>(
                                    future: _fetchBidDetails(bidId),
                                    builder: (context, bidSnapshot) {
                                      if (bidSnapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(
                                            child: CircularProgressIndicator());
                                      }

                                      if (bidSnapshot.hasError || bidSnapshot.data == null) {
                                        return const ListTile(
                                          title: Text(
                                            'Error fetching bid details.',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        );
                                      }

                                      final bidData =
                                      bidSnapshot.data!.data() as Map<String, dynamic>;

                                      return Column(
                                        children: [
                                          buildProductDetail('Quantity','${bidData['quantity']}'),
                                          buildProductDetail('Price','₹${bidData['bidAmount']}'),
                                          buildProductDetail('Order Date',_formatTimestamp(bidData['timestamp'])),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            } else {
              return const Center(child: Text('No orders found.'));
            }
          },
        ),
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16,color: Colors.grey ),
          ),
        ],
      ),
    );
  }
}