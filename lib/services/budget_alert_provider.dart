import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense_model.dart';
import '../services/expense_service.dart';
import '../providers/expense_providers.dart';
import '../services/budget_service.dart';
import '../providers/budget_providers.dart';
import '../services/notification_service.dart';
import '../services/app_settings_keys.dart';

// ── Shared Preferences key ──────────────────────────────────────────────────
const _kAlertSentKey = 'budget_alert_sent_month';
const _kCategoryAlertSentKeysKey = 'budget_category_alert_sent_keys';

// ── Helper: read/write the "sent month" from disk ───────────────────────────
Future<String?> _readSentMonth() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kAlertSentKey);
}

Future<void> _writeSentMonth(String monthKey) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kAlertSentKey, monthKey);
}

Future<Set<String>> _readSentCategoryKeys() async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList(_kCategoryAlertSentKeysKey) ?? const <String>[])
      .toSet();
}

Future<void> _writeSentCategoryKeys(Set<String> keys) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_kCategoryAlertSentKeysKey, keys.toList());
}

Future<bool> _readNotificationsEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kSettingsNotificationsEnabled) ?? true;
}

Future<bool> _readCategoryAlertsEnabled() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kSettingsCategoryAlertsEnabled) ?? true;
}

Future<double> _readAlertThreshold() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getDouble(kSettingsAlertThreshold) ?? 0.80;
}

// ── In-memory cache so we don't hit disk on every build ─────────────────────
// Null means "not yet loaded from disk this session".
String? _cachedSentMonth;
Set<String> _cachedSentCategoryKeys = <String>{};
bool _cacheLoaded = false;
bool _cacheLoading = false;
bool _processingAlerts = false;

Future<void> resetBudgetAlertCache() async {
  _cachedSentMonth = null;
  _cachedSentCategoryKeys = <String>{};
  _cacheLoaded = false;
}

String _categoryAlertKey(String monthKey, String category) =>
    '$monthKey::$category';

// ── The listener provider ────────────────────────────────────────────────────
/// Watch this provider from HomeScreen. It has no return value — its sole
/// purpose is the side effect of firing a notification when the threshold hits.
final budgetAlertListenerProvider = Provider.autoDispose<void>((ref) {
  final expensesValue = ref.watch(expensesStreamProvider);
  final budgetsValue = ref.watch(budgetsStreamProvider);

  // Only act when both streams have data
  final expenses = expensesValue.valueOrNull;
  final budgets = budgetsValue.valueOrNull;
  if (expenses == null || budgets == null) return;

  if (_processingAlerts) return;

  _processingAlerts = true;
  Future(() async {
    try {
      if (!_cacheLoaded) {
        if (_cacheLoading) return;
        _cacheLoading = true;
        try {
          _cachedSentMonth = await _readSentMonth();
          _cachedSentCategoryKeys = await _readSentCategoryKeys();
          _cacheLoaded = true;
        } finally {
          _cacheLoading = false;
        }
      }

      await _evaluateAndNotify(expenses, budgets);
    } finally {
      _processingAlerts = false;
    }
  });
});

Future<void> _evaluateAndNotify(
  List<ExpenseModel> expenses,
  Map<String, double> budgets,
) async {
  final notificationsEnabled = await _readNotificationsEnabled();
  if (!notificationsEnabled) return;

  final categoryAlertsEnabled = await _readCategoryAlertsEnabled();
  final warningThreshold = await _readAlertThreshold();

  final now = DateTime.now();
  final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

  final currentMonthExpenses = expenses
      .where((e) => e.date.year == now.year && e.date.month == now.month)
      .toList();

  final monthSpent = currentMonthExpenses.fold(
    0.0,
    (sum, expense) => sum + expense.amount,
  );

  final limit = budgets['Total'] ?? 0.0;
  if (limit > 0) {
    final progress = monthSpent / limit;
    if (progress >= warningThreshold && _cachedSentMonth != currentMonthKey) {
      await NotificationService.instance.showBudgetWarning(limit);
      _cachedSentMonth = currentMonthKey;
      await _writeSentMonth(currentMonthKey);
    }
  }

  if (!categoryAlertsEnabled) return;

  final alertsToSend = <MapEntry<String, double>>[];

  for (final entry in budgets.entries) {
    if (entry.key == 'Total' || entry.value <= 0) continue;

    final categorySpent = currentMonthExpenses
        .where((expense) => expense.category == entry.key)
        .fold(0.0, (sum, expense) => sum + expense.amount);

    final progress = categorySpent / entry.value;
    if (progress < warningThreshold) continue;

    final alertKey = _categoryAlertKey(currentMonthKey, entry.key);
    if (_cachedSentCategoryKeys.contains(alertKey)) continue;

    alertsToSend.add(entry);
    _cachedSentCategoryKeys.add(alertKey);
  }

  if (alertsToSend.isEmpty) return;

  for (final entry in alertsToSend) {
    await NotificationService.instance.showCategoryBudgetWarning(
      category: entry.key,
      limit: entry.value,
    );
  }

  await _writeSentCategoryKeys(_cachedSentCategoryKeys);
}
