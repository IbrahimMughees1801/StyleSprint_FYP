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

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _surface(BuildContext context) => Theme.of(context).colorScheme.surface;

  Color _surfaceLow(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1A2A3A) : AppTheme.atelierSurfaceLow;

  Color _border(BuildContext context) =>
      _isDark(context) ? AppTheme.gray700 : AppTheme.gray200;

  Color _accent(BuildContext context) =>
      _isDark(context) ? AppTheme.atelierAccent : AppTheme.atelierMidnight;

  Color _accentForeground(BuildContext context) =>
      _isDark(context) ? AppTheme.atelierDark : Colors.white;

  Color _strongText(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.color ??
      (_isDark(context) ? Colors.white : AppTheme.gray900);

  Color _mutedText(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.color ??
      (_isDark(context) ? AppTheme.gray400 : AppTheme.gray600);

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

  void _removeItem(CartItem item) {
    _cartService.removeItem(item.lineId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} removed from cart'),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _cartService.addItem(item),
        ),
      ),
    );
  }

  double get _subtotal => _cartService.subtotal;
  double get _shipping => _cartService.shipping;
  double get _tax => _cartService.tax;
  double get _total => _cartService.total;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                pinned: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: _accent(context)),
                  onPressed: widget.onBack,
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cart',
                      style: TextStyle(
                        color: _accent(context),
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
              SliverToBoxAdapter(
                child: SizedBox(
                  height: _cartItems.isEmpty ? 24 : 200,
                ), // Space for bottom summary
              ),
            ],
          ),
          // Bottom summary
          if (_cartItems.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _surface(context),
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
                          Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _strongText(context),
                            ),
                          ),
                          Text(
                            '\$${_total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _strongText(context),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _accent(context),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _accent(context).withValues(alpha: 0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _cartItems.isEmpty
                              ? null
                              : () =>
                                    widget.onNavigate?.call(AppScreen.checkout),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Proceed to Checkout',
                            style: TextStyle(
                              color: _accentForeground(context),
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
        color: _surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border(context)),
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
              placeholder: (context, url) =>
                  Container(color: _surfaceLow(context)),
              errorWidget: (context, url, error) => Container(
                width: 96,
                height: 96,
                color: _surfaceLow(context),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: _mutedText(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _strongText(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Size: ${item.size}  |  Color: ${item.color}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _mutedText(context),
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
                      onPressed: () => _removeItem(item),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _strongText(context),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: _surfaceLow(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Decrease quantity',
                            onPressed: item.quantity == 1
                                ? null
                                : () => _updateQuantity(item.lineId, -1),
                            icon: const Icon(Icons.remove, size: 16),
                            color: _accent(context),
                            disabledColor: AppTheme.gray400,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${item.quantity}',
                            style: TextStyle(
                              color: _strongText(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Increase quantity',
                            onPressed: () => _updateQuantity(item.lineId, 1),
                            icon: const Icon(Icons.add, size: 16),
                            color: _accent(context),
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            padding: EdgeInsets.zero,
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
              decoration: BoxDecoration(
                color: _surfaceLow(context),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: AppTheme.gray400,
                size: 56,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _strongText(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a product to see live totals here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _mutedText(context)),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: widget.onBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent(context),
                side: BorderSide(color: _accent(context)),
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
        color: _surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border(context)),
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
          Icon(Icons.local_offer_outlined, color: _accent(context)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              style: TextStyle(color: _strongText(context)),
              cursorColor: _accent(context),
              decoration: InputDecoration(
                hintText: 'Enter promo code',
                hintStyle: TextStyle(color: _mutedText(context)),
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
        Text(label, style: TextStyle(color: _mutedText(context), fontSize: 14)),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: _strongText(context),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
