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
  final int id;
  final String name;
  final String store;
  final double price;
  final String image;
  final String size;
  final String color;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.store,
    required this.price,
    required this.image,
    required this.size,
    required this.color,
    required this.quantity,
  });
}

