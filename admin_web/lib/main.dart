import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'env/firebase_config.dart';
import 'screens/auth/admin_login_screen.dart';
import 'services/auth_service.dart';
import 'screens/dashboard_layout.dart';
import 'theme/expressive_theme.dart';
import 'router/admin_router.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: getAdminFirebaseOptions(),
  );
  runApp(const ProviderScope(child: AdminWebApp()));
}

class AdminWebApp extends ConsumerWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'ExpenseSplit Pro - Admin Dashboard',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ExpressiveTheme.light(),
      darkTheme: ExpressiveTheme.dark(),
      routerConfig: router,
    );
  }
}
