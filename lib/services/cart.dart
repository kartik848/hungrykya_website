import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class CartLine {
  Product product;
  int qty;
  CartLine(this.product, this.qty);
  double get total => product.finalPrice * qty;
  double get mrp => product.price * qty;
}

/// Single-kitchen cart (like Zomato): items from one vendor per order,
/// so each order maps to exactly one kitchen and one commission line.
class Cart extends ChangeNotifier {
  static const _key = 'hk_cart_v1';
  final Map<String, CartLine> _lines = {};

  List<CartLine> get lines => _lines.values.toList();
  bool get isEmpty => _lines.isEmpty;
  int get count => _lines.values.fold(0, (a, l) => a + l.qty);
  double get subtotal => _lines.values.fold(0.0, (a, l) => a + l.total);
  double get mrpTotal => _lines.values.fold(0.0, (a, l) => a + l.mrp);
  double get saleSavings => mrpTotal - subtotal;
  String? get vendorId => _lines.isEmpty ? null : _lines.values.first.product.vendorId;
  String? get vendorName => _lines.isEmpty ? null : _lines.values.first.product.vendorName;

  int qtyOf(String productId) => _lines[productId]?.qty ?? 0;

  bool conflictsWith(Product p) => _lines.isNotEmpty && vendorId != p.vendorId;

  void add(Product p) {
    final l = _lines[p.id];
    if (l == null) {
      _lines[p.id] = CartLine(p, 1);
    } else {
      l.qty++;
    }
    _changed();
  }

  void decrement(Product p) {
    final l = _lines[p.id];
    if (l == null) return;
    if (--l.qty <= 0) _lines.remove(p.id);
    _changed();
  }

  void replaceWith(Product p) {
    _lines.clear();
    add(p);
  }

  void clear() {
    _lines.clear();
    _changed();
  }

  /// Refresh prices from live product data and drop items that went unavailable.
  void sync(List<Product> live) {
    if (_lines.isEmpty || live.isEmpty) return;
    final byId = {for (final p in live) p.id: p};
    var changed = false;
    for (final id in _lines.keys.toList()) {
      final p = byId[id];
      if (p == null || !p.isAvailable) {
        _lines.remove(id);
        changed = true;
      } else {
        _lines[id]!.product = p;
        changed = true;
      }
    }
    if (changed) _changed();
  }

  void _changed() {
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_lines.values.map((l) => {'p': l.product.toJson(), 'q': l.qty}).toList()));
    } catch (_) {}
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      for (final e in (jsonDecode(raw) as List)) {
        final p = Product.fromJson(Map<String, dynamic>.from(e['p'] as Map));
        _lines[p.id] = CartLine(p, (e['q'] as num).toInt());
      }
    } catch (_) {
      _lines.clear();
    }
  }
}
