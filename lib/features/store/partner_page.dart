import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/payout_form.dart';
import '../../widgets/doodles.dart';
import 'store_shell.dart';

class VendorRegisterPage extends StatelessWidget {
  const VendorRegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    const pitch = _Pitch();
    final Widget form = auth.vendor != null ? _AlreadyApplied(vendor: auth.vendor!) : const _VendorForm();

    return StoreShell(
      appBar: const StoreTopBar(),
      showCartBar: false,
      body: SingleChildScrollView(
        child: Column(children: [
          Stack(children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration:
                    BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [HK.tint, HK.bg])),
              ),
            ),
            const Positioned.fill(child: Doodles(seed: 9, opacity: .09, spacing: 130)),
            Padding(
              padding: const EdgeInsets.only(top: 48, bottom: 80),
              child: MaxWidth(
                child: wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Expanded(child: pitch),
                        const SizedBox(width: 48),
                        SizedBox(width: 520, child: form),
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [pitch, const SizedBox(height: 36), form]),
              ),
            ),
          ]),
          const StoreFooter(),
        ]),
      ),
    );
  }
}

class _Pitch extends StatelessWidget {
  const _Pitch();

  @override
  Widget build(BuildContext context) {
    final m = isMobile(context);
    final perks = [
      (Icons.percent_rounded, 'Just 2% commission', 'The lowest platform fee around. You keep 98% of every order.'),
      (Icons.storefront_rounded, 'Free listing', 'No setup fee, no monthly charges. Go live once approved.'),
      (Icons.dashboard_customize_rounded, 'Your own dashboard', 'Manage menu, photos, prices and live orders yourself.'),
      (Icons.trending_up_rounded, 'More customers', 'Reach hungry customers ordering on HungryKya every day.'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Pill('Partner with HungryKya', color: HK.amberDeep, icon: Icons.handshake_rounded),
      const SizedBox(height: 18),
      Text.rich(
        TextSpan(style: AppTheme.display(m ? 36 : 54), children: [
          const TextSpan(text: 'Take your kitchen\n'),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: FireText('online', style: AppTheme.display(m ? 36 : 54)),
          ),
          const TextSpan(text: ' in minutes.'),
        ]),
      ).animate().fadeIn(duration: 500.ms).slideY(begin: .1),
      const SizedBox(height: 16),
      Text(
        'Cloud kitchens, home chefs and restaurants — register with your email, business name and location. '
        'Our team reviews every application and approves your profile so you can start selling.',
        style: AppTheme.body(16, color: HK.muted, height: 1.65),
      ),
      const SizedBox(height: 30),
      LayoutBuilder(builder: (c, cons) {
        final cols = cons.maxWidth < 520 ? 1 : 2;
        final w = (cons.maxWidth - (cols - 1) * 14) / cols;
        return Wrap(spacing: 14, runSpacing: 14, children: [
          for (final (i, (icon, t, d)) in perks.indexed)
            SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: HK.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: HK.line)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: HK.amber.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: HK.amberDeep),
                  ),
                  const SizedBox(height: 14),
                  Text(t, style: AppTheme.body(16, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(d, style: AppTheme.body(13.5, color: HK.muted, height: 1.5)),
                ]),
              ).animate().fadeIn(delay: (100 * i).ms).slideY(begin: .15),
            ),
        ]);
      }),
      const SizedBox(height: 30),
      Text('How it works', style: AppTheme.body(16, weight: FontWeight.w800)),
      const SizedBox(height: 14),
      for (final (i, step) in [
        'Fill the form & accept the 2% commission terms',
        'HungryKya admin reviews and approves your kitchen',
        'Add your menu & photos from your vendor dashboard',
        'Receive orders — daily payouts to your bank / UPI after 2% commission',
      ].indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(gradient: HK.fire, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('${i + 1}', style: AppTheme.body(13, color: Colors.black, weight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(step, style: AppTheme.body(14.5))),
          ]),
        ),
    ]);
  }
}

