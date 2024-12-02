import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FarmerOrderHistoryPage extends StatelessWidget {
  const FarmerOrderHistoryPage({super.key});

  // Fetch products related to the logged-in farmer
  Stream<QuerySnapshot> _fetchFarmerProducts() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return FirebaseFirestore.instance
          .collection('Products')
          .where('farmerId', isEqualTo: user.uid) // Match farmer's UID
          .snapshots();
    }
    return const Stream.empty(); // Return empty if no user is logged in
  }

  // Fetch bids related to a specific product
  Stream<QuerySnapshot> _fetchProductBids(String productId) {
    return FirebaseFirestore.instance
        .collection('Bids')
        .where('productId', isEqualTo: productId)
        .snapshots();
  }

  // Fetch username based on retailerId from the Users collection
  Future<String> _fetchRetailerName(String retailerId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Users') // Query the Users collection
          .doc(retailerId) // Match retailerId with document ID
          .get();
      if (doc.exists) {
        return doc['username']; // Fetch the username field
      }
      return 'Unknown Retailer';
    } catch (e) {
      return 'Unknown Retailer';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchFarmerProducts(),
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
                final product = snapshot.data!.docs[index];
                dynamic imageUrl = product['productImages'];

                // Handle imageUrl if it's a list
                if (imageUrl is List && imageUrl.isNotEmpty) {
                  imageUrl = imageUrl.first; // Use the first URL from the list
                } else if (imageUrl is! String) {
                  imageUrl = null; // If not a string or a valid list, set to null
                }

                return Card(
                  margin: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      ListTile(
                        leading: imageUrl != null
                            ? Image.network(
                          imageUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image),
                        )
                            : const Icon(Icons.image_not_supported),
                        title: Text(product['productName']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Starting Bid: ₹${product['startingBid']}'),
                            Text('Highest Bid: ₹${product['currentBid']}'),
                            Text('Status: ${product['status']}'),
                          ],
                        ),
                      ),
                      ExpansionTile(
                        title: const Text('View Bids'),
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream: _fetchProductBids(product.id),
                            builder: (context, bidSnapshot) {
                              if (bidSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }
                              if (bidSnapshot.hasError) {
                                return const Center(
                                    child: Text('Error fetching bids'));
                              }

                              if (bidSnapshot.hasData &&
                                  bidSnapshot.data!.docs.isNotEmpty) {
                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: bidSnapshot.data!.docs.length,
                                  itemBuilder: (context, bidIndex) {
                                    final bid =
                                    bidSnapshot.data!.docs[bidIndex];

                                    return FutureBuilder<String>(
                                      future: _fetchRetailerName(
                                          bid['retailerId']),
                                      builder: (context, retailerSnapshot) {
                                        final retailerName =
                                        retailerSnapshot.connectionState ==
                                            ConnectionState.done
                                            ? retailerSnapshot.data ??
                                            'Unknown Retailer'
                                            : 'Loading...';
                                        return ListTile(
                                          title: Text(
                                              'Bid Amount: ₹${bid['bidAmount']}'),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                            children: [
                                              Text('Retailer: $retailerName'),
                                              Text('Status: ${bid['status']}'),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );
                              } else {
                                return const Center(
                                    child: Text('No bids found.'));
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          } else {
            return const Center(child: Text('No products found.'));
          }
        },
      ),
    );
  }
}
