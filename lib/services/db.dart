import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config.dart';
import '../core/fb.dart';
import '../models/models.dart';

/// All Firestore reads/writes. Queries deliberately use a single equality filter
/// (or a single orderBy) and sort client-side, so no composite indexes are needed.
class Db {
  static FirebaseFirestore get _fs => Fb.db;

  static CollectionReference<Map<String, dynamic>> get products => _fs.collection('products');
  static CollectionReference<Map<String, dynamic>> get banners => _fs.collection('banners');
  static CollectionReference<Map<String, dynamic>> get offers => _fs.collection('offers');
  static CollectionReference<Map<String, dynamic>> get orders => _fs.collection('orders');
  static CollectionReference<Map<String, dynamic>> get vendors => _fs.collection('vendors');
  static CollectionReference<Map<String, dynamic>> get users => _fs.collection('users');
  static DocumentReference<Map<String, dynamic>> get settingsDoc => _fs.collection('settings').doc('store');

  static int _byOrderThenName(Product a, Product b) {
    final c = a.sortOrder.compareTo(b.sortOrder);
    return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  // ---------- Products ----------

  /// Products visible in the store (their vendor is active).
  static Stream<List<Product>> liveProducts() => products
      .where('vendorActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Product.fromMap(d.id, d.data())).toList()..sort(_byOrderThenName));

  static Stream<List<Product>> allProducts() =>
      products.snapshots().map((s) => s.docs.map((d) => Product.fromMap(d.id, d.data())).toList()..sort(_byOrderThenName));

  static Stream<List<Product>> vendorProducts(String vendorId) => products
      .where('vendorId', isEqualTo: vendorId)
      .snapshots()
      .map((s) => s.docs.map((d) => Product.fromMap(d.id, d.data())).toList()..sort(_byOrderThenName));

  static Future<void> saveProduct(String? id, Map<String, dynamic> data) async {
    if (id == null) {
      await products.add({...data, 'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp()});
    } else {
      await products.doc(id).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  static Future<void> updateProduct(String id, Map<String, dynamic> data) =>
      products.doc(id).update({...data, 'updatedAt': FieldValue.serverTimestamp()});

  static Future<void> deleteProduct(String id) => products.doc(id).delete();

  /// Flash sale: set the same discount on every product in [category] (or all, when null).
  static Future<int> applySale({String? category, required int percent}) async {
    final snap = await products.get();
    final batch = _fs.batch();
    var n = 0;
    for (final d in snap.docs) {
      if (category != null && d.data()['category'] != category) continue;
      batch.update(d.reference, {'discountPercent': percent, 'updatedAt': FieldValue.serverTimestamp()});
      n++;
    }
    if (n > 0) await batch.commit();
    return n;
  }

  // ---------- Categories ----------

  static CollectionReference<Map<String, dynamic>> get categories => _fs.collection('categories');

  static Stream<List<CategoryModel>> allCategories() => categories.snapshots().map((s) => s.docs
      .map((d) => CategoryModel.fromMap(d.id, d.data()))
      .where((c) => c.name.isNotEmpty)
      .toList()
    ..sort((a, b) {
      final c = a.sortOrder.compareTo(b.sortOrder);
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }));

  /// Saves a category. Renaming also moves every dish in it to the new name.
  static Future<void> saveCategory(CategoryModel? old, Map<String, dynamic> data) async {
    if (old == null) {
      await categories.add({...data, 'createdAt': FieldValue.serverTimestamp()});
      return;
    }
    final batch = _fs.batch();
    batch.update(categories.doc(old.id), {...data, 'updatedAt': FieldValue.serverTimestamp()});
    final newName = data['name'] as String;
    if (newName != old.name) {
      final dishes = await products.where('category', isEqualTo: old.name).get();
      for (final d in dishes.docs) {
        batch.update(d.reference, {'category': newName});
      }
    }
    await batch.commit();
  }

  static Future<int> dishCount(String category) async => (await products.where('category', isEqualTo: category).get()).size;

  static Future<void> deleteCategory(String id) => categories.doc(id).delete();

  // ---------- Banners & offers ----------

  static Stream<List<BannerModel>> allBanners() => banners.snapshots().map((s) =>
      s.docs.map((d) => BannerModel.fromMap(d.id, d.data())).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)));

  static Future<void> saveBanner(String? id, Map<String, dynamic> data) =>
      id == null ? banners.add({...data, 'createdAt': FieldValue.serverTimestamp()}) : banners.doc(id).update(data);

  static Future<void> deleteBanner(String id) => banners.doc(id).delete();

  static Stream<List<Offer>> allOffers() =>
      offers.snapshots().map((s) => s.docs.map((d) => Offer.fromMap(d.id, d.data())).toList()..sort((a, b) => a.code.compareTo(b.code)));

  static Future<void> saveOffer(String? id, Map<String, dynamic> data) =>
      id == null ? offers.add({...data, 'createdAt': FieldValue.serverTimestamp()}) : offers.doc(id).update(data);

  static Future<void> deleteOffer(String id) => offers.doc(id).delete();

  static Future<Offer?> findOffer(String code) async {
    final s = await offers.where('code', isEqualTo: code.trim().toUpperCase()).limit(1).get();
    if (s.docs.isEmpty) return null;
    final o = Offer.fromMap(s.docs.first.id, s.docs.first.data());
    return o.active ? o : null;
  }

  // ---------- Settings ----------

  static Stream<StoreSettings> settings() => settingsDoc.snapshots().map((d) => StoreSettings.fromMap(d.data()));

  static Future<void> saveSettings(Map<String, dynamic> data) =>
      settingsDoc.set({...data, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

  // ---------- Orders ----------

  static List<OrderModel> _orders(QuerySnapshot<Map<String, dynamic>> s) => s.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList()
    ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));

  static Future<String> placeOrder(OrderModel o) async {
    final ref = orders.doc();
    await ref.set({
      ...o.toMap(),
      'statusHistory': [
        {'status': OrderStatus.placed, 'at': Timestamp.now()}
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Stream<OrderModel?> order(String id) =>
      orders.doc(id).snapshots().map((d) => d.exists ? OrderModel.fromMap(d.id, d.data()!) : null);

  static Stream<List<OrderModel>> userOrders(String uid) => orders.where('userId', isEqualTo: uid).snapshots().map(_orders);

  static Stream<List<OrderModel>> vendorOrders(String vendorId) => orders.where('vendorId', isEqualTo: vendorId).snapshots().map(_orders);

  static Stream<List<OrderModel>> allOrders({int limit = 1000}) =>
      orders.orderBy('createdAt', descending: true).limit(limit).snapshots().map(_orders);

  static Future<void> setOrderStatus(OrderModel o, String status) => orders.doc(o.id).update({
        'status': status,
        'statusHistory': FieldValue.arrayUnion([
          {'status': status, 'at': Timestamp.now()}
        ]),
        // Cash is collected at the door, so a delivered COD order is a paid one.
        if (status == OrderStatus.delivered && o.paymentMethod == 'cod') 'paymentStatus': PayStatus.paid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> setPaymentStatus(String id, String status) =>
      orders.doc(id).update({'paymentStatus': status, 'updatedAt': FieldValue.serverTimestamp()});

  static Future<void> submitUpiRef(String id, String ref) => orders.doc(id).update({
        'paymentStatus': PayStatus.verification,
        'upiRef': ref.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  static Future<void> switchToCod(String id) => orders.doc(id).update({
        'paymentMethod': 'cod',
        'paymentStatus': PayStatus.pending,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ---------- Vendors ----------

  static Stream<List<Vendor>> allVendors() => vendors.snapshots().map((s) => s.docs.map((d) => Vendor.fromMap(d.id, d.data())).toList()
    ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now())));

  static Stream<Vendor?> vendor(String id) => vendors.doc(id).snapshots().map((d) => d.exists ? Vendor.fromMap(d.id, d.data()!) : null);

  static Future<void> updateVendorProfile(String id, Map<String, dynamic> data) =>
      vendors.doc(id).update({...data, 'updatedAt': FieldValue.serverTimestamp()});

  /// Changes a vendor's status and shows/hides all of their products to match.
  static Future<void> setVendorStatus(Vendor v, String status, {String reason = ''}) async {
    final batch = _fs.batch();
    batch.update(vendors.doc(v.id), {
      'status': status,
      'rejectionReason': reason,
      if (status == VendorStatus.approved) 'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Blocking a vendor also blocks their login account from ordering.
    batch.set(users.doc(v.id), {'blocked': status == VendorStatus.blocked}, SetOptions(merge: true));
    final prods = await products.where('vendorId', isEqualTo: v.id).get();
    for (final p in prods.docs) {
      batch.update(p.reference, {'vendorActive': status == VendorStatus.approved, 'vendorName': v.businessName});
    }
    await batch.commit();
  }

  // ---------- Vendor payouts ----------

  static CollectionReference<Map<String, dynamic>> get payouts => _fs.collection('payouts');

  static List<Payout> _payouts(QuerySnapshot<Map<String, dynamic>> s) => s.docs.map((d) => Payout.fromMap(d.id, d.data())).toList()
    ..sort((a, b) => (b.paidAt ?? DateTime.now()).compareTo(a.paidAt ?? DateTime.now()));

  static Stream<List<Payout>> allPayouts() => payouts.snapshots().map(_payouts);
  static Stream<List<Payout>> vendorPayouts(String vendorId) => payouts.where('vendorId', isEqualTo: vendorId).snapshots().map(_payouts);

  /// Records that the admin paid [vendor] for [orders] and marks them settled.
  static Future<void> settleVendor({
    required Vendor vendor,
    required List<OrderModel> paidOrders,
    required String method,
    required String reference,
    required String note,
  }) async {
    final ref = payouts.doc();
    final batch = _fs.batch();
    batch.set(ref, {
      'vendorId': vendor.id,
      'vendorName': vendor.businessName,
      'amount': paidOrders.fold(0.0, (a, o) => a + o.vendorPayout),
      'commission': paidOrders.fold(0.0, (a, o) => a + o.commissionAmount),
      'orderIds': [for (final o in paidOrders) o.id],
      'method': method,
      'reference': reference.trim(),
      'note': note.trim(),
      'account': vendor.payout.toMap(),
      'paidAt': FieldValue.serverTimestamp(),
    });
    for (final o in paidOrders) {
      batch.update(orders.doc(o.id), {'payoutId': ref.id, 'updatedAt': FieldValue.serverTimestamp()});
    }
    await batch.commit();
  }

  // ---------- Users ----------

  static Stream<List<AppUser>> allUsers() => users.snapshots().map((s) => s.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList()
    ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now())));

  static Future<void> setUserBlocked(String uid, bool blocked) =>
      users.doc(uid).update({'blocked': blocked, 'updatedAt': FieldValue.serverTimestamp()});

  // ---------- Demo data ----------

  /// Seeds a complete store (categories with photos, full menu, banners, coupons, settings). Admin-only.
  static Future<void> seedFullStore() async {
    final batch = _fs.batch();

    // 1. Categories with photos
    final catData = [
      ('Biryani', 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800&h=600&q=75&fit=crop&auto=format', 1),
      ('Mains', 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=800&h=600&q=75&fit=crop&auto=format', 2),
      ('Combos', 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800&h=600&q=75&fit=crop&auto=format', 3),
      ('Starters', 'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=800&h=600&q=75&fit=crop&auto=format', 4),
      ('Street Food', 'https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=800&h=600&q=75&fit=crop&auto=format', 5),
      ('Pizza', 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&h=600&q=75&fit=crop&auto=format', 6),
      ('Fast Food', 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&h=600&q=75&fit=crop&auto=format', 7),
      ('Healthy', 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&h=600&q=75&fit=crop&auto=format', 8),
      ('Desserts', 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=800&h=600&q=75&fit=crop&auto=format', 9),
    ];
    for (final (name, img, order) in catData) {
      batch.set(categories.doc('demo-${name.toLowerCase().replaceAll(' ', '-')}'), {
        'name': name,
        'imageUrl': img,
        'active': true,
        'sortOrder': order,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 2. Menu items
    final prods = [
      ('Chicken Dum Biryani', 'Slow-cooked basmati, tender chicken, saffron & fried onions. Served with raita.', 'Biryani', 279.0, 20, false, true, 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800&h=600&q=75&fit=crop&auto=format'),
      ('Veg Handi Biryani', 'Fragrant basmati layered with garden vegetables and whole spices, sealed in a handi.', 'Biryani', 219.0, 15, true, false, 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800&h=600&q=75&fit=crop&auto=format'),
      ('Paneer Butter Masala', 'Soft paneer cubes in a silky tomato-butter gravy. Best with butter naan.', 'Mains', 229.0, 0, true, true, 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=800&h=600&q=75&fit=crop&auto=format'),
      ('Home-style Chicken Curry', 'Bone-in chicken simmered with onions, tomatoes and ghar ka masala.', 'Mains', 259.0, 0, false, false, 'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=800&h=600&q=75&fit=crop&auto=format'),
      ('Butter Chicken Rice Combo', 'Butter chicken, jeera rice, salad and a gulab jamun — a full meal.', 'Combos', 319.0, 15, false, true, 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800&h=600&q=75&fit=crop&auto=format'),
      ('Paneer Tikka (8 pc)', 'Char-grilled paneer, capsicum and onion marinated in tandoori spices.', 'Starters', 249.0, 25, true, false, 'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=800&h=600&q=75&fit=crop&auto=format'),
      ('Chicken Tikka Kebab', 'Juicy chicken skewers fresh off the grill with mint chutney.', 'Starters', 269.0, 0, false, true, 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=800&h=600&q=75&fit=crop&auto=format'),
      ('Mumbai Pav Bhaji', 'Buttery bhaji with 2 soft pav, onions and lemon — Juhu beach style.', 'Street Food', 149.0, 10, true, true, 'https://images.unsplash.com/photo-1606491956689-2ea866880c84?w=800&h=600&q=75&fit=crop&auto=format'),
      ('Cheese Burst Veg Pizza', 'Loaded with mozzarella, onion, capsicum and sweet corn.', 'Pizza', 299.0, 30, true, true, 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&h=600&q=75&fit=crop&auto=format'),
      ('Double Smash Burger', 'Two patties, cheddar cheese, pickles and our secret sauce.', 'Fast Food', 199.0, 0, false, false, 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&h=600&q=75&fit=crop&auto=format'),
      ('Fresh Garden Bowl', 'Avocado, chickpeas, greens and crunchy veggies with lemon dressing.', 'Healthy', 179.0, 0, true, false, 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&h=600&q=75&fit=crop&auto=format'),
      ('Choco Sprinkle Donuts (2 pc)', 'Soft donuts dipped in chocolate with rainbow sprinkles.', 'Desserts', 99.0, 0, true, false, 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=800&h=600&q=75&fit=crop&auto=format'),
    ];
    var pi = 0;
    for (final (name, desc, cat, price, disc, veg, best, photo) in prods) {
      batch.set(products.doc('demo-$pi'), {
        'name': name,
        'description': desc,
        'category': cat,
        'imageUrl': photo,
        'price': price,
        'discountPercent': disc,
        'isVeg': veg,
        'isAvailable': true,
        'isBestseller': best,
        'vendorId': AppConfig.houseVendorId,
        'vendorName': AppConfig.houseVendorName,
        'vendorActive': true,
        'sortOrder': pi++,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 3. Top Banners & Specials
    batch.set(banners.doc('demo-hero-1'), {
      'placement': 'hero',
      'title': 'Biryani Festival — Flat 20% OFF',
      'subtitle': 'Dum-cooked chicken & veg biryani, sealed in handi and delivered hot.',
      'badge': 'Limited time',
      'ctaText': 'Order biryani',
      'category': 'Biryani',
      'productId': '',
      'imageUrl': 'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=1600&h=900&q=75&fit=crop&auto=format',
      'sortOrder': 1,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(banners.doc('demo-hero-2'), {
      'placement': 'hero',
      'title': 'Weekend Pizza Party 🍕',
      'subtitle': 'Cheese-burst pizzas at 30% off — this weekend only.',
      'badge': '30% OFF',
      'ctaText': 'Grab a slice',
      'category': 'Pizza',
      'productId': '',
      'imageUrl': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=1600&h=900&q=75&fit=crop&auto=format',
      'sortOrder': 2,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(banners.doc('demo-bottom-1'), {
      'placement': 'bottom',
      'title': 'Sweet tooth? Desserts from ₹99',
      'subtitle': 'Pastries, brownies & donuts to end every meal right.',
      'badge': 'Freshly baked',
      'ctaText': 'See desserts',
      'category': 'Desserts',
      'productId': '',
      'imageUrl': 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=1200&h=600&q=75&fit=crop&auto=format',
      'sortOrder': 1,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 4. Coupons
    final offList = [
      ('HUNGRY20', 'Flat 20% off on your order', 'Valid on orders above ₹299', 20, 100.0, 299.0),
      ('FIRSTBITE', '50% off your first order', 'New here? Max ₹120 off on orders above ₹199', 50, 120.0, 199.0),
      ('FEAST15', '15% off on big feasts', 'No cap — on orders above ₹599', 15, 0.0, 599.0),
    ];
    for (final (code, title, desc, pct, max, min) in offList) {
      batch.set(offers.doc('demo-$code'), {
        'code': code,
        'title': title,
        'description': desc,
        'discountPercent': pct,
        'maxDiscount': max,
        'minOrder': min,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // 5. Store Settings
    batch.set(settingsDoc, {
      'storeOpen': true,
      'specialsTitle': "Don't miss these",
      'deliveryFee': 25.0,
      'freeDeliveryAbove': 299.0,
      'minOrder': 99.0,
      'etaMinutes': 30,
      'upiId': AppConfig.defaultUpiId,
      'payeeName': AppConfig.defaultPayeeName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Seeds a starter menu so a fresh store isn't empty. Admin-only.
  static Future<void> seedSampleMenu() async {
    await seedFullStore();
  }
}

