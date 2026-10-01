import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../services/store_data.dart';
import '../../widgets/auth_form.dart';
import '../../widgets/common.dart';
import 'store_shell.dart';

/// UPI intent link. `pa` is left unencoded: UPI ids only use [a-z0-9.-_@] and
/// some apps fail to decode `%40`.
String upiLink(StoreSettings s, OrderModel o, {String base = 'upi://pay'}) => '$base?pa=${s.upiId}&pn=${Uri.encodeComponent(s.payeeName)}'
    '&am=${o.total.toStringAsFixed(2)}&cu=INR&tn=${Uri.encodeComponent('HungryKya order ${o.orderNo}')}';

bool get _onPhone => kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

class PaymentPage extends StatelessWidget {
  final String orderId;
  const PaymentPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return StoreShell(
      appBar: const StoreTopBar(),
      showCartBar: false,
      body: RequireLogin(
        next: '/pay/$orderId',
        child: StreamBuilder<OrderModel?>(
          stream: Db.order(orderId),
          builder: (c, snap) {
            if (snap.hasError) return _Message('😕', 'Could not load this order', authErrorText(snap.error!));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final o = snap.data;
            if (o == null) return const _Message('🔍', 'Order not found', 'This order does not exist.');
            if (o.paymentStatus == PayStatus.paid) {
              return _Done(
                emoji: '✅',
                title: 'Payment received!',
                body: 'Thank you! Your payment of ${rupees(o.total)} is confirmed and the kitchen is on it.',
                orderId: o.id,
              );
            }
            if (o.paymentStatus == PayStatus.verification) {
              return _Done(
                emoji: '⏳',
                title: 'Verifying your payment',
                body: 'We received your UPI reference ${o.upiRef}. Our team will match it with the payment shortly — '
                    'your order is already with the kitchen. You can track it live.',
                orderId: o.id,
              );
            }
            if (!o.isUpi || o.status == OrderStatus.cancelled) {
              return _Done(
                emoji: o.status == OrderStatus.cancelled ? '❌' : '💵',
                title: o.status == OrderStatus.cancelled ? 'Order cancelled' : 'Cash on delivery',
                body: o.status == OrderStatus.cancelled
                    ? 'This order was cancelled, so no payment is needed.'
                    : 'Please keep ${rupees(o.total)} ready when your food arrives.',
                orderId: o.id,
              );
            }
            return _PayView(order: o);
          },
        ),
      ),
    );
  }
}

class _PayView extends StatefulWidget {
  final OrderModel order;
  const _PayView({required this.order});
  @override
  State<_PayView> createState() => _PayViewState();
}

class _PayViewState extends State<_PayView> {
  final _utr = TextEditingController();
  final _utrKey = GlobalKey<FormState>();
  late final DateTime _deadline;
  Timer? _tick;
  bool _submitting = false;
  bool _showScanner = false;
  bool _showQrOnPhone = false;

  @override
  void initState() {
    super.initState();
    _deadline = (widget.order.createdAt ?? DateTime.now()).add(const Duration(minutes: 10));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _utr.dispose();
    super.dispose();
  }

  Future<void> _open(String link) async {
    try {
      final ok = await launchUrl(Uri.parse(link), webOnlyWindowName: '_self');
      if (!ok && mounted) showToast(context, 'No UPI app found. Please scan the QR code instead.', error: true);
    } catch (_) {
      if (mounted) showToast(context, 'Could not open a UPI app. Please scan the QR code instead.', error: true);
    }
  }

