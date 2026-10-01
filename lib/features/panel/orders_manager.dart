import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import 'panel_widgets.dart';

import 'package:web/web.dart' as web;

String nextActionLabel(String status) => const {
      OrderStatus.placed: 'Accept order',
      OrderStatus.confirmed: 'Start preparing',
      OrderStatus.preparing: 'Out for delivery',
      OrderStatus.outForDelivery: 'Mark delivered',
    }[status] ??
    '';

void showPrintReceiptDialog(BuildContext context, OrderModel o) {
  showDialog(
    context: context,
    builder: (d) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('KOT / Invoice Receipt', style: AppTheme.body(16, color: PK.ink, weight: FontWeight.w800)),
                  IconButton(onPressed: () => Navigator.pop(d), icon: const Icon(Icons.close_rounded, size: 20)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        'HungryKya Kitchen',
                        style: AppTheme.body(18, color: Colors.black, weight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Center(
                      child: Text(
                        'KITCHEN ORDER TICKET (KOT)',
                        style: AppTheme.body(11, color: Colors.black54, weight: FontWeight.w800).copyWith(letterSpacing: 1.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Colors.black26, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order #: ${o.orderNo}', style: AppTheme.body(13, color: Colors.black, weight: FontWeight.w800)),
                        Text(fmtTime(o.createdAt), style: AppTheme.body(12, color: Colors.black87)),
                      ],
                    ),
                    Text('Date: ${fmtDate(o.createdAt)}', style: AppTheme.body(12, color: Colors.black87)),
                    Text('Kitchen: ${o.vendorName}', style: AppTheme.body(12, color: Colors.black87)),
                    const SizedBox(height: 8),
                    Text('Customer: ${o.customerName}', style: AppTheme.body(13, color: Colors.black, weight: FontWeight.w700)),
                    Text('Phone: +91 ${o.phone}', style: AppTheme.body(12, color: Colors.black87)),
                    Text('Address: ${o.address}${o.landmark.isEmpty ? '' : ', ${o.landmark}'}', style: AppTheme.body(11.5, color: Colors.black87)),
                    if (o.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Note: ${o.note}', style: AppTheme.body(12, color: Colors.black, weight: FontWeight.w800)),
                    ],
                    const SizedBox(height: 10),
                    const Divider(color: Colors.black26, thickness: 1),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('ITEM', style: AppTheme.body(11.5, color: Colors.black54, weight: FontWeight.w800))),
                        SizedBox(width: 40, child: Text('QTY', textAlign: TextAlign.center, style: AppTheme.body(11.5, color: Colors.black54, weight: FontWeight.w800))),
                        Text('AMT', style: AppTheme.body(11.5, color: Colors.black54, weight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final i in o.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(i.name, style: AppTheme.body(13, color: Colors.black, weight: FontWeight.w600))),
                            SizedBox(width: 40, child: Text('${i.qty}', textAlign: TextAlign.center, style: AppTheme.body(13, color: Colors.black, weight: FontWeight.w800))),
                            Text(rupees(i.total), style: AppTheme.body(13, color: Colors.black, weight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    const Divider(color: Colors.black26, thickness: 1),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Subtotal', style: AppTheme.body(12, color: Colors.black87)),
                      Text(rupees(o.subtotal), style: AppTheme.body(12, color: Colors.black87)),
                    ]),
                    if (o.couponDiscount > 0)
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Discount (${o.couponCode})', style: AppTheme.body(12, color: Colors.black87)),
                        Text('- ${rupees(o.couponDiscount)}', style: AppTheme.body(12, color: Colors.black87)),
                      ]),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Delivery', style: AppTheme.body(12, color: Colors.black87)),
                      Text(rupees(o.deliveryFee), style: AppTheme.body(12, color: Colors.black87)),
                    ]),
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('GRAND TOTAL', style: AppTheme.body(14, color: Colors.black, weight: FontWeight.w900)),
                      Text(rupees(o.total), style: AppTheme.body(15, color: Colors.black, weight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Payment: ${o.isUpi ? 'PREPAID UPI' : 'CASH ON DELIVERY'} (${PayStatus.label(o.paymentStatus).toUpperCase()})',
                        style: AppTheme.body(11.5, color: Colors.black87, weight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Colors.black26, thickness: 1),
                    Center(
                      child: Text('Thank you for ordering with HungryKya!', style: AppTheme.body(11, color: Colors.black54)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PK.ink,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  try {
                    web.window.print();
                  } catch (_) {}
                },
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Print Receipt / KOT'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> advanceOrder(BuildContext context, OrderModel o, String status) async {
  try {
    await Db.setOrderStatus(o, status);
    if (context.mounted) showToast(context, 'Order #${o.orderNo} → ${OrderStatus.label(status)}');
  } catch (e) {
    if (context.mounted) showToast(context, authErrorText(e), error: true);
  }
}

class OrdersManager extends StatefulWidget {
  final List<OrderModel> orders;
  final bool isAdmin;
  final String initialFilter;
  const OrdersManager({super.key, required this.orders, required this.isAdmin, this.initialFilter = 'all'});

  @override
  State<OrdersManager> createState() => _OrdersManagerState();
}

class _OrdersManagerState extends State<OrdersManager> {
  late String _filter = widget.initialFilter;
  String _q = '';

  bool _match(OrderModel o, String f) => switch (f) {
        'new' => o.status == OrderStatus.placed,
        'active' => o.isActive && o.status != OrderStatus.placed,
        'verify' => o.paymentStatus == PayStatus.verification,
        'house' => !o.isVendorOrder,
        'vendor' => o.isVendorOrder,
        'delivered' => o.status == OrderStatus.delivered,
        'cancelled' => o.status == OrderStatus.cancelled,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('all', 'All'),
      ('new', 'New'),
      ('active', 'In progress'),
      if (widget.isAdmin) ('verify', 'Verify payment'),
      if (widget.isAdmin) ('house', 'Our kitchen'),
      if (widget.isAdmin) ('vendor', 'Vendor orders'),
      ('delivered', 'Delivered'),
      ('cancelled', 'Cancelled'),
    ];
    final q = _q.trim().toLowerCase();
    final list = widget.orders.where((o) {
      if (!_match(o, _filter)) return false;
      if (q.isEmpty) return true;
      return o.orderNo.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.phone.contains(q) ||
          o.vendorName.toLowerCase().contains(q) ||
          o.upiRef.toLowerCase().contains(q);
    }).toList();

    return PanelPage(children: [
      PageHeader(title: 'Orders', subtitle: '${widget.orders.length} orders · updates live'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (k, label) in filters)
          ChoiceChip(
            selected: _filter == k,
            showCheckmark: false,
            onSelected: (_) => setState(() => _filter = k),
            label: Text('$label  ${widget.orders.where((o) => _match(o, k)).length}'),
          ),
      ]),
      const SizedBox(height: 14),
      SizedBox(
        width: 420,
        child: TextField(
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(
            isDense: true,
            hintText: 'Search order no, customer, phone, UTR…',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
      ),
      const SizedBox(height: 18),
      if (list.isEmpty)
        const PanelCard(child: EmptyState(emoji: '🧾', title: 'No orders here', body: 'New orders will appear here instantly.'))
      else
        for (final o in list) _OrderRow(o: o, isAdmin: widget.isAdmin),
    ]);
  }
}

class _OrderRow extends StatelessWidget {
  final OrderModel o;
  final bool isAdmin;
  const _OrderRow({required this.o, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    // Vendor orders are accepted / prepared / delivered by the vendor only.
    final kitchenControls = !isAdmin || !o.isVendorOrder;
    final next = kitchenControls ? OrderStatus.next(o.status) : null;
    final m = MediaQuery.sizeOf(context).width < 900;
    final isNew = o.status == OrderStatus.placed;

    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('#${o.orderNo}', style: AppTheme.body(15, color: PK.ink, weight: FontWeight.w800)),
        if (isNew) const Pill('NEW', color: PK.flame, solid: true),
        Pill(OrderStatus.label(o.status), color: OrderStatus.color(o.status)),
        Pill('${o.isUpi ? 'UPI' : 'COD'} · ${PayStatus.label(o.paymentStatus)}', color: PayStatus.color(o.paymentStatus)),
      ]),
      const SizedBox(height: 6),
      Text(
        '${o.customerName} · ${o.phone}${isAdmin ? ' · ${o.vendorName}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.body(13.5, color: PK.ink, weight: FontWeight.w600),
      ),
      const SizedBox(height: 3),
      Text(
        '${o.items.map((i) => '${i.qty}× ${i.name}').join(', ')} · ${timeAgo(o.createdAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.body(12.5, color: PK.muted),
      ),
    ]);

    final right = Row(mainAxisSize: MainAxisSize.min, children: [
      Text(rupees(o.total), style: AppTheme.body(16, color: PK.ink, weight: FontWeight.w800)),
      const SizedBox(width: 14),
      if (next != null)
        ElevatedButton(
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          onPressed: () => advanceOrder(context, o, next),
          child: Text(nextActionLabel(o.status)),
        )
      else if (!kitchenControls && o.isActive)
        const Pill('Vendor handles', color: PK.violet, icon: Icons.storefront_rounded),
    ]);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Hoverable(
        onTap: () => showOrderDetail(context, o.id, isAdmin: isAdmin),
        builder: (h) => AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isNew ? PK.flame.withOpacity(.5) : (h ? PK.amber.withOpacity(.5) : PK.line), width: isNew ? 1.4 : 1),
          ),
          child: m
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [info, const SizedBox(height: 12), right])
              : Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: OrderStatus.color(o.status).withOpacity(.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(OrderStatus.icon(o.status), color: OrderStatus.color(o.status)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: info),
                  const SizedBox(width: 14),
                  right,
                ]),
        ),
      ),
    );
  }
}

