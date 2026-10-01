import 'dart:math' as math;

import '../core/config.dart';
import '../core/format.dart';

export 'order.dart';
export 'product.dart';

class BannerModel {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String ctaText;

  /// Optional menu category the CTA jumps to.
  final String category;
  final bool active;
  final int sortOrder;

  /// 'hero' = top slider, 'bottom' = "Don't miss these" specials lower on the page.
  final String placement;

  /// Small tag on a special, e.g. "LIMITED TIME".
  final String badge;

  /// When set, tapping opens this dish instead of a category.
  final String productId;

  /// Optional expiry; the banner hides itself after this time.
  final DateTime? endsAt;

  const BannerModel({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.imageUrl = '',
    this.ctaText = 'Order now',
    this.category = '',
    this.active = true,
    this.sortOrder = 0,
    this.placement = 'hero',
    this.badge = '',
    this.productId = '',
    this.endsAt,
  });

  bool get isBottom => placement == 'bottom';
  bool get isExpired => endsAt != null && DateTime.now().isAfter(endsAt!);
  bool get isLive => active && !isExpired;

  factory BannerModel.fromMap(String id, Map<String, dynamic> m) => BannerModel(
        id: id,
        title: toStr(m['title']),
        subtitle: toStr(m['subtitle']),
        imageUrl: toStr(m['imageUrl']),
        ctaText: toStr(m['ctaText']).isEmpty ? 'Order now' : toStr(m['ctaText']),
        category: toStr(m['category']),
        active: toBool(m['active'], true),
        sortOrder: toInt(m['sortOrder']),
        placement: toStr(m['placement']) == 'bottom' ? 'bottom' : 'hero',
        badge: toStr(m['badge']),
        productId: toStr(m['productId']),
        endsAt: toDate(m['endsAt']),
      );

  Map<String, dynamic> toMap() => {
        'placement': placement,
        'badge': badge,
        'productId': productId,
        'endsAt': endsAt,
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
        'ctaText': ctaText,
        'category': category,
        'active': active,
        'sortOrder': sortOrder,
      };
}

/// A coupon code customers can apply at checkout.
class Offer {
  final String id;
  final String code;
  final String title;
  final String description;
  final int discountPercent;

  /// Cap on the discount in rupees; 0 = no cap.
  final double maxDiscount;
  final double minOrder;
  final bool active;

  const Offer({
    required this.id,
    required this.code,
    required this.title,
    this.description = '',
    required this.discountPercent,
    this.maxDiscount = 0,
    this.minOrder = 0,
    this.active = true,
  });

  double discountFor(double subtotal) {
    if (subtotal < minOrder) return 0;
    var d = subtotal * discountPercent / 100;
    if (maxDiscount > 0) d = math.min(d, maxDiscount);
    return d.roundToDouble();
  }

  String get shortLabel => maxDiscount > 0 ? '$discountPercent% OFF up to ${rupees(maxDiscount)}' : '$discountPercent% OFF';

  factory Offer.fromMap(String id, Map<String, dynamic> m) => Offer(
        id: id,
        code: toStr(m['code']).toUpperCase(),
        title: toStr(m['title']),
        description: toStr(m['description']),
        discountPercent: toInt(m['discountPercent']),
        maxDiscount: toDouble(m['maxDiscount']),
        minOrder: toDouble(m['minOrder']),
        active: toBool(m['active'], true),
      );

  Map<String, dynamic> toMap() => {
        'code': code.toUpperCase(),
        'title': title,
        'description': description,
        'discountPercent': discountPercent,
        'maxDiscount': maxDiscount,
        'minOrder': minOrder,
        'active': active,
      };
}

class StoreSettings {
  final String upiId;
  final String payeeName;
  final double deliveryFee;

  /// Orders with food value at or above this get free delivery; 0 disables.
  final double freeDeliveryAbove;
  final double minOrder;
  final int etaMinutes;
  final bool storeOpen;
  final String contactPhone;
  final String contactEmail;
  final String address;

  /// Heading of the specials section on the home page.
  final String specialsTitle;

  /// When true, orders are accepted only from the areas below.
  final bool restrictArea;
  final List<String> serviceCities;
  final List<String> servicePincodes;
  final double? kitchenLat;
  final double? kitchenLng;

  /// Delivery radius around the kitchen in km; 0 = not used.
  final double radiusKm;

