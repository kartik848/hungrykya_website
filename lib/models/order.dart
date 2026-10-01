import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/config.dart';
import '../core/format.dart';

class OrderStatus {
  static const placed = 'placed';
  static const confirmed = 'confirmed';
  static const preparing = 'preparing';
  static const outForDelivery = 'out_for_delivery';
  static const delivered = 'delivered';
  static const cancelled = 'cancelled';

  static const flow = [placed, confirmed, preparing, outForDelivery, delivered];

  static String label(String s) => const {
        placed: 'Order placed',
        confirmed: 'Confirmed',
        preparing: 'Preparing',
        outForDelivery: 'Out for delivery',
        delivered: 'Delivered',
        cancelled: 'Cancelled',
      }[s] ??
      s;

  /// Customer-facing headline for the tracking screen.
  static String headline(String s) => const {
        placed: 'Order received! Waiting for the kitchen to confirm',
        confirmed: 'Kitchen has accepted your order',
        preparing: 'Your food is being freshly prepared',
        outForDelivery: 'On the way — your food is out for delivery',
        delivered: 'Delivered. Enjoy your meal!',
        cancelled: 'This order was cancelled',
      }[s] ??
      s;

  static String emoji(String s) => const {
        placed: '🧾',
        confirmed: '✅',
        preparing: '👨‍🍳',
        outForDelivery: '🛵',
        delivered: '😋',
        cancelled: '❌',
      }[s] ??
      '🧾';

  static IconData icon(String s) => const {
        placed: Icons.receipt_long_rounded,
        confirmed: Icons.check_circle_rounded,
        preparing: Icons.soup_kitchen_rounded,
        outForDelivery: Icons.delivery_dining_rounded,
        delivered: Icons.celebration_rounded,
        cancelled: Icons.cancel_rounded,
      }[s] ??
      Icons.receipt_long_rounded;

  static Color color(String s) => const {
        placed: Color(0xFF2563EB),
        confirmed: Color(0xFF7C3AED),
        preparing: Color(0xFFF59E0B),
        outForDelivery: Color(0xFFEA580C),
        delivered: Color(0xFF16A34A),
        cancelled: Color(0xFFDC2626),
      }[s] ??
      Colors.grey;

  static String? next(String s) {
    final i = flow.indexOf(s);
    return (i >= 0 && i < flow.length - 1) ? flow[i + 1] : null;
  }

  static bool isActive(String s) => s != delivered && s != cancelled;
}

class PayStatus {
  static const pending = 'pending';
  static const verification = 'verification';
  static const paid = 'paid';
  static const failed = 'failed';
  static const refunded = 'refunded';

  static String label(String s) => const {
        pending: 'Payment pending',
        verification: 'Verifying payment',
        paid: 'Paid',
        failed: 'Payment failed',
        refunded: 'Refunded',
      }[s] ??
      s;

  static Color color(String s) => const {
        pending: Color(0xFFF59E0B),
        verification: Color(0xFF2563EB),
        paid: Color(0xFF16A34A),
        failed: Color(0xFFDC2626),
        refunded: Color(0xFF6B7280),
      }[s] ??
      Colors.grey;
}

class OrderItem {
  final String productId;
  final String name;
  final double price;
  final int qty;
  final bool isVeg;

  const OrderItem({required this.productId, required this.name, required this.price, required this.qty, this.isVeg = true});

  double get total => price * qty;

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
        productId: toStr(m['productId']),
        name: toStr(m['name']),
        price: toDouble(m['price']),
        qty: toInt(m['qty']),
        isVeg: toBool(m['isVeg'], true),
      );

  Map<String, dynamic> toMap() => {'productId': productId, 'name': name, 'price': price, 'qty': qty, 'isVeg': isVeg};
}

class OrderModel {
  final String id;
  final String orderNo;
  final String userId;
  final String customerName;
  final String phone;
  final String email;
  final String address;
  final String landmark;
  final String pincode;
  final String note;
  final double? lat;
  final double? lng;
  final List<OrderItem> items;
  final String vendorId;
  final String vendorName;

  /// Sum of item prices before sale discounts (for the "you saved" line).
  final double mrpTotal;

  /// Sum of item prices after sale discounts.
  final double subtotal;
  final double couponDiscount;
  final String couponCode;
  final double deliveryFee;
  final double total;
  final double commissionRate;
  final double commissionAmount;
  final double vendorPayout;
  final String paymentMethod;
  final String paymentStatus;
  final String upiRef;

