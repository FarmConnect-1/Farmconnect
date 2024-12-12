import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RetailerOffers extends StatefulWidget {
  const RetailerOffers({super.key});

  @override
  _RetailerOffersPageState createState() => _RetailerOffersPageState();
}

class _RetailerOffersPageState extends State<RetailerOffers> {
  User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  @override
  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pending Offers')),
        body: const Center(child: Text('You need to log in to view offers.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Offers'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0097b2), // Dodger Blue
              Color(0xFF87CEFA), // Light Sky Blue
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Bids')
              .where('status', isEqualTo: 'pending')
              .where('retailerId', isEqualTo: currentUser!.uid)
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
                String retailerId = bidData['retailerId'] ?? '';
                String bidId = bids[index].id;
                double bidAmount = (bidData['bidAmount'] ?? 0).toDouble();
                double bidQuantity = (bidData['quantity'] ?? 0).toDouble();

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('Products').doc(productId).get(),
                  builder: (context, productSnapshot) {
                    if (productSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (productSnapshot.hasError ||
                        !productSnapshot.hasData ||
                        !productSnapshot.data!.exists) {
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
                        if (userSnapshot.hasError ||
                            !userSnapshot.hasData ||
                            !userSnapshot.data!.exists) {
                          return const Center(child: Text('Error fetching farmer details'));
                        }

                        Map<String, dynamic> userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
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
                              'Bid Amount: ₹${bidAmount.toStringAsFixed(2)}\nBid Quantity: $bidQuantity\nFarmer: $farmerName',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () => _updateBidStatus(
                                      bidId, 'locked', productId, retailerId, farmerId, bidAmount, bidQuantity),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.green, // Green for accept button
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _updateBidStatus(
                                      bidId, 'rejected', null, retailerId, null, 0.0, bidQuantity),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.red, // Red for reject button
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                    ),
                                  ),
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
      ),
    );
  }



  Future<void> _updateBidStatus(
      String bidId,
      String newStatus,
      String? productId,
      String retailerId,
      String? farmerId,
      double bidAmount,
      double bidQuantity) async {
    try {
      await FirebaseFirestore.instance.collection('Bids').doc(bidId).update({
        'status': newStatus,
      });

      if (newStatus == 'locked' && productId != null && farmerId != null) {
        await FirebaseFirestore.instance.collection('Orders').add({
          'productID': productId,
          'retailerId': retailerId,
          'farmerId': farmerId,
          'bidId': bidId,
          'amountPaid': 0.10 * bidAmount * bidQuantity,
          'paymentLeft': (bidAmount * bidQuantity) -
              (0.10 * bidAmount * bidQuantity),
          'orderDate': FieldValue.serverTimestamp(),
        });

        DocumentReference retailerRef =
        FirebaseFirestore.instance.collection('Users').doc(retailerId);
        DocumentReference farmerRef =
        FirebaseFirestore.instance.collection('Users').doc(farmerId);

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentSnapshot retailerSnapshot =
          await transaction.get(retailerRef);
          double retailerBalance =
          (retailerSnapshot['balance'] ?? 0).toDouble();
          DocumentSnapshot farmerSnapshot = await transaction.get(farmerRef);
          double farmerBalance = (farmerSnapshot['balance'] ?? 0).toDouble();

          if (retailerBalance < 0.10 * bidAmount) {
            throw Exception('Retailer has insufficient balance');
          }

          transaction.update(
              retailerRef, {'balance': retailerBalance - (0.10 * bidAmount)});
          transaction.update(
              farmerRef, {'balance': farmerBalance + (0.10 * bidAmount)});
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer accepted successfully!')),
        );
      } else if (newStatus == 'rejected') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer rejected successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }
}