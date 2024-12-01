import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({Key? key}) : super(key: key);

  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> getChatListStream() {
    final String userId = _auth.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('Chats')
        .where('participants', arrayContains: userId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getChatListStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading chats.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No chats available.'));
          }

          final chats = snapshot.data!.docs;

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final chatId = chat.id;
              final participants = List<String>.from(chat['participants']);
              final recipientId = participants.firstWhere(
                    (id) => id != _auth.currentUser!.uid,
                orElse: () => 'Unknown',
              );

              // Fetch recipient details
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('Users')
                    .doc(recipientId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: CircleAvatar(),
                      title: Text('Loading...'),
                    );
                  }
                  if (userSnapshot.hasError || !userSnapshot.hasData) {
                    return const ListTile(
                      leading: CircleAvatar(),
                      title: Text('Unknown User'),
                    );
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                  final recipientName = userData?['username'] ?? 'Unknown User';
                  final recipientProfilePicture = userData?['profilePicture'];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: recipientProfilePicture != null
                          ? NetworkImage(recipientProfilePicture)
                          : null,
                      child: recipientProfilePicture == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(recipientName),
                    subtitle: const Text('Tap to chat'),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/chat_details',
                        arguments: {
                          'chatId': chatId,
                          'recipientName': recipientName,
                        },
                      );
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
