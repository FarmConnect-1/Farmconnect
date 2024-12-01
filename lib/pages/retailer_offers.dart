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

              String productName = bidData['productName'] ?? 'Unknown Product';
              double bidAmount = bidData['bidAmount']?.toDouble() ?? 0.0;
              String farmerName = bidData['farmerName'] ?? 'Unknown Farmer';
              String bidId = bids[index].id;
              String status = bidData['status'] ?? 'pending';

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
                  trailing: status == 'pending'
                      ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => _updateBidStatus(bidId, 'locked'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: const Text('Accept'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _updateBidStatus(bidId, 'rejected'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Reject'),
                      ),
                    ],
                  )
                      : Text(
                    status == 'locked'
                        ? 'Offer Accepted'
                        : 'Offer Rejected',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: status == 'locked' ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Function to update the bid status
  Future<void> _updateBidStatus(String bidId, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('Bids').doc(bidId).update({
        'status': newStatus,
      });
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