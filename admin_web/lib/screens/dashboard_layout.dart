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

  static const double _mobileBreakpoint = 768;
  static const double _compactDesktopBreakpoint = 1200;
  static const double _contentMaxWidth = 1600;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMobile = MediaQuery.of(context).size.width < _mobileBreakpoint;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: const Text('Admin Portal'),
              centerTitle: false,
            )
          : null,
      drawer: isMobile
          ? Drawer(
              width: 340,
              child: SafeArea(
                bottom: false,
                child: _buildSidebar(
                  context: context,
                  colorScheme: colorScheme,
                  isMobile: true,
                ),
              ),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useMobileLayout = constraints.maxWidth < _mobileBreakpoint;
          final useCompactDesktopLayout = constraints.maxWidth >= _mobileBreakpoint && constraints.maxWidth < _compactDesktopBreakpoint;

          if (useMobileLayout) {
            return SafeArea(
              top: false,
              child: SizedBox.expand(
                child: _buildContentArea(),
              ),
            );
          }

          if (useCompactDesktopLayout) {
            return Row(
              children: [
                _buildSidebar(
                  context: context,
                  colorScheme: colorScheme,
                  isMobile: false,
                  forceCollapsed: true,
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                      child: SizedBox.expand(
                        child: _buildContentArea(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              _buildSidebar(
                context: context,
                colorScheme: colorScheme,
                isMobile: false,
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                    child: SizedBox.expand(
                      child: _buildContentArea(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebar({
    required BuildContext context,
    required ColorScheme colorScheme,
    required bool isMobile,
    bool forceCollapsed = false,
  }) {
    final effectiveCollapsed = forceCollapsed || _isCollapsed;
    final sidebarWidth = effectiveCollapsed ? 76.0 : 300.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isMobile ? double.infinity : sidebarWidth,
      color: colorScheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: effectiveCollapsed && !isMobile ? 18 : 20,
                vertical: 24,
              ),
              child: effectiveCollapsed && !isMobile
                  ? Center(
                      child: Container(
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
                    )
                  : Row(
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ExpenseSplit Pro',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Admin Portal',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const Divider(height: 1, thickness: 1),

          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: effectiveCollapsed && !isMobile ? 12 : 16,
              ),
              children: [
                _buildSectionHeader('Overview', collapsed: effectiveCollapsed && !isMobile),
                _buildNavItem(
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  collapsed: effectiveCollapsed && !isMobile,
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Operations', collapsed: effectiveCollapsed && !isMobile),
                _buildNavItem(
                  index: 1,
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Expenses',
                  collapsed: effectiveCollapsed && !isMobile,
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.remove_red_eye_outlined,
                  activeIcon: Icons.remove_red_eye,
                  label: 'OCR Review',
                  collapsed: effectiveCollapsed && !isMobile,
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.hub_outlined,
                  activeIcon: Icons.hub,
                  label: 'Vendor Hub',
                  collapsed: effectiveCollapsed && !isMobile,
                ),
                _buildNavItem(
                  index: 4,
                  icon: Icons.notifications_active_outlined,
                  activeIcon: Icons.notifications_active,
                  label: 'Alerts',
                  collapsed: effectiveCollapsed && !isMobile,
                ),
                const SizedBox(height: 16),
                _buildSectionHeader('Access & Governance', collapsed: effectiveCollapsed && !isMobile),
                _buildNavItem(
                  index: 5,
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'User Management',
                  collapsed: effectiveCollapsed && !isMobile,
                ),
                _buildNavItem(
                  index: 6,
                  icon: Icons.history_edu_outlined,
                  activeIcon: Icons.history_edu,
                  label: 'Audit Log',
                  collapsed: effectiveCollapsed && !isMobile,
                ),
                _buildNavItem(
                  index: 7,
                  icon: Icons.security_outlined,
                  activeIcon: Icons.security,
                  label: 'Privacy Settings',
                  collapsed: effectiveCollapsed && !isMobile,
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          if (!isMobile && !forceCollapsed) ...[
            _buildToggleItem(collapsed: effectiveCollapsed, colorScheme: colorScheme),
            const Divider(height: 1, thickness: 1),
          ],

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: InkWell(
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
                  horizontal: effectiveCollapsed && !isMobile ? 0 : 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: effectiveCollapsed && !isMobile
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
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    return SizedBox.expand(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
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
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _buildContent(_selectedIndex),
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required bool collapsed,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: InkWell(
        onTap: () => setState(() => _isCollapsed = !_isCollapsed),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: 12,
            horizontal: collapsed ? 0 : 16,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: collapsed
              ? Center(
                  child: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                )
              : Row(
                  children: [
                    Icon(
                      Icons.chevron_left,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Collapse Sidebar',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
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

  Widget _buildSectionHeader(String title, {required bool collapsed}) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      firstCurve: Curves.easeInOut,
      secondCurve: Curves.easeInOut,
      crossFadeState: collapsed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
    required bool collapsed,
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
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: collapsed ? 0 : 16),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: collapsed
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
