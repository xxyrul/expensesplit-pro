import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/admin_login_screen.dart';
import 'theme/expressive_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: AdminWebApp()));
}

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExpenseSplit Pro - Admin Dashboard',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // Default to dark for admin
      theme: ExpressiveTheme.light(),
      darkTheme: ExpressiveTheme.dark(),
      home: const AdminLoginScreen(),
    );
  }
}
