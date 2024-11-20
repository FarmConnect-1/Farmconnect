import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FarmerProfilePage extends StatelessWidget {
  const FarmerProfilePage({super.key});

  Future<Map<String, dynamic>> _getFarmerDetails() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      DocumentSnapshot farmerSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      if (farmerSnapshot.exists) {
        return farmerSnapshot.data() as Map<String, dynamic>;
      }
    }

    return {};
  }

  Future<double> _getFarmerRating() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      DocumentSnapshot ratingSnapshot = await FirebaseFirestore.instance
          .collection('Ratings')
          .doc(user.uid)
          .get();

      if (ratingSnapshot.exists) {
        return (ratingSnapshot['rating'] ?? 0.0).toDouble();
      }
    }

    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Profile'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getFarmerDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading profile'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No profile data found'));
          }

          Map<String, dynamic> farmerData = snapshot.data!;
          String profilePictureUrl = farmerData['profilePicture'] ?? '';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: profilePictureUrl.isNotEmpty
                        ? NetworkImage(profilePictureUrl)
                        : const AssetImage('assets/placeholder.png')
                    as ImageProvider, // Use a placeholder image if no profile picture exists
                    onBackgroundImageError: (_, __) {
                      // Handle error when loading profile picture fails
                      print('Error loading profile picture');
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Name: ${farmerData['username']}',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text('Email: ${farmerData['email']}'),
                const SizedBox(height: 10),
                Text(
                    'Farmer Certificate Number: ${farmerData['farmerCertificateNumber']}'),
                const SizedBox(height: 10),
                Text('Address: ${farmerData['address']}'),
                const SizedBox(height: 10),
                Text('District: ${farmerData['district']}'),
                const SizedBox(height: 10),
                Text('State: ${farmerData['state']}'),
                const SizedBox(height: 20),
                FutureBuilder<double>(
                  future: _getFarmerRating(),
                  builder: (context, ratingSnapshot) {
                    if (ratingSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (ratingSnapshot.hasError) {
                      return const Center(child: Text('Error loading rating'));
                    }
                    double rating = ratingSnapshot.data ?? 0.0;
                    return Text(
                      'Rating: ${rating.toStringAsFixed(1)} / 5',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}