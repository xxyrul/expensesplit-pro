import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_layout.dart';
import 'ocr_review_queue.dart';
import 'user_management.dart';
import 'audit_log_screen.dart';

class ResponsiveAdminShell extends ConsumerStatefulWidget {
  const ResponsiveAdminShell({super.key});

  @override
  ConsumerState<ResponsiveAdminShell> createState() => _ResponsiveAdminShellState();
}

class _ResponsiveAdminShellState extends ConsumerState<ResponsiveAdminShell> {
  int _selectedIndex = 0;

  final List<Widget> _views = const [
    DashboardLayout(),
    OcrReviewQueueScreen(),
    UserManagementScreen(),
    AuditLogScreen(),
  ];

  final List<NavigationRailDestination> _destinations = const [
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Dashboard'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.document_scanner_outlined),
      selectedIcon: Icon(Icons.document_scanner),
      label: Text('OCR Review'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: Text('Users'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: Text('Audit Log'),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) {
            // Desktop Layout: Permanent NavigationRail
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: _destinations,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _views,
                  ),
                ),
              ],
            );
          } else {
            // Mobile Layout: Drawer + AppBar
            return Scaffold(
              appBar: AppBar(
                title: const Text('ExpenseSplit Admin'),
              ),
              drawer: Drawer(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            size: 48,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          const Spacer(),
                          Text(
                            'Admin Dashboard',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (int i = 0; i < _destinations.length; i++)
                      ListTile(
                        leading: _selectedIndex == i
                            ? _destinations[i].selectedIcon
                            : _destinations[i].icon,
                        title: _destinations[i].label,
                        selected: _selectedIndex == i,
                        onTap: () {
                          setState(() {
                            _selectedIndex = i;
                          });
                          Navigator.pop(context); // Close the drawer
                        },
                      ),
                  ],
                ),
              ),
              body: IndexedStack(
                index: _selectedIndex,
                children: _views,
              ),
            );
          }
        },
      ),
    );
  }
}