class _VendorForm extends StatefulWidget {
  const _VendorForm();
  @override
  State<_VendorForm> createState() => _VendorFormState();
}

class _VendorFormState extends State<_VendorForm> {
  final _form = GlobalKey<FormState>();
  final _business = TextEditingController();
  final _owner = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  final _cuisine = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _pincode = TextEditingController();
  final _fssai = TextEditingController();
  final _payout = PayoutFormController();
  bool _consent = false;
  bool _accurate = false;
  bool _busy = false;
  bool _done = false;
  bool _showConsentError = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_business, _owner, _email, _phone, _pw, _pw2, _cuisine, _address, _city, _pincode, _fssai]) {
      c.dispose();
    }
    _payout.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    setState(() => _showConsentError = !_consent || !_accurate);
    if (!valid || !_consent || !_accurate) return;
    final auth = context.read<AuthService>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.registerVendor(
        businessName: _business.text,
        ownerName: _owner.text,
        email: _email.text,
        phone: normalizePhone(_phone.text),
        password: _pw.text,
        address: _address.text,
        city: _city.text,
        pincode: _pincode.text,
        cuisine: _cuisine.text,
        fssai: _fssai.text,
        payout: _payout.value,
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const _Submitted();

    Widget gap() => const SizedBox(height: 14);
    Widget pair(Widget a, Widget b) => isMobile(context)
        ? Column(children: [a, gap(), b])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]);

    return Container(
      padding: EdgeInsets.all(isMobile(context) ? 22 : 32),
      decoration: BoxDecoration(
        color: HK.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: HK.line),
        boxShadow: HK.shadow(1.4),
      ),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Register as vendor', style: AppTheme.display(30)),
          const SizedBox(height: 6),
          Text('Takes about 2 minutes.', style: AppTheme.body(14, color: HK.muted)),
          const SizedBox(height: 24),
          _label('Business'),
          TextFormField(
            controller: _business,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Business / kitchen name', prefixIcon: Icon(Icons.storefront_outlined)),
            validator: (v) => validateRequired(v, 'Business name'),
          ),
          gap(),
          pair(
            TextFormField(
              controller: _owner,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Owner name'),
              validator: (v) => validateRequired(v, 'Owner name'),
            ),
            TextFormField(
              controller: _cuisine,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Cuisine', hintText: 'North Indian, Chinese…'),
              validator: (v) => validateRequired(v, 'Cuisine'),
            ),
          ),
          gap(),
          TextFormField(
            controller: _fssai,
            decoration: const InputDecoration(labelText: 'FSSAI licence no. (optional)', prefixIcon: Icon(Icons.verified_outlined)),
          ),
          const SizedBox(height: 22),
          _label('Contact & login'),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email (your vendor login)', prefixIcon: Icon(Icons.mail_outline_rounded)),
            validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid email',
          ),
          gap(),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91  ', prefixIcon: Icon(Icons.phone_outlined)),
            validator: validatePhone,
          ),
          gap(),
          pair(
            TextFormField(
              controller: _pw,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: 'Create password', prefixIcon: Icon(Icons.lock_outline_rounded)),
              validator: (v) => (v ?? '').length < 6 ? 'At least 6 characters' : null,
            ),
            TextFormField(
              controller: _pw2,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm password'),
              validator: (v) => v != _pw.text ? 'Passwords do not match' : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Use this email and password to log in to your vendor dashboard after approval.',
                style: AppTheme.body(12.5, color: HK.muted)),
          ),
          const SizedBox(height: 22),
          _label('Kitchen location'),
          TextFormField(
            controller: _address,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Full address', prefixIcon: Icon(Icons.location_on_outlined)),
            validator: (v) => (v ?? '').trim().length < 8 ? 'Please enter the full address' : null,
          ),
          gap(),
          pair(
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'City'),
              validator: (v) => validateRequired(v, 'City'),
            ),
            TextFormField(
              controller: _pincode,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Pincode'),
              validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim()) ? null : 'Enter a 6-digit pincode',
            ),
          ),
          const SizedBox(height: 22),
          _label('Payout details'),
          Text('HungryKya pays your earnings (after 2% commission) to this account at the end of each day.',
              style: AppTheme.body(13, color: HK.muted, height: 1.5)),
          const SizedBox(height: 12),
          PayoutFields(controller: _payout),
          const SizedBox(height: 24),

          // ---- Commission consent ----
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: HK.amber.withOpacity(.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _showConsentError && !_consent ? HK.nonVeg : HK.amber.withOpacity(.45), width: 1.4),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.handshake_rounded, color: HK.amberDeep),
                const SizedBox(width: 10),
                Text('Commission agreement', style: AppTheme.body(16, weight: FontWeight.w800)),
                const Spacer(),
                const Pill('2%', color: HK.amberDeep, solid: false),
              ]),
              const SizedBox(height: 12),
              Text(AppConfig.commissionConsentText, style: AppTheme.body(13.5, color: HK.ink.withOpacity(.85), height: 1.6)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: HK.cardHi, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.calculate_outlined, color: HK.amberDeep, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Example: on a ₹500 order, HungryKya keeps ₹10 and you receive ₹490.',
                        style: AppTheme.body(13, weight: FontWeight.w600)),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              _Check(
                value: _consent,
                onChanged: (v) => setState(() => _consent = v),
                label: 'I have read and agree to pay HungryKya a 2% commission on every order.',
              ),
              _Check(
                value: _accurate,
                onChanged: (v) => setState(() => _accurate = v),
                label: 'The details above are correct and my kitchen follows food-safety (FSSAI) norms.',
              ),
              if (_showConsentError && (!_consent || !_accurate))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Please accept both to continue.', style: AppTheme.body(12.5, color: HK.nonVeg, weight: FontWeight.w600)),
                ),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: AppTheme.body(13.5, color: HK.nonVeg, weight: FontWeight.w600)),
          ],
          const SizedBox(height: 22),
          SizedBox(
            height: 58,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const BtnSpinner() : const Text('Submit application'),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton(onPressed: () => context.go('/vendor'), child: const Text('Already registered? Vendor login')),
          ),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t.toUpperCase(), style: AppTheme.body(11.5, color: HK.amberDeep, weight: FontWeight.w800).copyWith(letterSpacing: 2)),
      );
}

