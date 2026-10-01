import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../services/location.dart';
import '../../services/store_data.dart';
import '../../services/sound_service.dart';
import '../../widgets/common.dart';
import '../panel/orders_manager.dart';
import '../panel/panel_widgets.dart';
import '../panel/products_manager.dart';

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

class AdminDashboard extends StatelessWidget {
  final List<OrderModel> orders;
  final List<Vendor> vendors;
  final List<AppUser> users;
  final void Function(int section, {String orderFilter}) onGo;
  const AdminDashboard({super.key, required this.orders, required this.vendors, required this.users, required this.onGo});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final live = orders.where((o) => o.status != OrderStatus.cancelled).toList();
    final todays = live.where((o) => o.createdAt != null && !o.createdAt!.isBefore(today)).toList();
    final delivered = orders.where((o) => o.status == OrderStatus.delivered).toList();
    final commission = delivered.where((o) => o.isVendorOrder).fold(0.0, (a, o) => a + o.commissionAmount);
    final verify = orders.where((o) => o.paymentStatus == PayStatus.verification).length;
    final newOrders = orders.where((o) => o.status == OrderStatus.placed).length;
    final active = orders.where((o) => o.isActive).length;
    final pendingVendors = vendors.where((v) => v.status == VendorStatus.pending).length;
    final customers = users.where((u) => u.role == 'customer').length;

    // Revenue for the last 7 days.
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final revenue = [
      for (final d in days) live.where((o) => o.createdAt != null && DateUtils.isSameDay(o.createdAt, d)).fold(0.0, (a, o) => a + o.total),
    ];
    final maxY = revenue.fold(0.0, (a, b) => b > a ? b : a);

