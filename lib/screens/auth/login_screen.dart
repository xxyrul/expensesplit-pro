import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import '../../theme/brand_theme.dart';
import '../../widgets/modern_bottom_toast.dart';
import 'register_screen.dart';
import '../welcome_page.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController emailResetController =
        TextEditingController(text: _emailController.text.trim());
    final colorScheme = Theme.of(context).colorScheme;
    String? dialogError;
    bool dialogLoading = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text(
                "Reset Password",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Enter your email address to receive a password reset link.",
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailResetController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email Address",
                      prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                    ),
                  ),
                  if (dialogError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: dialogLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: dialogLoading
                      ? null
                      : () async {
                          final email = emailResetController.text.trim();
                          if (email.isEmpty) {
                            setState(() => dialogError = "Please enter your email");
                            return;
                          }
                          setState(() {
                            dialogLoading = true;
                            dialogError = null;
                          });
                          try {
                            await ref.read(authServiceProvider).sendPasswordReset(email);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text("Password reset email sent to $email"),
                                  backgroundColor: const Color(0xFF0D9488),
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() {
                              dialogLoading = false;
                              dialogError = e.toString();
                            });
                          }
                        },
                  child: dialogLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Send Link"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = "Please fill in all fields");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authServiceProvider)
          .signIn(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );

      if (mounted) {
        // Show success toast
        ModernBottomToast.show(
          context,
          message: 'Login Successful!',
          type: ModernToastType.success,
        );
        
        // Navigate to WelcomePage
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const WelcomePage(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String userFriendlyMessage = _mapFirebaseErrorToUserMessage(e.code, e.message);
      setState(() => _errorMessage = userFriendlyMessage);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapFirebaseErrorToUserMessage(String code, String? message) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'account-exists-with-different-credential':
        return 'This email is linked to another login method. Please sign in with Google.';
      case 'operation-not-allowed':
        return 'Email/password login is currently disabled. Please try Google Sign-In.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check and try again.';
      default:
        return message ?? 'Login failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. GRADIENT HEADER
            _buildHeader(),

            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                children: [
                  // 2. LOGIN FORM CARD
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? colorScheme.surfaceContainer : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isDark
                            ? colorScheme.outlineVariant.withOpacity(0.5)
                            : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _emailController,
                          label: "Email Address",
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),
                        _buildPasswordField(),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(50, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),

                  // 3. SIGN IN BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _signIn,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Sign In",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 4. OR DIVIDER
                  Row(
                    children: [
                      Expanded(child: Divider(color: colorScheme.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Text(
                          "OR",
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: colorScheme.outlineVariant)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 5. GOOGLE SIGN IN
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : () async {
                        setState(() => _isLoading = true);
                        try {
                          await ref.read(authServiceProvider).signInWithGoogle();
                          if (mounted) {
                            // Show success toast
                            ModernBottomToast.show(
                              context,
                              message: 'Login Successful!',
                              type: ModernToastType.success,
                            );
                            
                            // Navigate to WelcomePage
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const WelcomePage(),
                              ),
                            );
                          }
                        } on FirebaseAuthException catch (e) {
                          String userFriendlyMessage = _mapFirebaseErrorToUserMessage(e.code, e.message);
                          setState(() => _errorMessage = userFriendlyMessage);
                        } catch (e) {
                          setState(() => _errorMessage = e.toString());
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      icon: Image.asset('assets/google_logo.png', height: 24),
                      label: const Text(
                        "Continue with Google",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                    const SizedBox(height: 20),

                    // Helpful troubleshooting link when Google Sign-In reports OAuth/SHA errors
                    if (_errorMessage != null && (_errorMessage!.contains('Google Sign-In failed') || _errorMessage!.toLowerCase().contains('sha') || _errorMessage!.toLowerCase().contains('oauth') || _errorMessage!.contains('10')))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _showGoogleTroubleshootDialog,
                          icon: const Icon(Icons.help_outline),
                          label: const Text('Troubleshoot Google Sign-In'),
                        ),
                      ),

                  // 6. REGISTER LINK
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                        children: [
                          TextSpan(
                            text: "Register",
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        labelText: "Password",
        prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: colorScheme.primary,
            size: 20,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
      ),
    );
  }

  Future<void> _showGoogleTroubleshootDialog() async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Google Sign-In Troubleshooting'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Common causes:'),
                const SizedBox(height: 8),
                const Text('• Missing SHA-1 / SHA-256 fingerprints in Firebase for Android.'),
                const Text('• OAuth client not configured (Web vs Android client IDs).'),
                const SizedBox(height: 12),
                const Text('Recommended steps:'),
                const SizedBox(height: 8),
                const Text('1. Run the following to get your debug keystore fingerprints on Windows:'),
                const SizedBox(height: 6),
                SelectableText('keytool -list -v -keystore %USERPROFILE%\\.android\\debug.keystore -alias androiddebugkey -storepass android -keypass android'),
                const SizedBox(height: 8),
                const Text('2. Add SHA-1 and SHA-256 to Firebase Console → Project Settings → Your apps.'),
                const SizedBox(height: 8),
                const Text('3. Download the updated google-services.json and replace android/app/google-services.json.'),
                const SizedBox(height: 8),
                const Text('4. Rebuild the app and try signing in again.'),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 26,
        bottom: 40,
        left: 30,
        right: 30,
      ),
      decoration: BoxDecoration(
        gradient: context.brandHeaderGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.account_balance_wallet, color: Colors.white, size: 50),
          SizedBox(height: 20),
          Text(
            "Welcome Back!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "Sign in to continue tracking your expenses",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: colorScheme.primary, size: 20),
      ),
    );
  }
}
