import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key, this.email});
  final String? email;

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool _sending = false;
  String? _message;

  Future<void> _resend() async {
    final email = widget.email;
    if (email == null || email.isEmpty) {
      setState(() => _message = 'Email not provided. Go back and enter your email.');
      return;
    }
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      await Supabase.instance.client.auth.resend(type: OtpType.signup, email: email);
      setState(() => _message = 'Verification email sent to $email');
    } catch (e) {
      setState(() => _message = e.toString().replaceAll('AuthException: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Text(
              'We\'ve sent a verification link to your email. Please open it to activate your account.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (email != null)
              Text(
                email,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _sending ? null : _resend,
              child: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Resend verification email'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Back to Login'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


