import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RetailerOffers extends StatefulWidget {
  const RetailerOffers({super.key});

  @override
  _RetailerOffersPageState createState() => _RetailerOffersPageState();
}

class _RetailerOffersPageState extends State<RetailerOffers> {
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    // Fetch the current user's ID
    currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pending Offers'),
        ),
        body: const Center(child: Text('User not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Offers'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Bids')
            .where('status', isEqualTo: 'pending')
            .where('retailerId', isEqualTo: currentUserId) // Current user's ID
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
                                onPressed: () => _updateBidStatus(bidId, 'locked', productId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text('Accept'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _updateBidStatus(bidId, 'rejected', null),
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

  Future<void> _updateBidStatus(String bidId, String newStatus, String? productId) async {
    try {
      await FirebaseFirestore.instance.collection('Bids').doc(bidId).update({
        'status': newStatus,
      });

      if (newStatus == 'locked' && productId != null) {
        DocumentSnapshot productSnapshot =
        await FirebaseFirestore.instance.collection('Products').doc(productId).get();

        if (productSnapshot.exists) {
          Map<String, dynamic> productData = productSnapshot.data() as Map<String, dynamic>;

          await FirebaseFirestore.instance.collection('Orders').add({
            'productID': productId,
            'retailerId': currentUserId,
            'farmerId': productData['farmerId'],
            'bidId': bidId,
            'orderDate': FieldValue.serverTimestamp(),
          });
        }
      }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }
}
