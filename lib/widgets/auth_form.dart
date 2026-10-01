import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../core/format.dart';
import '../services/auth_service.dart';
import 'common.dart';

/// Email/password (+ optional Google) login & signup. Adapts to the
/// surrounding theme so it works in the dark store and the light panels.
class AuthForm extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool allowSignup;
  final bool showGoogle;
  final VoidCallback? onDone;
  final String emailLabel;
  const AuthForm({
    super.key,
    this.title = 'Welcome back',
    this.subtitle = 'Log in to order, track and reorder your favourites.',
    this.allowSignup = true,
    this.showGoogle = true,
    this.onDone,
    this.emailLabel = 'Email',
  });

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pw = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _pw]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
      widget.onDone?.call();
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    _run(() =>
        _signup ? auth.signUp(name: _name.text, email: _email.text, phone: _phone.text, password: _pw.text) : auth.signIn(_email.text, _pw.text));
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter your email above, then tap "Forgot password".');
      return;
    }
    try {
      await context.read<AuthService>().resetPassword(email);
      if (mounted) showToast(context, 'Password reset link sent to $email');
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).brightness == Brightness.dark ? HK.muted : PK.muted;
    final line = Theme.of(context).dividerColor;
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(_signup ? 'Create your account' : widget.title, style: AppTheme.display(32, color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text(_signup ? 'Sign up in seconds — your next meal is waiting.' : widget.subtitle, style: AppTheme.body(14.5, color: muted, height: 1.5)),
          const SizedBox(height: 28),
          if (_signup) ...[
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded)),
              validator: (v) => (v ?? '').trim().length < 2 ? 'Please enter your name' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_outlined)),
              validator: validatePhone,
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(labelText: _signup ? 'Email' : widget.emailLabel, prefixIcon: const Icon(Icons.mail_outline_rounded)),
            // Login also accepts short ids like admin@123 (see AppConfig.normalizeLoginId).
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'Enter your email or Admin ID';
              if (!_signup && (s.toLowerCase() == 'admin' || s.toLowerCase() == 'admin@123')) return null;
              return RegExp(_signup ? r'^[^@\s]+@[^@\s]+\.[^@\s]+$' : r'^[^@\s]+(@[^@\s]+)?$').hasMatch(s)
                  ? null
                  : 'Enter a valid email or ID';
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _pw,
            obscureText: _hide,
            autofillHints: [_signup ? AutofillHints.newPassword : AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _hide = !_hide),
                icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
            validator: (v) => (v ?? '').length < 6 ? 'At least 6 characters' : null,
          ),
          if (!_signup)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _forgot, child: const Text('Forgot password?')),
            )
          else
            const SizedBox(height: 18),
          if (!_signup && widget.emailLabel.toLowerCase().contains('admin')) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFD56B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_rounded, size: 20, color: Color(0xFFB86E00)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin Credentials', style: AppTheme.body(12.5, color: const Color(0xFF5E3F00), weight: FontWeight.w800)),
                        Text('admin@123  ·  Pass: 123456', style: AppTheme.body(11.5, color: const Color(0xFF8A5B00))),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB321),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    onPressed: _busy
                        ? null
                        : () {
                            _email.text = 'admin@123';
                            _pw.text = '123456';
                            _submit();
                          },
                    icon: const Icon(Icons.bolt_rounded, size: 16),
                    label: const Text('1-Click Login'),
                  ),
                ],
              ),
            ),
          ],
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: HK.nonVeg.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: HK.nonVeg, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!, style: AppTheme.body(13.5, color: HK.nonVeg, weight: FontWeight.w600))),
              ]),
            ),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const BtnSpinner() : Text(_signup ? 'Create account' : 'Log in'),
            ),
          ),
          if (widget.showGoogle) ...[
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Divider(color: line)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: AppTheme.body(13, color: muted))),
              Expanded(child: Divider(color: line)),
            ]),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: _busy ? null : () => _run(() => context.read<AuthService>().signInWithGoogle()),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Text('G', style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                  const SizedBox(width: 12),
                  const Text('Continue with Google'),
                ]),
              ),
            ),
          ],
          if (widget.allowSignup) ...[
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_signup ? 'Already have an account?' : 'New to HungryKya?', style: AppTheme.body(14, color: muted)),
              TextButton(
                onPressed: () => setState(() {
                  _signup = !_signup;
                  _error = null;
                }),
                child: Text(_signup ? 'Log in' : 'Create account'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Shows a login prompt instead of [child] when nobody is signed in.
class RequireLogin extends StatelessWidget {
  final Widget child;
  final String next;
  final String message;
  const RequireLogin({super.key, required this.child, required this.next, this.message = 'Please log in to continue.'});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.ready) return const Center(child: CircularProgressIndicator());
    if (auth.signedIn) return child;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(color: HK.card, borderRadius: BorderRadius.circular(28), border: Border.all(color: HK.line)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔐', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 14),
            Text('Login required', style: AppTheme.display(28)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: AppTheme.body(14.5, color: HK.muted)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => context.go('/login?next=${Uri.encodeComponent(next)}'),
                child: const Text('Log in / Sign up'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
