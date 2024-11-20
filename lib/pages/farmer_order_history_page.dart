import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FarmerOrderHistoryPage extends StatelessWidget {
  const FarmerOrderHistoryPage({super.key});

  // Fetch products with 'stopped' status
  Stream<QuerySnapshot> _fetchStoppedProducts() {
    return FirebaseFirestore.instance
        .collection('Products')
        .where('status', isNotEqualTo: 'active')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchStoppedProducts(),
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
                return ListTile(
                  title: Text(product['productName']),
                  subtitle: Text('Status: ${product['status']}'),
                );
              },
            );
          } else {
            return const Center(child: Text('No stopped orders found.'));
          }
        },
      ),
    );
  }
}