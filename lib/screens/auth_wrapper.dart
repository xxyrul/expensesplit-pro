import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:expensesplit_pro/models/user_model.dart';
import '../services/auth_service.dart';
import 'auth/login_screen.dart'; 
import 'home/home_screen.dart'; 

// Use ConsumerWidget to listen to Riverpod providers
class AuthWrapper extends ConsumerWidget { 
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider that returns UserModel?
    final userAsync = ref.watch(userProfileProvider);

    return userAsync.when(
      data: (user) {
        // If user is null, they aren't logged in
        if (user == null) {
          return const LoginScreen();
        } 
        // If user is not null, they are logged in
        return const HomeScreen();
      },
      // While loading or if there's an error, show the LoadingScreen
      loading: () => const LoadingScreen(),
      error: (err, stack) => const LoginScreen(), 
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}