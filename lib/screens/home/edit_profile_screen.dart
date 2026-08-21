import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/brand_theme.dart';

class EditProfileScreen extends StatefulWidget {
  final String initialDisplayName;
  final String initialUsername;
  final String email;

  final bool isGoogleUser;
  final bool hasPasswordProvider;
  final Future<void> Function(String displayName, String username, String email) onSaveProfile;
  final Future<void> Function() onSetOrChangePassword;
  final Future<void> Function() onResetPassword;
  final Future<void> Function() onChangeEmail;
  final Future<void> Function() onDeleteAccount;
  final Future<void> Function() onLinkGoogle;
  final Future<void> Function() onUnlinkGoogle;


  const EditProfileScreen({
    super.key,
    required this.initialDisplayName,
    required this.initialUsername,
    required this.email,

    required this.isGoogleUser,
    required this.hasPasswordProvider,
    required this.onSaveProfile,
    required this.onSetOrChangePassword,
    required this.onResetPassword,
    required this.onChangeEmail,
    required this.onDeleteAccount,
    required this.onLinkGoogle,
    required this.onUnlinkGoogle,

  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;

  bool _isSavingProfile = false;
  bool _isLinkingGoogle = false;
  bool _isUnlinkingGoogle = false;
  late bool _localIsGoogleUser;

  bool get _showSetPasswordCta => _localIsGoogleUser && !widget.hasPasswordProvider;
  bool get _canUsePasswordAuth => !_localIsGoogleUser || widget.hasPasswordProvider;

  @override
  void initState() {
    super.initState();
    _localIsGoogleUser = widget.isGoogleUser;
    _displayNameController = TextEditingController(text: widget.initialDisplayName);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _emailController = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSavingProfile = true);
    try {
      await widget.onSaveProfile(
        _displayNameController.text.trim(),
        _usernameController.text.trim(),
        _emailController.text.trim(),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
      }
    }
  }

  Future<void> _linkGoogle() async {
    setState(() => _isLinkingGoogle = true);
    try {
      await widget.onLinkGoogle();
      if (mounted) {
        setState(() => _localIsGoogleUser = true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLinkingGoogle = false);
      }
    }
  }

  Future<void> _unlinkGoogle() async {
    setState(() => _isUnlinkingGoogle = true);
    try {
      await widget.onUnlinkGoogle();
      if (mounted) {
        setState(() {
          _localIsGoogleUser = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isUnlinkingGoogle = false);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 24,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: context.brandHeaderGradient,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Edit Profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('PROFILE'),
                  _profileCard(scheme),
                  const SizedBox(height: 22),
                  _sectionTitle('ACCOUNT'),
                  _accountCard(scheme),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _profileCard(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          TextField(
            controller: _displayNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.emailAddress,
            readOnly: widget.isGoogleUser,
            decoration: InputDecoration(
              labelText: 'Email Address',
              prefixIcon: const Icon(Icons.email_outlined),
              helperText: widget.isGoogleUser
                  ? 'Your email is managed securely by your Google Account. It cannot be changed here.'
                  : 'Changing email will send a verification link to the new address.',
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSavingProfile ? null : _saveProfile,
              icon: _isSavingProfile
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSavingProfile ? 'Saving...' : 'Save Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountCard(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          if (_showSetPasswordCta)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF0D9488).withOpacity(0.22),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_reset_rounded,
                      color: Color(0xFF0D9488),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Google sign-in detected. Add a password for email login.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onSetOrChangePassword,
                      child: const Text('Set Password'),
                    ),
                  ],
                ),
              ),
            ),
          _accountTile(
            icon: Icons.lock_outline,
            title: _showSetPasswordCta ? 'Set Password' : 'Change Password',
            color: const Color(0xFF6366F1),
            onTap: widget.onSetOrChangePassword,
          ),
          _divider(),
          _accountTile(
            icon: Icons.lock_reset_rounded,
            title: 'Reset Password',
            color: const Color(0xFF0D9488),
            onTap: widget.onResetPassword,
          ),
          _divider(),
          _accountTile(
            icon: Icons.email_outlined,
            title: 'Change Email',
            color: const Color(0xFF0284C7),
            onTap: widget.onChangeEmail,
          ),
          _divider(),
          if (_localIsGoogleUser)
            _accountTile(
              iconWidget: const GoogleLogoWidget(size: 20),
              title: 'Unlink Google Account',
              color: Colors.grey,
              containerColor: Theme.of(context).colorScheme.surfaceContainerHigh,
              onTap: _isUnlinkingGoogle ? () {} : _unlinkGoogle,
              trailing: _isUnlinkingGoogle
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right, color: Colors.grey),
            )
          else
            _accountTile(
              iconWidget: const GoogleLogoWidget(size: 20),
              title: 'Link Google Account',
              color: Colors.grey,
              containerColor: Theme.of(context).colorScheme.surfaceContainerHigh,
              onTap: _isLinkingGoogle ? () {} : _linkGoogle,
              trailing: _isLinkingGoogle
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right, color: Colors.grey),
            ),

          _divider(),
          _accountTile(
            icon: Icons.delete_forever_outlined,
            title: 'Delete Account',
            color: const Color(0xFFDC2626),
            onTap: widget.onDeleteAccount,
          ),
        ],
      ),
    );
  }

  Widget _accountTile({
    IconData? icon,
    Widget? iconWidget,
    required String title,
    required Color color,
    Color? containerColor,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: containerColor ?? color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: iconWidget ?? (icon != null ? Icon(icon, color: color, size: 20) : const SizedBox(width: 20, height: 20)),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
    );
  }

  Widget _divider() => const Divider(height: 1);
}

// ── Realistic Google Logo Drawing ───────────────────────────────────────────

class GoogleLogoWidget extends StatelessWidget {
  final double size;
  const GoogleLogoWidget({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/google_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
