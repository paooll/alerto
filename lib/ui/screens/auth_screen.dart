import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../theme.dart';
import '../widgets/glass_container.dart';

/// Login / Register / Password-reset screen.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    final auth = ref.read(authServiceProvider);
    try {
      if (_isRegister) {
        await auth.register(_email.text.trim(), _password.text);
      } else {
        await auth.signIn(_email.text.trim(), _password.text);
      }
    } on Exception catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'Enter your email first.');
      return;
    }
    try {
      await ref.read(authServiceProvider).sendPasswordReset(_email.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on Exception catch (e) {
      setState(() => _error = _friendly(e));
    }
  }

  String _friendly(Exception e) {
    final msg = e.toString();
    if (msg.contains('invalid-credential') || msg.contains('wrong-password')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email-already-in-use')) return 'That email is already registered.';
    if (msg.contains('weak-password')) return 'Password must be at least 6 characters.';
    if (msg.contains('invalid-email')) return 'That email address looks invalid.';
    return 'Authentication failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Soft ambient background shapes (subtle, not slop).
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withOpacity(
                    theme.brightness == Brightness.dark ? 0.07 : 0.10),
              ),
            ),
          ),
          Positioned(
            bottom: -60, left: -70,
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.purple.withOpacity(
                    theme.brightness == Brightness.dark ? 0.06 : 0.08),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GlassContainer(
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(Icons.trending_up, size: 52,
                                color: AppColors.gold),
                            const SizedBox(height: 12),
                            Text('Alerto',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineMedium),
                            const SizedBox(height: 6),
                            Text('Forex · Gold · CFD price alerts',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: theme.textDim)),
                            const SizedBox(height: 30),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration:
                                  const InputDecoration(labelText: 'Email'),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Enter a valid email'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _password,
                              obscureText: true,
                              autofillHints: const [AutofillHints.password],
                              decoration: const InputDecoration(
                                  labelText: 'Password'),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'At least 6 characters'
                                  : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(_error!,
                                  style: const TextStyle(color: AppColors.red)),
                            ],
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : Text(_isRegister
                                      ? 'Create account'
                                      : 'Sign in'),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                        _isRegister = !_isRegister;
                                        _error = null;
                                      }),
                              child: Text(_isRegister
                                  ? 'Already have an account? Sign in'
                                  : 'New here? Create an account'),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _resetPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ],
                        ),
                      ),
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