  const StoreSettings({
    this.upiId = AppConfig.defaultUpiId,
    this.payeeName = AppConfig.defaultPayeeName,
    this.deliveryFee = 30,
    this.freeDeliveryAbove = 399,
    this.minOrder = 99,
    this.etaMinutes = 35,
    this.storeOpen = true,
    this.contactPhone = '',
    this.contactEmail = '',
    this.address = '',
    this.specialsTitle = "Don't miss these",
    this.restrictArea = false,
    this.serviceCities = const [],
    this.servicePincodes = const [],
    this.kitchenLat,
    this.kitchenLng,
    this.radiusKm = 0,
  });

  bool get hasRadius => radiusKm > 0 && kitchenLat != null && kitchenLng != null;

  /// Whether HungryKya delivers to [a]. Matches any configured rule:
  /// city/district name, pincode, or distance from the kitchen.
  bool serves(Address a) {
    if (!restrictArea) return true;
    final cities = serviceCities.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
    if (cities.isNotEmpty) {
      final c = a.city.trim().toLowerCase();
      final d = a.district.trim().toLowerCase();
      for (final x in cities) {
        if (c == x || d == x || (c.isNotEmpty && (c.contains(x) || x.contains(c))) || (d.isNotEmpty && d.contains(x))) return true;
      }
    }
    if (servicePincodes.contains(a.pincode.trim())) return true;
    if (hasRadius && a.hasLocation && distanceKm(kitchenLat!, kitchenLng!, a.lat!, a.lng!) <= radiusKm) return true;
    return false;
  }

  /// Human-readable list of where we deliver, for customer messages.
  String get areaSummary {
    final parts = [
      ...serviceCities,
      if (servicePincodes.isNotEmpty) 'pincodes ${servicePincodes.take(6).join(', ')}${servicePincodes.length > 6 ? '…' : ''}',
      if (hasRadius) 'within ${radiusKm.toStringAsFixed(radiusKm % 1 == 0 ? 0 : 1)} km of our kitchen',
    ];
    return parts.isEmpty ? 'selected areas' : parts.join(', ');
  }

  double deliveryFor(double foodTotal) => (freeDeliveryAbove > 0 && foodTotal >= freeDeliveryAbove) ? 0 : deliveryFee;

  factory StoreSettings.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const StoreSettings();
    const d = StoreSettings();
    return StoreSettings(
      upiId: toStr(m['upiId']).isEmpty ? d.upiId : toStr(m['upiId']),
      payeeName: toStr(m['payeeName']).isEmpty ? d.payeeName : toStr(m['payeeName']),
      deliveryFee: m['deliveryFee'] == null ? d.deliveryFee : toDouble(m['deliveryFee']),
      freeDeliveryAbove: m['freeDeliveryAbove'] == null ? d.freeDeliveryAbove : toDouble(m['freeDeliveryAbove']),
      minOrder: m['minOrder'] == null ? d.minOrder : toDouble(m['minOrder']),
      etaMinutes: m['etaMinutes'] == null ? d.etaMinutes : toInt(m['etaMinutes']),
      storeOpen: toBool(m['storeOpen'], true),
      contactPhone: toStr(m['contactPhone']),
      contactEmail: toStr(m['contactEmail']),
      address: toStr(m['address']),
      specialsTitle: toStr(m['specialsTitle']).isEmpty ? d.specialsTitle : toStr(m['specialsTitle']),
      restrictArea: toBool(m['restrictArea']),
      serviceCities: ((m['serviceCities'] as List?) ?? []).map((e) => toStr(e)).where((e) => e.isNotEmpty).toList(),
      servicePincodes: ((m['servicePincodes'] as List?) ?? []).map((e) => toStr(e)).where((e) => e.isNotEmpty).toList(),
      kitchenLat: m['kitchenLat'] is num ? (m['kitchenLat'] as num).toDouble() : null,
      kitchenLng: m['kitchenLng'] is num ? (m['kitchenLng'] as num).toDouble() : null,
      radiusKm: toDouble(m['radiusKm']),
    );
  }

  Map<String, dynamic> toMap() => {
        'upiId': upiId,
        'payeeName': payeeName,
        'deliveryFee': deliveryFee,
        'freeDeliveryAbove': freeDeliveryAbove,
        'minOrder': minOrder,
        'etaMinutes': etaMinutes,
        'storeOpen': storeOpen,
        'contactPhone': contactPhone,
        'contactEmail': contactEmail,
        'address': address,
      };
}

class VendorStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const blocked = 'blocked';

  static String label(String s) =>
      const {pending: 'Pending review', approved: 'Approved', rejected: 'Rejected', blocked: 'Blocked'}[s] ?? s;
}

class Vendor {
  final String id;
  final String businessName;
  final String ownerName;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String pincode;
  final String cuisine;
  final String fssai;
  final String status;
  final double commissionRate;
  final bool consentAccepted;
  final DateTime? consentAt;
  final String consentVersion;
  final String rejectionReason;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final PayoutAccount payout;

  const Vendor({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.pincode,
    this.cuisine = '',
    this.fssai = '',
    this.status = VendorStatus.pending,
    this.commissionRate = AppConfig.vendorCommissionRate,
    this.consentAccepted = false,
    this.consentAt,
    this.consentVersion = '',
    this.rejectionReason = '',
    this.createdAt,
    this.approvedAt,
    this.payout = const PayoutAccount(),
  });

  bool get isApproved => status == VendorStatus.approved;
  String get location => [address, city, pincode].where((e) => e.isNotEmpty).join(', ');

  factory Vendor.fromMap(String id, Map<String, dynamic> m) {
    final consent = Map<String, dynamic>.from((m['commissionConsent'] as Map?) ?? const {});
    return Vendor(
      id: id,
      businessName: toStr(m['businessName']),
      ownerName: toStr(m['ownerName']),
      email: toStr(m['email']),
      phone: toStr(m['phone']),
      address: toStr(m['address']),
      city: toStr(m['city']),
      pincode: toStr(m['pincode']),
      cuisine: toStr(m['cuisine']),
      fssai: toStr(m['fssai']),
      status: toStr(m['status']).isEmpty ? VendorStatus.pending : toStr(m['status']),
      commissionRate: m['commissionRate'] == null ? AppConfig.vendorCommissionRate : toDouble(m['commissionRate']),
      consentAccepted: toBool(consent['accepted']),
      consentAt: toDate(consent['acceptedAt']),
      consentVersion: toStr(consent['version']),
      rejectionReason: toStr(m['rejectionReason']),
      createdAt: toDate(m['createdAt']),
      approvedAt: toDate(m['approvedAt']),
      payout: PayoutAccount.fromMap(Map<String, dynamic>.from((m['payout'] as Map?) ?? const {})),
    );
  }
}

/// Where a vendor receives their money: bank account and/or UPI.
class PayoutAccount {
  final String accountName;
  final String accountNumber;
  final String ifsc;
  final String bankName;
  final String branch;
  final String upiId;

  const PayoutAccount({
    this.accountName = '',
    this.accountNumber = '',
    this.ifsc = '',
    this.bankName = '',
    this.branch = '',
    this.upiId = '',
  });

  bool get hasBank => accountNumber.isNotEmpty && ifsc.isNotEmpty;
  bool get hasUpi => upiId.isNotEmpty;
  bool get isEmpty => !hasBank && !hasUpi;
  String get maskedAccount => accountNumber.length <= 4 ? accountNumber : '•••• ${accountNumber.substring(accountNumber.length - 4)}';

  factory PayoutAccount.fromMap(Map<String, dynamic> m) => PayoutAccount(
        accountName: toStr(m['accountName']),
        accountNumber: toStr(m['accountNumber']),
        ifsc: toStr(m['ifsc']).toUpperCase(),
        bankName: toStr(m['bankName']),
        branch: toStr(m['branch']),
        upiId: toStr(m['upiId']),
      );

  Map<String, dynamic> toMap() => {
        'accountName': accountName,
        'accountNumber': accountNumber,
        'ifsc': ifsc.toUpperCase(),
        'bankName': bankName,
        'branch': branch,
        'upiId': upiId,
      };
}

/// A settlement the admin paid to a vendor for a set of delivered orders.
class Payout {
  final String id;
  final String vendorId;
  final String vendorName;
  final double amount;
  final double commission;
  final List<String> orderIds;
  final String method;
  final String reference;
  final String note;
  final DateTime? paidAt;

  const Payout({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.amount,
    this.commission = 0,
    this.orderIds = const [],
    this.method = 'upi',
    this.reference = '',
    this.note = '',
    this.paidAt,
  });

