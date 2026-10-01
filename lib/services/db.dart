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

  /// Seeds a starter menu so a fresh store isn't empty. Admin-only.
  static Future<void> seedSampleMenu() async {
    final batch = _fs.batch();
    const items = [
      ('Paneer Butter Masala', 'Soft paneer cubes simmered in a silky tomato-butter gravy.', 'Mains', 229.0, true, true),
      ('Chicken Dum Biryani', 'Slow-cooked basmati, tender chicken, saffron & fried onions. Served with raita.', 'Biryani', 279.0, false, true),
      ('Veg Dum Biryani', 'Fragrant basmati layered with garden vegetables and whole spices.', 'Biryani', 219.0, true, false),
      ('Dal Makhani', 'Black lentils slow-cooked overnight with butter and cream.', 'Mains', 189.0, true, false),
      ('Butter Chicken', 'Smoky tandoori chicken in a rich makhani gravy.', 'Mains', 299.0, false, true),
      ('Classic Veg Thali', 'Dal, sabzi, paneer, rice, 3 rotis, salad & sweet.', 'Thali', 249.0, true, true),
      ('Chicken Kathi Roll', 'Flaky paratha wrapped around spiced chicken tikka and onions.', 'Rolls', 159.0, false, false),
      ('Paneer Tikka Roll', 'Char-grilled paneer tikka with mint mayo in a paratha.', 'Rolls', 149.0, true, false),
      ('Butter Naan', 'Soft tandoor-baked naan brushed with butter.', 'Breads', 45.0, true, false),
      ('Gulab Jamun (2 pc)', 'Warm, syrup-soaked khoya dumplings.', 'Desserts', 69.0, true, false),
      ('Masala Chaas', 'Chilled spiced buttermilk.', 'Beverages', 49.0, true, false),
    ];
    var i = 0;
    for (final (name, desc, cat, price, veg, best) in items) {
      batch.set(products.doc(), {
        'name': name,
        'description': desc,
        'category': cat,
        'imageUrl': '',
        'price': price,
        'discountPercent': 0,
        'isVeg': veg,
        'isAvailable': true,
        'isBestseller': best,
        'vendorId': AppConfig.houseVendorId,
        'vendorName': AppConfig.houseVendorName,
        'vendorActive': true,
        'sortOrder': i++,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    batch.set(offers.doc(), {
      'code': 'HUNGRY20',
      'title': 'Flat 20% off on your order',
      'description': 'Valid on orders above ₹299',
      'discountPercent': 20,
      'maxDiscount': 100,
      'minOrder': 299,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
