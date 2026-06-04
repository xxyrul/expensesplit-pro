import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_page.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint("Handling a background message: ${message.messageId}");

  final title = message.data['title'] ?? message.data['notification_title'];
  final body = message.data['body'] ?? message.data['notification_body'] ?? message.data['message'];

  if (title != null && body != null) {
    await NotificationService.instance.initialize();
    await NotificationService.instance.showSystemBroadcast(
      title: title,
      body: body,
    );
  }
}

void main() async {
  // 1. Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final hasSeenWelcome = prefs.getBool('has_seen_welcome') ?? false;

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

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    String? title;
    String? body;

    if (message.notification != null) {
      title = message.notification!.title;
      body = message.notification!.body;
    } else {
      title = message.data['title'];
      body = message.data['body'] ?? message.data['message'];
    }

    if (title == null || body == null) return;

    NotificationService.instance.showSystemBroadcast(
      title: title,
      body: body,
    );
  });

  // 3. Run the app wrapped in ProviderScope for Riverpod
  runApp(ProviderScope(child: MyApp(hasSeenWelcome: hasSeenWelcome)));
}

class MyApp extends ConsumerWidget {
  final bool hasSeenWelcome;
  const MyApp({super.key, this.hasSeenWelcome = false});

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
          home: hasSeenWelcome ? const AuthWrapper() : const WelcomePage(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
