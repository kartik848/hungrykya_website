import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/db.dart';
import '../../widgets/common.dart';
import '../panel/panel_widgets.dart';

/// Day-end settlement of vendor earnings (delivered orders − 2% commission).
class PayoutsManager extends StatelessWidget {
  final List<Vendor> vendors;
  final List<OrderModel> orders;
  const PayoutsManager({super.key, required this.vendors, required this.orders});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Payout>>(
      stream: Db.allPayouts(),
      builder: (c, snap) {
        final history = snap.data ?? const <Payout>[];
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final monthStart = DateTime(now.year, now.month);
        final pendingByVendor = <String, List<OrderModel>>{};
        for (final o in orders.where((o) => o.awaitingPayout)) {
          pendingByVendor.putIfAbsent(o.vendorId, () => []).add(o);
        }
        final toPay = [
          for (final v in vendors)
            if ((pendingByVendor[v.id] ?? const []).isNotEmpty) (v, pendingByVendor[v.id]!),
        ]..sort((a, b) => _sum(b.$2).compareTo(_sum(a.$2)));
        final missingDetails = vendors.where((v) => v.isApproved && v.payout.isEmpty).toList();
        final pendingTotal = toPay.fold(0.0, (a, e) => a + _sum(e.$2));
        final paidToday = history.where((p) => p.paidAt != null && !p.paidAt!.isBefore(today)).fold(0.0, (a, p) => a + p.amount);
        final paidMonth = history.where((p) => p.paidAt != null && !p.paidAt!.isBefore(monthStart)).fold(0.0, (a, p) => a + p.amount);

        return PanelPage(children: [
          const PageHeader(title: 'Vendor payouts', subtitle: 'At day end, pay each kitchen its earnings (delivered orders minus 2% commission).'),
          ResponsiveGrid(minItemWidth: 220, children: [
            StatCard(label: 'To pay now', value: rupees(pendingTotal), icon: Icons.schedule_rounded, color: PK.amber, sub: '${toPay.length} vendor${toPay.length == 1 ? '' : 's'}'),
            StatCard(label: 'Paid today', value: rupees(paidToday), icon: Icons.today_rounded, color: PK.green),
            StatCard(label: 'Paid this month', value: rupees(paidMonth), icon: Icons.calendar_month_rounded, color: PK.blue),
            StatCard(label: 'Commission kept (all time)', value: rupees(history.fold(0.0, (a, p) => a + p.commission)), icon: Icons.percent_rounded, color: PK.violet),
          ]),
          const SizedBox(height: 20),
          if (missingDetails.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: PK.red.withOpacity(.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: PK.red.withOpacity(.25))),
              child: Text(
                '⚠️ No bank / UPI details yet: ${missingDetails.map((v) => v.businessName).join(', ')}. Ask them to add it in Vendor dashboard → Earnings & payouts.',
                style: AppTheme.body(13, color: PK.ink, weight: FontWeight.w600, height: 1.45),
              ),
            ),
          PanelCard(
            title: 'To pay',
            child: toPay.isEmpty
                ? const EmptyState(emoji: '✅', title: 'All settled', body: 'Every delivered vendor order has been paid out.')
                : Column(children: [for (final (v, list) in toPay) _ToPayRow(vendor: v, orders: list)]),
          ),
          const SizedBox(height: 16),
          PanelCard(
            title: 'Payout history',
            child: history.isEmpty
                ? Text('Payouts you mark as paid will be listed here.', style: AppTheme.body(14, color: PK.muted))
                : Column(children: [
                    for (final p in history.take(100))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: PK.green.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.payments_rounded, size: 18, color: PK.green),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.vendorName, style: AppTheme.body(14, color: PK.ink, weight: FontWeight.w700)),
                              Text(
                                '${fmtDateTime(p.paidAt)} · ${p.methodLabel} · ${p.orderIds.length} orders${p.reference.isEmpty ? '' : ' · Ref ${p.reference}'}',
                                style: AppTheme.body(12, color: PK.muted),
                              ),
                            ]),
                          ),
                          Text(rupees(p.amount), style: AppTheme.body(15, color: PK.ink, weight: FontWeight.w800)),
                        ]),
                      ),
                  ]),
          ),
        ]);
      },
    );
  }
}

double _sum(List<OrderModel> l) => l.fold(0.0, (a, o) => a + o.vendorPayout);

class _ToPayRow extends StatelessWidget {
  final Vendor vendor;
  final List<OrderModel> orders;
  const _ToPayRow({required this.vendor, required this.orders});

  @override
  Widget build(BuildContext context) {
    final amount = _sum(orders);
    final commission = orders.fold(0.0, (a, o) => a + o.commissionAmount);
    final dates = orders.map((o) => o.createdAt).whereType<DateTime>().toList()..sort();
    final p = vendor.payout;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: PK.line)),
      child: Wrap(spacing: 20, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(vendor.businessName, style: AppTheme.body(16, color: PK.ink, weight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              '${orders.length} delivered order${orders.length == 1 ? '' : 's'}'
              '${dates.isEmpty ? '' : ' · ${fmtDate(dates.first)}${dates.length > 1 && !DateUtils.isSameDay(dates.first, dates.last) ? ' – ${fmtDate(dates.last)}' : ''}'}',
              style: AppTheme.body(12.5, color: PK.muted),
            ),
            Text('Commission kept: ${rupees(commission)}', style: AppTheme.body(12.5, color: PK.violet, weight: FontWeight.w600)),
          ]),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
          child: p.isEmpty
              ? Text('No bank / UPI details', style: AppTheme.body(13, color: PK.red, weight: FontWeight.w700))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (p.hasUpi) _CopyLine(Icons.bolt_rounded, 'UPI', p.upiId),
                  if (p.hasBank) ...[
                    _CopyLine(Icons.account_balance_rounded, 'A/C', p.accountNumber),
                    _CopyLine(Icons.qr_code_rounded, 'IFSC', p.ifsc),
                    Text('${p.accountName} · ${p.bankName}', style: AppTheme.body(12, color: PK.muted)),
                  ],
                ]),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(rupees(amount), style: AppTheme.body(22, color: PK.ink, weight: FontWeight.w800)),
          const SizedBox(width: 14),
          ElevatedButton.icon(
            onPressed: () => showDialog(context: context, builder: (_) => _PayDialog(vendor: vendor, orders: orders)),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Pay & mark paid'),
          ),
        ]),
      ]),
    );
  }
}

