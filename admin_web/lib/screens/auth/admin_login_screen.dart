import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../widgets/modern_bottom_toast.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LoginUI();
  }
}

class _LoginUI extends ConsumerStatefulWidget {
  const _LoginUI();

  @override
  ConsumerState<_LoginUI> createState() => _LoginUIState();
}

class _LoginUIState extends ConsumerState<_LoginUI>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isGoogleLoading = false;
  bool _isEmailLoading = false;
  bool _obscurePassword = true;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool get _isLoading => _isGoogleLoading || _isEmailLoading;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ModernBottomToast.show(
        context,
        message: 'Enter your admin email and password.',
        type: ModernToastType.error,
      );
      return;
    }

    setState(() => _isEmailLoading = true);
    try {
      await ref
          .read(authServiceProvider)
          .signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ModernBottomToast.show(
          context,
          message: msg,
          type: ModernToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isEmailLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ModernBottomToast.show(
          context,
          message: msg,
          type: ModernToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0F1E)
          : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // Decorative radial gradient background
          Positioned.fill(
            child: CustomPaint(painter: _BackgroundPainter(cs, isDark)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                                vertical: 48,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF111827).withOpacity(0.85)
                                    : Colors.white.withOpacity(0.92),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.07)
                                      : cs.outlineVariant.withOpacity(0.5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(
                                      isDark ? 0.4 : 0.08,
                                    ),
                                    blurRadius: 40,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Logo badge
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          cs.primary,
                                          cs.primary.withOpacity(0.6),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: cs.primary.withOpacity(0.35),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.admin_panel_settings_rounded,
                                      size: 36,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 28),

                                  // Title
                                  Text(
                                    'Admin Portal',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'ExpenseSplit Pro',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Access notice chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.errorContainer.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: cs.error.withOpacity(0.25),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.lock_outline_rounded,
                                          size: 13,
                                          color: cs.error,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Authorised admins only',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: cs.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 36),

                                  _AdminTextField(
                                    controller: _emailController,
                                    label: 'Admin email',
                                    icon: Icons.mail_outline_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    enabled: !_isLoading,
                                  ),
                                  const SizedBox(height: 14),
                                  _AdminTextField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    icon: Icons.lock_outline_rounded,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    enabled: !_isLoading,
                                    onSubmitted: (_) {
                                      if (!_isLoading) _signInWithEmail();
                                    },
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: _isLoading
                                          ? null
                                          : () => setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            ),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: FilledButton.icon(
                                      onPressed: _isLoading
                                          ? null
                                          : _signInWithEmail,
                                      icon: _isEmailLoading
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.login_rounded),
                                      label: const Text('Sign in with email'),
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: cs.outlineVariant.withOpacity(0.7),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        child: Text(
                                          'OR',
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: cs.outlineVariant.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),

                                  // Google Sign-In button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: _isGoogleLoading
                                        ? Center(
                                            child: SizedBox(
                                              width: 26,
                                              height: 26,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: cs.primary,
                                              ),
                                            ),
                                          )
                                        : _GoogleButton(
                                            onTap: _isLoading
                                                ? () {}
                                                : _signInWithGoogle,
                                          ),
                                  ),

                                  const SizedBox(height: 28),

                                  // Footer note
                                  Text(
                                    'Access is restricted to pre-registered admin\naccounts. Contact your system administrator\nif you need access.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant.withOpacity(0.6),
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ── About section (visible to public / OAuth reviewers) ──
                        const SizedBox(height: 32),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF111827).withOpacity(0.6)
                                    : Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.07)
                                      : cs.outlineVariant.withOpacity(0.4),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 16,
                                        color: cs.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'About ExpenseSplit Pro Admin Portal',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'This platform is an internal administrative dashboard used to manage expense tracking, review system OCR queues, monitor real-time audit logs, and maintain system compliance configuration.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ── Footer links (Privacy Policy & Terms) ──
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _FooterLink(
                              label: 'Privacy Policy',
                              url: '/privacy.html',
                              isDark: isDark,
                              cs: cs,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                '·',
                                style: TextStyle(
                                  color: cs.onSurfaceVariant.withOpacity(0.4),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            _FooterLink(
                              label: 'Terms of Service',
                              url: '/terms.html',
                              isDark: isDark,
                              cs: cs,
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
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
}

class _FooterLink extends StatefulWidget {
  final String label;
  final String url;
  final bool isDark;
  final ColorScheme cs;

  const _FooterLink({
    required this.label,
    required this.url,
    required this.isDark,
    required this.cs,
  });

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  void _open() {
    if (kIsWeb) {
      html.window.open(widget.url, '_blank');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _open,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _hovered
                ? widget.cs.primary
                : widget.cs.onSurfaceVariant.withOpacity(0.55),
            decoration: _hovered ? TextDecoration.underline : TextDecoration.none,
            decorationColor: widget.cs.primary,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class _AdminTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final bool enabled;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixIcon;

  const _AdminTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF0F172A),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? const Color(0xFF161D2E) : const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : const Color(0xFFDDE1E7),
            width: 1.4,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
      ),
    );
  }
}

/// Google sign-in button styled like the official Google design guidelines.
class _GoogleButton extends StatefulWidget {
  final VoidCallback onTap;
  const _GoogleButton({required this.onTap});

  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC))
              : (isDark ? const Color(0xFF161D2E) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(_hovered ? 0.18 : 0.1)
                : const Color(0xFFDDE1E7),
            width: 1.5,
          ),
          boxShadow: [
            if (_hovered)
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google 'G' logo rendered in SVG colours
                _GoogleLogo(),
                const SizedBox(width: 14),
                Text(
                  'Sign in with Google',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders the Google 'G' icon using the asset image.
class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/google_logo.png',
      width: 22,
      height: 22,
    );
  }
}

/// Subtle animated background gradient.
class _BackgroundPainter extends CustomPainter {
  final ColorScheme cs;
  final bool isDark;
  _BackgroundPainter(this.cs, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Top-left glow
    paint.shader =
        RadialGradient(
          colors: [
            cs.primary.withOpacity(isDark ? 0.18 : 0.10),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.15, size.height * 0.1),
            radius: size.width * 0.5,
          ),
        );
    canvas.drawRect(Offset.zero & size, paint);

    // Bottom-right glow
    paint.shader =
        RadialGradient(
          colors: [
            cs.tertiary.withOpacity(isDark ? 0.12 : 0.07),
            Colors.transparent,
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.9, size.height * 0.85),
            radius: size.width * 0.4,
          ),
        );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) => false;
}
