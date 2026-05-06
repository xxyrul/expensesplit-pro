import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/app_settings_keys.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';
import '../../services/export_service.dart';
import '../../services/budget_alert_provider.dart';
import 'set_budget_screen.dart';

class SettingsView extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const SettingsView({super.key, required this.onBack});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  bool _loadingSettings = true;

  bool _notificationsEnabled = true;
  bool _categoryAlertsEnabled = true;
  double _alertThreshold = 0.8;
  String _currency = 'RM';
  bool _weekStartsMonday = true;
  String _surplusAction = 'rollover';
  bool _appLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _notificationsEnabled =
          prefs.getBool(kSettingsNotificationsEnabled) ?? true;
      _categoryAlertsEnabled =
          prefs.getBool(kSettingsCategoryAlertsEnabled) ?? true;
      _alertThreshold = prefs.getDouble(kSettingsAlertThreshold) ?? 0.8;
      _currency = prefs.getString(kSettingsCurrency) ?? 'RM';
      _weekStartsMonday = prefs.getBool(kSettingsWeekStartsMonday) ?? true;
      _surplusAction = prefs.getString(kSettingsSurplusAction) ?? 'rollover';
      _appLockEnabled = prefs.getBool(kSettingsAppLockEnabled) ?? false;
      _loadingSettings = false;
    });
  }

  Future<void> _persistBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _persistDouble(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<void> _persistString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _showEditProfileDialog() async {
    final profile = ref.read(userProfileProvider).valueOrNull;
    final controller = TextEditingController(
      text:
          profile?.displayName ??
          FirebaseAuth.instance.currentUser?.displayName ??
          '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    if (!mounted) return;

    final newName = controller.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name cannot be empty')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.updateDisplayName(newName);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'displayName': newName},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No account email found')));
      return;
    }

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send reset email?'),
        content: Text(
          'We will send a password reset link to $email. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (shouldSend != true) return;
    if (!mounted) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send reset email: $e')));
    }
  }

  Future<void> _openThresholdPicker() async {
    final selected = await _showChoiceSheet<double>(
      title: 'Alert Threshold',
      options: const [0.5, 0.8, 0.9, 1.0],
      currentValue: _alertThreshold,
      labelBuilder: (value) => '${(value * 100).toStringAsFixed(0)}%',
    );

    if (selected == null) return;
    setState(() => _alertThreshold = selected);
    await _persistDouble(kSettingsAlertThreshold, selected);
  }

  Future<void> _openCurrencyPicker() async {
    final selected = await _showChoiceSheet<String>(
      title: 'Currency',
      options: const ['RM', 'USD', 'SGD', 'EUR'],
      currentValue: _currency,
      labelBuilder: (value) => value,
    );

    if (selected == null) return;
    setState(() => _currency = selected);
    await _persistString(kSettingsCurrency, selected);
  }

  Future<void> _openSurplusActionPicker() async {
    final selected = await _showChoiceSheet<String>(
      title: 'Default Surplus Action',
      options: const ['rollover', 'goal', 'debt'],
      currentValue: _surplusAction,
      labelBuilder: _surplusActionLabel,
    );

    if (selected == null) return;
    setState(() => _surplusAction = selected);
    await _persistString(kSettingsSurplusAction, selected);
  }

  Future<T?> _showChoiceSheet<T>({
    required String title,
    required List<T> options,
    required T currentValue,
    required String Function(T value) labelBuilder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...options.map(
              (option) => ListTile(
                title: Text(labelBuilder(option)),
                trailing: option == currentValue
                    ? const Icon(Icons.check, color: Color(0xFF0F766E))
                    : null,
                onTap: () => Navigator.pop(context, option),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _clearAlertDedupHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('budget_alert_sent_month');
    await prefs.remove('budget_category_alert_sent_keys');

    await resetBudgetAlertCache();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification history reset for this month'),
      ),
    );
  }

  Future<void> _exportCurrentMonth() async {
    try {
      final expenses = await ref
          .read(expenseServiceProvider)
          .getExpenses()
          .first;
      final now = DateTime.now();
      final filtered = expenses
          .where((e) => e.date.year == now.year && e.date.month == now.month)
          .toList();

      final monthLabel = DateFormat('MMMM yyyy').format(now);
      await ref
          .read(exportServiceProvider)
          .exportExpensesToCsv(filtered, monthLabel);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV export ready to share')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  String _surplusActionLabel(String value) {
    switch (value) {
      case 'rollover':
        return 'Roll Over to Next Month';
      case 'goal':
        return 'Invest in Goals';
      case 'debt':
        return 'Slash Debt';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: _loadingSettings
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                profileAsync.when(
                  data: (userProfile) {
                    final String name = userProfile?.displayName ?? 'User';
                    final String email = userProfile?.email ?? 'No email';
                    final String initials = name.isNotEmpty
                        ? name[0].toUpperCase()
                        : 'U';

                    return _buildHeader(context, name, email, initials);
                  },
                  loading: () => _buildLoadingHeader(context),
                  error: (err, stack) => _buildHeader(
                    context,
                    'Error',
                    'Could not load data',
                    '!',
                  ),
                ),
                if (_loadingSettings)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildSectionTitle('ACCOUNT'),
                        _buildSettingsCard([
                          _buildListTile(
                            Icons.person_outline,
                            'Edit Profile',
                            const Color(0xFF0F766E),
                            onTap: _showEditProfileDialog,
                          ),
                          const Divider(height: 1),
                          _buildListTile(
                            Icons.lock_outline,
                            'Reset Password',
                            const Color(0xFF0EA5A0),
                            onTap: _sendPasswordReset,
                          ),
                        ]),
                        const SizedBox(height: 22),
                        _buildSectionTitle('BUDGET'),
                        _buildSettingsCard([
                          _buildListTile(
                            Icons.monetization_on_outlined,
                            'Monthly Budget',
                            const Color(0xFF0284C7),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SetBudgetScreen(),
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          _buildListTile(
                            Icons.currency_exchange,
                            'Currency',
                            const Color(0xFF7C3AED),
                            trailingText: _currency,
                            onTap: _openCurrencyPicker,
                          ),
                          const Divider(height: 1),
                          _buildSwitchTile(
                            Icons.calendar_view_week,
                            'Week starts on Monday',
                            const Color(0xFFB45309),
                            value: _weekStartsMonday,
                            onChanged: (value) async {
                              setState(() => _weekStartsMonday = value);
                              await _persistBool(
                                kSettingsWeekStartsMonday,
                                value,
                              );
                            },
                          ),
                          const Divider(height: 1),
                          _buildListTile(
                            Icons.swap_horiz,
                            'Default Surplus Action',
                            const Color(0xFF0F766E),
                            trailingText: _surplusActionLabel(_surplusAction),
                            onTap: _openSurplusActionPicker,
                          ),
                        ]),
                        const SizedBox(height: 22),
                        _buildSectionTitle('NOTIFICATIONS'),
                        _buildSettingsCard([
                          _buildSwitchTile(
                            Icons.notifications_active_outlined,
                            'Budget Alerts',
                            const Color(0xFF0F766E),
                            value: _notificationsEnabled,
                            onChanged: (value) async {
                              setState(() => _notificationsEnabled = value);
                              await _persistBool(
                                kSettingsNotificationsEnabled,
                                value,
                              );
                            },
                          ),
                          const Divider(height: 1),
                          _buildSwitchTile(
                            Icons.category_outlined,
                            'Category Alerts',
                            const Color(0xFF0EA5A0),
                            value: _categoryAlertsEnabled,
                            onChanged: _notificationsEnabled
                                ? (value) async {
                                    setState(
                                      () => _categoryAlertsEnabled = value,
                                    );
                                    await _persistBool(
                                      kSettingsCategoryAlertsEnabled,
                                      value,
                                    );
                                  }
                                : null,
                          ),
                          const Divider(height: 1),
                          _buildListTile(
                            Icons.tune,
                            'Alert Threshold',
                            const Color(0xFF0284C7),
                            trailingText:
                                '${(_alertThreshold * 100).toStringAsFixed(0)}%',
                            onTap: _openThresholdPicker,
                          ),
                          const Divider(height: 1),
                          _buildListTile(
                            Icons.refresh,
                            'Reset Alert History',
                            const Color(0xFFB91C1C),
                            onTap: _clearAlertDedupHistory,
                          ),
                        ]),
                        const SizedBox(height: 22),
                        _buildSectionTitle('DATA & SECURITY'),
                        _buildSettingsCard([
                          _buildListTile(
                            Icons.download_rounded,
                            'Export Current Month CSV',
                            const Color(0xFF0EA5A0),
                            onTap: _exportCurrentMonth,
                          ),
                          const Divider(height: 1),
                          _buildSwitchTile(
                            Icons.lock_clock_outlined,
                            'App Lock',
                            const Color(0xFF475569),
                            value: _appLockEnabled,
                            onChanged: (value) async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _appLockEnabled = value);
                              await _persistBool(
                                kSettingsAppLockEnabled,
                                value,
                              );
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    value
                                        ? 'App lock preference saved'
                                        : 'App lock disabled',
                                  ),
                                ),
                              );
                            },
                          ),
                        ]),
                        const SizedBox(height: 40),
                        _buildLogoutButton(ref),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildLogoutButton(WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => ref.read(authServiceProvider).signOut(),
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          'Logout',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDC2626),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingHeader(BuildContext context) {
    return _buildHeader(context, 'Loading...', 'Fetching profile...', '');
  }

  Widget _buildHeader(
    BuildContext context,
    String name,
    String email,
    String initials,
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        bottom: 26,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF134E4A), Color(0xFF0F766E), Color(0xFF0EA5A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
            onPressed: widget.onBack,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 10, bottom: 20),
            child: Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 5, bottom: 10),
        child: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(
    IconData icon,
    String title,
    Color color, {
    required bool value,
    required Future<void> Function(bool value)? onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged == null ? null : (v) => onChanged(v),
        activeColor: const Color(0xFF0F766E),
      ),
      onTap: onChanged == null ? null : () => onChanged(!value),
    );
  }

  Widget _buildListTile(
    IconData icon,
    String title,
    Color color, {
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          const SizedBox(width: 5),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
      onTap: onTap,
    );
  }
}
