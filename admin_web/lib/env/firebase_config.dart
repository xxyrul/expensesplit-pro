import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart' as default_options;

/// Returns FirebaseOptions for the admin web app.
///
/// Prefer compile-time defines (`--dart-define=FIREBASE_API_KEY=...`) so
/// deployments can target different projects without editing source.
FirebaseOptions getAdminFirebaseOptions() {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
  if (apiKey.isNotEmpty) {
    return FirebaseOptions(
      apiKey: apiKey,
      appId: String.fromEnvironment('FIREBASE_APP_ID', defaultValue: ''),
      messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: ''),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: ''),
      authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: ''),
      storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: ''),
      androidClientId: String.fromEnvironment('FIREBASE_ANDROID_CLIENT_ID', defaultValue: ''),
      iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID', defaultValue: ''),
    );
  }

  // Fallback to the generated DefaultFirebaseOptions if no env defines are provided
  return default_options.DefaultFirebaseOptions.currentPlatform;
}