    // Top items across non-cancelled orders.
    final qty = <String, int>{};
    for (final o in live) {
      for (final i in o.items) {
        qty[i.name] = (qty[i.name] ?? 0) + i.qty;
      }
    }
    final top = qty.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return PanelPage(children: [
      PageHeader(
        title: 'Dashboard',
        subtitle: DateFormat('EEEE, d MMMM yyyy').format(now),
        actions: [
          IconButton(
            tooltip: 'Test Order Chime',
            icon: const Icon(Icons.notifications_active_outlined, size: 20),
            onPressed: () {
              SoundService.playOrderAlert();
              showToast(context, '🔔 Order alert chime played');
            },
          ),
          OutlinedButton.icon(
            onPressed: () async {
              if (await confirmDialog(
                context,
                title: 'Load Full Demo Store?',
                message: 'This populates categories with photos, popular dishes, banners, offers and default store settings.',
                confirm: 'Load Demo Store',
              )) {
                try {
                  await Db.seedFullStore();
                  if (context.mounted) showToast(context, '✨ Complete demo store loaded successfully!');
                } catch (e) {
                  if (context.mounted) showToast(context, authErrorText(e), error: true);
                }
              }
            },
            icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
            label: const Text('Load Demo Store'),
          ),
          ElevatedButton.icon(
            onPressed: () => showProductEditor(context, isAdmin: true),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Dish'),
          ),
          OutlinedButton.icon(
            onPressed: () => launchUrl(Uri.base.replace(path: '/')),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open store'),
          ),
        ],
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PK.line),
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Quick Shortcuts:', style: AppTheme.body(13, color: PK.muted, weight: FontWeight.w700)),
            ActionChip(
              avatar: const Icon(Icons.restaurant_menu_rounded, size: 16, color: PK.flame),
              label: const Text('Menu'),
              onPressed: () => onGo(3),
            ),
            ActionChip(
              avatar: const Icon(Icons.category_rounded, size: 16, color: PK.blue),
              label: const Text('Categories'),
              onPressed: () => onGo(2),
            ),
            ActionChip(
              avatar: const Icon(Icons.receipt_long_rounded, size: 16, color: PK.green),
              label: Text('Orders (${orders.length})'),
              onPressed: () => onGo(1),
            ),
            ActionChip(
              avatar: const Icon(Icons.local_offer_rounded, size: 16, color: PK.violet),
              label: const Text('Coupons & Sales'),
              onPressed: () => onGo(6),
            ),
            ActionChip(
              avatar: const Icon(Icons.view_carousel_rounded, size: 16, color: PK.amber),
              label: const Text('Banners'),
              onPressed: () => onGo(4),
            ),
            ActionChip(
              avatar: const Icon(Icons.storefront_rounded, size: 16, color: PK.ink),
              label: Text('Vendors (${vendors.length})'),
              onPressed: () => onGo(7),
            ),
            ActionChip(
              avatar: const Icon(Icons.account_balance_wallet_rounded, size: 16, color: PK.green),
              label: const Text('Payouts'),
              onPressed: () => onGo(8),
            ),
          ],
        ),
      ),
      ResponsiveGrid(minItemWidth: 230, children: [
        StatCard(
            label: "Today's sales",
            value: rupees(todays.fold(0.0, (a, o) => a + o.total)),
            icon: Icons.currency_rupee_rounded,
            color: PK.green,
            sub: '${todays.length} orders today'),
        StatCard(
            label: 'New orders',
            value: '$newOrders',
            icon: Icons.notifications_active_rounded,
            color: PK.flame,
            sub: '$active active right now',
            onTap: () => onGo(1, orderFilter: 'new')),
        StatCard(
            label: 'Payments to verify',
            value: '$verify',
            icon: Icons.verified_user_rounded,
            color: PK.blue,
            sub: 'UPI references submitted',
            onTap: () => onGo(1, orderFilter: 'verify')),
        StatCard(
            label: 'Vendor applications',
            value: '$pendingVendors',
            icon: Icons.storefront_rounded,
            color: PK.violet,
            sub: '${vendors.where((v) => v.isApproved).length} approved vendors',
            onTap: () => onGo(7)),
        StatCard(
            label: 'Gross sales (delivered)',
            value: rupees(delivered.fold(0.0, (a, o) => a + o.total)),
            icon: Icons.trending_up_rounded,
            color: PK.amber,
            sub: '${delivered.length} delivered orders'),
        StatCard(
            label: 'Commission earned (2%)',
            value: rupees(commission),
            icon: Icons.percent_rounded,
            color: PK.green,
            sub: 'From delivered vendor orders',
            onTap: () => onGo(7)),
        StatCard(
            label: 'Customers',
            value: '$customers',
            icon: Icons.people_alt_rounded,
            color: PK.blue,
            sub: '${users.where((u) => u.blocked).length} blocked',
            onTap: () => onGo(9)),
      ]),
      const SizedBox(height: 20),
      LayoutBuilder(builder: (c, cons) {
        final chart = PanelCard(
          title: 'Sales — last 7 days',
          child: SizedBox(
            height: 260,
            child: BarChart(BarChartData(
              maxY: maxY <= 0 ? 100 : maxY * 1.2,
              alignment: BarChartAlignment.spaceAround,
              gridData:
                  FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: PK.line, strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    getTitlesWidget: (v, meta) =>
                        Text(NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹').format(v), style: AppTheme.body(11, color: PK.muted)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, meta) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(DateFormat('E').format(days[v.toInt()]), style: AppTheme.body(11.5, color: PK.muted, weight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => PK.ink,
                  getTooltipItem: (g, gi, rod, ri) =>
                      BarTooltipItem(rupees(rod.toY), AppTheme.body(12.5, color: Colors.white, weight: FontWeight.w700)),
                ),
              ),
              barGroups: [
                for (var i = 0; i < 7; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: revenue[i],
                      width: 26,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      gradient: const LinearGradient(colors: [PK.flame, PK.amber], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                    ),
                  ]),
              ],
            )),
          ),
        );
        final topCard = PanelCard(
          title: 'Top dishes',
          child: top.isEmpty
              ? Text('No orders yet', style: AppTheme.body(14, color: PK.muted))
              : Column(children: [
                  for (final (i, e) in top.take(6).indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: PK.amber.withOpacity(.15), borderRadius: BorderRadius.circular(8)),
                          child: Text('${i + 1}', style: AppTheme.body(12, color: PK.ink, weight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(14, color: PK.ink))),
                        Text('${e.value} sold', style: AppTheme.body(13, color: PK.muted, weight: FontWeight.w600)),
                      ]),
                    ),
                ]),
        );
        if (cons.maxWidth < 900) return Column(children: [chart, const SizedBox(height: 16), topCard]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: chart),
          const SizedBox(width: 16),
          Expanded(child: topCard),
        ]);
      }),
      const SizedBox(height: 16),
      PanelCard(
        title: 'Recent orders',
        trailing: TextButton(onPressed: () => onGo(1), child: const Text('View all')),
        child: orders.isEmpty
            ? Text('Orders will show up here as soon as customers start ordering.', style: AppTheme.body(14, color: PK.muted))
            : Column(children: [
                for (final o in orders.take(6)) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    onTap: () => showOrderDetail(context, o.id, isAdmin: true),
                    leading: CircleAvatar(
                      backgroundColor: OrderStatus.color(o.status).withOpacity(.12),
                      child: Icon(OrderStatus.icon(o.status), color: OrderStatus.color(o.status), size: 20),
                    ),
                    title: Row(
                      children: [
                        Text('#${o.orderNo} · ${o.customerName}', style: AppTheme.body(14, color: PK.ink, weight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        if (o.status == OrderStatus.placed) const Pill('NEW', color: PK.flame, solid: true),
                        if (o.paymentStatus == PayStatus.verification)
                          const Pill('Verify UPI', color: PK.blue, solid: true),
                      ],
                    ),
                    subtitle: Text(
                      '${o.items.map((i) => '${i.qty}× ${i.name}').join(', ')} · ${o.vendorName} · ${timeAgo(o.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(12.5, color: PK.muted),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(rupees(o.total), style: AppTheme.body(14, color: PK.ink, weight: FontWeight.w800)),
                          Text(OrderStatus.label(o.status), style: AppTheme.body(11.5, color: OrderStatus.color(o.status), weight: FontWeight.w700)),
                        ]),
                        if (o.status == OrderStatus.placed && (!o.isVendorOrder)) ...[
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PK.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () => advanceOrder(context, o, OrderStatus.confirmed),
                            child: const Text('Accept'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ]),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Offers & sales
// ---------------------------------------------------------------------------

class OffersManager extends StatefulWidget {
  const OffersManager({super.key});
  @override
  State<OffersManager> createState() => _OffersManagerState();
}

class _OffersManagerState extends State<OffersManager> {
  String _saleCategory = '__all';
  final _salePct = TextEditingController(text: '20');
  bool _busy = false;

  @override
  void dispose() {
    _salePct.dispose();
    super.dispose();
  }

  Future<void> _runSale(int pct) async {
    final cat = _saleCategory == '__all' ? null : _saleCategory;
    final ok = await confirmDialog(
      context,
      title: pct == 0 ? 'End sale?' : 'Start $pct% sale?',
      message: pct == 0
          ? 'Removes the sale discount from ${cat ?? 'every item'}.'
          : 'Sets a $pct% discount on ${cat == null ? 'every item on the menu' : 'all "$cat" items'}. Customers see the sale price instantly.',
      confirm: pct == 0 ? 'End sale' : 'Start sale',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final n = await Db.applySale(category: cat, percent: pct);
      if (mounted) showToast(context, pct == 0 ? 'Sale ended on $n items' : '$pct% sale is live on $n items 🔥');
    } catch (e) {
      if (mounted) showToast(context, authErrorText(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final cats = context.watch<StoreData>().categories;
    final onSale = context.watch<StoreData>().products.where((p) => p.onSale).length;
    return StreamBuilder<List<Offer>>(
      stream: Db.allOffers(),
      builder: (c, snap) {
        final offers = snap.data ?? [];
        return PanelPage(children: [
          PageHeader(
            title: 'Offers & sales',
            subtitle: 'Run a flash sale on the menu, or create coupon codes for checkout.',
            actions: [ElevatedButton.icon(onPressed: () => _editOffer(null), icon: const Icon(Icons.add_rounded), label: const Text('New coupon'))],
          ),
          PanelCard(
            title: 'Flash sale',
            trailing: Pill('$onSale items on sale', color: onSale > 0 ? PK.flame : PK.muted),
            child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<String>(
                  value: cats.contains(_saleCategory) ? _saleCategory : '__all',
                  decoration: const InputDecoration(labelText: 'Apply to', isDense: true),
                  items: [
                    const DropdownMenuItem(value: '__all', child: Text('Entire menu')),
                    for (final c in cats) DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _saleCategory = v ?? '__all'),
                ),
              ),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _salePct,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Discount', suffixText: '%', isDense: true),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _busy
                    ? null
                    : () {
                        final pct = int.tryParse(_salePct.text.trim()) ?? 0;
                        if (pct <= 0 || pct > 90) {
                          showToast(context, 'Enter a discount between 1 and 90%', error: true);
                          return;
                        }
                        _runSale(pct);
                      },
                icon: const Icon(Icons.local_fire_department_rounded, size: 18),
                label: const Text('Start sale'),
              ),
              OutlinedButton(onPressed: _busy ? null : () => _runSale(0), child: const Text('End sale')),
            ]),
          ),
          const SizedBox(height: 16),
          PanelCard(
            title: 'Coupon codes',
            child: offers.isEmpty
                ? EmptyState(
                    emoji: '🎟️',
                    title: 'No coupons yet',
                    body: 'Coupons appear on the home page and can be applied at checkout.',
                    action: ElevatedButton(onPressed: () => _editOffer(null), child: const Text('Create coupon')),
                  )
                : Column(children: [
                    for (final o in offers)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: PK.line)),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration:
                                BoxDecoration(gradient: const LinearGradient(colors: [PK.amber, PK.flame]), borderRadius: BorderRadius.circular(10)),
                            child: Text('${o.discountPercent}%', style: AppTheme.body(16, color: Colors.black, weight: FontWeight.w900)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(o.code, style: AppTheme.body(15, color: PK.ink, weight: FontWeight.w800).copyWith(letterSpacing: 1.2)),
                              Text(
                                [o.title, if (o.minOrder > 0) 'min ${rupees(o.minOrder)}', if (o.maxDiscount > 0) 'max ${rupees(o.maxDiscount)} off']
                                    .join(' · '),
                                style: AppTheme.body(12.5, color: PK.muted),
                              ),
                            ]),
                          ),
                          Switch(value: o.active, onChanged: (v) => Db.saveOffer(o.id, {'active': v})),
                          IconButton(onPressed: () => _editOffer(o), icon: const Icon(Icons.edit_outlined, size: 20)),
                          IconButton(
                            onPressed: () async {
                              if (await confirmDialog(context,
                                  title: 'Delete ${o.code}?',
                                  message: 'Customers will no longer be able to use it.',
                                  confirm: 'Delete',
                                  destructive: true)) {
                                await Db.deleteOffer(o.id);
                              }
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: PK.red),
                          ),
                        ]),
                      ),
                  ]),
          ),
        ]);
      },
    );
  }

  Future<void> _editOffer(Offer? o) async {
    final code = TextEditingController(text: o?.code);
    final title = TextEditingController(text: o?.title);
    final desc = TextEditingController(text: o?.description);
    final pct = TextEditingController(text: '${o?.discountPercent ?? 10}');
    final max = TextEditingController(text: o == null || o.maxDiscount == 0 ? '' : o.maxDiscount.toStringAsFixed(0));
    final min = TextEditingController(text: o == null || o.minOrder == 0 ? '' : o.minOrder.toStringAsFixed(0));
    var active = o?.active ?? true;
    final form = GlobalKey<FormState>();
    await showDialog(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(o == null ? 'New coupon' : 'Edit coupon'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: code,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Code', hintText: 'HUNGRY20'),
                    validator: (v) => RegExp(r'^[A-Za-z0-9]{3,20}$').hasMatch((v ?? '').trim()) ? null : '3–20 letters/numbers',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Title', hintText: 'Flat 20% off on your order')),
                  const SizedBox(height: 12),
                  TextFormField(controller: desc, decoration: const InputDecoration(labelText: 'Description (optional)')),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: pct,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Discount', suffixText: '%'),
                        validator: (v) {
                          final n = int.tryParse((v ?? '').trim());
                          return n == null || n < 1 || n > 90 ? '1–90' : null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextFormField(
                            controller: max,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Max off (₹)', hintText: 'no cap'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextFormField(
                            controller: min,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Min order (₹)', hintText: '0'))),
                  ]),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero, title: const Text('Active'), value: active, onChanged: (v) => setD(() => active = v)),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                try {
                  await Db.saveOffer(o?.id, {
                    'code': code.text.trim().toUpperCase(),
                    'title': title.text.trim(),
                    'description': desc.text.trim(),
                    'discountPercent': int.parse(pct.text.trim()),
                    'maxDiscount': double.tryParse(max.text.trim()) ?? 0,
                    'minOrder': double.tryParse(min.text.trim()) ?? 0,
                    'active': active,
                  });
                  if (d.mounted) Navigator.pop(d);
                } catch (e) {
                  if (d.mounted) showToast(d, authErrorText(e), error: true);
                }
              },
              child: const Text('Save coupon'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vendors
// ---------------------------------------------------------------------------

class VendorsManager extends StatefulWidget {
  final List<Vendor> vendors;
  final List<OrderModel> orders;
  const VendorsManager({super.key, required this.vendors, required this.orders});
  @override
  State<VendorsManager> createState() => _VendorsManagerState();
}

class _VendorsManagerState extends State<VendorsManager> {
  String _tab = VendorStatus.pending;

  Future<void> _set(Vendor v, String status) async {
    var reason = '';
    if (status == VendorStatus.rejected || status == VendorStatus.blocked) {
      final c = TextEditingController();
      final r = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(status == VendorStatus.rejected ? 'Reject ${v.businessName}?' : 'Block ${v.businessName}?'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                status == VendorStatus.blocked
                    ? 'Their menu will be hidden from the store and they will not be able to manage it.'
                    : 'The vendor will see this reason on their dashboard.',
                style: AppTheme.body(13.5, color: PK.muted),
              ),
              const SizedBox(height: 12),
              TextField(controller: c, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason (shown to vendor)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: PK.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(d, c.text.trim()),
              child: Text(status == VendorStatus.rejected ? 'Reject' : 'Block'),
            ),
          ],
        ),
      );
      if (r == null) return;
      reason = r;
    }
    try {
      await Db.setVendorStatus(v, status, reason: reason);
      if (mounted) showToast(context, '${v.businessName}: ${VendorStatus.label(status)}');
    } catch (e) {
      if (mounted) showToast(context, authErrorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [VendorStatus.pending, VendorStatus.approved, VendorStatus.rejected, VendorStatus.blocked];
    final list = widget.vendors.where((v) => v.status == _tab).toList();
    return PanelPage(children: [
      const PageHeader(title: 'Vendors', subtitle: 'Approve new kitchens, track their 2% commission, block if needed.'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final t in tabs)
          ChoiceChip(
            selected: _tab == t,
            showCheckmark: false,
            onSelected: (_) => setState(() => _tab = t),
            label: Text('${VendorStatus.label(t)}  ${widget.vendors.where((v) => v.status == t).length}'),
          ),
      ]),
      const SizedBox(height: 18),
      if (list.isEmpty)
        PanelCard(
          child: EmptyState(
            emoji: '🏪',
            title: 'Nothing here',
            body: _tab == VendorStatus.pending
                ? 'New vendor applications from the website will appear here.'
                : 'No ${VendorStatus.label(_tab).toLowerCase()} vendors.',
          ),
        )
      else
        ResponsiveGrid(minItemWidth: 420, children: [for (final v in list) _VendorCard(v: v, orders: widget.orders, onSet: (s) => _set(v, s))]),
    ]);
  }
}

