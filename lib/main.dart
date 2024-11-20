import 'package:farmconnect/pages/product_details_page.dart'; // Import product details page
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/farmer_home_page.dart'; // Import role-specific pages
import 'pages/retailer_home_page.dart';
import 'pages/transporter_home_page.dart';
import 'pages/farmer_profile_page.dart'; // Import farmer profile page
import 'pages/retailer_profile_page.dart'; // Import retailer profile page
import 'pages/bid_history_page.dart'; // Import bid history page
import 'pages/order_history_page.dart';
import 'pages/farmer_order_history_page.dart';
import 'pages/select_transport_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Farm Connect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/', // Set the initial route
      routes: {
        '/': (context) => const AuthWrapper(), // Checks auth state
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(), // You can keep this for a generic home
        '/farmer_home': (context) => const FarmerHomePage(), // Farmer home route
        '/farmer_profile': (context) => const FarmerProfilePage(), // Farmer profile route
        '/retailer_home': (context) => const RetailerHomePage(), // Retailer home route
        '/retailer_profile': (context) => const RetailerProfilePage(), // Retailer profile route
        '/transporter_home': (context) => const TransporterHomePage(), // Transport provider home route
        '/product_details': (context) => const ProductDetailsPage(productId: ''), // Product details route
        '/bid_history': (context) => const BidHistoryPage(), // Bid history route
        '/order_history': (context) => const OrderHistoryPage(),
        '/farmer_order_history': (context) => const FarmerOrderHistoryPage(),
        '/selectTransportProvider': (context) => const SelectTransportProviderPage(productId: '', productName: '',) // Ensure this is defined correctly
      },
    );
  }
}

// Wrapper to handle authentication state and role-based redirection
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<String?> _getUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Fetch the user's role from Firestore
      DocumentSnapshot userDoc =
      await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
      if (userDoc.exists) {
        return userDoc['role'] as String?;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        } else if (snapshot.hasError) {
          return const Center(
            child: Text('Something went wrong!'),
          );
        } else if (snapshot.hasData) {
          // User is logged in, now check their role and redirect accordingly
          return FutureBuilder<String?>(
            future: _getUserRole(),
            builder: (context, AsyncSnapshot<String?> roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (roleSnapshot.hasError || !roleSnapshot.hasData) {
                return const Center(child: Text('Failed to retrieve role!'));
              }

              String? role = roleSnapshot.data;
              if (role == 'farmer') {
                return const FarmerHomePage();
              } else if (role == 'retailer') {
                return const RetailerHomePage();
              } else if (role == 'transport_provider') {
                return const TransporterHomePage();
              } else {
                return const HomePage(); // Fallback if role not found
              }
            },
          );
        } else {
          return const LoginPage(); // Redirect to LoginPage if not logged in
        }
      },
    );
  }
}
