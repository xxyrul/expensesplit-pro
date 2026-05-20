import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
