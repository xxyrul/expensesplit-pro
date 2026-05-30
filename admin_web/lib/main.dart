import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'env/firebase_config.dart';
import 'screens/auth/admin_login_screen.dart';
import 'services/auth_service.dart';
import 'screens/dashboard_layout.dart';
import 'theme/expressive_theme.dart';

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
    return MaterialApp(
      title: 'ExpenseSplit Pro - Admin Dashboard',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ExpressiveTheme.light(),
      darkTheme: ExpressiveTheme.dark(),
      home: const _AuthGate(),
    );
  }
}

/// Top-level gate: watches [verifiedAdminProvider] and routes accordingly.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminState = ref.watch(verifiedAdminProvider);

    return adminState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const AdminLoginScreen(),
      data: (state) {
        switch (state) {
          case AdminAuthState.loading:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          case AdminAuthState.admin:
            return const DashboardLayout();
          case AdminAuthState.unauthorized:
            return const AdminLoginScreen();
        }
      },
    );
  }
}
