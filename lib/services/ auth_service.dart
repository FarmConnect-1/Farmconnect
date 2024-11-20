import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Sign up with email and password
  Future<User?> signUpWithEmail(
      String email, String password, String username, String role) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      User? user = result.user;

      // Add user details to Firestore
      if (user != null) {
        await _firestore.collection('Users').doc(user.uid).set({
          'username': username,
          'email': email,
          'role': role,
          'profilePicture': '',
        });
      }
      return user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }
}
