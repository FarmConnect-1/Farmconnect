import 'package:farmconnect/pages/chat_page.dart';
import 'package:farmconnect/pages/product_details_page.dart';
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
import 'pages/order_history_page.dart';
import 'pages/farmer_order_history_page.dart';
import 'pages/select_transport_provider.dart';
import 'pages/retailer_offers.dart';
import 'pages/chatlist.dart'; // Import ChatListPage
import 'pages/welcome_page.dart';
import 'pages/farmer_signup_page.dart';
import 'pages/transporter_signup_page.dart';
import 'pages/signUp.dart';
import 'pages/roleandaddress_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }
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
      initialRoute: '/welcome_page', // Set the initial route
      onGenerateRoute: _generateRoute, // Use dynamic route generation
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (context) => const AuthWrapper());
      case '/login':
        return MaterialPageRoute(builder: (context) => const LoginPage());
      case '/home':
        return MaterialPageRoute(builder: (context) => const HomePage());
      case '/welcome_page':
        return MaterialPageRoute(builder: (context) => const WelcomePage());
      case '/signup':
        return MaterialPageRoute(builder: (context) => SignUp());
      case '/farmer_home':
        return MaterialPageRoute(builder: (context) => const FarmerHomePage(username: '', email: '',));
      case '/farmer_profile':
        return MaterialPageRoute(builder: (context) => const FarmerProfilePage());
      case '/retailer_home':
        return MaterialPageRoute(builder: (context) => const RetailerHome(username: '', email: '',));
      case '/retailer_profile':
        return MaterialPageRoute(builder: (context) => const RetailerProfilePage());
      case '/roleandaddress_page':
        return MaterialPageRoute(builder: (context) => const RoleAndAddressPage(name: '', email: '', phoneNumber: '', password: '',),);
      case '/transporter_home':
        return MaterialPageRoute(builder: (context) => const TransporterHomePage(username: '', email: '',));

      case '/farmer_signup_page':
        return MaterialPageRoute(builder: (context) => const FarmerSignupPage(username: '', email: '', phoneNumber: '', password: '', address: '', pincode: '', role: '',));
      case '/product_details':
        return MaterialPageRoute(
          builder: (context) => const ProductDetailsPage(productId: ''),
        );

      case '/order_history':
        return MaterialPageRoute(builder: (context) => const OrderHistoryPage());
      case '/farmer_order_history':
        return MaterialPageRoute(
          builder: (context) => const FarmerOrderHistoryPage(),
        );
      case '/selectTransportProvider':
        return MaterialPageRoute(
          builder: (context) =>
          const SelectTransportProviderPage(productId: '', productName: ''),
        );
      case '/retailer_offers':
        return MaterialPageRoute(builder: (context) => const RetailerOffers());
      case '/chat':
        final args = settings.arguments as Map<String, dynamic>?; // Retrieve arguments
        if (args != null &&
            args.containsKey('currentUserId') &&
            args.containsKey('targetUserId') &&
            args.containsKey('targetUserName')) {
          return MaterialPageRoute(
            builder: (context) => ChatPage(
              currentUserId: args['currentUserId'],
              targetUserId: args['targetUserId'],
              targetUserName: args['targetUserName'],
            ),
          );
        }
        return _errorRoute(); // Handle missing arguments

      case '/chat_list':
        final args = settings.arguments as Map<String, dynamic>?; // Retrieve arguments
        if (args != null && args.containsKey('currentUserRole')) {
          return MaterialPageRoute(
            builder: (context) =>
                ChatListPage(currentUserRole: args['currentUserRole']),
          );
        }
        return _errorRoute(); // Handle missing arguments
      default:
        return _errorRoute();
    }
  }

  Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (context) => const Scaffold(
        body: Center(child: Text('Page not found!')),
      ),
    );
  }
}

// Wrapper to handle authentication state and role-based redirection
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<String?> _getUserRole() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
        if (userDoc.exists) {
          return userDoc['role'] as String?;
        }
      }
    } catch (e) {
      debugPrint('Error fetching user role: $e');
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
                return const FarmerHomePage(username: '', email: '',);
              } else if (role == 'retailer') {
                return const RetailerHome(username: '', email: '',);
              } else if (role == 'transport_provider') {
                return const TransporterHomePage(username: '', email: '',);
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