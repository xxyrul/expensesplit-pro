import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ADD THIS: Simple getter to access the current user synchronously
  User? get currentUser => _auth.currentUser;

  // Sign In
  Future<User?> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? e.code;
    }
  }

  // Register
  Future<User?> register(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;

      if (user != null) {
        final String initialName = email.split('@')[0];

        // 1. Update Firebase Auth Profile (So user.displayName works immediately)
        await user.updateDisplayName(initialName);

        // 2. Create User Model
        final newUser = UserModel(
          id: user.uid,
          email: email,
          displayName: initialName,
        );

        // 3. Save to Firestore
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(newUser.toFirestore());

        // Reload user to ensure changes are reflected
        await user.reload();
      }
      return _auth.currentUser;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? e.code;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<UserModel?> getCurrentUser() async {
    return UserModel(id: '1', name: 'John Doe', email: 'john.doe@example.com');
  }
}

// --- Providers ---

final authServiceProvider = Provider((ref) => AuthService());

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// Watch this provider in any screen to get the user's Firestore data
final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      // Fetches real-time updates from the 'users' collection
      return FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .map((snapshot) {
            if (!snapshot.exists) return null;
            return UserModel.fromFirestore(snapshot);
          });
    },
    loading: () => const Stream.empty(),
    error: (_, __) => Stream.value(null),
  );
});