class _Check extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  const _Check({required this.value, required this.onChanged, required this.label});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            const SizedBox(width: 4),
            Expanded(
                child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(label, style: AppTheme.body(13.5, weight: FontWeight.w600)))),
          ]),
        ),
      );
}

class _Submitted extends StatelessWidget {
  const _Submitted();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(color: HK.card, borderRadius: BorderRadius.circular(28), border: Border.all(color: HK.amber.withOpacity(.4))),
        child: Column(children: [
          const Text('🎉', style: TextStyle(fontSize: 72)).animate().scaleXY(begin: .3, duration: 800.ms, curve: Curves.elasticOut),
          const SizedBox(height: 16),
          Text('Application submitted!', style: AppTheme.display(30), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            'Thank you for choosing HungryKya. Our team will review your kitchen details. '
            'Once approved, you can add your menu and start receiving orders from your vendor dashboard.',
            style: AppTheme.body(14.5, color: HK.muted, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(onPressed: () => context.go('/vendor'), child: const Text('Open vendor dashboard')),
          ),
        ]),
      );
}

class _AlreadyApplied extends StatelessWidget {
  final Vendor vendor;
  const _AlreadyApplied({required this.vendor});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: HK.card, borderRadius: BorderRadius.circular(28), border: Border.all(color: HK.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(vendor.businessName, style: AppTheme.display(28)),
          const SizedBox(height: 10),
          Pill(VendorStatus.label(vendor.status), color: vendor.isApproved ? HK.veg : HK.amberDeep),
          const SizedBox(height: 16),
          Text('You have already registered this account as a vendor.', style: AppTheme.body(14.5, color: HK.muted)),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(onPressed: () => context.go('/vendor'), child: const Text('Open vendor dashboard')),
          ),
        ]),
      );
}
