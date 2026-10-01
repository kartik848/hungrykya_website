import 'dart:convert';

import 'package:http/http.dart' as http;

class IfscInfo {
  final String bank;
  final String branch;
  final String city;
  const IfscInfo({required this.bank, required this.branch, required this.city});
}

/// Bank lookups for vendor payout details.
class BankService {
  static final _cache = <String, IfscInfo?>{};

  static bool isValidIfsc(String v) => RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v.trim().toUpperCase());
  static bool isValidUpi(String v) => RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$').hasMatch(v.trim());

  /// Bank + branch for an IFSC code (Razorpay's free IFSC API). Null if unknown.
  static Future<IfscInfo?> lookupIfsc(String ifsc) async {
    final code = ifsc.trim().toUpperCase();
    if (!isValidIfsc(code)) return null;
    if (_cache.containsKey(code)) return _cache[code];
    try {
      final r = await http.get(Uri.https('ifsc.razorpay.com', '/$code')).timeout(const Duration(seconds: 10));
      if (r.statusCode == 404) return _cache[code] = null;
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      return _cache[code] = IfscInfo(
        bank: (m['BANK'] ?? '').toString(),
        branch: (m['BRANCH'] ?? '').toString(),
        city: (m['CITY'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
