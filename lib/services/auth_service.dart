import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;

    if (user == null || email == null || email.isEmpty) {
      throw 'No signed-in email account found.';
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    try {
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? e.code;
    }
  }

  Future<void> setPassword({required String newPassword}) async {
    final user = _auth.currentUser;
    final email = user?.email;

    if (user == null || email == null || email.isEmpty) {
      throw 'No signed-in email account found.';
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: newPassword,
    );

    final hasPasswordProvider = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );

    try {
      if (hasPasswordProvider) {
        await user.updatePassword(newPassword);
      } else {
        await user.linkWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        await user.updatePassword(newPassword);
        return;
      }
      throw e.message ?? e.code;
    }
  }

  Future<void> linkGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw 'No authenticated user found.';

    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        await user.linkWithPopup(googleProvider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId: '539814694384-qk0h5n3ovco79qhukieb5c019l8p3l3n.apps.googleusercontent.com',
        );
        try {
          await googleSignIn.disconnect();
        } catch (_) {}
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) throw 'Google Sign-In cancelled.';

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await user.linkWithCredential(credential);
      }
      
      // Update Firestore user document metadata
      final name = user.displayName ?? user.email?.split('@')[0] ?? 'User';
      final newUser = UserModel(
        id: user.uid,
        name: name,
        email: user.email ?? '',
        displayName: name,
      );
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(newUser.toFirestore(), SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      throw e.message ?? e.code;
    }
  }

  Future<void> unlinkGoogle() async {
    final user = _auth.currentUser;
    if (user == null) throw 'No authenticated user found.';

    // Check if they have another sign-in method
    final hasOtherProvider = user.providerData.any(
      (p) => p.providerId != 'google.com',
    );
    if (!hasOtherProvider) {
      throw 'Please set a password first before unlinking your Google account.';
    }

    try {
      await user.unlink('google.com');
    } on FirebaseAuthException catch (e) {
      throw e.message ?? e.code;
    }
  }

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

        // 1. Update Firebase Auth Profile
        await user.updateDisplayName(initialName);

        // 2. Create User Model (MATCHES THE 4 REQUIRED FIELDS)
        final newUser = UserModel(
          id: user.uid,
          name: initialName,
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

  // Google Sign-In
  Future<User?> signInWithGoogle() async {
    try {
      UserCredential result;

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.setCustomParameters({'prompt': 'select_account'});
        result = await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId: '539814694384-qk0h5n3ovco79qhukieb5c019l8p3l3n.apps.googleusercontent.com',
        );
        try {
          await googleSignIn.disconnect();
        } catch (_) {}
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        result = await _auth.signInWithCredential(credential);
      }

      final user = result.user;
      
      if (user != null) {
        final String name = user.displayName ?? user.email?.split('@')[0] ?? 'User';
        final newUser = UserModel(
          id: user.uid,
          name: name,
          email: user.email ?? '',
          displayName: name,
        );
        // Use merge:true so this never overwrites existing data,
        // but always ensures the document exists.
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set(newUser.toFirestore(), SetOptions(merge: true));
      }
      return user;
    } on PlatformException catch (e) {
      // Common misconfiguration on Android (missing SHA keys / OAuth client)
      if (e.code == 'sign_in_failed' || e.code == '10') {
        throw 'Google Sign-In failed. Check Firebase OAuth client configuration and Android SHA fingerprints (SHA-1/256).';
      }
      throw e.message ?? e.code ?? e.toString();
    } catch (e) {
      // Fallback: surface a readable error
      final msg = e is FirebaseAuthException ? (e.message ?? e.code) : e.toString();
      throw msg;
    }
  }

  // Request a password reset email
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? e.code;
    } catch (e) {
      throw e.toString();
    }
  }

  // Link a phone number credential to the current account
  Future<void> linkPhoneNumber(String verificationId, String smsCode) async {
    final user = _auth.currentUser;
    if (user == null) throw 'No authenticated user found.';
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? e.code;
    } catch (e) {
      throw e.toString();
    }
  }

  // Unlink a phone number, ensuring there is another provider so the account is not orphaned
  Future<void> unlinkPhoneNumber() async {
    final user = _auth.currentUser;
    if (user == null) throw 'No authenticated user found.';
    final hasOtherProvider = user.providerData.any(
      (p) => p.providerId != 'phone',
    );
    if (!hasOtherProvider) {
      throw 'Please set a password or link Google before unlinking your phone number.';
    }
    try {
      await user.unlink('phone');
    } on FirebaseAuthException catch (e) {
      throw e.message ?? e.code;
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        await GoogleSignIn(
          serverClientId: '539814694384-qk0h5n3ovco79qhukieb5c019l8p3l3n.apps.googleusercontent.com',
        ).disconnect();
      } catch (e) {
        // Ignore if not signed in with Google
      }
    }
  }

  // Updated to include all 4 required fields
  Future<UserModel?> getCurrentUser() async {
    return UserModel(
      id: '1', 
      name: 'John Doe', 
      email: 'john.doe@example.com',
      displayName: 'John Doe',
    );
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