import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'product_details_page.dart';
import 'retailer_offers.dart'; // Import RetailersOfferPage
import 'chatlist.dart'; // Import the ChatListPage

class RetailerHomePage extends StatefulWidget {
  const RetailerHomePage({super.key});

  @override
  _RetailerHomePageState createState() => _RetailerHomePageState();
}

class _RetailerHomePageState extends State<RetailerHomePage> {
  String searchQuery = '';

  void _goToProfile(BuildContext context) {
    Navigator.pushNamed(context, '/retailer_profile');
  }

  void _goToNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RetailerOffers(),
      ),
    );
  }

  void _goToChatList(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatListPage(),
      ),
    );
  }

  void _goToProductDetails(BuildContext context, String productId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsPage(productId: productId),
      ),
    );
  }

  void _goToOrders(BuildContext context) {
    Navigator.pushNamed(context, '/bid_history');
  }

  Future<void> _confirmLogout(BuildContext context) async {
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirm) {
      try {
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacementNamed(context, '/login');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo1.png',
              height: 55,
            ),
            const SizedBox(width: 10),
            const Text(
              'Retailer Home',
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat), // Chat icon
            onPressed: () => _goToChatList(context), // Navigate to ChatListPage
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              _goToNotifications(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              _goToProfile(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _confirmLogout(context);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search products...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (query) {
                setState(() {
                  searchQuery = query.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Products')
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error fetching products'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No active products found'));
          }

          var filteredProducts = snapshot.data!.docs.where((DocumentSnapshot document) {
            Map<String, dynamic> product = document.data() as Map<String, dynamic>;
            String productName = product['productName'].toLowerCase();
            return productName.contains(searchQuery);
          }).toList();

          return ListView(
            children: filteredProducts.map((DocumentSnapshot document) {
              Map<String, dynamic> product = document.data() as Map<String, dynamic>;
              List<dynamic> productImages = product['productImages'] ?? [];
              double startingBid = product['startingBid']?.toDouble() ?? 0.0;
              double currentBid = (product['currentBid']?.toDouble() ?? startingBid);
              String highestBidder = product['highestBidder'] ?? '';

              Color bidColor;
              if (highestBidder.isEmpty) {
                bidColor = Colors.black;
              } else if (highestBidder == user?.uid) {
                bidColor = Colors.green;
              } else {
                bidColor = Colors.red;
              }

              return Card(
                margin: const EdgeInsets.all(10),
                elevation: 5,
                child: ListTile(
                  leading: productImages.isNotEmpty
                      ? Image.network(
                    productImages[0],
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  )
                      : const Icon(Icons.image_not_supported),
                  title: Text(
                    product['productName'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    highestBidder.isEmpty
                        ? 'Starting Bid: \$${startingBid.toStringAsFixed(2)}'
                        : 'Highest Bid: \$${currentBid.toStringAsFixed(2)}',
                    style: TextStyle(color: bidColor),
                  ),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => _goToProductDetails(context, document.id),
                ),
              );
            }).toList(),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () => _goToOrders(context),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
          child: const Text('View Orders'),
        ),
      ),
    );
  }
}