  String get methodLabel => const {'upi': 'UPI', 'bank': 'Bank transfer', 'cash': 'Cash'}[method] ?? method;

  factory Payout.fromMap(String id, Map<String, dynamic> m) => Payout(
        id: id,
        vendorId: toStr(m['vendorId']),
        vendorName: toStr(m['vendorName']),
        amount: toDouble(m['amount']),
        commission: toDouble(m['commission']),
        orderIds: ((m['orderIds'] as List?) ?? []).map((e) => toStr(e)).toList(),
        method: toStr(m['method']).isEmpty ? 'upi' : toStr(m['method']),
        reference: toStr(m['reference']),
        note: toStr(m['note']),
        paidAt: toDate(m['paidAt']),
      );
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool blocked;
  final DateTime? createdAt;
  final Map<String, dynamic> lastAddress;
  final List<Address> addresses;
  final String defaultAddressId;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.role = 'customer',
    this.blocked = false,
    this.createdAt,
    this.lastAddress = const {},
    this.addresses = const [],
    this.defaultAddressId = '',
  });

  /// The address orders go to: the chosen default, else the first saved one.
  Address? get currentAddress {
    if (addresses.isEmpty) return null;
    return addresses.where((a) => a.id == defaultAddressId).firstOrNull ?? addresses.first;
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> m) => AppUser(
        id: id,
        name: toStr(m['name']),
        email: toStr(m['email']),
        phone: toStr(m['phone']),
        role: toStr(m['role']).isEmpty ? 'customer' : toStr(m['role']),
        blocked: toBool(m['blocked']),
        createdAt: toDate(m['createdAt']),
        lastAddress: Map<String, dynamic>.from((m['lastAddress'] as Map?) ?? const {}),
        addresses: ((m['addresses'] as List?) ?? []).map((e) => Address.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
        defaultAddressId: toStr(m['defaultAddressId']),
      );
}

/// A saved delivery address. [lat]/[lng] come from the browser's location
/// permission when the customer taps "Use my current location".
class Address {
  final String id;
  final String label;
  final String house;
  final String area;
  final String landmark;
  final String city;

  /// District from GPS lookup (used for district-level delivery areas).
  final String district;
  final String pincode;
  final double? lat;
  final double? lng;

  const Address({
    required this.id,
    this.label = 'Home',
    required this.house,
    required this.area,
    this.landmark = '',
    required this.city,
    this.district = '',
    required this.pincode,
    this.lat,
    this.lng,
  });

  static String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  bool get hasLocation => lat != null && lng != null;

  /// One-line address used on orders.
  String get line => [house, area, city].where((e) => e.trim().isNotEmpty).join(', ');
  String get short => area.isNotEmpty ? area : (city.isNotEmpty ? city : house);

  factory Address.fromMap(Map<String, dynamic> m) => Address(
        id: toStr(m['id']).isEmpty ? newId() : toStr(m['id']),
        label: toStr(m['label']).isEmpty ? 'Home' : toStr(m['label']),
        house: toStr(m['house']),
        area: toStr(m['area']),
        landmark: toStr(m['landmark']),
        city: toStr(m['city']),
        district: toStr(m['district']),
        pincode: toStr(m['pincode']),
        lat: m['lat'] is num ? (m['lat'] as num).toDouble() : null,
        lng: m['lng'] is num ? (m['lng'] as num).toDouble() : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'house': house,
        'area': area,
        'landmark': landmark,
        'city': city,
        if (district.isNotEmpty) 'district': district,
        'pincode': pincode,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };
}

/// Great-circle distance in km.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Menu category managed by the admin (name, photo, display order).
class CategoryModel {
  final String id;
  final String name;
  final String imageUrl;
  final int sortOrder;
  final bool active;

  const CategoryModel({required this.id, required this.name, this.imageUrl = '', this.sortOrder = 0, this.active = true});

  factory CategoryModel.fromMap(String id, Map<String, dynamic> m) => CategoryModel(
        id: id,
        name: toStr(m['name']),
        imageUrl: toStr(m['imageUrl']),
        sortOrder: toInt(m['sortOrder']),
        active: toBool(m['active'], true),
      );

  Map<String, dynamic> toMap() => {'name': name, 'imageUrl': imageUrl, 'sortOrder': sortOrder, 'active': active};
}
