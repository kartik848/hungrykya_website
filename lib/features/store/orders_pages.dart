import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../services/store_data.dart';
import '../../widgets/auth_form.dart';
import '../../widgets/common.dart';
import 'payment_page.dart';
import 'store_shell.dart';

class OrderTrackingPage extends StatelessWidget {
  final String orderId;
  final bool justPlaced;
  const OrderTrackingPage({super.key, required this.orderId, this.justPlaced = false});

  @override
  Widget build(BuildContext context) {
    return StoreShell(
      appBar: const StoreTopBar(),
      body: RequireLogin(
        next: '/orders/$orderId',
        child: StreamBuilder<OrderModel?>(
          stream: Db.order(orderId),
          builder: (c, snap) {
            if (snap.hasError) return orderMessage('😕', 'Could not load this order', authErrorText(snap.error!));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final o = snap.data;
            if (o == null) return orderMessage('🔍', 'Order not found', 'This order does not exist.');
            return _Tracking(o: o, justPlaced: justPlaced);
          },
        ),
      ),
    );
  }
}

class _Tracking extends StatelessWidget {
  final OrderModel o;
  final bool justPlaced;
  const _Tracking({required this.o, required this.justPlaced});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StoreData>().settings;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final cancelled = o.status == OrderStatus.cancelled;
    final eta = o.createdAt?.add(Duration(minutes: s.etaMinutes));

