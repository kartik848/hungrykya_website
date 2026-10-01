import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

final _inr0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _inr2 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

String rupees(num v) => v == v.roundToDouble() ? _inr0.format(v) : _inr2.format(v);

double round2(num v) => (v * 100).round() / 100;

String fmtDateTime(DateTime? d) => d == null ? '—' : DateFormat('d MMM yyyy, h:mm a').format(d);
String fmtDate(DateTime? d) => d == null ? '—' : DateFormat('d MMM yyyy').format(d);
String fmtTime(DateTime? d) => d == null ? '' : DateFormat('h:mm a').format(d);

String timeAgo(DateTime? d) {
  if (d == null) return 'just now';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) return '${diff.inDays} d ago';
  return fmtDate(d);
}

// Lenient readers for Firestore maps (fields may be missing or stored as the wrong numeric type).
double toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
bool toBool(dynamic v, [bool fallback = false]) => v is bool ? v : fallback;
String toStr(dynamic v) => v == null ? '' : '$v';
DateTime? toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v);
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

String normalizePhone(String v) {
  var d = v.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
  return d;
}

String? validatePhone(String? v) =>
    RegExp(r'^[6-9]\d{9}$').hasMatch(normalizePhone(v ?? '')) ? null : 'Enter a valid 10-digit mobile number';

String? validateRequired(String? v, [String what = 'This field']) => (v ?? '').trim().isEmpty ? '$what is required' : null;
