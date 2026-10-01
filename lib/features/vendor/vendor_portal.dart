import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import '../../widgets/payout_form.dart';
import '../panel/orders_manager.dart';
import '../panel/panel_widgets.dart';
import '../panel/products_manager.dart';

class VendorPortal extends StatelessWidget {
  const VendorPortal({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.panel,
      child: Builder(builder: (context) {
        final auth = context.watch<AuthService>();
        if (!auth.ready) return const Scaffold(backgroundColor: PK.bg, body: Center(child: CircularProgressIndicator()));
        if (!auth.signedIn) {
          return PanelLogin(
            title: 'Vendor dashboard',
            subtitle: 'Log in to manage your kitchen, menu and orders.',
            footer: Center(child: TextButton(onPressed: () => context.go('/partner'), child: const Text('New kitchen? Register as vendor'))),
          );
        }
        final v = auth.vendor;
        if (v == null) {
          return PanelMessage(
            emoji: '🏪',
            title: 'No kitchen registered',
            body: '${auth.user?.email} is not registered as a vendor yet. Register your kitchen to start selling on HungryKya.',
            actions: [
              ElevatedButton(onPressed: () => context.go('/partner'), child: const Text('Register as vendor')),
              TextButton(onPressed: auth.signOut, child: const Text('Log out')),
            ],
          );
        }
        switch (v.status) {
          case VendorStatus.pending:
            return PanelMessage(
              emoji: '⏳',
              title: 'Application under review',
              body: 'Thanks, ${v.ownerName.split(' ').first}! ${v.businessName} has been submitted. '
                  'The HungryKya team will verify your details and approve your kitchen. This page updates automatically once approved.',
              actions: [
                OutlinedButton(onPressed: () => context.go('/'), child: const Text('Visit store')),
                TextButton(onPressed: auth.signOut, child: const Text('Log out')),
              ],
            );
          case VendorStatus.rejected:
            return PanelMessage(
              emoji: '📝',
              title: 'Application not approved',
              body: 'Unfortunately ${v.businessName} was not approved.${v.rejectionReason.isEmpty ? '' : '\n\nReason: ${v.rejectionReason}'}\n\n'
                  'Please contact HungryKya support if you think this is a mistake.',
              actions: [TextButton(onPressed: auth.signOut, child: const Text('Log out'))],
            );
          case VendorStatus.blocked:
            return PanelMessage(
              emoji: '🚫',
              title: 'Kitchen blocked',
              body: '${v.businessName} has been blocked by HungryKya and is hidden from the store.'
                  '${v.rejectionReason.isEmpty ? '' : '\n\nReason: ${v.rejectionReason}'}',
              actions: [TextButton(onPressed: auth.signOut, child: const Text('Log out'))],
            );
        }
        return _VendorHome(vendor: v);
      }),
    );
  }
}

class _VendorHome extends StatefulWidget {
  final Vendor vendor;
  const _VendorHome({required this.vendor});
  @override
  State<_VendorHome> createState() => _VendorHomeState();
}

class _VendorHomeState extends State<_VendorHome> {
  StreamSubscription? _sub;
  List<OrderModel> _orders = [];
  int _section = 0;
  int _lastNew = -1;