class _CopyLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _CopyLine(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: value));
          showToast(context, '$label copied');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: PK.muted),
            const SizedBox(width: 6),
            Text('$label: ', style: AppTheme.body(13, color: PK.muted)),
            Flexible(child: Text(value, style: AppTheme.body(13, color: PK.ink, weight: FontWeight.w700))),
            const SizedBox(width: 6),
            const Icon(Icons.copy_rounded, size: 13, color: PK.muted),
          ]),
        ),
      );
}

class _PayDialog extends StatefulWidget {
  final Vendor vendor;
  final List<OrderModel> orders;
  const _PayDialog({required this.vendor, required this.orders});
  @override
  State<_PayDialog> createState() => _PayDialogState();
}

class _PayDialogState extends State<_PayDialog> {
  late String _method = widget.vendor.payout.hasUpi ? 'upi' : (widget.vendor.payout.hasBank ? 'bank' : 'cash');
  final _ref = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ref.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_method != 'cash' && _ref.text.trim().length < 6) {
      showToast(context, 'Enter the UTR / transaction reference of your payment', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await Db.settleVendor(vendor: widget.vendor, paidOrders: widget.orders, method: _method, reference: _ref.text, note: _note.text);
      if (mounted) {
        Navigator.pop(context);
        showToast(context, 'Payout of ${rupees(_sum(widget.orders))} to ${widget.vendor.businessName} recorded');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, authErrorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vendor;
    final p = v.payout;
    final amount = _sum(widget.orders);
    final upiLink = 'upi://pay?pa=${p.upiId}&pn=${Uri.encodeComponent(v.businessName)}&am=${amount.toStringAsFixed(2)}&cu=INR'
        '&tn=${Uri.encodeComponent('HungryKya payout')}';

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 860),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Pay ${v.businessName}', style: AppTheme.body(20, color: PK.ink, weight: FontWeight.w800))),
              IconButton(onPressed: _saving ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ]),
            const SizedBox(height: 6),
            Text(rupees(amount), style: AppTheme.body(34, color: PK.ink, weight: FontWeight.w800)),
            Text('${widget.orders.length} delivered orders · after 2% commission', style: AppTheme.body(13, color: PK.muted)),
            const SizedBox(height: 18),
            SegmentedButton<String>(
              segments: [
                if (p.hasUpi) const ButtonSegment(value: 'upi', icon: Icon(Icons.bolt_rounded), label: Text('UPI')),
                if (p.hasBank) const ButtonSegment(value: 'bank', icon: Icon(Icons.account_balance_rounded), label: Text('Bank')),
                const ButtonSegment(value: 'cash', icon: Icon(Icons.payments_rounded), label: Text('Cash')),
              ],
              selected: {_method},
              onSelectionChanged: (s) => setState(() => _method = s.first),
            ),
            const SizedBox(height: 16),
            if (_method == 'upi')
              Center(
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: PK.line)),
                    child: QrImageView(data: upiLink, size: 200, backgroundColor: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text('Scan with your phone’s UPI app — amount is pre-filled', style: AppTheme.body(12.5, color: PK.muted)),
                  _CopyLine(Icons.bolt_rounded, 'UPI', p.upiId),
                ]),
              ),
            if (_method == 'bank')
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: PK.bg, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _CopyLine(Icons.person_rounded, 'Name', p.accountName),
                  _CopyLine(Icons.account_balance_rounded, 'A/C', p.accountNumber),
                  _CopyLine(Icons.qr_code_rounded, 'IFSC', p.ifsc),
                  Text('${p.bankName}${p.branch.isEmpty ? '' : ' · ${p.branch}'}', style: AppTheme.body(12.5, color: PK.muted)),
                ]),
              ),
            const SizedBox(height: 16),
            if (_method != 'cash')
              TextField(
                controller: _ref,
                decoration: const InputDecoration(labelText: 'UTR / transaction reference', hintText: 'From your UPI or bank app', prefixIcon: Icon(Icons.tag_rounded)),
              ),
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'e.g. Payout for 1 Oct')),
            const SizedBox(height: 14),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Orders included (${widget.orders.length})', style: AppTheme.body(14, color: PK.ink, weight: FontWeight.w700)),
              children: [
                for (final o in widget.orders)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text('#${o.orderNo} · ${fmtDate(o.createdAt)}', style: AppTheme.body(13, color: PK.ink))),
                      Text(rupees(o.vendorPayout), style: AppTheme.body(13, color: PK.ink, weight: FontWeight.w700)),
                    ]),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: PK.green, foregroundColor: Colors.white),
                onPressed: _saving ? null : _confirm,
                icon: _saving ? const BtnSpinner(color: Colors.white) : const Icon(Icons.verified_rounded),
                label: Text('I have paid ${rupees(amount)} — mark as paid'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
