import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    try {
      // In Web, signInWithPopup is standard.
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      final result = await _auth.signInWithPopup(googleProvider);
      final user = result.user;

      if (user != null) {
        // Verify admin access
        final adminDoc = await _firestore.collection('admins').doc(user.uid).get();
        if (!adminDoc.exists) {
          // If not an admin, sign them out and throw error
          await signOut();
          throw "Access Denied: You are not authorized as an admin.";
        }
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? e.code;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final user = result.user;

      if (user != null) {
        // Verify admin access
        final adminDoc = await _firestore.collection('admins').doc(user.uid).get();
        if (!adminDoc.exists) {
          await signOut();
          throw "Access Denied: You are not authorized as an admin.";
        }
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? e.code;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

final authServiceProvider = Provider((ref) => AuthService());
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});
