import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';
import 'services/notification_service.dart';
import 'providers/theme_provider.dart';
import 'theme/dynamic_theme_scope.dart';
import 'widgets/keyboard_dismiss_on_tap.dart';

void main() async {
  // 1. Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notifications and prompt for permission
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