class _VendorCard extends StatelessWidget {
  final Vendor v;
  final List<OrderModel> orders;
  final ValueChanged<String> onSet;
  const _VendorCard({required this.v, required this.orders, required this.onSet});

  @override
  Widget build(BuildContext context) {
    final mine = orders.where((o) => o.vendorId == v.id).toList();
    final delivered = mine.where((o) => o.status == OrderStatus.delivered).toList();
    final sales = delivered.fold(0.0, (a, o) => a + o.foodTotal);
    final commission = delivered.fold(0.0, (a, o) => a + o.commissionAmount);
    final payout = delivered.fold(0.0, (a, o) => a + o.vendorPayout);

    Widget line(IconData i, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 16, color: PK.muted),
            const SizedBox(width: 8),
            Expanded(child: SelectableText(t, style: AppTheme.body(13.5, color: PK.ink))),
          ]),
        );

    final statusColor = switch (v.status) {
      VendorStatus.approved => PK.green,
      VendorStatus.pending => PK.amber,
      _ => PK.red,
    };

    return PanelCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [PK.amber, PK.flame])),
            alignment: Alignment.center,
            child: Text(v.businessName.isEmpty ? '?' : v.businessName[0].toUpperCase(),
                style: AppTheme.body(20, color: Colors.black, weight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.businessName, style: AppTheme.body(16.5, color: PK.ink, weight: FontWeight.w800)),
              Text('${v.ownerName} · ${v.cuisine}', style: AppTheme.body(13, color: PK.muted)),
            ]),
          ),
          Pill(VendorStatus.label(v.status), color: statusColor),
        ]),
        const SizedBox(height: 16),
        line(Icons.mail_outline_rounded, v.email),
        line(Icons.phone_outlined, '+91 ${v.phone}'),
        line(Icons.location_on_outlined, v.location),
        if (v.fssai.isNotEmpty) line(Icons.verified_outlined, 'FSSAI: ${v.fssai}'),
        if (v.payout.hasUpi) line(Icons.bolt_rounded, 'UPI: ${v.payout.upiId}'),
        if (v.payout.hasBank)
          line(Icons.account_balance_outlined, '${v.payout.accountName} · A/C ${v.payout.accountNumber} · ${v.payout.ifsc}${v.payout.bankName.isEmpty ? '' : ' (${v.payout.bankName})'}'),
        if (v.payout.isEmpty) line(Icons.warning_amber_rounded, 'No bank / UPI details added'),
        line(Icons.event_outlined, 'Applied ${fmtDateTime(v.createdAt)}'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (v.consentAccepted ? PK.green : PK.red).withOpacity(.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(v.consentAccepted ? Icons.task_alt_rounded : Icons.error_outline_rounded, color: v.consentAccepted ? PK.green : PK.red, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                v.consentAccepted
                    ? 'Agreed to ${(v.commissionRate * 100).toStringAsFixed(0)}% commission on ${fmtDateTime(v.consentAt)} (terms ${v.consentVersion})'
                    : 'Commission consent missing',
                style: AppTheme.body(12.5, color: PK.ink, weight: FontWeight.w600),
              ),
            ),
          ]),
        ),
        if (v.rejectionReason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Reason: ${v.rejectionReason}', style: AppTheme.body(12.5, color: PK.red)),
        ],
        if (v.isApproved) ...[
          const SizedBox(height: 14),
          Row(children: [
            _Mini('Orders', '${mine.length}'),
            _Mini('Sales', rupees(sales)),
            _Mini('Commission', rupees(commission), color: PK.green),
            _Mini('Payout', rupees(payout)),
          ]),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (v.status != VendorStatus.approved)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: PK.green, foregroundColor: Colors.white),
              onPressed: () => onSet(VendorStatus.approved),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text(v.status == VendorStatus.blocked ? 'Unblock' : 'Approve'),
            ),
          if (v.status == VendorStatus.pending)
            OutlinedButton.icon(
              onPressed: () => onSet(VendorStatus.rejected),
              icon: const Icon(Icons.close_rounded, size: 18, color: PK.red),
              label: const Text('Reject'),
            ),
          if (v.status == VendorStatus.approved)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: PK.red),
              onPressed: () => onSet(VendorStatus.blocked),
              icon: const Icon(Icons.block_rounded, size: 18),
              label: const Text('Block vendor'),
            ),
          if (v.isApproved)
            TextButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => Dialog(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 800),
                    child: ProductsManager(isAdmin: false, vendorId: v.id, vendorName: v.businessName),
                  ),
                ),
              ),
              icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
              label: const Text('View menu'),
            ),
        ]),
      ]),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Mini(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: AppTheme.body(14.5, color: color ?? PK.ink, weight: FontWeight.w800)),
          Text(label, style: AppTheme.body(11.5, color: PK.muted)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Customers
// ---------------------------------------------------------------------------

class CustomersManager extends StatefulWidget {
  final List<AppUser> users;
  final List<OrderModel> orders;
  const CustomersManager({super.key, required this.users, required this.orders});
  @override
  State<CustomersManager> createState() => _CustomersManagerState();
}

class _CustomersManagerState extends State<CustomersManager> {
  String _q = '';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final me = context.read<AuthService>().user?.uid;
    final q = _q.trim().toLowerCase();
    final list = widget.users.where((u) {
      if (_filter == 'blocked' && !u.blocked) return false;
      if (_filter == 'vendor' && u.role != 'vendor') return false;
      if (_filter == 'customer' && u.role != 'customer') return false;
      return q.isEmpty || u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q) || u.phone.contains(q);
    }).toList();
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    return PanelPage(children: [
      PageHeader(title: 'Customers', subtitle: '${widget.users.length} accounts · ${widget.users.where((u) => u.blocked).length} blocked'),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (final (k, l) in [('all', 'All'), ('customer', 'Customers'), ('vendor', 'Vendors'), ('blocked', 'Blocked')])
          ChoiceChip(selected: _filter == k, showCheckmark: false, label: Text(l), onSelected: (_) => setState(() => _filter = k)),
        const SizedBox(width: 8),
        SizedBox(
          width: 320,
          child: TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(isDense: true, hintText: 'Search name, email, phone', prefixIcon: Icon(Icons.search_rounded)),
          ),
        ),
      ]),
      const SizedBox(height: 18),
      PanelCard(
        padding: EdgeInsets.zero,
        child: list.isEmpty
            ? const EmptyState(emoji: '👥', title: 'No accounts found', body: 'Customers appear here once they sign up.')
            : Column(children: [
                for (final (i, u) in list.indexed) ...[
                  if (i > 0) const Divider(),
                  _UserRow(user: u, orders: widget.orders.where((o) => o.userId == u.id).toList(), wide: wide, isMe: u.id == me),
                ],
              ]),
      ),
    ]);
  }
}

