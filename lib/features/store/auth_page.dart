import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_form.dart';
import '../../widgets/common.dart';
import '../../widgets/doodles.dart';

class CustomerAuthPage extends StatelessWidget {
  final String? next;
  const CustomerAuthPage({super.key, this.next});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final target = (next == null || next!.isEmpty) ? '/' : next!;

    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(onTap: () => context.go('/'), child: const BrandLogo(size: 46)),
            ),
            const SizedBox(height: 36),
            if (auth.signedIn)
              _AlreadyIn(name: auth.displayName, onContinue: () => context.go(target))
            else
              AuthForm(onDone: () => context.go('/welcome?next=${Uri.encodeComponent(target)}')),
          ]),
        ),
      ),
    );

    return Scaffold(
      body: wide
          ? Row(children: [
              const Expanded(child: _AuthVisual()),
              Expanded(child: form),
            ])
          : form,
    );
  }
}

class _AlreadyIn extends StatelessWidget {
  final String name;
  final VoidCallback onContinue;
  const _AlreadyIn({required this.name, required this.onContinue});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Hi ${name.split(' ').first} 👋', style: AppTheme.display(32)),
        const SizedBox(height: 8),
        Text('You are already logged in.', style: AppTheme.body(15, color: HK.muted)),
        const SizedBox(height: 24),
        SizedBox(height: 54, child: ElevatedButton(onPressed: onContinue, child: const Text('Continue'))),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.read<AuthService>().signOut(), child: const Text('Log in with another account')),
      ]);
}

class _AuthVisual extends StatelessWidget {
  const _AuthVisual();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const RadialGradient(center: Alignment(.3, -.3), radius: 1.2, colors: [Color(0xFFFFE3B8), HK.tint]),
        border: Border.all(color: HK.line),
      ),
      child: Stack(children: [
        const Positioned.fill(child: Doodles(seed: 5, opacity: .12, spacing: 110)),
        for (final (i, (e, x, y)) in [('🍕', .15, .18), ('🍛', .78, .14), ('🍔', .1, .74), ('🥤', .88, .84), ('🍜', .5, .93), ('🥟', .88, .4)].indexed)
          Align(
            alignment: Alignment(x * 2 - 1, y * 2 - 1),
            child: Text(e, style: const TextStyle(fontSize: 44))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: -10, end: 10, duration: (2000 + i * 300).ms, curve: Curves.easeInOut),
          ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: HK.amber.withOpacity(.35), blurRadius: 80)]),
                child: ClipOval(child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover)),
              ).animate().scaleXY(begin: .8, duration: 800.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 32),
              Text('Bhook lagi?', style: AppTheme.script(40)),
              const SizedBox(height: 8),
              Text('Log in and get it delivered hot.', style: AppTheme.display(30), textAlign: TextAlign.center),
            ]),
          ),
        ),
      ]),
    );
  }
}
