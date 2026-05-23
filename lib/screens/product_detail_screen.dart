import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../widgets/virtual_tryon_dialog.dart';
import '../models/product.dart';
import '../models/product_photo.dart';
import '../services/cart_service.dart';
import '../services/supabase_products_service.dart';
import '../services/wishlist_service.dart';

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
  int _selectedImageIndex = 0;
  bool _isFavorite = false;

  final SupabaseProductsService _productsService = SupabaseProductsService();
  final WishlistService _wishlistService = WishlistService.instance;
  ProductPhoto? _product;
  bool _isLoadingProduct = false;
  String? _productError;

  final String? _displayOriginalPrice = null;
  final double _displayRating = 4.7;

  String get _selectedColorName {
    return _colors[_selectedColorIndex]['name'] as String;
  }

  String _selectedProductImageUrl(ProductPhoto product) {
    final imageUrls = product.galleryImageUrls;
    if (imageUrls.isEmpty) return product.imageUrl;
    final safeImageIndex = _selectedImageIndex < imageUrls.length
        ? _selectedImageIndex
        : 0;
    return imageUrls[safeImageIndex];
  }

  @override
  void initState() {
    super.initState();
    _wishlistService.addListener(_refreshWishlist);
    _wishlistService.load();
    _loadProduct();
  }

  @override
  void dispose() {
    _wishlistService.removeListener(_refreshWishlist);
    super.dispose();
  }

  void _refreshWishlist() {
    final product = _product;
    if (mounted && product != null) {
      setState(() {
        _isFavorite = _wishlistService.contains(product.id);
      });
    }
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
        _selectedImageIndex = 0;
        _isFavorite = item == null ? false : _wishlistService.contains(item.id);
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

  void _addToCart({required bool goToCheckout}) {
    final product = _product;
    if (product == null) return;

    CartService.instance.addItem(
      CartItem(
        id: product.id,
        name: product.name,
        store: product.brand,
        price: product.price,
        image: _selectedProductImageUrl(product),
        size: _selectedSize,
        color: _selectedColorName,
        quantity: 1,
      ),
    );

    if (goToCheckout) {
      widget.onNavigate(AppScreen.checkout);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${product.name} added to cart - $_selectedSize, $_selectedColorName',
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => widget.onNavigate(AppScreen.cart),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final product = _product;
    if (product == null) return;

    final added = await _wishlistService.toggle(product);
    if (!mounted) return;
    setState(() => _isFavorite = added);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added ? 'Added to wishlist' : 'Removed from wishlist'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProduct) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

    final product = _product;
    final imageUrls = product?.galleryImageUrls ?? const <String>[];
    final safeImageIndex = _selectedImageIndex < imageUrls.length
        ? _selectedImageIndex
        : 0;
    final selectedImageUrl = imageUrls.isNotEmpty
        ? imageUrls[safeImageIndex]
        : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                expandedHeight: MediaQuery.of(context).size.height * 0.5,
                pinned: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  onPressed: widget.onBack,
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.share_outlined,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    tooltip: _isFavorite
                        ? 'Remove from wishlist'
                        : 'Add to wishlist',
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite
                          ? AppTheme.red500
                          : Theme.of(context).iconTheme.color,
                    ),
                    onPressed: _toggleFavorite,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (selectedImageUrl != null)
                        Container(
                          color: AppTheme.atelierSurfaceLow,
                          child: CachedNetworkImage(
                            imageUrl: selectedImageUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) =>
                                Container(color: AppTheme.gray100),
                            errorWidget: (context, url, error) => Container(
                              color: AppTheme.gray100,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(color: AppTheme.gray100),
                      if ((product?.tryOnReady ?? false) && product != null)
                        Positioned(
                          bottom: 24,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.atelierMidnight,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.atelierMidnight.withValues(
                                      alpha: 0.24,
                                    ),
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
                                      productImageUrl:
                                          _selectedProductImageUrl(product),
                                      productName: product.name,
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                ),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
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
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageUrls.length > 1) ...[
                        _buildImageGalleryThumbs(imageUrls, safeImageIndex),
                        const SizedBox(height: 20),
                      ],
                      // Store and rating
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            (product?.brand ?? 'StyleSprint').toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.gray600,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 16,
                                color: AppTheme.yellow400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _displayRating.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '(234 reviews)',
                                style: TextStyle(
                                  color: AppTheme.gray500,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Product name
                      Text(
                        product?.name ?? 'Product',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      // Price
                      Row(
                        children: [
                          Text(
                            '\$${(product?.price ?? 49.99).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.atelierMidnight,
                            ),
                          ),
                          if (_displayOriginalPrice != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              _displayOriginalPrice,
                              style: const TextStyle(
                                fontSize: 18,
                                color: AppTheme.gray400,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.red500.withValues(alpha: 0.1),
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
                      const SizedBox(height: 4),
                      Text(
                        _selectedColorName,
                        style: const TextStyle(
                          color: AppTheme.gray600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
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
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colorData['color'],
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.atelierMidnight
                                      : AppTheme.gray200,
                                  width: isSelected ? 3 : 2,
                                ),
                              ),
                              child: colorData['name'] == 'White'
                                  ? DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.gray300,
                                        ),
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
                      const SizedBox(height: 4),
                      Text(
                        _selectedSize,
                        style: const TextStyle(
                          color: AppTheme.gray600,
                          fontSize: 13,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.atelierSurfaceLow
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.atelierMidnight
                                      : AppTheme.gray200,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                size,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppTheme.atelierMidnight
                                      : AppTheme.gray700,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
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
                        product?.description ??
                            'Premium quality ${(product?.name ?? 'product').toLowerCase()} made with high-quality materials. Features a modern fit and comfortable design perfect for everyday wear. Available in multiple colors and sizes to suit your style.',
                        style: const TextStyle(
                          color: AppTheme.gray600,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Features
                      Row(
                        children: [
                          _buildFeatureBox(
                            Icons.local_shipping_outlined,
                            'Free\nShipping',
                          ),
                          const SizedBox(width: 16),
                          _buildFeatureBox(Icons.autorenew, 'Easy\nReturns'),
                          const SizedBox(width: 16),
                          _buildFeatureBox(
                            Icons.verified_user_outlined,
                            'Secure\nPayment',
                          ),
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
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
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
                        onPressed: () => _addToCart(goToCheckout: false),
                        icon: const Icon(Icons.shopping_cart_outlined),
                        label: const Text('Add to Cart'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.atelierMidnight,
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
                        color: AppTheme.atelierSurface,
                        border: Border.all(color: AppTheme.atelierMidnight),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: () => _addToCart(goToCheckout: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Buy Now',
                          style: TextStyle(
                            color: AppTheme.atelierMidnight,
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

  Widget _buildImageGalleryThumbs(List<String> imageUrls, int selectedIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${selectedIndex + 1} of ${imageUrls.length} photos',
          style: const TextStyle(
            color: AppTheme.gray600,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: imageUrls.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final isSelected = selectedIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedImageIndex = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 76,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.atelierMidnight
                          : AppTheme.gray200,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.atelierMidnight.withValues(
                                alpha: 0.14,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: CachedNetworkImage(
                      imageUrl: imageUrls[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: AppTheme.gray100),
                      errorWidget: (context, url, error) => Container(
                        color: AppTheme.gray100,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
            Icon(icon, color: AppTheme.atelierMidnight, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.gray600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
