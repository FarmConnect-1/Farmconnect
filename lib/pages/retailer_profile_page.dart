import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RetailerProfilePage extends StatefulWidget {
  const RetailerProfilePage({super.key});

  @override
  _RetailerProfilePageState createState() => _RetailerProfilePageState();
}

class _RetailerProfilePageState extends State<RetailerProfilePage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _businessController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (_user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(_user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _usernameController.text = userDoc['username'] ?? '';
          _emailController.text = userDoc['email'] ?? '';
          _businessController.text = userDoc['businessName'] ?? '';
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_user != null) {
      await FirebaseFirestore.instance.collection('Users').doc(_user.uid).update({
        'username': _usernameController.text.trim(),
        'businessName': _businessController.text.trim(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retailer Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: _user?.photoURL != null
                  ? NetworkImage(_user!.photoURL!)
                  : const AssetImage('assets/default_profile.png') as ImageProvider,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              readOnly: true, // Email is usually not editable
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _businessController,
              decoration: const InputDecoration(labelText: 'Business Name'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateProfile,
              child: const Text('Update Profile'),
            ),
          ],
        ),
      ),
    );
  }
}