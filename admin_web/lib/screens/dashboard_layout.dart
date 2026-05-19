import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import 'global_analytics.dart';
import 'expense_management.dart';
import 'ocr_review_queue.dart';
import 'anomaly_alerts.dart';
import 'user_management.dart';
import 'audit_log_screen.dart';
import 'privacy_settings.dart';
import 'vendor_intelligence_hub.dart';

class DashboardLayout extends ConsumerStatefulWidget {
  const DashboardLayout({super.key});

  @override
  ConsumerState<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends ConsumerState<DashboardLayout> {
  int _selectedIndex = 0;
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Row(
        children: [
          // Animated sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isCollapsed ? 76 : 280,
            color: colorScheme.surfaceContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header/Logo section
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _isCollapsed ? 12 : 20,
                      vertical: 24,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.admin_panel_settings,
                            color: colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        Expanded(
                          child: AnimatedOpacity(
                            opacity: _isCollapsed ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'ExpenseSplit Pro',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Admin Portal',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1, thickness: 1),

                // Navigation list
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: _isCollapsed ? 12 : 16,
                    ),
                    children: [
                      // Overview Section
                      _buildSectionHeader('Overview'),
                      _buildNavItem(
                        index: 0,
                        icon: Icons.dashboard_outlined,
                        activeIcon: Icons.dashboard,
                        label: 'Dashboard',
                      ),

                      const SizedBox(height: 16),

                      // Operations Section
                      _buildSectionHeader('Operations'),
                      _buildNavItem(
                        index: 1,
                        icon: Icons.receipt_long_outlined,
                        activeIcon: Icons.receipt_long,
                        label: 'Expenses',
                      ),
                      _buildNavItem(
                        index: 2,
                        icon: Icons.remove_red_eye_outlined,
                        activeIcon: Icons.remove_red_eye,
                        label: 'OCR Review',
                      ),
                      _buildNavItem(
                        index: 3,
                        icon: Icons.hub_outlined,
                        activeIcon: Icons.hub,
                        label: 'Vendor Hub',
                      ),
                      _buildNavItem(
                        index: 4,
                        icon: Icons.notifications_active_outlined,
                        activeIcon: Icons.notifications_active,
                        label: 'Alerts',
                      ),

                      const SizedBox(height: 16),

                      // Access & Governance Section
                      _buildSectionHeader('Access & Governance'),
                      _buildNavItem(
                        index: 5,
                        icon: Icons.people_outline,
                        activeIcon: Icons.people,
                        label: 'User Management',
                      ),
                      _buildNavItem(
                        index: 6,
                        icon: Icons.history_edu_outlined,
                        activeIcon: Icons.history_edu,
                        label: 'Audit Log',
                      ),
                      _buildNavItem(
                        index: 7,
                        icon: Icons.security_outlined,
                        activeIcon: Icons.security,
                        label: 'Privacy Settings',
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1),

                // Collapse & Logout section at the bottom
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // Collapse toggle button
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isCollapsed = !_isCollapsed;
                          });
                        },
                        icon: Icon(
                          _isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        tooltip: _isCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
                      ),
                      const SizedBox(height: 8),
                      // Logout option
                      InkWell(
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Sign out?'),
                              content: const Text('Leave the admin dashboard?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Sign out'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            ref.read(authServiceProvider).signOut();
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: _isCollapsed ? 0 : 16,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _isCollapsed
                              ? Center(
                                  child: Icon(
                                    Icons.logout,
                                    color: colorScheme.error,
                                    size: 20,
                                  ),
                                )
                              : Row(
                                  children: [
                                    Icon(
                                      Icons.logout,
                                      color: colorScheme.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: AnimatedOpacity(
                                        opacity: _isCollapsed ? 0.0 : 1.0,
                                        duration: const Duration(milliseconds: 200),
                                        curve: Curves.easeInOut,
                                        child: Text(
                                          'Logout',
                                          style: TextStyle(
                                            color: colorScheme.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),

          // Main content view area
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.01, 0.0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Container(
                key: ValueKey<int>(_selectedIndex),
                child: _buildContent(_selectedIndex),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      firstCurve: Curves.easeInOut,
      secondCurve: Curves.easeInOut,
      crossFadeState: _isCollapsed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
        child: SizedBox(
          width: double.infinity,
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
              letterSpacing: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      secondChild: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Divider(indent: 8, endIndent: 8),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: _isCollapsed ? 0 : 16),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _isCollapsed
              ? Center(
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      isSelected ? activeIcon : icon,
                      color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildContent(int index) {
    switch (index) {
      case 0:
        return const GlobalAnalyticsScreen();
      case 1:
        return const ExpenseManagementScreen();
      case 2:
        return const OcrReviewQueueScreen();
      case 3:
        return const VendorIntelligenceHub();
      case 4:
        return const AnomalyAlertsScreen();
      case 5:
        return const UserManagementScreen();
      case 6:
        return const AuditLogScreen();
      case 7:
        return const PrivacySettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}