  Future<void> _submitUtr() async {
    if (!_utrKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await Db.submitUpiRef(widget.order.id, _utr.text.trim());
    } catch (e) {
      if (mounted) showToast(context, authErrorText(e), error: true);
    }
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _switchCod() async {
    final ok = await confirmDialog(
      context,
      title: 'Pay by cash instead?',
      message: 'Your order will be switched to Cash on Delivery. Please keep ${rupees(widget.order.total)} ready.',
      confirm: 'Switch to COD',
    );
    if (!ok) return;
    try {
      await Db.switchToCod(widget.order.id);
      if (mounted) context.go('/orders/${widget.order.id}?placed=1');
    } catch (e) {
      if (mounted) showToast(context, authErrorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final s = context.watch<StoreData>().settings;
    final left = _deadline.difference(DateTime.now());
    final mm = left.isNegative ? '00' : left.inMinutes.toString().padLeft(2, '0');
    final ss = left.isNegative ? '00' : (left.inSeconds % 60).toString().padLeft(2, '0');
    final link = upiLink(s, o);

    final qr = Container(
      padding: const EdgeInsets.all(18),
      decoration:
          BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: HK.line), boxShadow: HK.shadow()),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _showScanner
              ? ClipRRect(
                  key: const ValueKey('static'),
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/images/upi_qr.jpg', width: 240, height: 240, fit: BoxFit.contain),
                )
              : QrImageView(
                  key: const ValueKey('dynamic'),
                  data: link,
                  size: 240,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                  embeddedImage: const AssetImage('assets/images/logo.jpg'),
                  embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(46, 46)),
                ),
        ),
        const SizedBox(height: 10),
        Text(
          _showScanner ? 'Enter ${rupees(o.total)} manually after scanning' : 'Amount ${rupees(o.total)} is filled automatically',
          style: AppTheme.body(13, color: Colors.black87, weight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final a in ['GPay', 'PhonePe', 'Paytm', 'BHIM'])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(a, style: AppTheme.body(11, color: Colors.black45, weight: FontWeight.w700)),
            ),
        ]),
      ]),
    );

    final qrBlock = Column(children: [
      qr,
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => setState(() => _showScanner = !_showScanner),
        child: Text(_showScanner ? 'Show QR with amount' : 'QR not working? Use the HungryKya scanner'),
      ),
    ]);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: MaxWidth(
        max: 620,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ---- Amount header ----
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(colors: [Color(0xFFFFEBCB), Colors.white], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: HK.shadow(),
              border: Border.all(color: HK.amber.withOpacity(.35)),
            ),
            child: Column(children: [
              const Pill('Order placed · awaiting payment', color: HK.amberDeep, icon: Icons.check_circle_rounded),
              const SizedBox(height: 18),
              Text('Pay to ${s.payeeName}', style: AppTheme.body(15, color: HK.muted, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              FireText(rupees(o.total), style: AppTheme.display(60)).animate().scaleXY(begin: .8, curve: Curves.easeOutBack, duration: 600.ms),
              const SizedBox(height: 6),
              Text('Order #${o.orderNo} · ${o.itemCount} item${o.itemCount == 1 ? '' : 's'}', style: AppTheme.body(13.5, color: HK.muted)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.timer_outlined, size: 18, color: HK.amberDeep),
                const SizedBox(width: 6),
                Text(left.isNegative ? 'Please complete your payment' : 'Complete payment in $mm:$ss',
                    style: AppTheme.body(14, color: HK.amberDeep, weight: FontWeight.w700)),
              ]),
            ]),
          ),
          const SizedBox(height: 22),

          // ---- Step 1: pay ----
          _Step(
            n: 1,
            title: 'Pay with any UPI app',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_onPhone) ...[
                SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () => _open(link),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.bolt_rounded),
                      const SizedBox(width: 8),
                      Text('Pay ${rupees(o.total)} with UPI app'),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  _AppBtn('GPay', const Color(0xFF4285F4), () => _open(upiLink(s, o, base: 'tez://upi/pay'))),
                  _AppBtn('PhonePe', const Color(0xFF6739B7), () => _open(upiLink(s, o, base: 'phonepe://pay'))),
                  _AppBtn('Paytm', const Color(0xFF00BAF2), () => _open(upiLink(s, o, base: 'paytmmp://pay'))),
                  _AppBtn('Other', HK.amberDeep, () => _open(link)),
                ]),
                const SizedBox(height: 10),
                Text('UPI ID and amount are filled in for you — just enter your UPI PIN.',
                    textAlign: TextAlign.center, style: AppTheme.body(12.5, color: HK.muted)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _showQrOnPhone = !_showQrOnPhone),
                  child: Text(_showQrOnPhone ? 'Hide QR code' : 'Paying from another phone? Show QR'),
                ),
                if (_showQrOnPhone) Center(child: qrBlock),
              ] else ...[
                Text('Open any UPI app on your phone and scan this code.', style: AppTheme.body(14, color: HK.muted)),
                const SizedBox(height: 18),
                Center(child: qrBlock),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: HK.cardHi, borderRadius: BorderRadius.circular(14), border: Border.all(color: HK.line)),
                child: Row(children: [
                  const Icon(Icons.account_balance_rounded, color: HK.amberDeep, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('UPI ID', style: AppTheme.body(12, color: HK.muted)),
                      Text(s.upiId, style: AppTheme.body(15.5, weight: FontWeight.w800)),
                    ]),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: s.upiId));
                      showToast(context, 'UPI ID copied');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 18),

          // ---- Step 2: confirm ----
          _Step(
            n: 2,
            title: 'Confirm your payment',
            child: Form(
              key: _utrKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('After paying, enter the 12-digit UPI reference / UTR number shown in your UPI app.',
                    style: AppTheme.body(14, color: HK.muted, height: 1.5)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _utr,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'UPI reference no. (UTR)',
                    hintText: 'e.g. 412345678901',
                    prefixIcon: Icon(Icons.tag_rounded),
                  ),
                  validator: (v) => RegExp(r'^[A-Za-z0-9]{8,30}$').hasMatch((v ?? '').trim()) ? null : 'Enter the reference number from your UPI app',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitUtr,
                    child: _submitting ? const BtnSpinner() : const Text("I've paid — confirm"),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
              TextButton(onPressed: _switchCod, child: const Text('Pay cash on delivery instead')),
              Text('·', style: AppTheme.body(14, color: HK.muted)),
              TextButton(onPressed: () => context.go('/orders/${o.id}'), child: const Text('Track order')),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String title;
  final Widget child;
  const _Step({required this.n, required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration:
            BoxDecoration(color: HK.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: HK.line), boxShadow: HK.shadow(.8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(gradient: HK.fire, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text('$n', style: AppTheme.body(14, color: Colors.black, weight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            Text(title, style: AppTheme.body(18, weight: FontWeight.w800)),
          ]),
          const SizedBox(height: 16),
          child,
        ]),
      );
}

class _AppBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AppBtn(this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: color.withOpacity(.6)),
            ),
            child: Text(label, style: AppTheme.body(13, color: HK.ink, weight: FontWeight.w700)),
          ),
        ),
      );
}

class _Done extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  final String orderId;
  const _Done({required this.emoji, required this.title, required this.body, required this.orderId});
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(children: [
              Text(emoji, style: const TextStyle(fontSize: 80)).animate().scaleXY(begin: .4, duration: 700.ms, curve: Curves.elasticOut),
              const SizedBox(height: 18),
              Text(title, style: AppTheme.display(32), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(body, style: AppTheme.body(15, color: HK.muted, height: 1.6), textAlign: TextAlign.center),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(onPressed: () => context.go('/orders/$orderId'), child: const Text('Track my order')),
              ),
            ]),
          ),
        ),
      );
}

class _Message extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  const _Message(this.emoji, this.title, this.body);
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 14),
            Text(title, style: AppTheme.display(26), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, style: AppTheme.body(14, color: HK.muted), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => context.go('/'), child: const Text('Go home')),
          ]),
        ),
      );
}

/// Exposed for the tracking page.
Widget orderMessage(String emoji, String title, String body) => _Message(emoji, title, body);
