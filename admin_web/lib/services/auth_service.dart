import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Returns true if the given uid exists in the `admins` Firestore collection.
  Future<bool> isAdmin(String uid) async {
    final doc = await _firestore.collection('admins').doc(uid).get();
    return doc.exists;
  }

  Future<User?> signInWithGoogle() async {
    try {
      final googleProvider = GoogleAuthProvider()..addScope('email');
      final result = await _auth.signInWithPopup(googleProvider);
      final user = result.user;

      if (user != null) {
        final allowed = await isAdmin(user.uid);
        if (!allowed) {
          // Sign out immediately — account not registered as admin.
          await signOut();
          throw 'Access Denied: Your Google account is not registered as an admin.';
        }
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? e.code;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}

final authServiceProvider = Provider((ref) => AuthService());

/// Raw Firebase auth stream — only use for loading/signed-out detection.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// The three possible verified states for the admin portal.
enum AdminAuthState { loading, admin, unauthorized }

/// Verified admin stream that re-checks Firestore on EVERY auth state change.
/// This prevents a cached Firebase session from bypassing the admin check.
/// Gate the dashboard behind this provider instead of [authStateProvider].
final verifiedAdminProvider = StreamProvider<AdminAuthState>((ref) async* {
  final authService = ref.watch(authServiceProvider);

  yield AdminAuthState.loading;

  await for (final user in authService.authStateChanges) {
    if (user == null) {
      yield AdminAuthState.unauthorized;
      continue;
    }

    // Always re-validate against Firestore, even on session restore.
    final allowed = await authService.isAdmin(user.uid);
    if (allowed) {
      yield AdminAuthState.admin;
    } else {
      // Kick out any signed-in user not in the admins collection.
      await authService.signOut();
      yield AdminAuthState.unauthorized;
    }
  }
});
