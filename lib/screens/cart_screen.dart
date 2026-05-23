import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import '../main.dart';

class CartScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(AppScreen)? onNavigate;

  const CartScreen({super.key, required this.onBack, this.onNavigate});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService.instance;

  List<CartItem> get _cartItems => _cartService.items;

  @override
  void initState() {
    super.initState();
    _cartService.addListener(_refreshCart);
  }

  @override
  void dispose() {
    _cartService.removeListener(_refreshCart);
    super.dispose();
  }

  void _refreshCart() {
    if (mounted) setState(() {});
  }

  void _updateQuantity(String lineId, int delta) {
    _cartService.updateQuantity(lineId, delta);
  }

  void _removeItem(String lineId) {
    _cartService.removeItem(lineId);
  }

  double get _subtotal => _cartService.subtotal;
  double get _shipping => _cartService.shipping;
  double get _tax => _cartService.tax;
  double get _total => _cartService.total;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.atelierBackground,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                pinned: true,
                backgroundColor: AppTheme.atelierBackground,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppTheme.atelierMidnight),
                  onPressed: widget.onBack,
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cart',
                      style: const TextStyle(
                        color: AppTheme.atelierMidnight,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${_cartService.itemCount} ${_cartService.itemCount == 1 ? 'item' : 'items'}',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Cart items
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                sliver: _cartItems.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyCart(),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          if (index < _cartItems.length) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildCartItem(_cartItems[index]),
                            );
                          } else if (index == _cartItems.length) {
                            return _buildPromoCode();
                          }
                          return null;
                        }, childCount: _cartItems.length + 1),
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
                color: AppTheme.atelierSurface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
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
                        color: AppTheme.atelierMidnight,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.atelierMidnight.withValues(
                              alpha: 0.18,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _cartItems.isEmpty
                            ? null
                            : () => widget.onNavigate?.call(AppScreen.checkout),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
        color: AppTheme.atelierSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
              errorWidget: (context, url, error) => Container(
                width: 96,
                height: 96,
                color: AppTheme.gray100,
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppTheme.gray400,
                  size: 32,
                ),
              ),
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
                            'Size: ${item.size}  |  Color: ${item.color}',
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
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppTheme.red500,
                      ),
                      onPressed: () => _removeItem(item.lineId),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.atelierSurfaceLow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _updateQuantity(item.lineId, -1),
                            child: const Icon(Icons.remove, size: 16),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${item.quantity}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => _updateQuantity(item.lineId, 1),
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

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: AppTheme.gray400,
                size: 56,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a product to see live totals here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.gray600),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: widget.onBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.atelierMidnight,
                side: const BorderSide(color: AppTheme.atelierMidnight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
              ),
              child: const Text('Keep Shopping'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoCode() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.atelierSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.gray200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_offer_outlined,
            color: AppTheme.atelierMidnight,
          ),
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
          TextButton(onPressed: () {}, child: const Text('Apply')),
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
          style: const TextStyle(color: AppTheme.gray600, fontSize: 14),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
