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
                Navigator.of(context).pop(false); // User cancels the logout
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // User confirms the logout
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(

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

          return Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/light_green.jpg'), // Background image
                fit: BoxFit.cover, // Adjust the image to cover the screen
              ),
            ),
            child: Stack(
              children: [
                // Light Green Section (Bottom 70%) overlapping the dark green section
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.3 - 50, // Overlap the dark green section by 50
                  left: 0,
                  right: 0,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.7 + 50, // Extend the height for the overlap
                    decoration: BoxDecoration(
                      color: Colors.lightGreen[50],
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: 70),
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 20), // Add some padding to the left
                            ),
                            Text(
                              '${farmerData['username'] ?? 'Unknown'}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[900],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 5),
                        Divider(thickness: 5, height: 10),//Thick divider
                        SizedBox(height: 10), // Space between name and other information
                        buildInfoRow(Icons.phone, 'Phone Number', '${farmerData['phoneNumber'] ?? 'N/A'}'),
                        Divider(thickness: 1, height: 25,indent: 50,endIndent: 40),
                        buildInfoRow(Icons.email, 'Email', '${farmerData['email'] ?? 'N/A'}'),
                        Divider(thickness: 1, height: 25,indent: 50,endIndent: 40),
                        buildInfoRow(Icons.document_scanner, 'Farmer Certificate Number', '${farmerData['farmerCertificateNumber'] ?? 'N/A'}'),
                        Divider(thickness: 1, height: 25,indent: 50,endIndent: 40),
                        buildInfoRow(Icons.home, 'Address', '${farmerData['address'] ?? 'N/A'}'),
                        Divider(thickness: 1, height: 25,indent: 50,endIndent: 40),
                        buildInfoRow(Icons.location_city, 'District', '${farmerData['district'] ?? 'N/A'}'),
                        Divider(thickness: 1, height: 25,indent: 50,endIndent: 40),
                        buildInfoRow(Icons.map, 'State', '${farmerData['state'] ?? 'N/A'}'),
                        Divider(thickness: 1, height: 25,indent: 50,endIndent: 40),
                        buildInfoRow(Icons.currency_rupee_rounded, 'Balance', '${farmerData['balance']?? 'N/A'}'),
                        Divider(thickness: 1, height: 25,indent: 50,endIndent: 40),


                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.6, // Button takes 60% of the screen width
                              height: 50, // Fixed height for the button
                              child: ElevatedButton(
                                onPressed: () {
                                  _logout(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15), // Rounded corners
                                  ),
                                  backgroundColor: Colors.green[700], // Button background color
                                ),
                                child: const Text(
                                  "Logout",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white, // Text color
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      ],
                    ),

                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.3-120, // Center the circle at the top of the light green section
                  left: MediaQuery.of(context).size.width*0.01+5, // Center the circle horizontally
                  child: CircleAvatar(
                    radius: 70, // Size of the circle
                    backgroundColor: Colors.green[700], // Darker shade for the profile circle
                    backgroundImage: AssetImage('assets/farmer_profile.jpg'), // Profile photo inside the circle
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10, // Adjust for the status bar
                  left: 10,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.green[900], size: 30),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.3-40, // Center the circle at the top of the light green section
                  left: MediaQuery.of(context).size.width*0.01+150,
                  child: FutureBuilder<double>(
                    future: _getFarmerRating(),
                    builder: (context, ratingSnapshot) {
                      if (ratingSnapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (ratingSnapshot.hasError || !ratingSnapshot.hasData) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Rating: N/A',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        );
                      }

                      double rating = ratingSnapshot.data!;
                      int fullStars = rating.floor();
                      bool hasHalfStar = (rating - fullStars) >= 0.5;

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Full stars
                              for (int i = 0; i < fullStars; i++)
                                Icon(Icons.star, color: Colors.amber, size: 30),
                              // Half star if applicable
                              if (hasHalfStar)
                                Icon(Icons.star_half, color: Colors.amber, size: 30),
                              // Empty stars to make up 5 stars
                              for (int i = fullStars + (hasHalfStar ? 1 : 0); i < 5; i++)
                                Icon(Icons.star_border, color: Colors.amber, size: 30),
                              // Rating number
                              SizedBox(width: 10),
                              Text(
                                rating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[900],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),)
              ],
            ),

          );
        },
      ),
    );
  }
  Widget buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Padding(padding: EdgeInsets.only(left: 20)),
        Icon(
          icon,
          color: Colors.green[700],
        ),
        SizedBox(width: 10), // Space between icon and text
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green[900],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 20,
              color: Colors.green[700],
            ),
          ),
        ),
      ],
    );
  }
}