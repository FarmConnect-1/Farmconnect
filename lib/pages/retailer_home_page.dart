import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'product_details_page.dart';
import 'retailer_offers.dart';
import 'chatlist.dart';

class RetailerHome extends StatefulWidget {
  final String username;
  final String email;

  const RetailerHome({
    Key? key,
    required this.username,
    required this.email
  }) : super(key: key);

  @override
  _RetailerHomePageState createState() => _RetailerHomePageState();
}

class _RetailerHomePageState extends State<RetailerHome> {
  String searchQuery = '';
  String? selectedState;
  String? selectedDistrict;
  String? selectedTaluka;

  List<String> states = [];
  List<String> districts = [];
  List<String> talukas = [];

  List<QueryDocumentSnapshot> allProducts = [];
  List<QueryDocumentSnapshot> filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _fetchProducts();
  }

  Future<void> _fetchLocations() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('role', isEqualTo: 'farmer')
          .get();

      final uniqueStates = snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['state'] as String?)
          .where((state) => state != null && state.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      setState(() {
        states = uniqueStates.cast<String>();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching states: $e')),
      );
    }
  }

  Future<void> _fetchDistricts(String state) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('role', isEqualTo: 'farmer')
          .where('state', isEqualTo: state)
          .get();

      final uniqueDistricts = snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['district'] as String?)
          .where((district) => district != null && district.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      setState(() {
        districts = uniqueDistricts.cast<String>();
        talukas = [];
        selectedDistrict = null;
        selectedTaluka = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching districts: $e')),
      );
    }
  }

  Future<void> _fetchTalukas(String district) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('role', isEqualTo: 'farmer')
          .where('district', isEqualTo: district)
          .get();

      final uniqueTalukas = snapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['taluka'] as String?)
          .where((taluka) => taluka != null && taluka.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      setState(() {
        talukas = uniqueTalukas.cast<String>();
        selectedTaluka = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching talukas: $e')),
      );
    }
  }

  Future<void> _fetchProducts() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Products')
          .where('status', isEqualTo: 'active')
          .get();

      setState(() {
        allProducts = snapshot.docs;
        filteredProducts = List.from(allProducts);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching products: $e')),
      );
    }
  }

  void _applyFilters() async {
    if (selectedState == null && selectedDistrict == null && selectedTaluka == null) {
      setState(() {
        filteredProducts = List.from(allProducts);
      });
      return;
    }

    List<QueryDocumentSnapshot> filtered = [];

    for (var product in allProducts) {
      final farmerId = product['farmerId'];
      DocumentSnapshot farmerDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(farmerId)
          .get();

      final farmerData = farmerDoc.data() as Map<String, dynamic>?;
      if (farmerData == null) continue;

      final matchesState = selectedState == null || (farmerData['state'] ?? '') == selectedState;
      final matchesDistrict = selectedDistrict == null || (farmerData['district'] ?? '') == selectedDistrict;
      final matchesTaluka = selectedTaluka == null || (farmerData['taluka'] ?? '') == selectedTaluka;

      if (matchesState && matchesDistrict && matchesTaluka) {
        filtered.add(product);
      }
    }

    setState(() {
      filteredProducts = filtered;
    });
  }

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

  void _goToChatList(BuildContext context, String currentUserId, String userRole) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatListPage(currentUserRole: userRole),
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
    Navigator.pushNamed(context, '/order_history');
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

    if (user == null) {
      return const Center(child: Text('User not logged in'));
    }

    String currentUserId = user.uid;
    String userRole = 'retailer';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo1.png',
              height: 55,
            ),
            const SizedBox(width: 10),

          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () => _goToChatList(context, currentUserId, userRole),
          ),
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => _goToNotifications(context),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => _goToProfile(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (query) {
                    setState(() {
                      searchQuery = query.toLowerCase();
                      _applyFilters();
                    });
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedState,
                        hint: const Text('Select State'),
                        items: states.map((state) {
                          return DropdownMenuItem(
                            value: state,
                            child: Text(state),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedState = value;
                            _fetchDistricts(value!);
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedDistrict,
                        hint: const Text('Select District'),
                        items: districts.map((district) {
                          return DropdownMenuItem(
                            value: district,
                            child: Text(district),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedDistrict = value;
                            _fetchTalukas(value!);
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: selectedTaluka,
                        hint: const Text('Select Taluka'),
                        items: talukas.map((taluka) {
                          return DropdownMenuItem(
                            value: taluka,
                            child: Text(taluka),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedTaluka = value;
                            _applyFilters();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: filteredProducts.length,
        itemBuilder: (context, index) {
          final product = filteredProducts[index].data() as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.all(10),
            elevation: 5,
            child: ListTile(
              leading: product['productImages'] != null &&
                  (product['productImages'] as List).isNotEmpty
                  ? Image.network(
                product['productImages'][0],
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              )
                  : const Icon(Icons.image_not_supported),
              title: Text(product['productName'] ?? 'Unknown Product'),
              subtitle: Text(
                'Starting Bid: ₹${product['startingBid'] ?? 0}',
                style: const TextStyle(color: Colors.black),
              ),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => _goToProductDetails(context, filteredProducts[index].id),
            ),
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