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

// ─────────────────────────────────────────────────────────────────────────────
// Nav item data model
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String section;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.section,
  });
}

const List<_NavItem> _kNavItems = [
  _NavItem(
    index: 0,
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
    label: 'Dashboard',
    section: 'Overview',
  ),
  _NavItem(
    index: 1,
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
    label: 'Expenses',
    section: 'Operations',
  ),
  _NavItem(
    index: 2,
    icon: Icons.remove_red_eye_outlined,
    activeIcon: Icons.remove_red_eye,
    label: 'OCR Review',
    section: 'Operations',
  ),
  _NavItem(
    index: 3,
    icon: Icons.hub_outlined,
    activeIcon: Icons.hub,
    label: 'Vendor Hub',
    section: 'Operations',
  ),
  _NavItem(
    index: 4,
    icon: Icons.notifications_active_outlined,
    activeIcon: Icons.notifications_active,
    label: 'Alerts',
    section: 'Operations',
  ),
  _NavItem(
    index: 5,
    icon: Icons.people_outline,
    activeIcon: Icons.people,
    label: 'User Management',
    section: 'Governance',
  ),
  _NavItem(
    index: 6,
    icon: Icons.history_edu_outlined,
    activeIcon: Icons.history_edu,
    label: 'Audit Log',
    section: 'Governance',
  ),
  _NavItem(
    index: 7,
    icon: Icons.security_outlined,
    activeIcon: Icons.security,
    label: 'Privacy Settings',
    section: 'Governance',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// DashboardLayout
// ─────────────────────────────────────────────────────────────────────────────
class DashboardLayout extends ConsumerStatefulWidget {
  const DashboardLayout({super.key});

  @override
  ConsumerState<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends ConsumerState<DashboardLayout> {
  // ── State variables ────────────────────────────────────────────────────────
  int _selectedIndex = 0;
  bool _isExpanded = true;

  // ── Layout constants ───────────────────────────────────────────────────────
  static const double _mobileBreakpoint = 600;
  static const double _compactDesktopBreakpoint = 1120;
  static const double _expandedWidth = 260;
  static const double _collapsedWidth = 70;
  static const Duration _animDuration = Duration(milliseconds: 220);

  // ── Screen router ──────────────────────────────────────────────────────────
  Widget get _activeScreen {
    switch (_selectedIndex) {
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

  // ── Logout confirmation ────────────────────────────────────────────────────
  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
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
    if (ok == true && mounted) {
      ref.read(authServiceProvider).signOut();
    }
  }

  // ── Root build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < _mobileBreakpoint;
    final isCompactDesktop = screenWidth < _compactDesktopBreakpoint;
    final cs = Theme.of(context).colorScheme;
    return isMobile
        ? _buildMobileLayout(cs)
        : _buildDesktopLayout(cs, isCompactDesktop: isCompactDesktop);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DESKTOP LAYOUT
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopLayout(ColorScheme cs, {required bool isCompactDesktop}) {
    final showExpanded = isCompactDesktop ? false : _isExpanded;
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Zone A + B + C: Sidebar ──────────────────────────────────────
          AnimatedContainer(
            duration: _animDuration,
            curve: Curves.easeInOut,
            width: showExpanded ? _expandedWidth : _collapsedWidth,
            color: cs.surfaceContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Zone A: Header (fixed) ─────────────────────────────
                SafeArea(
                  bottom: false,
                  child: _buildHeader(
                    cs,
                    isMobile: false,
                    forceExpanded: showExpanded,
                  ),
                ),
                Divider(height: 1, thickness: 1, color: cs.outlineVariant),

                // ── Zone B: Navigation (scrollable) ───────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 0,
                    ),
                    children: _buildNavItems(
                      cs,
                      isMobile: false,
                      forceExpanded: showExpanded,
                    ),
                  ),
                ),

                Divider(height: 1, thickness: 1, color: cs.outlineVariant),
                // ── Zone C: Footer (fixed) ─────────────────────────────
                _buildDesktopFooter(
                  cs,
                  showExpanded: showExpanded,
                  canToggle: !isCompactDesktop,
                ),
              ],
            ),
          ),

          // ── Vertical divider ──────────────────────────────────────────
          VerticalDivider(thickness: 1, width: 1, color: cs.outlineVariant),

          // ── Main content ──────────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: _animDuration,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedIndex),
                child: _activeScreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOBILE LAYOUT
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobileLayout(ColorScheme cs) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ExpenseSplit Pro',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More pages',
            onPressed: () => _showMobileMoreSheet(cs),
          ),
        ],
      ),
      // ── Screen content ───────────────────────────────────────────────
      body: AnimatedSwitcher(
        duration: _animDuration,
        child: KeyedSubtree(
          key: ValueKey<int>(_selectedIndex),
          child: _activeScreen,
        ),
      ),
      // ── Bottom navigation bar (first 5 items) ────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex.clamp(0, 4),
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
        selectedFontSize: 11.5,
        unselectedFontSize: 11.5,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.remove_red_eye_outlined),
            activeIcon: Icon(Icons.remove_red_eye),
            label: 'OCR',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hub_outlined),
            activeIcon: Icon(Icons.hub),
            label: 'Vendors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_active_outlined),
            activeIcon: Icon(Icons.notifications_active),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }

  Future<void> _showMobileMoreSheet(ColorScheme cs) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainer,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('User Management'),
              onTap: () => Navigator.of(ctx).pop(5),
            ),
            ListTile(
              leading: const Icon(Icons.history_edu_outlined),
              title: const Text('Audit Log'),
              onTap: () => Navigator.of(ctx).pop(6),
            ),
            ListTile(
              leading: const Icon(Icons.security_outlined),
              title: const Text('Privacy Settings'),
              onTap: () => Navigator.of(ctx).pop(7),
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: cs.error),
              title: Text('Logout', style: TextStyle(color: cs.error)),
              onTap: () => Navigator.of(ctx).pop(-1),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );

    if (!mounted || picked == null) return;
    if (picked == -1) {
      _confirmLogout();
      return;
    }

    setState(() => _selectedIndex = picked);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Zone A: Header
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(
    ColorScheme cs, {
    required bool isMobile,
    bool? forceExpanded,
  }) {
    final showFull = isMobile || (forceExpanded ?? _isExpanded);
    return AnimatedContainer(
      duration: _animDuration,
      curve: Curves.easeInOut,
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: showFull ? 16 : 0),
      alignment: showFull ? Alignment.centerLeft : Alignment.center,
      child: showFull
          ? Row(
              children: [
                _LogoBadge(cs: cs),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ExpenseSplit Pro',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: cs.onSurface,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Admin',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : _LogoBadge(cs: cs),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Zone B: Nav item widgets
  // ─────────────────────────────────────────────────────────────────────────
  List<Widget> _buildNavItems(
    ColorScheme cs, {
    required bool isMobile,
    bool? forceExpanded,
  }) {
    final showLabels = isMobile || (forceExpanded ?? _isExpanded);
    final widgets = <Widget>[];
    String? lastSection;

    for (final item in _kNavItems) {
      final sectionChanged = item.section != lastSection;

      if (sectionChanged) {
        if (lastSection != null) {
          widgets.add(const SizedBox(height: 4));
        }
        if (showLabels) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                top: 10,
                bottom: 4,
                right: 8,
              ),
              child: Text(
                item.section.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant.withOpacity(0.5),
                  letterSpacing: 1.3,
                ),
              ),
            ),
          );
        } else {
          if (lastSection != null) {
            widgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Divider(
                  height: 1,
                  color: cs.outlineVariant.withOpacity(0.5),
                ),
              ),
            );
          }
        }
        lastSection = item.section;
      }

      widgets.add(
        _NavTile(
          item: item,
          isSelected: _selectedIndex == item.index,
          showLabel: showLabels,
          cs: cs,
          onTap: () {
            setState(() => _selectedIndex = item.index);
            if (isMobile) Navigator.of(context).pop();
          },
        ),
      );
    }

    return widgets;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Zone C: Desktop footer (logout + toggle)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDesktopFooter(
    ColorScheme cs, {
    required bool showExpanded,
    required bool canToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logout
          _logoutTile(cs, expanded: showExpanded),
          const SizedBox(height: 4),
          // Collapse / expand toggle
          if (canToggle)
            Tooltip(
              message: _isExpanded ? 'Collapse sidebar' : 'Expand sidebar',
              child: InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: AnimatedRotation(
                      duration: _animDuration,
                      // chevron_left (points left) when expanded;
                      // rotated 180° (points right) when collapsed.
                      turns: _isExpanded ? 0.0 : 0.5,
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: cs.onSurfaceVariant,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Shared logout tile
  Widget _logoutTile(ColorScheme cs, {required bool expanded}) {
    return Tooltip(
      message: 'Sign out',
      child: InkWell(
        onTap: _confirmLogout,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0),
          child: expanded
              ? Row(
                  children: [
                    Icon(Icons.logout_rounded, color: cs.error, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: cs.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Icon(Icons.logout_rounded, color: cs.error, size: 20),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NavTile — individual navigation row
// ─────────────────────────────────────────────────────────────────────────────
class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final bool showLabel;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.isSelected,
    required this.showLabel,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            vertical: 10,
            horizontal: showLabel ? 12 : 0,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: showLabel
              ? Row(
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected ? cs.primary : cs.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected)
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                )
              : Center(
                  child: Icon(
                    isSelected ? item.activeIcon : item.icon,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                    size: 20,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LogoBadge — gradient admin icon
// ─────────────────────────────────────────────────────────────────────────────
class _LogoBadge extends StatelessWidget {
  final ColorScheme cs;
  const _LogoBadge({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withOpacity(0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.admin_panel_settings_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }
}
