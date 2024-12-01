import 'package:farmconnect/pages/product_details_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/farmer_home_page.dart';
import 'pages/retailer_home_page.dart';
import 'pages/transporter_home_page.dart';
import 'pages/farmer_profile_page.dart';
import 'pages/retailer_profile_page.dart';
import 'pages/bid_history_page.dart';
import 'pages/order_history_page.dart';
import 'pages/farmer_order_history_page.dart';
import 'pages/select_transport_provider.dart';
import 'pages/retailer_offers.dart';
import 'pages/chatlist.dart';
import 'pages/chat_details_page.dart';

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
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/farmer_home': (context) => const FarmerHomePage(),
        '/farmer_profile': (context) => const FarmerProfilePage(),
        '/retailer_home': (context) => const RetailerHomePage(),
        '/retailer_profile': (context) => const RetailerProfilePage(),
        '/transporter_home': (context) => const TransporterHomePage(),
        '/product_details': (context) => const ProductDetailsPage(productId: ''),
        '/bid_history': (context) => const BidHistoryPage(),
        '/order_history_page': (context) => const OrderHistoryPage(),
        '/farmer_order_history': (context) => const FarmerOrderHistoryPage(),
        '/selectTransportProvider': (context) => const SelectTransportProviderPage(
          productId: '',
          productName: '',
        ),
        '/retailer_offers': (context) => const RetailerOffers(),
        '/chatlist': (context) => const ChatListPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/chat_details') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ChatDetailsPage(
              chatId: args['chatId'],
              recipientName: args['recipientName'],
            ),
          );
        }
        return null;
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<String?> _getUserRole() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
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
                return const HomePage();
              }
            },
          );
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
