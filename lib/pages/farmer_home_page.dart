import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_product_page.dart';
import 'farmer_products_details_page.dart';
import 'farmer_profile_page.dart';
import 'farmer_order_history_page.dart';
import 'chatlist.dart';

class FarmerHomePage extends StatefulWidget {
  final String username;
  final String email;

  const FarmerHomePage({
    Key? key,
    required this.username,
    required this.email
  }) : super(key: key);

  @override
  _FarmerHomePageState createState() => _FarmerHomePageState();
}

class _FarmerHomePageState extends State<FarmerHomePage> {
  User? user;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;

    // If no user is logged in, redirect to login
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _goToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FarmerProfilePage()),
    );
  }

  void _goToAddProduct(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddProductPage()),
    );
  }

  _goToChatList(BuildContext context, String currentUserId, String userRole) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatListPage(currentUserRole: userRole),
      ),
    );
  }

  void _goToProductDetails(BuildContext context, String productId,
      Map<String, dynamic> productData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FarmerProductDetailsPage(
              productId: productId,
              productData: productData,
            ),
      ),
    );
  }

  void _goToOrderHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FarmerOrderHistoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if the user is logged in
    if (user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("User is not logged in."),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Go to Login'),
              )
            ],
          ),
        ),
      );
    }

    String currentUserId = user!.uid;
    String userRole = "farmer";

    return Scaffold(
      appBar: AppBar(
        // Add the logo in the leading property of the AppBar
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          // Optional: Adjust padding as needed
          child: Image.asset(
            'assets/logo1.png', // Path to your logo file
            height: 100, // Adjust the height as needed
          ),
        ),
        title: const Text('Farmer Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat), // Chat icon
            onPressed: () =>
                _goToChatList(context, currentUserId,
                    userRole), // Pass the currentUserId and userRole
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _goToProfile(context), // Go to the profile page
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                _logout(context), // Show logout confirmation dialog
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Welcome, Farmer!',
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Products')
                  .where('farmerId', isEqualTo: user?.uid)
                  .where('status',
                  isEqualTo: 'active') // Exclude products with status 'closed'
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error fetching products'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No products found'));
                }

                return ListView(
                  children: snapshot.data!.docs.map((
                      DocumentSnapshot document) {
                    Map<String, dynamic> product = document.data() as Map<
                        String,
                        dynamic>;

                    // Safely handle numeric values, converting them to double
                    double currentBid = 0.0;
                    if (product['currentBid'] is int) {
                      currentBid = (product['currentBid'] as int).toDouble();
                    } else if (product['currentBid'] is double) {
                      currentBid = product['currentBid'];
                    }

                    return ListTile(
                      title: Text(product['productName']),
                      subtitle: Text(
                          'Current Bid: \$${currentBid.toStringAsFixed(2)}'),
                      trailing: Text(product['status']),
                      onTap: () {
                        _goToProductDetails(context, document.id, product);
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => _goToAddProduct(context),
              child: const Text('Add Product'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _goToOrderHistory(context),
              // Navigate to order history page
              child: const Text('Order History'),
            ),
          ],
        ),
      ),
    );
  }
}
