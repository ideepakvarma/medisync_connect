import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      // 1. Create Auth User
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // 2. Save User Document to Firestore with "Skeleton" data
      await _db.collection('users').doc(credential.user!.uid).set({
        'uid': credential.user!.uid,
        'email': email.trim(),
        'role': role,
        'displayName': name.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        
        // --- NEW FIELDS START HERE ---
        // We initialize these as empty strings so the Doctor Dashboard 
        // doesn't encounter "null" errors for new users.
        'age': '',
        'gender': '',
        'height': '',
        'weight': '',
        // -----------------------------
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(), 
      password: password.trim()
    );
  }
}