  @override
  void initState() {
    super.initState();
    _sub = Db.vendorOrders(widget.vendor.id).listen((o) {
      final n = o.where((e) => e.status == OrderStatus.placed).length;
      if (_lastNew >= 0 && n > _lastNew && mounted) {
        showToast(context, '🔔 New order received!');
        SystemSound.play(SystemSoundType.alert);
      }
      _lastNew = n;
      setState(() => _orders = o);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vendor;
    final newCount = _orders.where((o) => o.status == OrderStatus.placed).length;
    final body = switch (_section) {
      0 => _VendorDashboard(vendor: v, orders: _orders, onGo: (i) => setState(() => _section = i)),
      1 => OrdersManager(orders: _orders, isAdmin: false),
      2 => ProductsManager(isAdmin: false, vendorId: v.id, vendorName: v.businessName),
      _ => _VendorProfile(vendor: v, orders: _orders),
    };
    return PanelShell(
      roleLabel: 'Vendor',
      items: [
        const PanelNavItem(Icons.space_dashboard_rounded, 'Dashboard'),
        PanelNavItem(Icons.receipt_long_rounded, 'Orders', badge: newCount),
        const PanelNavItem(Icons.restaurant_menu_rounded, 'Menu & photos'),
        const PanelNavItem(Icons.account_balance_rounded, 'Earnings & payouts'),
      ],
      selected: _section,
      onSelect: (i) => setState(() => _section = i),
      body: body,
    );
  }
}

class _Earnings {
  final int delivered;
  final double sales;
  final double commission;
  final double payout;
  _Earnings(List<OrderModel> orders)
      : delivered = orders.where((o) => o.status == OrderStatus.delivered).length,
        sales = orders.where((o) => o.status == OrderStatus.delivered).fold(0.0, (a, o) => a + o.foodTotal),
        commission = orders.where((o) => o.status == OrderStatus.delivered).fold(0.0, (a, o) => a + o.commissionAmount),
        payout = orders.where((o) => o.status == OrderStatus.delivered).fold(0.0, (a, o) => a + o.vendorPayout);
}

class _VendorDashboard extends StatelessWidget {
  final Vendor vendor;
  final List<OrderModel> orders;
  final ValueChanged<int> onGo;
  const _VendorDashboard({required this.vendor, required this.orders, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todays = orders.where((o) => o.createdAt != null && !o.createdAt!.isBefore(today) && o.status != OrderStatus.cancelled).toList();
    final active = orders.where((o) => o.isActive).toList();
    final e = _Earnings(orders);

    return PanelPage(children: [
      PageHeader(
        title: 'Namaste, ${vendor.ownerName.split(' ').first} 👋',
        subtitle: '${vendor.businessName} · ${vendor.city}',
        actions: [
          const Pill('Live on HungryKya', color: PK.green, icon: Icons.circle),
          ElevatedButton.icon(onPressed: () => onGo(2), icon: const Icon(Icons.add_rounded), label: const Text('Add dish')),
        ],
      ),
      ResponsiveGrid(minItemWidth: 220, children: [
        StatCard(label: "Today's orders", value: '${todays.length}', icon: Icons.today_rounded, color: PK.blue, sub: rupees(todays.fold(0.0, (a, o) => a + o.foodTotal))),
        StatCard(label: 'Active orders', value: '${active.length}', icon: Icons.local_fire_department_rounded, color: PK.flame, sub: 'Tap to manage', onTap: () => onGo(1)),
        StatCard(label: 'Delivered sales', value: rupees(e.sales), icon: Icons.trending_up_rounded, color: PK.amber, sub: '${e.delivered} delivered orders'),
        StatCard(label: 'HungryKya commission (2%)', value: rupees(e.commission), icon: Icons.percent_rounded, color: PK.violet),
        StatCard(label: 'Your earnings', value: rupees(e.payout), icon: Icons.account_balance_wallet_rounded, color: PK.green, sub: 'After 2% commission', onTap: () => onGo(3)),
        StatCard(
          label: 'Pending payout',
          value: rupees(orders.where((o) => o.awaitingPayout).fold(0.0, (a, o) => a + o.vendorPayout)),
          icon: Icons.schedule_rounded,
          color: PK.amber,
          sub: vendor.payout.isEmpty ? 'Add bank / UPI details!' : 'Paid at day end',
          onTap: () => onGo(3),
        ),
      ]),
      const SizedBox(height: 20),
      PanelCard(
        title: 'Orders needing action',
        trailing: TextButton(onPressed: () => onGo(1), child: const Text('All orders')),
        child: active.isEmpty
            ? Text('No active orders right now. New orders appear here instantly with a sound alert.', style: AppTheme.body(14, color: PK.muted))
            : Column(children: [
                for (final o in active.take(8))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => showOrderDetail(context, o.id, isAdmin: false),
                    leading: CircleAvatar(
                      backgroundColor: OrderStatus.color(o.status).withOpacity(.12),
                      child: Icon(OrderStatus.icon(o.status), color: OrderStatus.color(o.status), size: 20),
                    ),
                    title: Text('#${o.orderNo} · ${o.items.map((i) => '${i.qty}× ${i.name}').join(', ')}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(14, color: PK.ink, weight: FontWeight.w700)),
                    subtitle: Text('${OrderStatus.label(o.status)} · ${timeAgo(o.createdAt)}', style: AppTheme.body(12.5, color: PK.muted)),
                    trailing: OrderStatus.next(o.status) == null
                        ? null
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                            onPressed: () => advanceOrder(context, o, OrderStatus.next(o.status)!),
                            child: Text(nextActionLabel(o.status)),
                          ),
                  ),
              ]),
      ),
    ]);
  }
}

class _VendorProfile extends StatefulWidget {
  final Vendor vendor;
  final List<OrderModel> orders;
  const _VendorProfile({required this.vendor, required this.orders});
  @override
  State<_VendorProfile> createState() => _VendorProfileState();
}

class _VendorProfileState extends State<_VendorProfile> {
  final _form = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.vendor.phone);
  late final _cuisine = TextEditingController(text: widget.vendor.cuisine);
  late final _address = TextEditingController(text: widget.vendor.address);
  late final _city = TextEditingController(text: widget.vendor.city);
  late final _pincode = TextEditingController(text: widget.vendor.pincode);
  late final _fssai = TextEditingController(text: widget.vendor.fssai);
  bool _saving = false;
  final _payoutForm = GlobalKey<FormState>();
  late final _payoutCtl = PayoutFormController(widget.vendor.payout);
  late final Stream<List<Payout>> _payouts = Db.vendorPayouts(widget.vendor.id);
  bool _savingPayout = false;

  @override
  void dispose() {
    for (final c in [_phone, _cuisine, _address, _city, _pincode, _fssai]) {
      c.dispose();
    }
    _payoutCtl.dispose();
    super.dispose();
  }

  Future<void> _savePayout() async {
    if (!_payoutForm.currentState!.validate()) return;
    setState(() => _savingPayout = true);
    try {
      await Db.updateVendorProfile(widget.vendor.id, {'payout': _payoutCtl.value.toMap()});
      if (mounted) showToast(context, 'Payout details updated');
    } catch (e) {
      if (mounted) showToast(context, authErrorText(e), error: true);
    }
    if (mounted) setState(() => _savingPayout = false);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await Db.updateVendorProfile(widget.vendor.id, {
        'phone': normalizePhone(_phone.text),
        'cuisine': _cuisine.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'pincode': _pincode.text.trim(),
        'fssai': _fssai.text.trim(),
      });
      if (mounted) showToast(context, 'Profile updated');
    } catch (e) {
      if (mounted) showToast(context, authErrorText(e), error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vendor;
    final e = _Earnings(widget.orders);
    final delivered = widget.orders.where((o) => o.status == OrderStatus.delivered).toList();

    final pending = widget.orders.where((o) => o.awaitingPayout).toList();
    final pendingAmount = pending.fold(0.0, (a, o) => a + o.vendorPayout);

    final payouts = StreamBuilder<List<Payout>>(
      stream: _payouts,
      builder: (c, snap) {
        final list = snap.data ?? const <Payout>[];
        final paid = list.fold(0.0, (a, p) => a + p.amount);
        return PanelCard(
          title: 'Payouts',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: _Mini2('Pending (next payout)', rupees(pendingAmount), '${pending.length} delivered orders', PK.amber)),
              const SizedBox(width: 12),
              Expanded(child: _Mini2('Paid to you', rupees(paid), '${list.length} payouts', PK.green)),
            ]),
            const SizedBox(height: 10),
            Text('HungryKya settles delivered orders at the end of each day to your bank / UPI below.',
                style: AppTheme.body(12.5, color: PK.muted, height: 1.45)),
            if (list.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('PAYOUT HISTORY', style: AppTheme.body(11.5, color: PK.muted, weight: FontWeight.w800).copyWith(letterSpacing: 1.4)),
              const SizedBox(height: 6),
              for (final p in list.take(20))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: PK.green.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.payments_rounded, size: 18, color: PK.green),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${fmtDateTime(p.paidAt)} · ${p.methodLabel}', style: AppTheme.body(13, color: PK.ink, weight: FontWeight.w700)),
                        Text('${p.orderIds.length} orders${p.reference.isEmpty ? '' : ' · Ref ${p.reference}'}', style: AppTheme.body(12, color: PK.muted)),
                      ]),
                    ),
                    Text(rupees(p.amount), style: AppTheme.body(14.5, color: PK.green, weight: FontWeight.w800)),
                  ]),
                ),
            ],
          ]),
        );
      },
    );

    final payoutDetails = PanelCard(
      title: 'Payout account',
      child: Form(
        key: _payoutForm,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (v.payout.isEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: PK.red.withOpacity(.08), borderRadius: BorderRadius.circular(12)),
              child: Text('Add your bank account or UPI ID so HungryKya can pay you.',
                  style: AppTheme.body(13, color: PK.red, weight: FontWeight.w600)),
            ),
          PayoutFields(controller: _payoutCtl, requireBank: false),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _savingPayout ? null : _savePayout,
              child: _savingPayout ? const BtnSpinner() : const Text('Save payout details'),
            ),
          ),
        ]),
      ),
    );

    final earnings = PanelCard(
      title: 'Earnings statement',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Line('Delivered orders', '${e.delivered}'),
        _Line('Food sales (after discounts)', rupees(e.sales)),
        _Line('HungryKya commission @ ${(v.commissionRate * 100).toStringAsFixed(0)}%', '− ${rupees(e.commission)}', color: PK.flame),
        const Divider(height: 22),
        _Line('Your net earnings', rupees(e.payout), bold: true, color: PK.green),
        const SizedBox(height: 14),
        if (delivered.isNotEmpty) ...[
          Text('RECENT DELIVERED ORDERS', style: AppTheme.body(11.5, color: PK.muted, weight: FontWeight.w800).copyWith(letterSpacing: 1.4)),
          const SizedBox(height: 8),
          for (final o in delivered.take(10))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(child: Text('#${o.orderNo} · ${fmtDate(o.createdAt)}', style: AppTheme.body(13, color: PK.ink))),
                Text('${rupees(o.foodTotal)} − ${rupees(o.commissionAmount)} = ', style: AppTheme.body(12.5, color: PK.muted)),
                Text(rupees(o.vendorPayout), style: AppTheme.body(13, color: PK.ink, weight: FontWeight.w800)),
              ]),
            ),
        ],
      ]),
    );

    final agreement = PanelCard(
      title: 'Commission agreement',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.task_alt_rounded, color: PK.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You agreed to a ${(v.commissionRate * 100).toStringAsFixed(0)}% commission on ${fmtDateTime(v.consentAt)}',
              style: AppTheme.body(14, color: PK.ink, weight: FontWeight.w700),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text('Terms version ${v.consentVersion}. Payouts are settled by HungryKya after deducting the commission from each delivered order.',
            style: AppTheme.body(13, color: PK.muted, height: 1.5)),
      ]),
    );

    final profile = PanelCard(
      title: 'Kitchen profile',
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Line('Business name', v.businessName),
          _Line('Owner', v.ownerName),
          _Line('Login email', v.email),
          const SizedBox(height: 14),
          TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone', prefixText: '+91 '), validator: validatePhone),
          const SizedBox(height: 12),
          TextFormField(controller: _cuisine, decoration: const InputDecoration(labelText: 'Cuisine')),
          const SizedBox(height: 12),
          TextFormField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address'), validator: (x) => validateRequired(x, 'Address')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'City'))),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _pincode,
                decoration: const InputDecoration(labelText: 'Pincode'),
                validator: (x) => RegExp(r'^\d{6}$').hasMatch((x ?? '').trim()) ? null : '6 digits',
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(controller: _fssai, decoration: const InputDecoration(labelText: 'FSSAI licence no.')),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const BtnSpinner() : const Text('Save profile')),
          ),
        ]),
      ),
    );

    return PanelPage(children: [
      const PageHeader(title: 'Earnings & payouts', subtitle: 'Your payouts, bank / UPI details, commission and kitchen profile.'),
      LayoutBuilder(builder: (c, cons) {
        if (cons.maxWidth < 900) {
          return Column(children: [
            payouts,
            const SizedBox(height: 16),
            payoutDetails,
            const SizedBox(height: 16),
            earnings,
            const SizedBox(height: 16),
            agreement,
            const SizedBox(height: 16),
            profile,
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(children: [payouts, const SizedBox(height: 16), earnings, const SizedBox(height: 16), agreement])),
          const SizedBox(width: 16),
          Expanded(child: Column(children: [payoutDetails, const SizedBox(height: 16), profile])),
        ]);
      }),
    ]);
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _Line(this.label, this.value, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label, style: AppTheme.body(bold ? 15 : 13.5, color: bold ? PK.ink : PK.muted, weight: bold ? FontWeight.w800 : FontWeight.w500))),
          Text(value, style: AppTheme.body(bold ? 17 : 14, color: color ?? PK.ink, weight: bold ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );
}

class _Mini2 extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _Mini2(this.label, this.value, this.sub, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTheme.body(12, color: PK.muted, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: AppTheme.body(20, color: PK.ink, weight: FontWeight.w800)),
          Text(sub, style: AppTheme.body(11.5, color: color, weight: FontWeight.w700)),
        ]),
      );
}
