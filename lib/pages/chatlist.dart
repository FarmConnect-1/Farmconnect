import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_details_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat List'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('Users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No users found!'),
            );
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userDoc = users[index];
              final userId = userDoc.id;
              final username = userDoc['username'];
              final role = userDoc['role'];

              return ListTile(
                title: Text(username),
                subtitle: Text(role),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/chat_details',
                    arguments: {
                      'chatId': userId,
                      'recipientName': username,
                    },
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
