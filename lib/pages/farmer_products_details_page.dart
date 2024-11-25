import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

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

  // Function to load bids and retailer names
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
          'bidAmount': bidData['bidAmount'],
          'retailerName': retailerName,
          'timestamp': bidData['timestamp'],
          'retailerId': bidData['retailerId'],
        });
      }

      setState(() {
        bidsWithRetailerNames = loadedBids;
      });
    } catch (e) {
      print('Error loading bids: $e');
    }
  }

  // Function to accept a bid
  Future<void> _acceptBid(String retailerId, double bidAmount) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Update product status and assign the highest bidder
      await FirebaseFirestore.instance
          .collection('Products')
          .doc(widget.productId)
          .update({
        'status': 'closed',
        'highestBidder': retailerId,
        'currentBid': bidAmount,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer accepted and bidding closed.')),
      );

      // Refresh data after accepting bid
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

  // Function to stop bidding manually
  Future<void> _stopBidding() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('Products')
          .doc(widget.productId)
          .update({'status': 'closed'});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bidding stopped manually.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping bidding: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Display bids with "Accept Offer" functionality
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
            trailing: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _acceptBid(bid['retailerId'], bid['bidAmount']),
              child: const Text('Accept Offer'),
            ),
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
                style:
                const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text('Description: ${product['description']}'),
              const SizedBox(height: 20),
              Text('Current Bid: \$${product['currentBid'] ?? 0.0}'),
              const SizedBox(height: 20),
              const Text(
                'Bids:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              _displayBids(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _stopBidding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Stop Bid'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
