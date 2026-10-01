import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'cart.dart';
import 'db.dart';

/// Live storefront data shared by every customer-facing screen.
class StoreData extends ChangeNotifier {
  final Cart cart;
  final _subs = <StreamSubscription>[];

  List<Product> products = [];
  List<BannerModel> banners = [];
  List<Offer> offers = [];
  List<CategoryModel> categoryDocs = [];
  StoreSettings settings = const StoreSettings();
  bool loaded = false;
  String? error;

  StoreData(this.cart) {
    _subs.add(Db.liveProducts().listen((p) {
      products = p;
      loaded = true;
      cart.sync(p);
      notifyListeners();
    }, onError: _onError));
    _subs.add(Db.allBanners().listen((b) {
      banners = b.where((e) => e.isLive).toList();
      notifyListeners();
    }, onError: _onError));
    _subs.add(Db.allOffers().listen((o) {
      offers = o.where((e) => e.active).toList();
      notifyListeners();
    }, onError: _onError));
    _subs.add(Db.allCategories().listen((c) {
      categoryDocs = c;
      notifyListeners();
    }, onError: (_) {}));
    _subs.add(Db.settings().listen((s) {
      settings = s;
      notifyListeners();
    }, onError: _onError));
  }

  void _onError(Object e) {
    error = e.toString();
    loaded = true;
    notifyListeners();
  }

  /// Categories that have dishes, in the admin's order; categories that only
  /// exist on dishes (not created in admin) come last.
  List<String> get categories {
    final withDishes = {for (final p in products) p.category};
    final hidden = {for (final c in categoryDocs) if (!c.active) c.name};
    final ordered = [for (final c in categoryDocs) if (c.active && withDishes.contains(c.name)) c.name];
    final seen = {...ordered, ...hidden};
    return [...ordered, for (final p in products) if (seen.add(p.category)) p.category];
  }

  /// Admin-set photo for a category, if any.
  String categoryImage(String name) => categoryDocs.where((c) => c.name == name).map((c) => c.imageUrl).firstOrNull ?? '';

  /// Dishes visible on the website (their category isn't hidden).
  List<Product> get visibleProducts {
    final hidden = {for (final c in categoryDocs) if (!c.active) c.name};
    return hidden.isEmpty ? products : products.where((p) => !hidden.contains(p.category)).toList();
  }

  List<BannerModel> get heroBanners => banners.where((b) => !b.isBottom).toList();
  List<BannerModel> get bottomBanners => banners.where((b) => b.isBottom).toList();

  List<Product> get bestsellers => products.where((p) => p.isBestseller && p.isAvailable).toList();

  /// vendorId → kitchen name, HungryKya's own kitchen first.
  Map<String, String> get kitchens {
    final m = <String, String>{};
    for (final p in products.where((p) => p.isHouse)) {
      m[p.vendorId] = p.vendorName;
    }
    for (final p in products.where((p) => !p.isHouse)) {
      m[p.vendorId] = p.vendorName;
    }
    return m;
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
