import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderHistoryPage extends StatelessWidget {
  const OrderHistoryPage({super.key});

  // Fetch orders based on the authenticated user
  Future<QuerySnapshot?> _fetchOrders() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Return orders where the retailerId matches the current user
      return FirebaseFirestore.instance
          .collection('Orders')
          .where('retailerId', isEqualTo: user.uid)
          .get();
    }
    return null; // Return null if the user is not authenticated
  }

  // Fetch bid details using bidId from the Bids collection
  Future<DocumentSnapshot?> _fetchBidDetails(String bidId) async {
    if (bidId.isNotEmpty) {
      return FirebaseFirestore.instance.collection('Bids').doc(bidId).get();
    }
    return null; // Return null if bidId is empty
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
      ),
      body: FutureBuilder<QuerySnapshot?>(
        future: _fetchOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading orders'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No orders found'));
          }

          return ListView(
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              Map<String, dynamic> order = document.data() as Map<String, dynamic>;

              String productId = order['productID'] ?? '';
              String bidId = order['bidId'] ?? '';
              String farmerId = order['farmerId'] ?? '';

              // Fetch product and farmer information
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('Products').doc(productId).get(),
                builder: (context, productSnapshot) {
                  if (productSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (productSnapshot.hasError || !productSnapshot.hasData || !productSnapshot.data!.exists) {
                    return const Center(child: Text('Error fetching product details'));
                  }

                  Map<String, dynamic> productData = productSnapshot.data!.data() as Map<String, dynamic>;
                  String productName = productData['productName'] ?? 'Unknown Product';

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('Users').doc(farmerId).get(),
                    builder: (context, farmerSnapshot) {
                      if (farmerSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (farmerSnapshot.hasError || !farmerSnapshot.hasData || !farmerSnapshot.data!.exists) {
                        return const Center(child: Text('Error fetching farmer details'));
                      }

                      Map<String, dynamic> farmerData = farmerSnapshot.data!.data() as Map<String, dynamic>;
                      String farmerName = farmerData['username'] ?? 'Unknown Farmer';

                      // Fetch bid details using bidId
                      return FutureBuilder<DocumentSnapshot?>(
                        future: _fetchBidDetails(bidId),
                        builder: (context, bidSnapshot) {
                          if (bidSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (bidSnapshot.hasError || !bidSnapshot.hasData || !bidSnapshot.data!.exists) {
                            return const Center(child: Text('Error fetching bid details'));
                          }

                          Map<String, dynamic> bidData = bidSnapshot.data!.data() as Map<String, dynamic>;
                          double bidAmount = (bidData['bidAmount'] ?? 0).toDouble();;
                          int quantity = bidData['quantity'] ?? 0;

                          return Card(
                            margin: const EdgeInsets.all(10),
                            elevation: 5,
                            child: ListTile(
                              title: Text(
                                productName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Farmer: $farmerName'),
                                  Text('Bid Amount: \${bidAmount.toStringAsFixed(2)}'),
                                  Text('Quantity: $quantity'),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  // Placeholder for Select Transporter functionality
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                ),
                                child: const Text('Select Transporter'),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}