class _UserRow extends StatelessWidget {
  final AppUser user;
  final List<OrderModel> orders;
  final bool wide;
  final bool isMe;
  const _UserRow({required this.user, required this.orders, required this.wide, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final spent = orders.where((o) => o.status != OrderStatus.cancelled).fold(0.0, (a, o) => a + o.total);
    final u = user;
    final action = isMe
        ? const Pill('You', color: PK.blue)
        : u.blocked
            ? OutlinedButton.icon(
                onPressed: () => Db.setUserBlocked(u.id, false),
                icon: const Icon(Icons.lock_open_rounded, size: 18, color: PK.green),
                label: const Text('Unblock'),
              )
            : OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: PK.red),
                onPressed: () async {
                  if (await confirmDialog(context,
                      title: 'Block ${u.name.isEmpty ? u.email : u.name}?',
                      message: 'They will not be able to place new orders until you unblock them.',
                      confirm: 'Block',
                      destructive: true)) {
                    try {
                      await Db.setUserBlocked(u.id, true);
                    } catch (e) {
                      if (context.mounted) showToast(context, authErrorText(e), error: true);
                    }
                  }
                },
                icon: const Icon(Icons.block_rounded, size: 18),
                label: const Text('Block'),
              );

    final who = Row(children: [
      CircleAvatar(
        backgroundColor: (u.blocked ? PK.red : PK.amber).withOpacity(.15),
        child:
            Text(u.name.isEmpty ? '?' : u.name[0].toUpperCase(), style: TextStyle(color: u.blocked ? PK.red : PK.ink, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(u.name.isEmpty ? '(no name)' : u.name, style: AppTheme.body(14.5, color: PK.ink, weight: FontWeight.w700)),
            if (u.role == 'vendor') const Pill('Vendor', color: PK.violet),
            if (u.blocked) const Pill('Blocked', color: PK.red),
          ]),
          Text([u.email, if (u.phone.isNotEmpty) u.phone].join(' · '), style: AppTheme.body(12.5, color: PK.muted)),
        ]),
      ),
    ]);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: wide
          ? Row(children: [
              Expanded(flex: 4, child: who),
              Expanded(child: Text('${orders.length} orders', style: AppTheme.body(13.5, color: PK.ink))),
              Expanded(child: Text(rupees(spent), style: AppTheme.body(13.5, color: PK.ink, weight: FontWeight.w700))),
              Expanded(child: Text('Joined ${fmtDate(u.createdAt)}', style: AppTheme.body(12.5, color: PK.muted))),
              SizedBox(width: 130, child: Align(alignment: Alignment.centerRight, child: action)),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              who,
              const SizedBox(height: 8),
              Row(children: [
                Text('${orders.length} orders · ${rupees(spent)}', style: AppTheme.body(12.5, color: PK.muted)),
                const Spacer(),
                action,
              ]),
            ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class SettingsManager extends StatefulWidget {
  const SettingsManager({super.key});
  @override
  State<SettingsManager> createState() => _SettingsManagerState();
}

class _SettingsManagerState extends State<SettingsManager> {
  final _form = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{};
  bool _loaded = false;
  bool _saving = false;

  TextEditingController _ctl(String k) => _c.putIfAbsent(k, TextEditingController.new);

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : '$v';

  void _load(StoreSettings s) {
    if (_loaded) return;
    _loaded = true;
    _ctl('upiId').text = s.upiId;
    _ctl('payeeName').text = s.payeeName;
    _ctl('deliveryFee').text = _n(s.deliveryFee);
    _ctl('freeDeliveryAbove').text = _n(s.freeDeliveryAbove);
    _ctl('minOrder').text = _n(s.minOrder);
    _ctl('etaMinutes').text = '${s.etaMinutes}';
    _ctl('contactPhone').text = s.contactPhone;
    _ctl('contactEmail').text = s.contactEmail;
    _ctl('address').text = s.address;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await Db.saveSettings({
        'upiId': _ctl('upiId').text.trim(),
        'payeeName': _ctl('payeeName').text.trim(),
        'deliveryFee': double.tryParse(_ctl('deliveryFee').text.trim()) ?? 0,
        'freeDeliveryAbove': double.tryParse(_ctl('freeDeliveryAbove').text.trim()) ?? 0,
        'minOrder': double.tryParse(_ctl('minOrder').text.trim()) ?? 0,
        'etaMinutes': int.tryParse(_ctl('etaMinutes').text.trim()) ?? 35,
        'contactPhone': _ctl('contactPhone').text.trim(),
        'contactEmail': _ctl('contactEmail').text.trim(),
        'address': _ctl('address').text.trim(),
      });
      if (mounted) showToast(context, 'Settings saved');
    } catch (e) {
      if (mounted) showToast(context, authErrorText(e), error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<StoreData>().settings;
    _load(s);
    Widget field(String k, String label,
            {String? hint, bool number = false, String? prefix, String? suffix, FormFieldValidator<String>? validator}) =>
        TextFormField(
          controller: _ctl(k),
          keyboardType: number ? TextInputType.number : null,
          validator: validator,
          decoration: InputDecoration(labelText: label, hintText: hint, prefixText: prefix, suffixText: suffix),
        );

    return PanelPage(children: [
      PageHeader(
        title: 'Settings',
        subtitle: 'Store, payment and delivery settings. Changes go live instantly.',
        actions: [ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const BtnSpinner() : const Text('Save changes'))],
      ),
      PanelCard(
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: (s.storeOpen ? PK.green : PK.red).withOpacity(.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(s.storeOpen ? Icons.storefront_rounded : Icons.nightlight_round, color: s.storeOpen ? PK.green : PK.red),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.storeOpen ? 'Store is open' : 'Store is closed', style: AppTheme.body(16, color: PK.ink, weight: FontWeight.w800)),
              Text(s.storeOpen ? 'Customers can place orders.' : 'Customers can browse but cannot order.', style: AppTheme.body(13, color: PK.muted)),
            ]),
          ),
          Switch(value: s.storeOpen, onChanged: (v) => Db.saveSettings({'storeOpen': v})),
        ]),
      ),
      const SizedBox(height: 16),
      Form(
        key: _form,
        child: LayoutBuilder(builder: (c, cons) {
          final payment = PanelCard(
            title: 'UPI payments',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              field('upiId', 'UPI ID',
                  hint: 'name@bank',
                  validator: (v) => RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid UPI ID'),
              const SizedBox(height: 12),
              field('payeeName', 'Payee name (shown in UPI app)', validator: (v) => validateRequired(v, 'Payee name')),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/images/upi_qr.jpg', width: 110, height: 110)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Customers get a QR with the exact amount pre-filled for this UPI ID, plus “Pay with UPI app” buttons on mobile. '
                    'Your HungryKya scanner (left) is shown as a backup. After paying, customers enter their UTR and you verify it under Orders → Verify payment.',
                    style: AppTheme.body(12.5, color: PK.muted, height: 1.5),
                  ),
                ),
              ]),
            ]),
          );
          final delivery = PanelCard(
            title: 'Delivery & orders',
            child: Column(children: [
              Row(children: [
                Expanded(child: field('deliveryFee', 'Delivery fee', number: true, prefix: '₹ ')),
                const SizedBox(width: 12),
                Expanded(child: field('freeDeliveryAbove', 'Free delivery above', number: true, prefix: '₹ ', hint: '0 = never')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: field('minOrder', 'Minimum order', number: true, prefix: '₹ ')),
                const SizedBox(width: 12),
                Expanded(child: field('etaMinutes', 'Avg. delivery time', number: true, suffix: 'min')),
              ]),
            ]),
          );
          final contact = PanelCard(
            title: 'Contact (shown in footer & order page)',
            child: Column(children: [
              field('contactPhone', 'Support phone'),
              const SizedBox(height: 12),
              field('contactEmail', 'Support email'),
              const SizedBox(height: 12),
              field('address', 'Kitchen address'),
            ]),
          );
          if (cons.maxWidth < 900) {
            return Column(children: [payment, const SizedBox(height: 16), delivery, const SizedBox(height: 16), contact]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: payment),
            const SizedBox(width: 16),
            Expanded(child: Column(children: [delivery, const SizedBox(height: 16), contact])),
          ]);
        }),
      ),
      const SizedBox(height: 16),
      _DeliveryAreasCard(settings: s),
    ]);
  }
}

