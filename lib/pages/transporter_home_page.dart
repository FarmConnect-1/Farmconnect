import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'transporter_profile_page.dart'; // Import the new transporter profile page
import 'login_page.dart'; // Import the login page or welcome screen after logout

class TransporterHomePage extends StatefulWidget {
  const TransporterHomePage({super.key, required String username, required String email});

  @override
  _TransporterHomePageState createState() => _TransporterHomePageState();
}

class _TransporterHomePageState extends State<TransporterHomePage> {
  // Function to fetch transport requests
  Stream<QuerySnapshot> _fetchTransportRequests() {
    return FirebaseFirestore.instance.collection('Products').where('status', isEqualTo: 'open').snapshots();
  }

  // Function to handle logout
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(), // Navigate to your login page after logout
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transporter Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransporterProfilePage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout), // Logout icon
            onPressed: () {
              _logout();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Available Transport Requests',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _fetchTransportRequests(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  var products = snapshot.data!.docs;

                  if (products.isEmpty) {
                    return const Center(
                      child: Text('No transport requests available.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      var product = products[index];
                      return Card(
                        elevation: 3,
                        child: ListTile(
                          title: Text(product['productName']),
                          subtitle: Text(product['description']),
                          trailing: ElevatedButton(
                            onPressed: () {
                              _acceptTransportRequest(product.id);
                            },
                            child: const Text('Accept Job'),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function to accept a transport request
  Future<void> _acceptTransportRequest(String productId) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Update the product document with the transporter's details
      await FirebaseFirestore.instance.collection('Products').doc(productId).update({
        'transportProviderId': user.uid,
        'status': 'in_progress',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transport request accepted!')),
      );
    }
  }
}