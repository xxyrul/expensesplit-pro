import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/app_settings_keys.dart';
import '../../services/auth_service.dart';
import '../../services/expense_service.dart';
import '../../services/export_service.dart';
import '../../services/budget_alert_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/brand_theme.dart';
import '../../widgets/modern_bottom_toast.dart';
import 'edit_profile_screen.dart';
import 'set_budget_screen.dart';

class SettingsView extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const SettingsView({super.key, required this.onBack});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView>
  with WidgetsBindingObserver {
  bool _loadingSettings = true;

  bool _notificationsEnabled = true;
  bool _categoryAlertsEnabled = true;
  double _alertThreshold = 0.8;
  String _currency = 'RM';
  bool _weekStartsMonday = true;
  String _surplusAction = 'rollover';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _refreshAuthProviderState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAuthProviderState();
    }
  }

  Future<void> _refreshAuthProviderState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await user.reload();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // Ignore refresh failures; account UI can still render from current data.
    }
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

  Future<void> _saveProfileDetails(String newName, String newUsername, String newEmail) async {
    if (newName.isEmpty) {
      ModernBottomToast.show(
        context,
        message: 'Display name cannot be empty',
        type: ModernToastType.error,
      );
      return;
    }
    if (newUsername.isEmpty) {
      ModernBottomToast.show(
        context,
        message: 'Username cannot be empty',
        type: ModernToastType.error,
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (newName != user.displayName) {
        await user.updateDisplayName(newName);
      }

      if (newEmail.isNotEmpty && newEmail != user.email) {
        await user.verifyBeforeUpdateEmail(newEmail);
        if (mounted) {
          ModernBottomToast.show(
            context,
            message: 'Verification email sent to $newEmail. Please verify to update your email.',
            type: ModernToastType.info,
          );
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'displayName': newName,
        'name': newUsername,
        'email': newEmail,
      });

      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Profile updated',
        type: ModernToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Failed to update profile: $e',
        type: ModernToastType.error,
      );
    }
  }

  Future<void> _linkGoogleAccount() async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.linkGoogle();
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Google account linked successfully.',
        type: ModernToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Failed to link Google: $e',
        type: ModernToastType.error,
      );
    } finally {
      await _refreshAuthProviderState();
    }
  }

  Future<void> _unlinkGoogleAccount() async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.unlinkGoogle();
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Google account unlinked successfully.',
        type: ModernToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Failed to unlink Google: $e',
        type: ModernToastType.error,
      );
    } finally {
      await _refreshAuthProviderState();
    }
  }

  Future<void> _linkPhoneNumber(String verificationId, String smsCode) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.linkPhoneNumber(verificationId, smsCode);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'phoneNumber': user.phoneNumber,
        });
      }
      
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Phone number linked successfully.',
        type: ModernToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Failed to link phone number: $e',
        type: ModernToastType.error,
      );
      rethrow;
    } finally {
      await _refreshAuthProviderState();
    }
  }

  Future<void> _unlinkPhoneNumber() async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.unlinkPhoneNumber();
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'phoneNumber': FieldValue.delete(),
        });
      }
      
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Phone number unlinked successfully.',
        type: ModernToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Failed to unlink phone number: $e',
        type: ModernToastType.error,
      );
      rethrow;
    } finally {
      await _refreshAuthProviderState();
    }
  }

  Future<void> _setPasswordForGoogleUser() async {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email;

    if (user == null || email == null || email.isEmpty) {
      ModernBottomToast.show(
        context,
        message: 'No account email found',
        type: ModernToastType.info,
      );
      return;
    }

    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add a password so you can sign in with email and password too.',
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm new password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      ModernBottomToast.show(
        context,
        message: 'Please fill in all password fields.',
        type: ModernToastType.error,
      );
      return;
    }

    if (newPassword.length < 6) {
      ModernBottomToast.show(
        context,
        message: 'New password must be at least 6 characters.',
        type: ModernToastType.error,
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ModernBottomToast.show(
        context,
        message: 'New passwords do not match.',
        type: ModernToastType.error,
      );
      return;
    }

    try {
      await ref.read(authServiceProvider).setPassword(newPassword: newPassword);
      await _refreshAuthProviderState();
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Password added successfully.',
        type: ModernToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Failed to add password: $e',
        type: ModernToastType.error,
      );
    }
  }

  Future<void> _changePassword() async {
    if (_isGoogleUser && !_hasPasswordProvider) {
      await _setPasswordForGoogleUser();
      return;
    }

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm new password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final currentPassword = currentPasswordController.text.trim();
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      ModernBottomToast.show(
        context,
        message: 'Please fill in all password fields.',
        type: ModernToastType.error,
      );
      return;
    }

    if (newPassword.length < 6) {
      ModernBottomToast.show(
        context,
        message: 'New password must be at least 6 characters.',
        type: ModernToastType.error,
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ModernBottomToast.show(
        context,
        message: 'New passwords do not match.',
        type: ModernToastType.error,
      );
      return;
    }

    try {
      await ref.read(authServiceProvider).changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      await _refreshAuthProviderState();
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Password updated successfully.',
        type: ModernToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Failed to update password: $e',
        type: ModernToastType.error,
      );
    }
  }

  // True when signed in via Google (no password)
  bool get _isGoogleUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'google.com');
  }

  bool get _hasPasswordProvider {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  bool get _canUsePasswordAuth => !_isGoogleUser || _hasPasswordProvider;

  Future<void> _openEditProfileScreen(String name, String rawUsername, String email) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, __, ___) => EditProfileScreen(
          initialDisplayName: name,
          initialUsername: rawUsername,
          email: email,
          phoneNumber: FirebaseAuth.instance.currentUser?.phoneNumber,
          isGoogleUser: _isGoogleUser,
          hasPasswordProvider: _hasPasswordProvider,
          onSaveProfile: _saveProfileDetails,
          onSetOrChangePassword: _changePassword,
          onResetPassword: _sendPasswordReset,
          onChangeEmail: _changeEmail,
          onDeleteAccount: _deleteAccount,
          onLinkGoogle: _linkGoogleAccount,
          onUnlinkGoogle: _unlinkGoogleAccount,
          onLinkPhoneNumber: _linkPhoneNumber,
          onUnlinkPhoneNumber: _unlinkPhoneNumber,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slide = Tween<Offset>(
            begin: const Offset(0.06, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );

    await _refreshAuthProviderState();
  }

  Future<void> _changeEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final controller = TextEditingController(text: user.email ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Email'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'New email address'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    final newEmail = controller.text.trim();
    if (newEmail.isEmpty || newEmail == user.email) return;

    try {
      await user.verifyBeforeUpdateEmail(newEmail);
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message:
            'Verification email sent to $newEmail. Please verify to complete the change.',
        type: ModernToastType.info,
      );
    } catch (e) {
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Failed to update email: $e',
        type: ModernToastType.error,
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and ALL your expense data. This cannot be undone.\n\nAre you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Delete Firestore data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // Delete Firebase Auth account
      await user.delete();

      // Sign out Google too
      await GoogleSignIn().disconnect();
    } catch (e) {
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message:
            'Could not delete account. You may need to re-login first: $e',
        type: ModernToastType.error,
      );
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      ModernBottomToast.show(
        context,
        message: 'No account email found',
        type: ModernToastType.info,
      );
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
      ModernBottomToast.show(
        context,
        message: 'Password reset email sent to $email',
        type: ModernToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Failed to send reset email: $e',
        type: ModernToastType.error,
      );
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
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
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
    ModernBottomToast.show(
      context,
      message: 'Notification history reset for this month',
      type: ModernToastType.info,
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
      ModernBottomToast.show(
        context,
        message: 'CSV export ready to share',
        type: ModernToastType.success,
      );
    } catch (e) {
      if (!mounted) return;
      ModernBottomToast.show(
        context,
        message: 'Export failed: $e',
        type: ModernToastType.error,
      );
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: _loadingSettings
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                profileAsync.when(
                  data: (userProfile) {
                    final String name = userProfile?.displayName ?? 'User';
                    final String email = userProfile?.email ?? 'No email';
                    final String rawUsername = userProfile?.name ?? (email.contains('@') ? email.split('@').first : 'user');
                    final String username = '@$rawUsername';
                    final String initials = name.isNotEmpty
                        ? name[0].toUpperCase()
                        : 'U';

                    return _buildHeader(
                      context,
                      name,
                      username,
                      email,
                      initials,
                      onEdit: () => _openEditProfileScreen(name, rawUsername, email),
                    );
                  },
                  loading: () => _buildLoadingHeader(context),
                  error: (err, stack) => _buildHeader(
                    context,
                    'Error',
                    '@user',
                    'Could not load data',
                    '!',
                    onEdit: () => _openEditProfileScreen('User', 'user', ''),
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
                        _buildSectionTitle('APPEARANCE'),
                        _buildSettingsCard([
                          _buildSwitchTile(
                            Icons.brightness_auto_outlined,
                            'Match system theme',
                            colorScheme.primary,
                            value: ref.watch(themeProvider) == ThemeMode.system,
                            onChanged: (value) async {
                              if (value) {
                                ref.read(themeProvider.notifier).useSystemTheme();
                              } else {
                                final isDark = Theme.of(context).brightness == Brightness.dark;
                                ref.read(themeProvider.notifier).setDarkMode(isDark);
                              }
                            },
                            subtitle:
                                'Light/dark and accent colors from Android Material You (wallpaper)',
                          ),
                          const Divider(height: 1),
                          _buildSwitchTile(
                            Icons.dark_mode_outlined,
                            'Dark Mode',
                            colorScheme.primary,
                            value: Theme.of(context).brightness == Brightness.dark,
                            onChanged: ref.watch(themeProvider) == ThemeMode.system
                                ? null
                                : (value) async {
                                    ref.read(themeProvider.notifier).setDarkMode(value);
                                  },
                            subtitle: ref.watch(themeProvider) == ThemeMode.system
                                ? 'Disabled while following system theme'
                                : null,
                          ),
                        ]),
                        const SizedBox(height: 22),
                        _buildSectionTitle('BUDGET'),
                        _buildSettingsCard([
                          _buildListTile(
                            Icons.monetization_on_outlined,
                            'Monthly Budget',
                            colorScheme.primary,
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
                            colorScheme.primary,
                            trailingText: _currency,
                            onTap: _openCurrencyPicker,
                          ),
                          const Divider(height: 1),
                          _buildSwitchTile(
                            Icons.calendar_view_week,
                            'Week starts on Monday',
                            colorScheme.primary,
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
                            colorScheme.primary,
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
                            colorScheme.primary,
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
                            colorScheme.primary,
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
                            colorScheme.primary,
                            trailingText:
                                '${(_alertThreshold * 100).toStringAsFixed(0)}%',
                            onTap: _openThresholdPicker,
                          ),
                          const Divider(height: 1),
                          _buildListTile(
                            Icons.refresh,
                            'Reset Alert History',
                            colorScheme.error,
                            onTap: _clearAlertDedupHistory,
                          ),
                        ]),
                        const SizedBox(height: 22),
                        _buildSectionTitle('DATA & SECURITY'),
                        _buildSettingsCard([
                          _buildListTile(
                            Icons.download_rounded,
                            'Export Current Month CSV',
                            colorScheme.primary,
                            onTap: _exportCurrentMonth,
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
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => ref.read(authServiceProvider).signOut(),
        icon: const Icon(Icons.logout),
        label: const Text(
          'Logout',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
          side: BorderSide(
            color: colorScheme.error.withOpacity(0.35),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingHeader(BuildContext context) {
    return _buildHeader(
      context,
      'Loading...',
      '@user',
      'Fetching profile...',
      '',
      onEdit: () {},
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String name,
    String username,
    String email,
    String initials,
    {required VoidCallback onEdit}
  ) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        bottom: 26,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        gradient: context.brandHeaderGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: widget.onBack,
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                const SizedBox(height: 4),
                                Text(
                                  username,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: onEdit,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withValues(alpha: 0.12),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text('Edit'),
                          ),
                        ],
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
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : const Color(0xFF64748B),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
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
    String? subtitle,
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
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged == null ? null : (v) => onChanged(v),
        activeThumbColor: Theme.of(context).colorScheme.onPrimary,
        activeTrackColor: Theme.of(context).colorScheme.primary,
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF0F172A),
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
