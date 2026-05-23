class Product {
  final int id;
  final String name;
  final String store;
  final String price;
  final String? originalPrice;
  final String image;
  final double rating;
  final bool virtualTryOn;
  final String category;

  Product({
    required this.id,
    required this.name,
    required this.store,
    required this.price,
    this.originalPrice,
    required this.image,
    required this.rating,
    required this.virtualTryOn,
    required this.category,
  });
}

class CartItem {
  final String lineId;
  final int id;
  final String name;
  final String store;
  final double price;
  final String image;
  final String size;
  final String color;
  int quantity;

  CartItem({
    String? lineId,
    required this.id,
    required this.name,
    required this.store,
    required this.price,
    required this.image,
    required this.size,
    required this.color,
    required this.quantity,
  }) : lineId = lineId ?? '$id|$size|$color';

  CartItem copyWith({
    String? lineId,
    int? id,
    String? name,
    String? store,
    double? price,
    String? image,
    String? size,
    String? color,
    int? quantity,
  }) {
    return CartItem(
      lineId: lineId ?? this.lineId,
      id: id ?? this.id,
      name: name ?? this.name,
      store: store ?? this.store,
      price: price ?? this.price,
      image: image ?? this.image,
      size: size ?? this.size,
      color: color ?? this.color,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lineId': lineId,
      'id': id,
      'name': name,
      'store': store,
      'price': price,
      'image': image,
      'size': size,
      'color': color,
      'quantity': quantity,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    final rawId = map['id'];
    final rawPrice = map['price'];
    final rawQuantity = map['quantity'];

    return CartItem(
      lineId: map['lineId'] as String?,
      id: rawId is int
          ? rawId
          : rawId is String
          ? int.tryParse(rawId) ?? 0
          : 0,
      name: map['name'] as String? ?? 'Product',
      store: map['store'] as String? ?? 'StyleSprint',
      price: rawPrice is num
          ? rawPrice.toDouble()
          : rawPrice is String
          ? double.tryParse(rawPrice) ?? 0
          : 0,
      image: map['image'] as String? ?? '',
      size: map['size'] as String? ?? 'M',
      color: map['color'] as String? ?? 'Default',
      quantity: rawQuantity is int
          ? rawQuantity
          : rawQuantity is String
          ? int.tryParse(rawQuantity) ?? 1
          : 1,
    );
  }
}
