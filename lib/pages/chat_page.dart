import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ChatPage extends StatefulWidget {
  final String currentUserId;
  final String targetUserId;
  final String targetUserName;

  const ChatPage({
    Key? key,
    required this.currentUserId,
    required this.targetUserId,
    required this.targetUserName,
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  bool isTyping = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {
        isTyping = _messageController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatId = _generateChatId(widget.currentUserId, widget.targetUserId);

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.targetUserName}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Chats')
                  .doc(chatId)
                  .collection('Messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final message = snapshot.data!.docs[index];
                    final isSentByCurrentUser =
                        message['senderId'] == widget.currentUserId;

                    if (message['type'] == 'text') {
                      return _buildTextMessage(message, isSentByCurrentUser);
                    } else if (message['type'] == 'image') {
                      return _buildImageMessage(message, isSentByCurrentUser);
                    }
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),
          _buildMessageInput(chatId),
        ],
      ),
    );
  }

  Widget _buildTextMessage(QueryDocumentSnapshot message, bool isSentByCurrentUser) {
    return Align(
      alignment:
      isSentByCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSentByCurrentUser ? Colors.green[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(message['text'] ?? ''),
      ),
    );
  }

  Widget _buildImageMessage(QueryDocumentSnapshot message, bool isSentByCurrentUser) {
    final mediaUrl = message['mediaUrl'] as String;

    return Align(
      alignment:
      isSentByCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _showFullImage(mediaUrl),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Image.network(
            mediaUrl,
            width: 200,
            height: 200,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.error, size: 50, color: Colors.red),
          ),
        ),
      ),
    );
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.error, size: 50, color: Colors.red),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput(String chatId) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () {
              _pickImage(chatId);
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Enter a message...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.send,
              color: isTyping ? Colors.green : Colors.grey,
            ),
            onPressed: isTyping
                ? () {
              final messageText = _messageController.text.trim();
              if (messageText.isNotEmpty) {
                _sendMessage(chatId, messageText);
                _messageController.clear();
                _scrollToBottom();
              }
            }
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(String chatId) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef =
      FirebaseStorage.instance.ref().child('Images').child(fileName);

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      FirebaseFirestore.instance
          .collection('Chats')
          .doc(chatId)
          .collection('Messages')
          .add({
        'type': 'image',
        'mediaUrl': downloadUrl,
        'senderId': widget.currentUserId,
        'receiverId': widget.targetUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      FirebaseFirestore.instance.collection('Chats').doc(chatId).set({
        'latestMessage': 'Image',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  void _sendMessage(String chatId, String text) {
    FirebaseFirestore.instance
        .collection('Chats')
        .doc(chatId)
        .collection('Messages')
        .add({
      'type': 'text',
      'text': text,
      'senderId': widget.currentUserId,
      'receiverId': widget.targetUserId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    FirebaseFirestore.instance.collection('Chats').doc(chatId).set({
      'latestMessage': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _generateChatId(String userId1, String userId2) {
    return userId1.compareTo(userId2) < 0
        ? '${userId1}_$userId2'
        : '${userId2}_$userId1';
  }
}
