import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../widgets/virtual_tryon_dialog.dart';
import '../models/product_photo.dart';
import '../services/supabase_products_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;
  final VoidCallback onBack;
  final Function(AppScreen) onNavigate;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.onBack,
    required this.onNavigate,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final List<String> _sizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  final List<Map<String, dynamic>> _colors = [
    {'name': 'Black', 'color': Colors.black},
    {'name': 'White', 'color': Colors.white},
    {'name': 'Gray', 'color': Colors.grey},
    {'name': 'Navy', 'color': const Color(0xFF1E3A8A)},
  ];

  String _selectedSize = 'M';
  int _selectedColorIndex = 0;
  bool _isFavorite = false;

  final SupabaseProductsService _productsService = SupabaseProductsService();
  ProductPhoto? _product;
  bool _isLoadingProduct = false;
  String? _productError;

  final String _displayStore = 'StyleSprint';
  final String _displayPrice = '\$49.99';
  final String? _displayOriginalPrice = null;
  final double _displayRating = 4.7;
  final bool _displayTryOn = true;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() {
      _isLoadingProduct = true;
      _productError = null;
    });

    try {
      final item = await _productsService.fetchProductById(widget.productId);
      if (!mounted) return;

      setState(() {
        _product = item;
        _isLoadingProduct = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productError = 'Failed to load product: $e';
        _isLoadingProduct = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProduct) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_productError != null) {
      return Scaffold(
        body: Center(
          child: Text(
            _productError!,
            style: const TextStyle(color: AppTheme.red500),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.5,
                pinned: true,
                backgroundColor: Theme.of(context).colorScheme.surface,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
                  onPressed: widget.onBack,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: AppTheme.gray900),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? AppTheme.red500 : AppTheme.gray900,
                    ),
                    onPressed: () {
                      setState(() {
                        _isFavorite = !_isFavorite;
                      });
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_product != null)
                        CachedNetworkImage(
                          imageUrl: _product!.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppTheme.gray100,
                          ),
                        )
                      else
                        Container(color: AppTheme.gray100),
                      if (_displayTryOn && _product != null)
                        Positioned(
                          bottom: 24,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: AppTheme.purplePinkGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.purple600.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => VirtualTryOnDialog(
                                      productImageUrl: _product!.imageUrl,
                                      productName: _product!.name,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.auto_awesome, color: Colors.white),
                                label: const Text(
                                  'Try This On',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Product details
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store and rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _displayStore,
                            style: const TextStyle(
                              color: AppTheme.gray500,
                              fontSize: 14,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, size: 16, color: AppTheme.yellow400),
                              const SizedBox(width: 4),
                              Text(
                                _displayRating.toString(),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '(234 reviews)',
                                style: TextStyle(color: AppTheme.gray500, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Product name
                      Text(
                        _product?.name ?? 'Product',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      // Price
                      Row(
                        children: [
                          Text(
                            _displayPrice,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.gray900,
                            ),
                          ),
                          if (_displayOriginalPrice != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              _displayOriginalPrice!,
                              style: const TextStyle(
                                fontSize: 18,
                                color: AppTheme.gray400,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.red500.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Save 30%',
                                style: TextStyle(
                                  color: AppTheme.red600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Color selection
                      const Text(
                        'Select Color',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(_colors.length, (index) {
                          final isSelected = _selectedColorIndex == index;
                          final colorData = _colors[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedColorIndex = index;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colorData['color'],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppTheme.purple600 : AppTheme.gray200,
                                  width: isSelected ? 3 : 2,
                                ),
                              ),
                              child: colorData['name'] == 'White'
                                  ? Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppTheme.gray300),
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      // Size selection
                      const Text(
                        'Select Size',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _sizes.map((size) {
                          final isSelected = _selectedSize == size;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSize = size;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.purple600.withOpacity(0.1) : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? AppTheme.purple600 : AppTheme.gray200,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                size,
                                style: TextStyle(
                                  color: isSelected ? AppTheme.purple600 : AppTheme.gray700,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      // Description
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Premium quality ${( _product?.name ?? 'product').toLowerCase()} made with high-quality materials. Features a modern fit and comfortable design perfect for everyday wear. Available in multiple colors and sizes to suit your style.',
                        style: const TextStyle(
                          color: AppTheme.gray600,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Features
                      Row(
                        children: [
                          _buildFeatureBox(Icons.local_shipping_outlined, 'Free\nShipping'),
                          const SizedBox(width: 16),
                          _buildFeatureBox(Icons.autorenew, 'Easy\nReturns'),
                          const SizedBox(width: 16),
                          _buildFeatureBox(Icons.verified_user_outlined, 'Secure\nPayment'),
                        ],
                      ),
                      const SizedBox(height: 100), // Space for bottom bar
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Bottom action bar
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
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => widget.onNavigate(AppScreen.cart),
                        icon: const Icon(Icons.shopping_cart_outlined),
                        label: const Text('Add to Cart'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gray900,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.purplePinkGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Buy Now',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

  Widget _buildFeatureBox(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.gray50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.purple600, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.gray600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
