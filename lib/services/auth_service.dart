import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Auth State Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current User
  User? get currentUser => _auth.currentUser;

  // Email/Password Login
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  // Email/Password Register
  Future<UserCredential?> registerWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final provider = GoogleAuthProvider();
      final UserCredential cred;
      if (kIsWeb) {
        cred = await _auth.signInWithPopup(provider);
      } else {
        cred = await _auth.signInWithProvider(provider);
      }
      if (cred.additionalUserInfo?.isNewUser == true) {
        final user = cred.user;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'city': '',
            'university': '',
            'createdAt': FieldValue.serverTimestamp(),
            'isPro': false,
            'proExpiresAt': null,
            'hasanat': 0,
            'seri': 0,
            'totalPages': 0,
            'hatimCount': 0,
          });
        }
      }
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