Future<void> showOrderDetail(BuildContext context, String orderId, {required bool isAdmin}) => showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
          child: StreamBuilder<OrderModel?>(
            stream: Db.order(orderId),
            builder: (c, snap) {
              if (!snap.hasData) return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
              final o = snap.data;
              if (o == null) return const SizedBox(height: 200, child: Center(child: Text('Order not found')));
              return _OrderDetail(o: o, isAdmin: isAdmin);
            },
          ),
        ),
      ),
    );

class _OrderDetail extends StatelessWidget {
  final OrderModel o;
  final bool isAdmin;
  const _OrderDetail({required this.o, required this.isAdmin});

  Future<void> _setPay(BuildContext context, String status) async {
    try {
      await Db.setPaymentStatus(o.id, status);
      if (context.mounted) showToast(context, 'Payment marked as ${PayStatus.label(status).toLowerCase()}');
    } catch (e) {
      if (context.mounted) showToast(context, authErrorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kitchenControls = !isAdmin || !o.isVendorOrder;
    final next = OrderStatus.next(o.status);
    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title.toUpperCase(), style: AppTheme.body(11.5, color: PK.muted, weight: FontWeight.w800).copyWith(letterSpacing: 1.6)),
            const SizedBox(height: 10),
            child,
          ]),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 12, 20),
        decoration: const BoxDecoration(color: PK.bg, border: Border(bottom: BorderSide(color: PK.line))),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Order #${o.orderNo}', style: AppTheme.body(20, color: PK.ink, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${fmtDateTime(o.createdAt)} · ${o.vendorName}', style: AppTheme.body(13, color: PK.muted)),
            ]),
          ),
          Pill(OrderStatus.label(o.status), color: OrderStatus.color(o.status)),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Print KOT / Bill Receipt',
            onPressed: () => showPrintReceiptDialog(context, o),
            icon: const Icon(Icons.print_rounded, size: 20),
          ),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
      ),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            section(
              'Customer',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.customerName, style: AppTheme.body(15.5, color: PK.ink, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('+91 ${o.phone}', style: AppTheme.body(14, color: PK.ink)),
                  IconButton(
                    tooltip: 'Call',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => launchUrl(Uri.parse('tel:+91${o.phone}')),
                    icon: const Icon(Icons.call_rounded, size: 18, color: PK.green),
                  ),
                  IconButton(
                    tooltip: 'WhatsApp',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => launchUrl(Uri.parse('https://wa.me/91${o.phone}'), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.chat_rounded, size: 18, color: PK.green),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Clipboard.setData(ClipboardData(text: o.phone)),
                    icon: const Icon(Icons.copy_rounded, size: 16, color: PK.muted),
                  ),
                ]),
                if (o.email.isNotEmpty) Text(o.email, style: AppTheme.body(13.5, color: PK.muted)),
                const SizedBox(height: 6),
                Text([o.address, o.landmark, o.pincode].where((e) => e.isNotEmpty).join(', '),
                    style: AppTheme.body(14, color: PK.ink, height: 1.5)),
                if (o.hasLocation)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(o.mapsUrl), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.map_rounded, size: 18, color: PK.blue),
                      label: const Text('Open location in Google Maps'),
                    ),
                  ),
                if (o.note.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: PK.amber.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
                    child: Text('Note: ${o.note}', style: AppTheme.body(13.5, color: PK.ink, weight: FontWeight.w600)),
                  ),
              ]),
            ),
            section(
              'Items',
              Column(children: [
                for (final i in o.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      VegMark(isVeg: i.isVeg, size: 13),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${i.name}  × ${i.qty}', style: AppTheme.body(14, color: PK.ink))),
                      Text(rupees(i.total), style: AppTheme.body(14, color: PK.ink, weight: FontWeight.w600)),
                    ]),
                  ),
                const Divider(height: 20),
                BillRow('Item total', rupees(o.subtotal)),
                if (o.couponDiscount > 0) BillRow('Coupon ${o.couponCode}', '− ${rupees(o.couponDiscount)}', color: PK.green),
                BillRow('Delivery fee', rupees(o.deliveryFee)),
                BillRow('Customer pays', rupees(o.total), bold: true),
                if (o.isVendorOrder) ...[
                  const Divider(height: 20),
                  BillRow('Food value (after discount)', rupees(o.foodTotal)),
                  BillRow('HungryKya commission (${(o.commissionRate * 100).toStringAsFixed(0)}%)', '− ${rupees(o.commissionAmount)}', color: PK.flame),
                  BillRow('Vendor payout', rupees(o.vendorPayout), bold: true, color: PK.green),
                ],
              ]),
            ),
            section(
              'Payment',
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(o.isUpi ? 'UPI' : 'Cash on delivery', style: AppTheme.body(14.5, color: PK.ink, weight: FontWeight.w700)),
                  Pill(PayStatus.label(o.paymentStatus), color: PayStatus.color(o.paymentStatus)),
                ]),
                if (o.upiRef.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    SelectableText('UTR: ${o.upiRef}', style: AppTheme.body(14, color: PK.ink, weight: FontWeight.w600)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Clipboard.setData(ClipboardData(text: o.upiRef)),
                      icon: const Icon(Icons.copy_rounded, size: 16, color: PK.muted),
                    ),
                  ]),
                  if (isAdmin && o.paymentStatus == PayStatus.verification)
                    Text('Match this UTR and amount ${rupees(o.total)} in your bank / UPI app before marking paid.',
                        style: AppTheme.body(12.5, color: PK.muted)),
                ],
                if (isAdmin) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (o.paymentStatus != PayStatus.paid)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: PK.green, foregroundColor: Colors.white),
                        onPressed: () => _setPay(context, PayStatus.paid),
                        icon: const Icon(Icons.verified_rounded, size: 18),
                        label: const Text('Mark as paid'),
                      ),
                    if (o.paymentStatus == PayStatus.verification || o.paymentStatus == PayStatus.pending)
                      OutlinedButton.icon(
                        onPressed: () => _setPay(context, PayStatus.failed),
                        icon: const Icon(Icons.close_rounded, size: 18, color: PK.red),
                        label: const Text('Payment not received'),
                      ),
                    if (o.paymentStatus == PayStatus.paid && o.status == OrderStatus.cancelled)
                      OutlinedButton(onPressed: () => _setPay(context, PayStatus.refunded), child: const Text('Mark refunded')),
                  ]),
                ],
              ]),
            ),
            section(
              'Status timeline',
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final h in o.statusHistory)
                  Chip(
                    avatar: Icon(OrderStatus.icon(toStr(h['status'])), size: 16, color: OrderStatus.color(toStr(h['status']))),
                    label: Text('${OrderStatus.label(toStr(h['status']))} · ${fmtTime(toDate(h['at']))}'),
                  ),
              ]),
            ),
          ]),
        ),
      ),
      if (o.isActive && !kitchenControls)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: PK.violet.withOpacity(.06), border: const Border(top: BorderSide(color: PK.line))),
          child: Row(children: [
            const Icon(Icons.storefront_rounded, color: PK.violet),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${o.vendorName} accepts, prepares and delivers this order from their vendor portal. You can verify the payment above.',
                  style: AppTheme.body(13, color: PK.ink, weight: FontWeight.w600)),
            ),
          ]),
        ),
      if (o.isActive && kitchenControls)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: PK.line))),
          child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: PK.red),
              onPressed: () async {
                if (await confirmDialog(context, title: 'Cancel order #${o.orderNo}?', message: 'The customer will see this order as cancelled.', confirm: 'Cancel order', destructive: true)) {
                  if (context.mounted) await advanceOrder(context, o, OrderStatus.cancelled);
                }
              },
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Cancel order'),
            ),
            if (next != null)
              ElevatedButton.icon(
                onPressed: () => advanceOrder(context, o, next),
                icon: Icon(OrderStatus.icon(next), size: 18),
                label: Text(nextActionLabel(o.status)),
              ),
          ]),
        ),
    ]);
  }
}
