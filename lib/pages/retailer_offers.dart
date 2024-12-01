import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RetailerOffers extends StatefulWidget {
  const RetailerOffers({super.key});

  @override
  _RetailerOffersPageState createState() => _RetailerOffersPageState();
}

class _RetailerOffersPageState extends State<RetailerOffers> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Offers'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Bids')
            .where('status', isEqualTo: 'pending') // Filter by pending status
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error fetching offers'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No pending offers found'));
          }

          var bids = snapshot.data!.docs;

          return ListView.builder(
            itemCount: bids.length,
            itemBuilder: (context, index) {
              Map<String, dynamic> bidData = bids[index].data() as Map<String, dynamic>;

              String productId = bidData['productId'] ?? '';
              String retailerId = bidData['retailerId'] ?? ''; // Fetch retailerId from Bids
              String bidId = bids[index].id;
              double bidAmount = bidData['bidAmount']?.toDouble() ?? 0.0;

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
                  String farmerId = productData['farmerId'] ?? '';

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('Users').doc(farmerId).get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
                        return const Center(child: Text('Error fetching farmer details'));
                      }

                      Map<String, dynamic> userData = userSnapshot.data!.data() as Map<String, dynamic>;
                      String farmerName = userData['username'] ?? 'Unknown Farmer';

                      return Card(
                        margin: const EdgeInsets.all(10),
                        elevation: 5,
                        child: ListTile(
                          title: Text(
                            productName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Bid Amount: ₹${bidAmount.toStringAsFixed(2)}\nFarmer: $farmerName',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () => _updateBidStatus(bidId, 'locked', productId, retailerId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text('Accept'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _updateBidStatus(bidId, 'rejected', null, retailerId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Reject'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Function to update the bid status and add an order if accepted
  Future<void> _updateBidStatus(String bidId, String newStatus, String? productId, String retailerId) async {
    try {
      // Update the bid status
      await FirebaseFirestore.instance.collection('Bids').doc(bidId).update({
        'status': newStatus,
      });

      if (newStatus == 'locked' && productId != null) {
        // Fetch the product document to get details
        DocumentSnapshot productSnapshot =
        await FirebaseFirestore.instance.collection('Products').doc(productId).get();

        if (productSnapshot.exists) {
          Map<String, dynamic> productData = productSnapshot.data() as Map<String, dynamic>;

          // Add the data to Orders collection
          await FirebaseFirestore.instance.collection('Orders').add({
            'productID': productId,
            'retailerId': retailerId, // Taken from Bids collection
            'farmerId': productData['farmerId'], // Extracted from product
            'bidId': bidId,
            'orderDate': FieldValue.serverTimestamp(), // Optional timestamp
          });
        }
      }

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'locked'
                ? 'Offer accepted successfully!'
                : 'Offer rejected successfully!',
          ),
        ),
      );
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }
}