/// Where the store accepts orders from: cities/districts, pincodes and/or a
/// radius around the kitchen. An address matching any rule is accepted.
class _DeliveryAreasCard extends StatefulWidget {
  final StoreSettings settings;
  const _DeliveryAreasCard({required this.settings});
  @override
  State<_DeliveryAreasCard> createState() => _DeliveryAreasCardState();
}

class _DeliveryAreasCardState extends State<_DeliveryAreasCard> {
  late bool _restrict = widget.settings.restrictArea;
  late final List<String> _cities = [...widget.settings.serviceCities];
  late final List<String> _pins = [...widget.settings.servicePincodes];
  late double? _lat = widget.settings.kitchenLat;
  late double? _lng = widget.settings.kitchenLng;
  late final _radius = TextEditingController(
      text: widget.settings.radiusKm > 0 ? widget.settings.radiusKm.toStringAsFixed(widget.settings.radiusKm % 1 == 0 ? 0 : 1) : '');
  final _cityIn = TextEditingController();
  final _pinIn = TextEditingController();
  bool _saving = false;
  bool _locating = false;

  @override
  void dispose() {
    _radius.dispose();
    _cityIn.dispose();
    _pinIn.dispose();
    super.dispose();
  }

  void _addCities() {
    final parts = _cityIn.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    setState(() {
      for (final p in parts) {
        if (!_cities.any((c) => c.toLowerCase() == p.toLowerCase())) _cities.add(p);
      }
      _cityIn.clear();
    });
  }

