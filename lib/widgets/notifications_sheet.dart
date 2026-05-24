import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/budget_alert_provider.dart';
import '../../services/expense_service.dart';
import '../../services/budget_service.dart';

class NotificationsSheet extends ConsumerStatefulWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotificationsSheet(),
    );
  }

  @override
  ConsumerState<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends ConsumerState<NotificationsSheet> {
  bool _clearingAll = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _clearAllNotifications() async {
    setState(() => _clearingAll = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('budget_alert_sent_month');
    await prefs.remove('budget_category_alert_sent_keys');
    await resetBudgetAlertCache();

    if (!mounted) return;
    setState(() {
      _clearingAll = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expensesAsync = ref.watch(expensesStreamProvider);
    final budgetsAsync = ref.watch(budgetsStreamProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            top: 12,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _clearingAll ? null : _clearAllNotifications,
                    icon: _clearingAll
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.clear_all_rounded),
                    label: const Text('Clear all'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Recent alerts and announcements',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Flexible(
                child: expensesAsync.when(
                  data: (expenses) {
                    return budgetsAsync.when(
                      data: (budgets) {
                        final now = DateTime.now();
                        final monthExpenses = expenses.where((e) {
                          return e.date.year == now.year && e.date.month == now.month;
                        }).toList();

                        final totalSpent = monthExpenses.fold(0.0, (sum, e) => sum + e.amount);
                        final totalLimit = budgets['Total'] ?? 0.0;

                        final List<Widget> alertWidgets = [];



                        if (totalLimit > 0) {
                          final progress = totalSpent / totalLimit;
                          if (progress >= 0.8) {
                            alertWidgets.add(
                              _buildAlertCard(
                                context: context,
                                title: 'BUDGET WARNING',
                                subtitle:
                                    'Spent RM ${totalSpent.toStringAsFixed(2)} of RM ${totalLimit.toStringAsFixed(0)} monthly budget (${(progress * 100).toStringAsFixed(0)}%).',
                                icon: Icons.warning_amber_rounded,
                                color: progress >= 1.0 ? Colors.red : Colors.orange,
                                progress: progress,
                              ),
                            );
                          }
                        }

                        for (final entry in budgets.entries) {
                          if (entry.key == 'Total' || entry.value <= 0) continue;

                          final categorySpent = monthExpenses
                              .where((e) => e.category == entry.key)
                              .fold(0.0, (sum, e) => sum + e.amount);

                          final progress = categorySpent / entry.value;
                          if (progress >= 0.8) {
                            alertWidgets.add(
                              _buildAlertCard(
                                context: context,
                                title: '${entry.key.toUpperCase()} BUDGET WARNING',
                                subtitle:
                                    'Spent RM ${categorySpent.toStringAsFixed(2)} of RM ${entry.value.toStringAsFixed(0)} allocation.',
                                icon: Icons.pie_chart_outline_rounded,
                                color: progress >= 1.0 ? Colors.red : Colors.orange,
                                progress: progress,
                              ),
                            );
                          }
                        }

                        if (alertWidgets.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_none_rounded,
                                    size: 64,
                                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'All caught up',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'No active alerts right now.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: alertWidgets.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => alertWidgets[index],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    double? progress,
    bool isDismissed = false,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    final cardColor = isDismissed
        ? theme.colorScheme.surfaceContainer
        : color.withOpacity(0.08);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDismissed
              ? theme.colorScheme.outlineVariant.withOpacity(0.5)
              : color.withOpacity(0.24),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDismissed
                  ? theme.colorScheme.onSurface.withOpacity(0.08)
                  : color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isDismissed ? theme.colorScheme.onSurfaceVariant : color,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDismissed ? theme.colorScheme.onSurfaceVariant : color,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (isDismissed)
                      Text(
                        'READ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isDismissed ? FontWeight.normal : FontWeight.w600,
                    color: isDismissed
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: theme.colorScheme.onSurface.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
              if (!isDismissed || action != null) const SizedBox(height: 10),
              if (action != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: action,
                ),
        ],
      ),
    );
  }
}
