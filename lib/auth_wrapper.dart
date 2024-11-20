import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/farmer_home_page.dart';
import 'pages/retailer_home_page.dart';
import 'pages/transporter_home_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

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
    return FutureBuilder<String?>(
      future: _getUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return const Center(child: Text('Error fetching role'));
        } else if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text('Role not found'));
        } else {
          String role = snapshot.data!;
          if (role == 'farmer') {
            return const FarmerHomePage();
          } else if (role == 'retailer') {
            return const RetailerHomePage();
          } else if (role == 'transport_provider') {
            return const TransporterHomePage();
          } else {
            return const Center(child: Text('Unknown role'));
          }
        }
      },
    );
  }
}
