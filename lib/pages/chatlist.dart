import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class ChatListPage extends StatelessWidget {
  final String currentUserRole;

  const ChatListPage({Key? key, required this.currentUserRole}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat List')),
        body: const Center(child: Text('No user logged in.')),
      );
    }

    // Fetch opposite role users
    String targetRole = currentUserRole == 'farmer' ? 'retailer' : 'farmer';

    return Scaffold(
      appBar: AppBar(title: const Text('Chat List')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Users')
            .where('role', isEqualTo: targetRole)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Error loading users.'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('No $targetRole users found.'),
            );
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final userId = user.id;
              final username = user['username'];
              final email = user['email'];

              return ListTile(
                title: Text(username ?? 'Unknown'),
                subtitle: Text(email ?? ''),
                onTap: () {
                  // Navigate to the chat page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(
                        currentUserId: currentUserId,
                        targetUserId: userId,
                        targetUserName: username,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}