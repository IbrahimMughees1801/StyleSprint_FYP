import 'product.dart';

class Order {
  final String id;
  final DateTime date;
  final String status;
  final int itemCount;
  final double subtotal;
  final double shipping;
  final double tax;
  final double total;
  final String paymentMethod;
  final String addressName;
  final String address;
  final String city;
  final String phone;
  final List<CartItem> items;

  Order({
    required this.id,
    required this.date,
    required this.status,
    required this.itemCount,
    required this.subtotal,
    required this.shipping,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.addressName,
    required this.address,
    required this.city,
    required this.phone,
    required this.items,
  });

  String get totalLabel => '\$${total.toStringAsFixed(2)}';

  String get thumbnail => itemImages.isEmpty ? '' : itemImages.first;

  List<String> get itemImages {
    return items
        .map((item) => item.image)
        .where((image) => image.trim().isNotEmpty)
        .toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'status': status,
      'itemCount': itemCount,
      'subtotal': subtotal,
      'shipping': shipping,
      'tax': tax,
      'total': total,
      'paymentMethod': paymentMethod,
      'addressName': addressName,
      'address': address,
      'city': city,
      'phone': phone,
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    final rawDate = map['date'];
    final rawItems = map['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => CartItem.fromMap(Map<String, dynamic>.from(item)))
              .toList()
        : <CartItem>[];

    double readDouble(String key) {
      final value = map[key];
      return value is num
          ? value.toDouble()
          : value is String
          ? double.tryParse(value) ?? 0
          : 0;
    }

    DateTime readDate(Object? value) {
      if (value is DateTime) return value;
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }

      try {
        final dynamic timestamp = value;
        final converted = timestamp.toDate();
        if (converted is DateTime) return converted;
      } catch (_) {
        // Firestore Timestamp is handled above when available at runtime.
      }

      return DateTime.now();
    }

    return Order(
      id: map['id'] as String? ?? '',
      date: readDate(rawDate),
      status: map['status'] as String? ?? 'Order Placed',
      itemCount: map['itemCount'] is int
          ? map['itemCount'] as int
          : items.fold(0, (sum, item) => sum + item.quantity),
      subtotal: readDouble('subtotal'),
      shipping: readDouble('shipping'),
      tax: readDouble('tax'),
      total: readDouble('total'),
      paymentMethod: map['paymentMethod'] as String? ?? 'Cash on Delivery',
      addressName: map['addressName'] as String? ?? 'Delivery Address',
      address: map['address'] as String? ?? '',
      city: map['city'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      items: items,
    );
  }
}
