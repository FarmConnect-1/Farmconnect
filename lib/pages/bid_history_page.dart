import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BidHistoryPage extends StatefulWidget {
  const BidHistoryPage({super.key});

  @override
  _BidHistoryPageState createState() => _BidHistoryPageState();
}

class _BidHistoryPageState extends State<BidHistoryPage> {
  User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Closed Deals'),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('Bids')
            .where('retailerId', isEqualTo: currentUser?.uid) // Only bids from this retailer
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Error loading bid history.'));
          }

          List<QueryDocumentSnapshot> allBids = snapshot.data?.docs ?? [];

          if (allBids.isEmpty) {
            return const Center(child: Text('No closed deals found.'));
          }

          // Use a Set to keep track of displayed product IDs
          Set<String> displayedProductIds = {};

          return ListView.builder(
            itemCount: allBids.length,
            itemBuilder: (context, index) {
              var bid = allBids[index];
              String productId = bid['productId'];

              // For each bid, get the associated product
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('Products')
                    .doc(productId)
                    .get(),
                builder: (context, productSnapshot) {
                  if (productSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Loading product...'),
                    );
                  }

                  if (productSnapshot.hasError || !productSnapshot.hasData || productSnapshot.data == null) {
                    return const ListTile(
                      title: Text('Error loading product details or product no longer exists.'),
                    );
                  }

                  var productData = productSnapshot.data?.data() as Map<String, dynamic>?;

                  if (productData == null) {
                    return const ListTile(
                      title: Text('Product details are not available.'),
                    );
                  }

                  // Check if the product is closed and if the current retailer is the highest bidder
                  String productStatus = productData['status'] ?? 'active'; // Checking the product's status
                  String highestBidder = productData['highestBidder'] ?? ''; // Get the highest bidder UID

                  // Only show products where the retailer has the highest bid and the status is closed
                  if (productStatus != 'closed' || highestBidder != currentUser?.uid) {
                    return Container(); // Skip if the deal is not closed or the retailer is not the highest bidder
                  }

                  String productName = productData['productName'] ?? 'Unknown';

                  // Check if the product has already been displayed
                  if (displayedProductIds.contains(productId)) {
                    return Container(); // Skip if the product is already displayed
                  } else {
                    displayedProductIds.add(productId); // Add product ID to the set
                  }

                  return ListTile(
                    title: Text(productName),
                    subtitle: Text('Your Bid: \$${bid['bidAmount'].toString()}'),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Closed',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Add Button for selecting a transport provider
                        ElevatedButton(
                          onPressed: () {
                            // Navigate to Select Transport Provider page
                            Navigator.pushNamed(
                              context,
                              '/selectTransportProvider',
                              arguments: {
                                'productId': productId,
                                'productName': productName,
                              }, // Pass necessary product details
                            );
                          },
                          child: const Text('Select Transport Provider'),
                        ),
                      ],
                    ),
                    onTap: () {
                      // Navigate to the Product Details page
                      Navigator.pushNamed(
                        context,
                        '/product_details', // Adjusted to match the naming convention
                        arguments: productId, // Passing the product ID to the product details page
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
}
