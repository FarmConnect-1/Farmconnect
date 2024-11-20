import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<String?> _getUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();
      return doc['role'];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: FutureBuilder<String?>(
        future: _getUserRole(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          } else if (snapshot.hasError) {
            return const Text('Error fetching role');
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Text('Role not found');
          } else {
            String role = snapshot.data!;
            String welcomeMessage = 'Welcome, ${role == 'farmer' ? 'Farmer' : role == 'retailer' ? 'Retailer' : 'Transport Provider'}!';
            return Center(
              child: Text(
                welcomeMessage,
                style: const TextStyle(fontSize: 24),
              ),
            );
          }
        },
      ),
    );
  }
}

