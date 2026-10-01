import '../core/config.dart';
import '../core/format.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final String category;
  final String imageUrl;
  final double price;

  /// Sale discount on this item, 0–90. Set per product or in bulk via a flash sale.
  final int discountPercent;
  final bool isVeg;
  final bool isAvailable;
  final bool isBestseller;
  final String vendorId;
  final String vendorName;

  /// False while the owning vendor is blocked/unapproved — hides the product from the store.
  final bool vendorActive;
  final int sortOrder;
  final DateTime? createdAt;

  const Product({
    required this.id,
    required this.name,
    this.description = '',
    this.category = 'Mains',
    this.imageUrl = '',
    required this.price,
    this.discountPercent = 0,
    this.isVeg = true,
    this.isAvailable = true,
    this.isBestseller = false,
    this.vendorId = AppConfig.houseVendorId,
    this.vendorName = AppConfig.houseVendorName,
    this.vendorActive = true,
    this.sortOrder = 0,
    this.createdAt,
  });

  bool get isHouse => vendorId == AppConfig.houseVendorId;
  bool get onSale => discountPercent > 0;
  double get finalPrice => onSale ? (price * (100 - discountPercent) / 100).roundToDouble() : price;

  factory Product.fromMap(String id, Map<String, dynamic> m) => Product(
        id: id,
        name: toStr(m['name']),
        description: toStr(m['description']),
        category: toStr(m['category']).isEmpty ? 'Mains' : toStr(m['category']),
        imageUrl: toStr(m['imageUrl']),
        price: toDouble(m['price']),
        discountPercent: toInt(m['discountPercent']).clamp(0, 90),
        isVeg: toBool(m['isVeg'], true),
        isAvailable: toBool(m['isAvailable'], true),
        isBestseller: toBool(m['isBestseller']),
        vendorId: toStr(m['vendorId']).isEmpty ? AppConfig.houseVendorId : toStr(m['vendorId']),
        vendorName: toStr(m['vendorName']).isEmpty ? AppConfig.houseVendorName : toStr(m['vendorName']),
        vendorActive: toBool(m['vendorActive'], true),
        sortOrder: toInt(m['sortOrder']),
        createdAt: toDate(m['createdAt']),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'category': category,
        'imageUrl': imageUrl,
        'price': price,
        'discountPercent': discountPercent,
        'isVeg': isVeg,
        'isAvailable': isAvailable,
        'isBestseller': isBestseller,
        'vendorId': vendorId,
        'vendorName': vendorName,
        'vendorActive': vendorActive,
        'sortOrder': sortOrder,
      };

  /// JSON-safe form for persisting the cart in local storage.
  Map<String, dynamic> toJson() => {'id': id, ...toMap()};
  factory Product.fromJson(Map<String, dynamic> j) => Product.fromMap(toStr(j['id']), j);
}

/// Emoji used when a category has no photo yet.
String categoryEmoji(String category) {
  final c = category.toLowerCase();
  const map = {
    'pizza': '🍕',
    'burger': '🍔',
    'biryani': '🍛',
    'rice': '🍚',
    'thali': '🍱',
    'roll': '🌯',
    'wrap': '🌯',
    'momo': '🥟',
    'chinese': '🥡',
    'noodle': '🍜',
    'pasta': '🍝',
    'sandwich': '🥪',
    'dessert': '🍰',
    'sweet': '🍮',
    'ice': '🍨',
    'shake': '🥤',
    'drink': '🥤',
    'beverage': '🥤',
    'juice': '🧃',
    'coffee': '☕',
    'tea': '🍵',
    'chai': '🍵',
    'chicken': '🍗',
    'tandoor': '🍢',
    'kebab': '🍢',
    'starter': '🍟',
    'snack': '🍟',
    'fries': '🍟',
    'salad': '🥗',
    'paneer': '🧀',
    'breakfast': '🍳',
    'paratha': '🫓',
    'roti': '🫓',
    'bread': '🫓',
    'dal': '🍲',
    'curry': '🍲',
    'main': '🍲',
    'soup': '🥣',
    'combo': '🍱',
    'south': '🥞',
    'dosa': '🥞',
    'egg': '🥚',
    'fish': '🐟',
    'seafood': '🦐',
  };
  for (final e in map.entries) {
    if (c.contains(e.key)) return e.value;
  }
  return '🍽️';
}
