import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/cart.dart';
import '../../services/db.dart';
import '../../services/store_data.dart';
import '../../widgets/auth_form.dart';
import '../../widgets/common.dart';
import 'address_widgets.dart';
import 'store_shell.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _couponCtrl = TextEditingController();

  String _pay = 'upi';
  Offer? _coupon;
  String? _couponError;
  bool _couponBusy = false;
  bool _placing = false;
  bool _prefilled = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _note, _couponCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill(AuthService auth) {
    if (_prefilled || auth.profile == null) return;
    _prefilled = true;
    final p = auth.profile!;
    _name.text = p.name.isNotEmpty ? p.name : (auth.user?.displayName ?? '');
    _phone.text = p.phone;
  }

  Future<void> _applyCoupon(String code, double subtotal) async {
    if (code.trim().isEmpty) return;
    setState(() {
      _couponBusy = true;
      _couponError = null;
    });
    try {
      final o = await Db.findOffer(code);
      if (o == null) {
        _couponError = 'Invalid or expired coupon';
      } else if (subtotal < o.minOrder) {
        _couponError = 'Add ${rupees(o.minOrder - subtotal)} more to use ${o.code}';
      } else {
        _coupon = o;
        _couponCtrl.text = o.code;
        if (mounted) showToast(context, '${o.code} applied! You save ${rupees(o.discountFor(subtotal))} 🎉');
      }
    } catch (e) {
      _couponError = authErrorText(e);
    }
    if (mounted) setState(() => _couponBusy = false);
  }

  Future<void> _place() async {
    final auth = context.read<AuthService>();
    final cart = context.read<Cart>();
    final s = context.read<StoreData>().settings;
    final address = auth.currentAddress;
    if (address == null) {
      showToast(context, 'Please add a delivery address', error: true);
      showAddressEditor(context, autoLocate: true);
      return;
    }
    if (!s.serves(address)) {
      showToast(context, "Sorry, we don't deliver to this address yet. We deliver in ${s.areaSummary}.", error: true);
      return;
    }
    if (!_form.currentState!.validate()) {
      showToast(context, 'Please fill in your name and mobile number', error: true);
      return;
    }
    if (auth.isBlocked) {
      showToast(context, 'Your account is blocked. Please contact support.', error: true);
      return;
    }
    if (!s.storeOpen) {
      showToast(context, 'Sorry, we are not taking orders right now.', error: true);
      return;
    }
    if (cart.subtotal < s.minOrder) {
      showToast(context, 'Minimum order value is ${rupees(s.minOrder)}', error: true);
      return;
    }

    setState(() => _placing = true);
    try {
      final subtotal = cart.subtotal;
      final discount = _coupon?.discountFor(subtotal) ?? 0;
      final food = subtotal - discount;
      final fee = s.deliveryFor(food);
      final isVendor = cart.vendorId != AppConfig.houseVendorId;
      final rate = isVendor ? AppConfig.vendorCommissionRate : 0.0;
      final commission = round2(food * rate);
      final order = OrderModel(
        orderNo: OrderModel.newOrderNo(),
        userId: auth.user!.uid,
        customerName: _name.text.trim(),
        phone: normalizePhone(_phone.text),
        email: auth.user!.email ?? '',
        address: '${address.label}: ${address.line}',
        landmark: address.landmark,
        pincode: address.pincode,
        lat: address.lat,
        lng: address.lng,
        note: _note.text.trim(),
        items: [
          for (final l in cart.lines)
            OrderItem(productId: l.product.id, name: l.product.name, price: l.product.finalPrice, qty: l.qty, isVeg: l.product.isVeg),
        ],
        vendorId: cart.vendorId!,
        vendorName: cart.vendorName!,
        mrpTotal: cart.mrpTotal,
        subtotal: subtotal,
        couponDiscount: discount,
        couponCode: discount > 0 ? _coupon!.code : '',
        deliveryFee: fee,
        total: food + fee,
        commissionRate: rate,
        commissionAmount: commission,
        vendorPayout: isVendor ? round2(food - commission) : 0,
        paymentMethod: _pay,
      );
      final id = await Db.placeOrder(order);
      auth.saveLastAddress(address.toMap(), name: order.customerName, phone: order.phone).catchError((_) {});
      cart.clear();
      if (!mounted) return;
      context.go(_pay == 'upi' ? '/pay/$id' : '/orders/$id?placed=1');
    } catch (e) {
      if (mounted) {
        showToast(context, authErrorText(e), error: true);
        setState(() => _placing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final cart = context.watch<Cart>();
    final data = context.watch<StoreData>();
    _prefill(auth);

    Widget body;
    if (_placing) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('👨‍🍳', style: TextStyle(fontSize: 64)).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: .9, end: 1.1),
          const SizedBox(height: 18),
          Text('Placing your order…', style: AppTheme.display(26)),
        ]),
      );
    } else if (cart.isEmpty) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🛒', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text('Your cart is empty', style: AppTheme.display(28)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () => context.go('/?s=menu'), child: const Text('Browse menu')),
        ]),
      );
    } else {
      body = _content(context, auth, cart, data);
    }

    return StoreShell(
      appBar: const StoreTopBar(),
      showCartBar: false,
      body: RequireLogin(next: '/checkout', message: 'Log in to place your order — it takes 10 seconds.', child: body),
    );
  }

  Widget _content(BuildContext context, AuthService auth, Cart cart, StoreData data) {
    final s = data.settings;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final subtotal = cart.subtotal;
    final discount = _coupon?.discountFor(subtotal) ?? 0;
    final food = subtotal - discount;
    final fee = s.deliveryFor(food);
    final total = food + fee;

    final details = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Card(
        icon: Icons.location_on_rounded,
        title: 'Delivery details',
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (auth.currentAddress != null)
              AddressTile(address: auth.currentAddress!, selected: true, onTap: () => showAddressPicker(context))
            else
              Hoverable(
                onTap: () => showAddressEditor(context, autoLocate: true),
                builder: (h) => Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: HK.amber.withOpacity(h ? .16 : .1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: HK.amber, width: 1.4),
                  ),
                  child: Row(children: [
                    const Icon(Icons.add_location_alt_rounded, color: HK.flame, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Add delivery address', style: AppTheme.body(15.5, weight: FontWeight.w800)),
                        Text('Use your current location or type it in', style: AppTheme.body(12.5, color: HK.muted)),
                      ]),
                    ),
                    const Icon(Icons.arrow_forward_rounded),
                  ]),
                ),
              ),
            if (auth.currentAddress != null && !s.serves(auth.currentAddress!))
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: HK.nonVeg.withOpacity(.08), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  "We don't deliver to this address yet 😔  We currently deliver in ${s.areaSummary}. Please choose another address.",
                  style: AppTheme.body(13, color: HK.nonVeg, weight: FontWeight.w600, height: 1.45),
                ),
              ),
            if (auth.currentAddress != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showAddressPicker(context),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Change / add address'),
                ),
              ),
            const SizedBox(height: 14),
            _row(wide, [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => validateRequired(v, 'Name'),
              ),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91  '),
                validator: validatePhone,
              ),
            ]),
            const SizedBox(height: 14),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Cooking / delivery instructions (optional)', hintText: 'e.g. less spicy, ring the bell'),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 20),
      _Card(
        icon: Icons.account_balance_wallet_rounded,
        title: 'Payment method',
        child: Column(children: [
          _PayOption(
            selected: _pay == 'upi',
            onTap: () => setState(() => _pay = 'upi'),
            leading: const Icon(Icons.qr_code_2_rounded, color: HK.amberDeep, size: 28),
            title: 'Pay online with UPI',
            subtitle: 'GPay, PhonePe, Paytm, BHIM or any UPI app',
            badge: 'Recommended',
          ),
          const SizedBox(height: 12),
          _PayOption(
            selected: _pay == 'cod',
            onTap: () => setState(() => _pay = 'cod'),
            leading: const Icon(Icons.payments_rounded, color: HK.amberDeep, size: 28),
            title: 'Cash on delivery',
            subtitle: 'Pay in cash when your food arrives',
          ),
        ]),
      ),
    ]);

    final summary = _Card(
      icon: Icons.receipt_long_rounded,
      title: 'Order summary',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.storefront_rounded, size: 18, color: HK.amberDeep),
          const SizedBox(width: 8),
          Expanded(child: Text(cart.vendorName ?? '', style: AppTheme.body(14, weight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        for (final l in cart.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              VegMark(isVeg: l.product.isVeg, size: 13),
              const SizedBox(width: 8),
              Expanded(child: Text('${l.product.name}  × ${l.qty}', style: AppTheme.body(14))),
              Text(rupees(l.total), style: AppTheme.body(14, weight: FontWeight.w600)),
            ]),
          ),
        const Divider(height: 28),
        // Coupon
        if (_coupon != null && discount > 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HK.veg.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HK.veg.withOpacity(.4)),
            ),
            child: Row(children: [
              const Icon(Icons.local_offer_rounded, color: HK.veg, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${_coupon!.code} applied · you save ${rupees(discount)}',
                    style: AppTheme.body(13.5, color: HK.veg, weight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _coupon = null;
                  _couponCtrl.clear();
                }),
                child: const Text('Remove'),
              ),
            ]),
          )
        else ...[
          Row(children: [
            Expanded(
              child: TextField(
                controller: _couponCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Coupon code',
                  prefixIcon: const Icon(Icons.local_offer_outlined, color: HK.muted),
                  errorText: _couponError,
                  isDense: true,
                ),
                onSubmitted: (v) => _applyCoupon(v, subtotal),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: _couponBusy ? null : () => _applyCoupon(_couponCtrl.text, subtotal),
                child: _couponBusy ? const BtnSpinner(color: HK.amberDeep) : const Text('Apply'),
              ),
            ),
          ]),
          if (data.offers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final o in data.offers)
                ActionChip(
                  backgroundColor: HK.amber.withOpacity(.08),
                  side: BorderSide(color: HK.amber.withOpacity(.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  label: Text('${o.code} · ${o.shortLabel}', style: AppTheme.body(12, color: HK.amberDeep, weight: FontWeight.w700)),
                  onPressed: () => _applyCoupon(o.code, subtotal),
                ),
            ]),
          ],
        ],
        if (_coupon != null && discount == 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${_coupon!.code} needs a minimum order of ${rupees(_coupon!.minOrder)}.', style: AppTheme.body(12.5, color: HK.nonVeg)),
          ),
        const Divider(height: 28),
        BillRow('Item total', rupees(cart.mrpTotal)),
        if (cart.saleSavings > 0) BillRow('Sale savings', '− ${rupees(cart.saleSavings)}', color: HK.veg),
        if (discount > 0) BillRow('Coupon (${_coupon!.code})', '− ${rupees(discount)}', color: HK.veg),
        BillRow('Delivery fee', fee == 0 ? 'FREE' : rupees(fee), color: fee == 0 ? HK.veg : null),
        const Divider(height: 24),
        BillRow('To pay', rupees(total), bold: true),
        if (cart.saleSavings + discount > 0)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: HK.veg.withOpacity(.1), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text('🎉 You are saving ${rupees(cart.saleSavings + discount)} on this order',
                style: AppTheme.body(13, color: HK.veg, weight: FontWeight.w700)),
          ),
        const SizedBox(height: 20),
        SizedBox(
          height: 58,
          child: ElevatedButton(
            onPressed: s.storeOpen && (auth.currentAddress == null || s.serves(auth.currentAddress!)) ? _place : null,
            child: Row(children: [
              Text(rupees(total), style: const TextStyle(fontSize: 17)),
              const Spacer(),
              Text(!s.storeOpen ? 'Store closed' : (_pay == 'upi' ? 'Place order & pay' : 'Place order')),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.lock_rounded, size: 14, color: HK.muted),
          const SizedBox(width: 6),
          Text('Safe & secure checkout', style: AppTheme.body(12.5, color: HK.muted)),
        ]),
      ]),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 32, bottom: 80),
      child: MaxWidth(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextButton.icon(onPressed: () => context.go('/'), icon: const Icon(Icons.arrow_back_rounded), label: const Text('Back to menu')),
          const SizedBox(height: 8),
          Text('Checkout', style: AppTheme.display(isMobile(context) ? 34 : 46)),
          const SizedBox(height: 24),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: details),
              const SizedBox(width: 28),
              SizedBox(width: 420, child: summary),
            ])
          else ...[
            details,
            const SizedBox(height: 20),
            summary,
          ],
        ]),
      ),
    );
  }

  Widget _row(bool wide, List<Widget> children) => wide
      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 14), Expanded(child: children[i])],
        ])
      : Column(children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 14), children[i]],
        ]);
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Card({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration:
            BoxDecoration(color: HK.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: HK.line), boxShadow: HK.shadow(.8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: HK.amber.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: HK.amberDeep, size: 20),
            ),
            const SizedBox(width: 12),
            Text(title, style: AppTheme.body(18, weight: FontWeight.w800)),
          ]),
          const SizedBox(height: 20),
          child,
        ]),
      );
}

class _PayOption extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final String? badge;
  const _PayOption({required this.selected, required this.onTap, required this.leading, required this.title, required this.subtitle, this.badge});

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (h) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? HK.amber.withOpacity(.08) : (h ? HK.cardHi : HK.surface),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? HK.amberDeep : HK.line, width: selected ? 1.6 : 1),
          ),
          child: Row(children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(title, style: AppTheme.body(15.5, weight: FontWeight.w700)),
                  if (badge != null) Pill(badge!, color: HK.veg),
                ]),
                const SizedBox(height: 3),
                Text(subtitle, style: AppTheme.body(13, color: HK.muted)),
              ]),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: selected ? HK.amberDeep : HK.muted, width: 2),
              ),
              padding: const EdgeInsets.all(3),
              child: selected ? Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: HK.amberDeep)) : null,
            ),
          ]),
        ),
      );
}
