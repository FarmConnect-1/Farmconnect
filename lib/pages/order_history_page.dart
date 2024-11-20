import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderHistoryPage extends StatelessWidget {
  const OrderHistoryPage({super.key});

  Future<QuerySnapshot?> _fetchOrders(String status) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Return actual order data if the user is authenticated
      return FirebaseFirestore.instance
          .collection('Orders')
          .where('farmerId', isEqualTo: user.uid)
          .where('status', isEqualTo: status)
          .get();
    }

    // Return null if there's no authenticated user
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Number of tabs for statuses
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Order History'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'In Transport'),
              Tab(text: 'Delivered'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrderList(context, 'Pending'),
            _buildOrderList(context, 'In Transport'),
            _buildOrderList(context, 'Delivered'),
          ],
        ),
      ),
    );
  }

  // Widget to build each order list based on the status
  Widget _buildOrderList(BuildContext context, String status) {
    return FutureBuilder<QuerySnapshot?>(
      future: _fetchOrders(status),
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

            return ListTile(
              title: Text(order['productName']),
              subtitle: Text('Buyer: ${order['buyerName']} | Quantity: ${order['quantity']}'),
              trailing: Text(order['status']),
            );
          }).toList(),
        );
      },
    );
  }
}