  /// Set when the admin has paid the vendor for this order.
  final String payoutId;
  final String status;
  final List<Map<String, dynamic>> statusHistory;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OrderModel({
    this.id = '',
    required this.orderNo,
    required this.userId,
    required this.customerName,
    required this.phone,
    this.email = '',
    required this.address,
    this.landmark = '',
    this.pincode = '',
    this.note = '',
    this.lat,
    this.lng,
    required this.items,
    required this.vendorId,
    required this.vendorName,
    required this.mrpTotal,
    required this.subtotal,
    this.couponDiscount = 0,
    this.couponCode = '',
    required this.deliveryFee,
    required this.total,
    this.commissionRate = 0,
    this.commissionAmount = 0,
    this.vendorPayout = 0,
    required this.paymentMethod,
    this.paymentStatus = PayStatus.pending,
    this.upiRef = '',
    this.payoutId = '',
    this.status = OrderStatus.placed,
    this.statusHistory = const [],
    this.createdAt,
    this.updatedAt,
  });

  bool get isSettled => payoutId.isNotEmpty;

  /// Delivered vendor order whose money hasn't been paid to the vendor yet.
  bool get awaitingPayout => isVendorOrder && status == OrderStatus.delivered && !isSettled;

  bool get hasLocation => lat != null && lng != null;
  String get mapsUrl => 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  bool get isVendorOrder => vendorId != AppConfig.houseVendorId;
  bool get isUpi => paymentMethod == 'upi';
  bool get isActive => OrderStatus.isActive(status);
  bool get needsPayment => isUpi && (paymentStatus == PayStatus.pending || paymentStatus == PayStatus.failed) && status != OrderStatus.cancelled;
  int get itemCount => items.fold(0, (a, i) => a + i.qty);
  double get foodTotal => subtotal - couponDiscount;
  double get saleSavings => mrpTotal - subtotal;

  DateTime? timeOf(String s) {
    for (final h in statusHistory) {
      if (h['status'] == s) return toDate(h['at']);
    }
    return null;
  }

  static String newOrderNo() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    final tail = List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
    return 'HK${DateFormat('yyMMdd').format(DateTime.now())}$tail';
  }

  factory OrderModel.fromMap(String id, Map<String, dynamic> m) => OrderModel(
        id: id,
        orderNo: toStr(m['orderNo']),
        userId: toStr(m['userId']),
        customerName: toStr(m['customerName']),
        phone: toStr(m['phone']),
        email: toStr(m['email']),
        address: toStr(m['address']),
        landmark: toStr(m['landmark']),
        pincode: toStr(m['pincode']),
        note: toStr(m['note']),
        lat: m['lat'] is num ? (m['lat'] as num).toDouble() : null,
        lng: m['lng'] is num ? (m['lng'] as num).toDouble() : null,
        items: ((m['items'] as List?) ?? []).map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
        vendorId: toStr(m['vendorId']).isEmpty ? AppConfig.houseVendorId : toStr(m['vendorId']),
        vendorName: toStr(m['vendorName']).isEmpty ? AppConfig.houseVendorName : toStr(m['vendorName']),
        mrpTotal: toDouble(m['mrpTotal']),
        subtotal: toDouble(m['subtotal']),
        couponDiscount: toDouble(m['couponDiscount']),
        couponCode: toStr(m['couponCode']),
        deliveryFee: toDouble(m['deliveryFee']),
        total: toDouble(m['total']),
        commissionRate: toDouble(m['commissionRate']),
        commissionAmount: toDouble(m['commissionAmount']),
        vendorPayout: toDouble(m['vendorPayout']),
        paymentMethod: toStr(m['paymentMethod']).isEmpty ? 'cod' : toStr(m['paymentMethod']),
        paymentStatus: toStr(m['paymentStatus']).isEmpty ? PayStatus.pending : toStr(m['paymentStatus']),
        upiRef: toStr(m['upiRef']),
        payoutId: toStr(m['payoutId']),
        status: toStr(m['status']).isEmpty ? OrderStatus.placed : toStr(m['status']),
        statusHistory: ((m['statusHistory'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        createdAt: toDate(m['createdAt']),
        updatedAt: toDate(m['updatedAt']),
      );

  Map<String, dynamic> toMap() => {
        'orderNo': orderNo,
        'userId': userId,
        'customerName': customerName,
        'phone': phone,
        'email': email,
        'address': address,
        'landmark': landmark,
        'pincode': pincode,
        'note': note,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'items': items.map((e) => e.toMap()).toList(),
        'vendorId': vendorId,
        'vendorName': vendorName,
        'mrpTotal': mrpTotal,
        'subtotal': subtotal,
        'couponDiscount': couponDiscount,
        'couponCode': couponCode,
        'deliveryFee': deliveryFee,
        'total': total,
        'commissionRate': commissionRate,
        'commissionAmount': commissionAmount,
        'vendorPayout': vendorPayout,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentStatus,
        'upiRef': upiRef,
        'status': status,
      };
}
