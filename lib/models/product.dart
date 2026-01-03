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

// Sample product data
final List<Product> sampleProducts = [
  Product(
    id: 1,
    name: 'Classic White Hoodie',
    store: 'H&M',
    price: '\$49.99',
    originalPrice: '\$69.99',
    image: 'https://images.unsplash.com/photo-1711387718409-a05f62a3dc39?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    rating: 4.5,
    virtualTryOn: true,
    category: 'Hoodies',
  ),
  Product(
    id: 2,
    name: 'Elegant Summer Dress',
    store: 'Zara',
    price: '\$89.99',
    image: 'https://images.unsplash.com/photo-1610202631408-fa6ba0f39ca3?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    rating: 4.8,
    virtualTryOn: true,
    category: 'Dresses',
  ),
  Product(
    id: 3,
    name: 'Premium Sneakers',
    store: 'Nike',
    price: '\$129.99',
    image: 'https://images.unsplash.com/photo-1656944227480-98180d2a5155?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    rating: 4.7,
    virtualTryOn: false,
    category: 'Shoes',
  ),
  Product(
    id: 4,
    name: 'Winter Jacket',
    store: 'The North Face',
    price: '\$199.99',
    originalPrice: '\$249.99',
    image: 'https://images.unsplash.com/photo-1706765779494-2705542ebe74?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    rating: 4.9,
    virtualTryOn: true,
    category: 'Jackets',
  ),
  Product(
    id: 5,
    name: 'Casual T-Shirt',
    store: 'Uniqlo',
    price: '\$19.99',
    image: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    rating: 4.3,
    virtualTryOn: true,
    category: 'T-Shirts',
  ),
  Product(
    id: 6,
    name: 'Denim Jeans',
    store: "Levi's",
    price: '\$79.99',
    image: 'https://images.unsplash.com/photo-1542272454315-7f6fabf4b0b4?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    rating: 4.6,
    virtualTryOn: true,
    category: 'Jeans',
  ),
];
