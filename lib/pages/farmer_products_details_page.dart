import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FarmerProductDetailsPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const FarmerProductDetailsPage({
    Key? key,
    required this.productId,
    required this.productData,
  }) : super(key: key);

  @override
  _FarmerProductDetailsPageState createState() =>
      _FarmerProductDetailsPageState();
}

class _FarmerProductDetailsPageState extends State<FarmerProductDetailsPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> bidsWithRetailerNames = [];

  @override
  void initState() {
    super.initState();
    _loadBids();
  }

  Future<void> _loadBids() async {
    try {
      QuerySnapshot bidSnapshot = await FirebaseFirestore.instance
          .collection('Bids')
          .where('productId', isEqualTo: widget.productId)
          .get();

      List<Map<String, dynamic>> loadedBids = [];

      for (var doc in bidSnapshot.docs) {
        Map<String, dynamic> bidData = doc.data() as Map<String, dynamic>;
        DocumentSnapshot retailerSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .doc(bidData['retailerId'])
            .get();

        String retailerName = retailerSnapshot.exists
            ? retailerSnapshot['username'] ?? 'Unknown'
            : 'Retailer not found';

        loadedBids.add({
          'bidId': doc.id,
          'bidAmount': bidData['bidAmount'],
          'retailerName': retailerName,
          'retailerId': bidData['retailerId'],
          'status': bidData['status'],
          'quantity': bidData['quantity'], // Assuming bid includes quantity
        });
      }

      setState(() {
        bidsWithRetailerNames = loadedBids;
      });
    } catch (e) {
      print('Error loading bids: $e');
    }
  }

  Future<void> _acceptBid(String bidId, int bidQuantity) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch the current available quantity from the Products collection
      DocumentReference productRef =
      FirebaseFirestore.instance.collection('Products').doc(widget.productId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot productSnapshot = await transaction.get(productRef);

        if (!productSnapshot.exists) {
          throw Exception("Product does not exist");
        }

        int currentQuantity = productSnapshot['availableQuantity'] ?? 0;

        if (currentQuantity < bidQuantity) {
          throw Exception("Insufficient product quantity");
        }

        // Subtract the bid quantity from the available quantity
        transaction.update(productRef, {
          'availableQuantity': currentQuantity - bidQuantity,
        });

        // Update the status of the bid
        transaction.update(
          FirebaseFirestore.instance.collection('Bids').doc(bidId),
          {'status': 'pending'},
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer accepted. Waiting for retailer to accept.')),
      );

      // Refresh bids
      _loadBids();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting bid: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _displayBids() {
    if (bidsWithRetailerNames.isEmpty) {
      return const Center(child: Text('No bids available'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: bidsWithRetailerNames.map((bid) {
        return Card(
          child: ListTile(
            title: Text('Bid: \$${bid['bidAmount']}'),
            subtitle: Text('Retailer: ${bid['retailerName']}'),
            trailing: bid['status'] == 'offered'
                ? ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _acceptBid(bid['bidId'], bid['quantity'] ?? 0),
              child: const Text('Accept Offer'),
            )
                : (bid['status'] == 'pending'
                ? const Text('Waiting for retailer to accept')
                : null),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> product = widget.productData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product: ${product['productName']}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text('Description: ${product['description']}'),
              const SizedBox(height: 20),
              Text('Current Bid: \₹${product['currentBid'] ?? 0.0}'),
              const SizedBox(height: 20),
              Text(
                'Available Quantity: ${product['availableQuantity']}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              const Text(
                'Bids:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              _displayBids(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                  await FirebaseFirestore.instance
                      .collection('Products')
                      .doc(widget.productId)
                      .update({'status': 'closed'});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Stop Bidding'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
