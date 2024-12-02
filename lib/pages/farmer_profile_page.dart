import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FarmerProfilePage extends StatefulWidget {
  const FarmerProfilePage({super.key});

  @override
  _FarmerProfilePageState createState() => _FarmerProfilePageState();
}

class _FarmerProfilePageState extends State<FarmerProfilePage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _farmController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController(); // Controller for balance input

  double _balance = 0.0; // To store current balance

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadBalance();
  }

  // Load farmer profile details
  Future<void> _loadProfile() async {
    if (_user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(_user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _usernameController.text = userDoc['username'] ?? '';
          _emailController.text = userDoc['email'] ?? '';
          _farmController.text = userDoc['farmName'] ?? '';
        });
      }
    }
  }

  // Load current balance from Firestore
  Future<void> _loadBalance() async {
    if (_user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('Users').doc(_user.uid).get();
      if (userDoc.exists && userDoc['balance'] != null) {
        setState(() {
          _balance = userDoc['balance'].toDouble();
        });
      }
    }
  }

  // Update profile details in Firestore
  Future<void> _updateProfile() async {
    if (_user != null) {
      await FirebaseFirestore.instance.collection('Users').doc(_user.uid).update({
        'username': _usernameController.text.trim(),
        'farmName': _farmController.text.trim(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
    }
  }

  // Add balance to Firestore
  Future<void> _addBalance() async {
    double enteredAmount = double.tryParse(_balanceController.text) ?? 0.0;
    if (enteredAmount > 0) {
      setState(() {
        _balance += enteredAmount; // Update balance locally
      });
      if (_user != null) {
        await FirebaseFirestore.instance.collection('Users').doc(_user.uid).update({
          'balance': _balance, // Update balance in Firestore
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Balance updated successfully!')));
        _balanceController.clear();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Profile'),
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
              controller: _farmController,
              decoration: const InputDecoration(labelText: 'Farm Name'),
            ),
            const SizedBox(height: 20),
            Text('Balance: \$${_balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            // Input field to enter balance amount
            TextField(
              controller: _balanceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Enter Amount to Add'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addBalance,
              child: const Text('Add Balance'),
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
