import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';
import 'services/notification_service.dart';
import 'providers/theme_provider.dart';
import 'theme/dynamic_theme_scope.dart';
import 'widgets/keyboard_dismiss_on_tap.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  // 1. Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Request notifications permission (Android 14+) before getting token/subscribing
  final permissionStatus = await Permission.notification.request();
  if (permissionStatus.isGranted) {
    try {
      final messaging = FirebaseMessaging.instance;
      
      // Request permission via SDK (to configure iOS APNS if run on iOS, handles Android gracefully)
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Foreground presentation options
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Retrieve FCM Token
      final token = await messaging.getToken();
      debugPrint('FCM Token: $token');

      // Subscribe to global_broadcast topic
      await messaging.subscribeToTopic('global_broadcast');
      debugPrint('Successfully subscribed to global_broadcast topic');
    } catch (e) {
      debugPrint('Error initializing FCM: $e');
    }
  } else {
    debugPrint('Notification permission denied or restricted');
  }

  // Initialize local notification services
  await NotificationService.instance.initialize();

  // 3. Run the app wrapped in ProviderScope for Riverpod
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return DynamicThemeScope(
      useDynamicColors: themeMode == ThemeMode.system,
      builder: ({required lightTheme, required darkTheme}) {
        return MaterialApp(
          title: 'ExpenseSplit Pro',
          themeMode: themeMode,
          builder: (context, child) {
            return KeyboardDismissOnTap(
              child: child ?? const SizedBox.shrink(),
            );
          },
          theme: lightTheme,
          darkTheme: darkTheme,
          home: AuthWrapper(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}