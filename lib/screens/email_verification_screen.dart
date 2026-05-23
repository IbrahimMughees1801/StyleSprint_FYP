import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';
import '../theme/app_theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  final VoidCallback onVerified;
  final VoidCallback onBackToSignIn;

  const EmailVerificationScreen({
    super.key,
    required this.onVerified,
    required this.onBackToSignIn,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _authService = FirebaseAuthService();
  bool _isChecking = false;
  bool _isResending = false;

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    try {
      final verified = await _authService.reloadAndCheckEmailVerified();
      if (!mounted) return;

      if (verified) {
        widget.onVerified();
      } else {
        _showSnackBar('Email is not verified yet.', AppTheme.orange600);
      }
    } catch (e) {
      if (mounted) _showSnackBar(e.toString(), AppTheme.red600);
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _isResending = true);
    try {
      await _authService.sendEmailVerification();
      if (mounted) {
        _showSnackBar('Verification email sent again.', AppTheme.green600);
      }
    } catch (e) {
      if (mounted) _showSnackBar(e.toString(), AppTheme.red600);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _backToSignIn() async {
    await _authService.signOut();
    if (mounted) widget.onBackToSignIn();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final email = user?.email ?? 'your email';
    final isBusy = _isChecking || _isResending;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.atelierDarkGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppTheme.atelierMidnight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Verify your email',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: AppTheme.gray900,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We sent a verification link to $email. Open that email, verify your account, then return here.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(height: 1.45),
                      ),
                      const SizedBox(height: 24),
                      _GradientButton(
                        isLoading: _isChecking,
                        label: 'I verified my email',
                        icon: Icons.verified_user_outlined,
                        onPressed: isBusy ? null : _checkVerification,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: isBusy ? null : _resendVerification,
                        icon: _isResending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(
                          _isResending ? 'Sending...' : 'Resend email',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isBusy ? null : _backToSignIn,
                        child: const Text('Back to sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _GradientButton({
    required this.isLoading,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: onPressed == null ? AppTheme.gray300 : AppTheme.atelierMidnight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(icon, color: Colors.white),
        label: Text(
          isLoading ? 'Checking...' : label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
