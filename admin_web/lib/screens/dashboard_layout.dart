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
    final effectiveCollapsed = !isMobile && (forceCollapsed || _isCollapsed);
    final sidebarWidth = effectiveCollapsed ? 76.0 : 300.0;
    final canToggle = !isMobile && !forceCollapsed;

    final sidebar = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isMobile ? double.infinity : sidebarWidth,
      color: colorScheme.surfaceContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: effectiveCollapsed
                ? _CollapsedSidebarHeader(colorScheme: colorScheme)
                : _ExpandedSidebarHeader(colorScheme: colorScheme),
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
          if (canToggle) const SizedBox(height: 56),
        ],
      ),
    );

    if (!canToggle) return sidebar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        sidebar,
        Positioned(
          bottom: 20,
          left: effectiveCollapsed ? 0 : null,
          right: effectiveCollapsed ? 0 : -16,
          child: Center(
            child: _SidebarHeaderToggleButton(
              icon: effectiveCollapsed ? Icons.chevron_right : Icons.chevron_left,
              tooltip: effectiveCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
              onTap: () => setState(() => _isCollapsed = !_isCollapsed),
              colorScheme: colorScheme,
            ),
          ),
        ),
      ],
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

class _SidebarHeaderToggleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _SidebarHeaderToggleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.circle,
        color: colorScheme.surfaceContainerHighest,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.4),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.outlineVariant.withOpacity(0.8),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                color: colorScheme.onSurfaceVariant,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedSidebarHeader extends StatelessWidget {
  final ColorScheme colorScheme;

  const _CollapsedSidebarHeader({
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      alignment: Alignment.center,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
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
    );
  }
}

class _ExpandedSidebarHeader extends StatelessWidget {
  final ColorScheme colorScheme;

  const _ExpandedSidebarHeader({
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      alignment: Alignment.center,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ExpenseSplit Pro',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Admin Portal',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
