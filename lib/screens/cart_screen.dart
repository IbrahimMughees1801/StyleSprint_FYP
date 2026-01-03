import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../main.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(AppScreen)? onNavigate;

  const CartScreen({
    super.key,
    required this.onBack,
    this.onNavigate,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> _cartItems = [
    CartItem(
      id: 1,
      name: 'Classic White Hoodie',
      store: 'H&M',
      price: 49.99,
      image: 'https://images.unsplash.com/photo-1711387718409-a05f62a3dc39?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
      size: 'M',
      color: 'White',
      quantity: 1,
    ),
    CartItem(
      id: 2,
      name: 'Elegant Summer Dress',
      store: 'Zara',
      price: 89.99,
      image: 'https://images.unsplash.com/photo-1610202631408-fa6ba0f39ca3?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
      size: 'L',
      color: 'Black',
      quantity: 2,
    ),
    CartItem(
      id: 3,
      name: 'Premium Sneakers',
      store: 'Nike',
      price: 129.99,
      image: 'https://images.unsplash.com/photo-1656944227480-98180d2a5155?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
      size: '10',
      color: 'White',
      quantity: 1,
    ),
  ];

  void _updateQuantity(int id, int delta) {
    setState(() {
      final index = _cartItems.indexWhere((item) => item.id == id);
      if (index != -1) {
        _cartItems[index].quantity = (_cartItems[index].quantity + delta).clamp(1, 99);
      }
    });
  }

  void _removeItem(int id) {
    setState(() {
      _cartItems.removeWhere((item) => item.id == id);
    });
  }

  double get _subtotal {
    return _cartItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  double get _shipping => 9.99;
  double get _tax => _subtotal * 0.1;
  double get _total => _subtotal + _shipping + _tax;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray50,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.gray900),
                  onPressed: widget.onBack,
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shopping Cart',
                      style: TextStyle(color: AppTheme.gray900, fontSize: 20),
                    ),
                    Text(
                      '${_cartItems.length} items',
                      style: const TextStyle(color: AppTheme.gray500, fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Cart items
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index < _cartItems.length) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildCartItem(_cartItems[index]),
                        );
                      } else if (index == _cartItems.length) {
                        return _buildPromoCode();
                      }
                      return null;
                    },
                    childCount: _cartItems.length + 1,
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 200), // Space for bottom summary
              ),
            ],
          ),
          // Bottom summary
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSummaryRow('Subtotal', _subtotal),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Shipping', _shipping),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Tax', _tax),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${_total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: AppTheme.purplePinkGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.purple600.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => widget.onNavigate?.call(AppScreen.checkout),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Proceed to Checkout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: item.image,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: AppTheme.gray100),
            ),
          ),
          const SizedBox(width: 16),
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.store,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.gray500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Size: ${item.size}  •  Color: ${item.color}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.gray500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.red500),
                      onPressed: () => _removeItem(item.id),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.gray100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _updateQuantity(item.id, -1),
                            child: const Icon(Icons.remove, size: 16),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${item.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => _updateQuantity(item.id, 1),
                            child: const Icon(Icons.add, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCode() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer_outlined, color: AppTheme.purple600),
          const SizedBox(width: 12),
          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Enter promo code',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.gray600,
            fontSize: 14,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