    final hero = Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [cancelled ? const Color(0xFFFFE4E4) : const Color(0xFFFFEBCB), HK.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: (cancelled ? HK.nonVeg : HK.amberDeep).withOpacity(.35)),
      ),
      child: Row(children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: OrderStatus.color(o.status).withOpacity(.6), width: 2),
          ),
          alignment: Alignment.center,
          child: Text(OrderStatus.emoji(o.status), style: const TextStyle(fontSize: 42))
              .animate(key: ValueKey(o.status), onPlay: (c) => o.isActive ? c.repeat(reverse: true) : null)
              .scaleXY(begin: .92, end: 1.06, duration: 900.ms, curve: Curves.easeInOut),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(OrderStatus.label(o.status).toUpperCase(),
                style: AppTheme.body(12, color: OrderStatus.color(o.status), weight: FontWeight.w800).copyWith(letterSpacing: 2)),
            const SizedBox(height: 6),
            Text(OrderStatus.headline(o.status), style: AppTheme.display(isMobile(context) ? 22 : 28, height: 1.2)),
            const SizedBox(height: 8),
            if (o.isActive && eta != null)
              Text('Estimated arrival by ${fmtTime(eta)}', style: AppTheme.body(14, color: HK.amberDeep, weight: FontWeight.w700)),
            Text('Order #${o.orderNo} · ${fmtDateTime(o.createdAt)}', style: AppTheme.body(13, color: HK.muted)),
          ]),
        ),
      ]),
    );

    final payment = _Box(
      title: 'Payment',
      icon: Icons.account_balance_wallet_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text(o.isUpi ? 'UPI (online)' : 'Cash on delivery', style: AppTheme.body(15, weight: FontWeight.w700)),
          const Spacer(),
          Pill(PayStatus.label(o.paymentStatus), color: PayStatus.color(o.paymentStatus)),
        ]),
        if (o.upiRef.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('UPI ref: ${o.upiRef}', style: AppTheme.body(13, color: HK.muted)),
        ],
        if (o.needsPayment) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ElevatedButton(onPressed: () => context.go('/pay/${o.id}'), child: Text('Complete payment · ${rupees(o.total)}')),
          ),
        ],
        if (o.paymentStatus == PayStatus.verification) ...[
          const SizedBox(height: 10),
          Text('We are matching your UPI reference with the payment. This usually takes a few minutes.',
              style: AppTheme.body(13, color: HK.muted, height: 1.5)),
        ],
        if (!o.isUpi && o.paymentStatus != PayStatus.paid && !cancelled) ...[
          const SizedBox(height: 10),
          Text('Please keep ${rupees(o.total)} ready for the delivery partner.', style: AppTheme.body(13, color: HK.muted)),
        ],
      ]),
    );

    final timeline = _Box(
      title: 'Order status',
      icon: Icons.timeline_rounded,
      child: cancelled
          ? Row(children: [
              const Icon(Icons.cancel_rounded, color: HK.nonVeg),
              const SizedBox(width: 10),
              Text('Cancelled ${fmtTime(o.timeOf(OrderStatus.cancelled))}', style: AppTheme.body(15, weight: FontWeight.w700)),
            ])
          : _Timeline(o),
    );

    final items = _Box(
      title: 'Your order from ${o.vendorName}',
      icon: Icons.receipt_long_rounded,
      child: Column(children: [
        for (final i in o.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              VegMark(isVeg: i.isVeg, size: 13),
              const SizedBox(width: 8),
              Expanded(child: Text('${i.name}  × ${i.qty}', style: AppTheme.body(14))),
              Text(rupees(i.total), style: AppTheme.body(14, weight: FontWeight.w600)),
            ]),
          ),
        const Divider(height: 24),
        BillRow('Item total', rupees(o.mrpTotal > 0 ? o.mrpTotal : o.subtotal)),
        if (o.saleSavings > 0) BillRow('Sale savings', '− ${rupees(o.saleSavings)}', color: HK.veg),
        if (o.couponDiscount > 0) BillRow('Coupon (${o.couponCode})', '− ${rupees(o.couponDiscount)}', color: HK.veg),
        BillRow('Delivery fee', o.deliveryFee == 0 ? 'FREE' : rupees(o.deliveryFee)),
        const Divider(height: 20),
        BillRow(o.paymentStatus == PayStatus.paid ? 'Paid' : 'To pay', rupees(o.total), bold: true),
      ]),
    );

    final delivery = _Box(
      title: 'Delivering to',
      icon: Icons.location_on_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(o.customerName, style: AppTheme.body(15, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text([o.address, o.landmark, o.pincode].where((e) => e.isNotEmpty).join(', '), style: AppTheme.body(14, color: HK.muted, height: 1.5)),
        const SizedBox(height: 4),
        Text('+91 ${o.phone}', style: AppTheme.body(14, color: HK.muted)),
        if (o.note.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Note: ${o.note}', style: AppTheme.body(13.5, color: HK.amberDeep)),
        ],
      ]),
    );

    final actions = Wrap(spacing: 12, runSpacing: 12, children: [
      if (s.contactPhone.isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => launchUrl(Uri.parse('tel:${s.contactPhone}')),
          icon: const Icon(Icons.call_rounded, size: 18),
          label: const Text('Call support'),
        ),
      if (o.status == OrderStatus.placed)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: HK.nonVeg, side: BorderSide(color: HK.nonVeg.withOpacity(.5))),
          onPressed: () async {
            final ok = await confirmDialog(context,
                title: 'Cancel this order?',
                message: 'You can cancel only until the kitchen accepts it.',
                confirm: 'Cancel order',
                destructive: true);
            if (!ok) return;
            try {
              await Db.setOrderStatus(o, OrderStatus.cancelled);
            } catch (e) {
              if (context.mounted) showToast(context, authErrorText(e), error: true);
            }
          },
          icon: const Icon(Icons.close_rounded, size: 18),
          label: const Text('Cancel order'),
        ),
      OutlinedButton.icon(
          onPressed: () => context.go('/orders'), icon: const Icon(Icons.list_alt_rounded, size: 18), label: const Text('All orders')),
    ]);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 28, bottom: 110),
      child: MaxWidth(
        max: 1000,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (justPlaced && o.isActive)
            Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: HK.fire, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                const Text('🎉', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Order placed successfully! Sit back — we will keep this page updated live.',
                      style: AppTheme.body(15, color: Colors.black, weight: FontWeight.w700)),
                ),
              ]),
            ).animate().fadeIn().slideY(begin: -.3, curve: Curves.easeOutBack),
          hero.animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 20),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(children: [timeline, const SizedBox(height: 20), delivery])),
              const SizedBox(width: 20),
              Expanded(child: Column(children: [payment, const SizedBox(height: 20), items])),
            ])
          else ...[
            payment,
            const SizedBox(height: 16),
            timeline,
            const SizedBox(height: 16),
            items,
            const SizedBox(height: 16),
            delivery,
          ],
          const SizedBox(height: 20),
          actions,
        ]),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final OrderModel o;
  const _Timeline(this.o);

  @override
  Widget build(BuildContext context) {
    final current = OrderStatus.flow.indexOf(o.status);
    return Column(children: [
      for (var i = 0; i < OrderStatus.flow.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 36,
              child: Column(children: [
                _Dot(state: i < current ? 2 : (i == current ? 1 : 0), icon: OrderStatus.icon(OrderStatus.flow[i])),
                if (i < OrderStatus.flow.length - 1)
                  Expanded(
                    child: Container(
                      width: 2.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: i < current ? HK.fire : null,
                        color: i < current ? null : HK.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 22),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      OrderStatus.label(OrderStatus.flow[i]),
                      style: AppTheme.body(15, color: i <= current ? HK.ink : HK.muted, weight: i == current ? FontWeight.w800 : FontWeight.w600),
                    ),
                  ),
                  Text(fmtTime(o.timeOf(OrderStatus.flow[i])), style: AppTheme.body(12.5, color: HK.muted)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

class _Dot extends StatelessWidget {
  /// 0 = upcoming, 1 = current, 2 = done.
  final int state;
  final IconData icon;
  const _Dot({required this.state, required this.icon});

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: state > 0 ? HK.fire : null,
        color: state > 0 ? null : HK.surface,
        border: state > 0 ? null : Border.all(color: HK.line, width: 2),
      ),
      child: Icon(state == 2 ? Icons.check_rounded : icon, size: 17, color: state > 0 ? Colors.black : HK.muted),
    );
    if (state != 1) return dot;
    return dot.animate(onPlay: (c) => c.repeat(reverse: true)).boxShadow(
          begin: BoxShadow(color: HK.amber.withOpacity(0), blurRadius: 0, spreadRadius: 0),
          end: BoxShadow(color: HK.amber.withOpacity(.5), blurRadius: 18, spreadRadius: 4),
          borderRadius: BorderRadius.circular(40),
          duration: 900.ms,
        );
  }
}

class _Box extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Box({required this.title, required this.icon, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration:
            BoxDecoration(color: HK.card, borderRadius: BorderRadius.circular(22), border: Border.all(color: HK.line), boxShadow: HK.shadow(.7)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: HK.amberDeep, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: AppTheme.body(16.5, weight: FontWeight.w800))),
          ]),
          const SizedBox(height: 16),
          child,
        ]),
      );
}

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return StoreShell(
      appBar: const StoreTopBar(),
      body: RequireLogin(
        next: '/orders',
        message: 'Log in to see and track your orders.',
        child: auth.user == null
            ? const SizedBox()
            : StreamBuilder<List<OrderModel>>(
                stream: Db.userOrders(auth.user!.uid),
                builder: (c, snap) {
                  if (snap.hasError) return orderMessage('😕', 'Could not load orders', authErrorText(snap.error!));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final orders = snap.data!;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 32, bottom: 110),
                    child: MaxWidth(
                      max: 900,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('My orders', style: AppTheme.display(isMobile(context) ? 34 : 44)),
                        const SizedBox(height: 6),
                        Text('Track live orders and see your order history.', style: AppTheme.body(15, color: HK.muted)),
                        const SizedBox(height: 26),
                        if (orders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 60),
                            child: Column(children: [
                              const Text('🍽️', style: TextStyle(fontSize: 64)),
                              const SizedBox(height: 14),
                              Text('No orders yet', style: AppTheme.display(26)),
                              const SizedBox(height: 8),
                              Text('Your first delicious order is one tap away.', style: AppTheme.body(14.5, color: HK.muted)),
                              const SizedBox(height: 22),
                              ElevatedButton(onPressed: () => context.go('/?s=menu'), child: const Text('Browse menu')),
                            ]),
                          )
                        else
                          for (final (i, o) in orders.indexed) _OrderCard(o).animate().fadeIn(delay: (40 * i).ms).slideY(begin: .1),
                      ]),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel o;
  const _OrderCard(this.o);

  @override
  Widget build(BuildContext context) {
    final summary = o.items.map((i) => '${i.qty} × ${i.name}').join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Hoverable(
        onTap: () => context.go('/orders/${o.id}'),
        builder: (h) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: h ? HK.cardHi : HK.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: o.isActive ? HK.amber.withOpacity(.45) : HK.line),
          ),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: OrderStatus.color(o.status).withOpacity(.14), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(OrderStatus.emoji(o.status), style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(o.vendorName, style: AppTheme.body(15.5, weight: FontWeight.w800)),
                  Pill(OrderStatus.label(o.status), color: OrderStatus.color(o.status)),
                  if (o.needsPayment) const Pill('Payment pending', color: HK.amberDeep),
                ]),
                const SizedBox(height: 6),
                Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(13.5, color: HK.muted)),
                const SizedBox(height: 4),
                Text('#${o.orderNo} · ${fmtDateTime(o.createdAt)}', style: AppTheme.body(12.5, color: HK.muted)),
              ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(rupees(o.total), style: AppTheme.body(17, weight: FontWeight.w800)),
              const SizedBox(height: 6),
              Icon(Icons.arrow_forward_rounded, color: h ? HK.amberDeep : HK.muted, size: 20),
            ]),
          ]),
        ),
      ),
    );
  }
}
