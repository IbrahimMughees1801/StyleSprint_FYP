import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/product_photo.dart';
import '../services/supabase_products_service.dart';
import '../services/wishlist_service.dart';
import '../theme/app_theme.dart';

class ProductGrid extends StatefulWidget {
  final Function(int) onProductClick;

  const ProductGrid({super.key, required this.onProductClick});

  @override
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> {
  final SupabaseProductsService _productsService = SupabaseProductsService();
  final WishlistService _wishlistService = WishlistService.instance;
  List<ProductPhoto> _products = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _wishlistService.addListener(_refreshWishlist);
    _wishlistService.load();
    _loadProducts();
  }

  @override
  void dispose() {
    _wishlistService.removeListener(_refreshWishlist);
    super.dispose();
  }

  void _refreshWishlist() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleWishlist(ProductPhoto product) async {
    final added = await _wishlistService.toggle(product);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added ? 'Added to wishlist' : 'Removed from wishlist'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _productsService.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load products: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'New Arrivals',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.red500),
            ),
          )
        else if (_products.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No products found in Supabase.',
              style: TextStyle(color: AppTheme.gray600),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.49,
              crossAxisSpacing: 16,
              mainAxisSpacing: 32,
            ),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              return ProductCard(
                product: product,
                isFavorite: _wishlistService.contains(product.id),
                onTap: () => widget.onProductClick(product.id),
                onFavoriteTap: () => _toggleWishlist(product),
              );
            },
          ),
      ],
    );
  }
}

class ProductCard extends StatelessWidget {
  final ProductPhoto product;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFFE9EDFF),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFFE9EDFF),
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
              ),
              if (product.tryOnReady)
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Color(0xFF070235),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'AR',
                          style: TextStyle(
                            color: Color(0xFF070235),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  tooltip: isFavorite
                      ? 'Remove from wishlist'
                      : 'Add to wishlist',
                  onPressed: onFavoriteTap,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                    fixedSize: const Size(34, 34),
                    minimumSize: const Size(34, 34),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: isFavorite
                        ? AppTheme.red500
                        : AppTheme.atelierMidnight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            product.brand.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              height: 1.15,
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            product.name,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 15,
              height: 1.15,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '\$${product.price.toStringAsFixed(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 15,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
