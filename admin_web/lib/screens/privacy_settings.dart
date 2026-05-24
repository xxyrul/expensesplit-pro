import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../services/audit_log_service.dart';
import '../widgets/modern_bottom_toast.dart';

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState
    extends ConsumerState<PrivacySettingsScreen> {
  // ── State variables ──────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _retentionController = TextEditingController();

  bool _maskSensitiveData = false;
  bool _isLoading = true;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  @override
  void dispose() {
    _retentionController.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────
  Future<void> _loadPrivacySettings() async {
    try {
      final doc = await _firestore
          .collection('system_config')
          .doc('privacy_settings')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _maskSensitiveData = data['maskSensitiveData'] ?? false;
          _retentionController.text =
              (data['retentionDays'] ?? 365).toString();
          _isLoading = false;
        });
      } else {
        _retentionController.text = '365';
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading privacy settings: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────
  Future<void> _savePrivacySettings() async {
    final retentionDays =
        int.tryParse(_retentionController.text.trim()) ?? 365;

    setState(() => _isLoading = true);

    try {
      await _firestore
          .collection('system_config')
          .doc('privacy_settings')
          .set({
        'maskSensitiveData': _maskSensitiveData,
        'retentionDays': retentionDays,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      ref.read(auditLogServiceProvider).logAction(
            action: 'UPDATE_PRIVACY_POLICY',
            targetId: 'privacy_settings',
            targetType: 'system_config',
            detail:
                'Updated policy: Mask PII = $_maskSensitiveData, Data Retention = $retentionDays Days.',
          );

      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Privacy Policy Applied & Audited Successfully!',
          type: ModernToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Failed to save settings: $e',
          type: ModernToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined),
            SizedBox(width: 10),
            Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _policySection('Overview & Scope',
                    'ExpenseSplit Pro is a closed, internal expense management platform. This policy governs all users of both the mobile application and the administrative web portal. Access is restricted exclusively to pre-authorised personnel.'),
                _policySection('Data We Collect',
                    '• Authentication data: Google account email and display name for sign-in via Google OAuth 2.0.\n• Expense records: Transaction amounts, categories, dates, and group split allocations.\n• Receipt images: Photos uploaded for OCR parsing.\n• Audit logs: Administrative action records timestamped for compliance.\n• Phone number (optional): Linked for 2FA recovery.'),
                _policySection('Data Usage',
                    '• To authenticate users and manage access control.\n• To record and split shared group expenses between authorised members.\n• To parse receipt images and auto-populate expense fields.\n• To generate internal financial reports and analytics dashboards.\n• To maintain an immutable audit trail for system compliance.'),
                _policySection('Security',
                    '• All data transmitted over HTTPS/TLS encryption.\n• Firebase Security Rules enforce role-based access at database level.\n• Configurable PII masking hides sensitive email addresses in administrative lists.\n• Administrative actions logged immutably to prevent unauthorised modification.'),
                _policySection('Data Retention',
                    'Retention periods are configurable by administrators in this settings panel. Upon account deletion or administrator request, all personally identifiable information is permanently removed within 30 days.'),
                _policySection('Third Parties',
                    'Data is never sold or shared commercially. Google Firebase (Authentication, Firestore, Storage) and Google OAuth 2.0 are used solely to operate the platform.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => html.window.open('/privacy.html', '_blank'),
            child: const Text('Open Full Page'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.description_outlined),
            SizedBox(width: 10),
            Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _policySection('Acceptance of Terms',
                    'By accessing or using ExpenseSplit Pro, you agree to be bound by these Terms of Service. If you do not agree, you must not access or use the platform.'),
                _policySection('Authorised Use Only',
                    'This is a closed, internal platform restricted to pre-authorised personnel only. You confirm that:\n• You have been granted explicit access by a system administrator.\n• You are using your own, legitimate account credentials.\n• You will not attempt to access areas beyond your assigned permissions.\n• You will not share your login credentials with any other person.\n\n⚠️ Unauthorised access may result in immediate account termination and legal action.'),
                _policySection('User Responsibilities',
                    '• Enter accurate, truthful expense data and do not falsify records.\n• Use the OCR feature solely for legitimate business expense documentation.\n• Refrain from uploading illegal, offensive, or unlawful content.\n• Report any suspected security vulnerabilities to a system administrator promptly.'),
                _policySection('Audit Logging & Monitoring',
                    'All administrative actions are logged to an immutable audit trail. By using the platform, you acknowledge and consent to this monitoring for compliance and accountability. Audit logs may be reviewed by authorised administrators at any time.'),
                _policySection('Google Authentication',
                    'This platform uses Google OAuth 2.0 for authentication. By signing in with Google, you also agree to Google\'s Terms of Service and Privacy Policy. We receive only your email address and display name from Google.'),
                _policySection('Governing Law',
                    'These Terms are governed by the laws of Malaysia. Any disputes shall be subject to the exclusive jurisdiction of the courts of Malaysia.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => html.window.open('/terms.html', '_blank'),
            child: const Text('Open Full Page'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _policySection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final isMobile = constraints.maxWidth < 600;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Page header ───────────────────────────────────────
                  Text(
                    'Privacy & Data Governance',
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure personal data masking rules, record retention '
                    'schedules, and oversee regulatory compliance policies.',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Layout grid ───────────────────────────────────────
                  if (isNarrow) ...[
                    _buildSettingsCard(colorScheme),
                    const SizedBox(height: 24),
                    _buildComplianceSummaryCard(colorScheme),
                    const SizedBox(height: 24),
                    _buildGovernanceInfoCard(colorScheme),
                  ] else Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          children: [
                            _buildSettingsCard(colorScheme),
                            const SizedBox(height: 24),
                            _buildComplianceSummaryCard(colorScheme),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 2,
                        child: _buildGovernanceInfoCard(colorScheme),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Settings card ─────────────────────────────────────────────────────────
  Widget _buildSettingsCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: colorScheme.primary),
                const SizedBox(width: 12),
                const Text(
                  'Governance Configurations',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // PII masking toggle
            SwitchListTile(
              title: const Text(
                'Mask Sensitive Data (PII)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Mask email addresses (e.g. ex***@domain.com) in all '
                'administrative lists to adhere to privacy regulations.',
              ),
              value: _maskSensitiveData,
              activeColor: colorScheme.primary,
              onChanged: (val) => setState(() => _maskSensitiveData = val),
            ),
            const Divider(height: 32),

            // Retention days field
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data Retention Limit',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Number of days transaction history is kept before '
                        'being systematically purged.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: _retentionController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Days Limit',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _savePrivacySettings,
                icon: const Icon(Icons.lock_person),
                label: const Text('Enforce Governance Policies'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 24),

            // View Privacy Policy tile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.privacy_tip_outlined,
                color: colorScheme.primary,
              ),
              title: const Text(
                'View Privacy Policy',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Data collection, usage, and security details.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: _showPrivacyPolicyDialog,
            ),
            const Divider(height: 1),

            // View Terms of Service tile
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.description_outlined,
                color: colorScheme.primary,
              ),
              title: const Text(
                'View Terms of Service',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Platform usage rules and obligations.',
                style: TextStyle(fontSize: 12),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: _showTermsDialog,
            ),
          ],
        ),
      ),
    );
  }

  // ── Compliance summary card ───────────────────────────────────────────────
  Widget _buildComplianceSummaryCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield, color: colorScheme.primary),
                const SizedBox(width: 12),
                const Text(
                  'Privacy Policy Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _complianceRow(
              'PII Data Masking',
              _maskSensitiveData ? 'ENFORCED' : 'DISABLED',
              _maskSensitiveData ? Colors.green : Colors.amber,
            ),
            _complianceRow(
              'Data Retention Policy',
              '${_retentionController.text} Days active',
              Colors.blue,
            ),
            _complianceRow(
              'Local Storage Logs',
              'Encrypted',
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _complianceRow(String label, String value, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Chip(
            label: Text(
              value,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: statusColor.withOpacity(0.1),
            side: BorderSide(color: statusColor.withOpacity(0.2)),
          ),
        ],
      ),
    );
  }

  // ── Governance info card ──────────────────────────────────────────────────
  Widget _buildGovernanceInfoCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thesis Governance Framework',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This admin portal includes active configurations to model '
              'personal data protections under standard governance regulations '
              'such as GDPR (General Data Protection Regulation) and PDPA '
              '(Personal Data Protection Act 2010 of Malaysia).',
              style: TextStyle(height: 1.5, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _buildBulletPoint(
              colorScheme,
              'Sensitive PII (Personally Identifiable Information) masking '
              'prevents internal developers/system administrators from '
              'harvesting user emails without explicit consent.',
            ),
            _buildBulletPoint(
              colorScheme,
              'Retention Purge schedules limit exposure durations of scanned '
              'receipts to reduce data breach impacts.',
            ),
            _buildBulletPoint(
              colorScheme,
              'Immutable action logging provides verifiable security trails '
              'to third-party safety auditors.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(ColorScheme colorScheme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right, color: colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
