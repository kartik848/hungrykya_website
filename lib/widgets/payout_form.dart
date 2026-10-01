import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/models.dart';
import '../services/bank.dart';

/// Holds the payout fields so the parent form can read them on submit.
class PayoutFormController {
  final accountName = TextEditingController();
  final accountNumber = TextEditingController();
  final confirmNumber = TextEditingController();
  final ifsc = TextEditingController();
  final upi = TextEditingController();
  String bankName = '';
  String branch = '';

  PayoutFormController([PayoutAccount? initial]) {
    if (initial == null) return;
    accountName.text = initial.accountName;
    accountNumber.text = initial.accountNumber;
    confirmNumber.text = initial.accountNumber;
    ifsc.text = initial.ifsc;
    upi.text = initial.upiId;
    bankName = initial.bankName;
    branch = initial.branch;
  }

  PayoutAccount get value => PayoutAccount(
        accountName: accountName.text.trim(),
        accountNumber: accountNumber.text.replaceAll(' ', ''),
        ifsc: ifsc.text.trim().toUpperCase(),
        bankName: bankName,
        branch: branch,
        upiId: upi.text.trim(),
      );

  void dispose() {
    for (final c in [accountName, accountNumber, confirmNumber, ifsc, upi]) {
      c.dispose();
    }
  }
}

/// Bank account + UPI fields with IFSC → bank/branch lookup. Place inside a [Form].
class PayoutFields extends StatefulWidget {
  final PayoutFormController controller;
  final bool requireBank;
  const PayoutFields({super.key, required this.controller, this.requireBank = true});

  @override
  State<PayoutFields> createState() => _PayoutFieldsState();
}

class _PayoutFieldsState extends State<PayoutFields> {
  bool _checking = false;
  String? _ifscError;

  PayoutFormController get c => widget.controller;

  Future<void> _lookup(String v) async {
    final code = v.trim().toUpperCase();
    if (!BankService.isValidIfsc(code)) {
      setState(() {
        c.bankName = '';
        c.branch = '';
        _ifscError = null;
      });
      return;
    }
    setState(() => _checking = true);
    final info = await BankService.lookupIfsc(code);
    if (!mounted || c.ifsc.text.trim().toUpperCase() != code) return;
    setState(() {
      _checking = false;
      c.bankName = info?.bank ?? '';
      c.branch = info == null ? '' : [info.branch, info.city].where((e) => e.isNotEmpty).toSet().join(', ');
      _ifscError = info == null ? 'IFSC not found — please check it' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ok = dark ? HK.veg : PK.green;
    final muted = dark ? HK.muted : PK.muted;
    String? need(String? v, String what) => widget.requireBank && (v ?? '').trim().isEmpty ? '$what is required' : null;
    final anyBank = c.accountNumber.text.trim().isNotEmpty || c.ifsc.text.trim().isNotEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextFormField(
        controller: c.accountName,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Account holder name', prefixIcon: Icon(Icons.person_outline_rounded)),
        validator: (v) => need(v, 'Account holder name') ?? (anyBank && (v ?? '').trim().isEmpty ? 'Account holder name is required' : null),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: c.accountNumber,
        keyboardType: TextInputType.number,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(labelText: 'Bank account number', prefixIcon: Icon(Icons.account_balance_outlined)),
        validator: (v) {
          final n = (v ?? '').replaceAll(' ', '');
          if (n.isEmpty) return need(v, 'Account number');
          return RegExp(r'^\d{9,18}$').hasMatch(n) ? null : 'Enter a valid account number (9–18 digits)';
        },
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: c.confirmNumber,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Re-enter account number', prefixIcon: Icon(Icons.account_balance_outlined)),
        validator: (v) =>
            (v ?? '').replaceAll(' ', '') != c.accountNumber.text.replaceAll(' ', '') ? 'Account numbers do not match' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: c.ifsc,
        textCapitalization: TextCapitalization.characters,
        maxLength: 11,
        onChanged: (v) {
          setState(() {});
          _lookup(v);
        },
        decoration: InputDecoration(
          labelText: 'IFSC code',
          hintText: 'e.g. SBIN0001234',
          counterText: '',
          prefixIcon: const Icon(Icons.qr_code_rounded),
          suffixIcon: _checking
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
              : (c.bankName.isNotEmpty ? Icon(Icons.check_circle_rounded, color: ok) : null),
        ),
        validator: (v) {
          final code = (v ?? '').trim().toUpperCase();
          if (code.isEmpty) return need(v, 'IFSC') ?? (c.accountNumber.text.trim().isNotEmpty ? 'IFSC is required' : null);
          if (!BankService.isValidIfsc(code)) return 'IFSC looks like ABCD0123456 (11 characters)';
          return _ifscError;
        },
      ),
      if (c.bankName.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text('✓ ${c.bankName}${c.branch.isEmpty ? '' : ' · ${c.branch}'}',
              style: AppTheme.body(12.5, color: ok, weight: FontWeight.w700)),
        ),
      const SizedBox(height: 12),
      TextFormField(
        controller: c.upi,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: 'UPI ID (recommended — fastest payouts)',
          hintText: 'e.g. 9876543210@ybl',
          prefixIcon: const Icon(Icons.bolt_rounded),
          helperText: widget.requireBank ? null : 'Add a bank account, a UPI ID, or both',
          helperStyle: TextStyle(color: muted),
        ),
        validator: (v) {
          final u = (v ?? '').trim();
          if (u.isNotEmpty && !BankService.isValidUpi(u)) return 'Enter a valid UPI ID, like name@bank';
          if (!widget.requireBank && u.isEmpty && c.accountNumber.text.trim().isEmpty) return 'Add a bank account or a UPI ID';
          return null;
        },
      ),
    ]);
  }
}