  void _addPins() {
    final parts = _pinIn.text.split(RegExp(r'[\s,]+')).map((e) => e.trim()).where((e) => e.isNotEmpty);
    final bad = parts.where((p) => !RegExp(r'^\d{6}$').hasMatch(p)).toList();
    if (bad.isNotEmpty) {
      showToast(context, 'Not a 6-digit pincode: ${bad.join(', ')}', error: true);
      return;
    }
    setState(() {
      for (final p in parts) {
        if (!_pins.contains(p)) _pins.add(p);
      }
      _pinIn.clear();
    });
  }

  Future<void> _locateKitchen() async {
    setState(() => _locating = true);
    try {
      final p = await LocationService.currentPosition();
      setState(() {
        _lat = p.lat;
        _lng = p.lng;
      });
    } catch (e) {
      if (mounted) showToast(context, e.toString(), error: true);
    }
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _save() async {
    final radius = double.tryParse(_radius.text.trim()) ?? 0;
    if (_restrict && _cities.isEmpty && _pins.isEmpty && (radius <= 0 || _lat == null)) {
      showToast(context, 'Add at least one city, pincode or a delivery radius — otherwise nobody can order.', error: true);
      return;
    }
    if (radius > 0 && _lat == null) {
      showToast(context, 'Set the kitchen location to use a delivery radius.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await Db.saveSettings({
        'restrictArea': _restrict,
        'serviceCities': _cities,
        'servicePincodes': _pins,
        'radiusKm': radius,
        'kitchenLat': _lat,
        'kitchenLng': _lng,
      });
      if (mounted) {
        showToast(context, _restrict ? 'Delivery areas saved — orders limited to these areas' : 'Saved — accepting orders from everywhere');
      }
    } catch (e) {
      if (mounted) showToast(context, authErrorText(e), error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _chips(List<String> items, Color color) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final i in items)
          InputChip(
            label: Text(i),
            backgroundColor: color.withOpacity(.08),
            side: BorderSide(color: color.withOpacity(.35)),
            onDeleted: () => setState(() => items.remove(i)),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final m = isMobile(context);
    Widget adder(TextEditingController c, String label, String hint, VoidCallback onAdd, {bool number = false}) => Row(children: [
          Expanded(
            child: TextField(
              controller: c,
              keyboardType: number ? TextInputType.number : null,
              textCapitalization: TextCapitalization.words,
              onSubmitted: (_) => onAdd(),
              decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(onPressed: onAdd, child: const Text('Add')),
        ]);

    final cities = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Cities / districts', style: AppTheme.body(14.5, color: PK.ink, weight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('Accept every address in these cities or districts.', style: AppTheme.body(12.5, color: PK.muted)),
      const SizedBox(height: 10),
      adder(_cityIn, 'City or district', 'e.g. Nagpur, Wardha', _addCities),
      const SizedBox(height: 10),
      _chips(_cities, PK.blue),
    ]);
    final pins = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Pincodes', style: AppTheme.body(14.5, color: PK.ink, weight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('Accept these exact pincodes (paste many separated by commas).', style: AppTheme.body(12.5, color: PK.muted)),
      const SizedBox(height: 10),
      adder(_pinIn, 'Pincode(s)', 'e.g. 440001, 440010', _addPins, number: true),
      const SizedBox(height: 10),
      _chips(_pins, PK.violet),
    ]);
    final radius = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Radius around kitchen', style: AppTheme.body(14.5, color: PK.ink, weight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('Accept customers whose GPS location is within this distance.', style: AppTheme.body(12.5, color: PK.muted)),
      const SizedBox(height: 10),
      Row(children: [
        SizedBox(
          width: 130,
          child: TextField(
            controller: _radius,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Radius', suffixText: 'km', isDense: true, hintText: '0 = off'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _locating ? null : _locateKitchen,
            icon: _locating ? const BtnSpinner(color: PK.ink) : const Icon(Icons.my_location_rounded, size: 18),
            label: Text(_lat == null ? 'Set kitchen location' : 'Update kitchen location', overflow: TextOverflow.ellipsis),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Text(
        _lat == null
            ? 'Kitchen location not set. Open this page at the kitchen and tap the button.'
            : 'Kitchen at ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
        style: AppTheme.body(12.5, color: _lat == null ? PK.red : PK.green, weight: FontWeight.w600),
      ),
    ]);

    return PanelCard(
      title: 'Delivery areas',
      trailing: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const BtnSpinner() : const Text('Save areas')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (_restrict ? PK.amber : PK.green).withOpacity(.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Icon(_restrict ? Icons.share_location_rounded : Icons.public_rounded, color: _restrict ? const Color(0xFFB86E00) : PK.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_restrict ? 'Only accept orders from selected areas' : 'Accepting orders from everywhere',
                    style: AppTheme.body(15, color: PK.ink, weight: FontWeight.w800)),
                Text(
                  _restrict
                      ? 'Customers outside these areas see “We don’t deliver here yet” and cannot place an order.'
                      : 'Turn on to limit orders to the cities, pincodes or radius below.',
                  style: AppTheme.body(12.5, color: PK.muted),
                ),
              ]),
            ),
            Switch(value: _restrict, onChanged: (v) => setState(() => _restrict = v)),
          ]),
        ),
        const SizedBox(height: 18),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _restrict ? 1 : .45,
          child: m
              ? Column(children: [cities, const SizedBox(height: 22), pins, const SizedBox(height: 22), radius])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: cities),
                  const SizedBox(width: 24),
                  Expanded(child: pins),
                  const SizedBox(width: 24),
                  Expanded(child: radius),
                ]),
        ),
      ]),
    );
  }
}
