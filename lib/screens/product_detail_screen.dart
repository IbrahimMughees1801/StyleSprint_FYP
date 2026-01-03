import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../main.dart';

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

  late Product product;

  @override
  void initState() {
    super.initState();
    product = sampleProducts.firstWhere(
      (p) => p.id == widget.productId,
      orElse: () => sampleProducts[0],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.5,
                pinned: true,
                backgroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppTheme.gray900),
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
                      CachedNetworkImage(
                        imageUrl: product.image,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppTheme.gray100,
                        ),
                      ),
                      if (product.virtualTryOn)
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
                                onPressed: () => widget.onNavigate(AppScreen.tryon),
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
                            product.store,
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
                                product.rating.toString(),
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
                        product.name,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      // Price
                      Row(
                        children: [
                          Text(
                            product.price,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.gray900,
                            ),
                          ),
                          if (product.originalPrice != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              product.originalPrice!,
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
                        'Premium quality ${product.name.toLowerCase()} made with high-quality materials. Features a modern fit and comfortable design perfect for everyday wear. Available in multiple colors and sizes to suit your style.',
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
