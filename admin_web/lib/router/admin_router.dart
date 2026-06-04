import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/dashboard_layout.dart';
import '../screens/global_analytics.dart';
import '../screens/expense_management.dart';
import '../screens/ocr_review_queue.dart';
import '../screens/anomaly_alerts.dart';
import '../screens/user_management.dart';
import '../screens/audit_log_screen.dart';
import '../screens/privacy_settings.dart';
import '../screens/vendor_intelligence_hub.dart';
import '../screens/auth/admin_login_screen.dart';
import '../services/auth_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(verifiedAdminProvider);

  return GoRouter(
    initialLocation: '/overview',
    redirect: (context, state) {
      final isAuth = authState.asData?.value == AdminAuthState.admin;
      final isLoggingIn = state.uri.path == '/login';

      if (!isAuth && !isLoggingIn) return '/login';
      if (isAuth && isLoggingIn) return '/overview';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return DashboardLayout(child: child);
        },
        routes: [
          GoRoute(
            path: '/overview',
            pageBuilder: (context, state) => const NoTransitionPage(child: GlobalAnalyticsScreen()),
          ),
          GoRoute(
            path: '/expenses',
            pageBuilder: (context, state) => const NoTransitionPage(child: ExpenseManagementScreen()),
          ),
          GoRoute(
            path: '/ocr-review',
            pageBuilder: (context, state) => const NoTransitionPage(child: OcrReviewQueueScreen()),
          ),
          GoRoute(
            path: '/vendor-hub',
            pageBuilder: (context, state) => const NoTransitionPage(child: VendorIntelligenceHub()),
          ),
          GoRoute(
            path: '/alerts',
            pageBuilder: (context, state) => const NoTransitionPage(child: AnomalyAlertsScreen()),
          ),
          GoRoute(
            path: '/users',
            pageBuilder: (context, state) => const NoTransitionPage(child: UserManagementScreen()),
          ),
          GoRoute(
            path: '/audit-log',
            pageBuilder: (context, state) => const NoTransitionPage(child: AuditLogScreen()),
          ),
          GoRoute(
            path: '/privacy',
            pageBuilder: (context, state) => const NoTransitionPage(child: PrivacySettingsScreen()),
          ),
        ],
      ),
    ],
  );
});
