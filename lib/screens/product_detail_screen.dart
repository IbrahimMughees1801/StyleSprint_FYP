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
  int _quantity = 1;
  bool _isFavorite = false;

  final SupabaseProductsService _productsService = SupabaseProductsService();
  final WishlistService _wishlistService = WishlistService.instance;
  ProductPhoto? _product;
  bool _isLoadingProduct = false;
  String? _productError;

  final String? _displayOriginalPrice = null;
  final double _displayRating = 4.7;

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

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
        quantity: _quantity,
      ),
    );

    if (goToCheckout) {
      widget.onNavigate(AppScreen.checkout);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added $_quantity x ${product.name} - $_selectedSize, $_selectedColorName',
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

  void _updateQuantity(int delta) {
    setState(() {
      _quantity = (_quantity + delta).clamp(1, 9).toInt();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProduct) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_productError != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppTheme.red500,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _productError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.red500),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: widget.onBack,
                        child: const Text('Back'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _loadProduct,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
                          color: _surfaceLow(context),
                          child: CachedNetworkImage(
                            imageUrl: selectedImageUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) =>
                                Container(color: _surfaceLow(context)),
                            errorWidget: (context, url, error) => Container(
                              color: _surfaceLow(context),
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(color: _surfaceLow(context)),
                      if ((product?.tryOnReady ?? false) && product != null)
                        Positioned(
                          bottom: 24,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: _accent(context),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: _accent(
                                      context,
                                    ).withValues(alpha: 0.24),
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
                                      productImageUrl: _selectedProductImageUrl(
                                        product,
                                      ),
                                      productName: product.name,
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.auto_awesome,
                                  color: _accentForeground(context),
                                ),
                                label: Text(
                                  'Try This On',
                                  style: TextStyle(
                                    color: _accentForeground(context),
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
                            style: TextStyle(
                              color: _mutedText(context),
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
                              Text(
                                '(234 reviews)',
                                style: TextStyle(
                                  color: _mutedText(context),
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
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: _accent(context),
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
                      Text(
                        'Select Color',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _strongText(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedColorName,
                        style: TextStyle(
                          color: _mutedText(context),
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
                                      ? _accent(context)
                                      : _border(context),
                                  width: isSelected ? 3 : 2,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (colorData['name'] == 'White')
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppTheme.gray300,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check,
                                      size: 18,
                                      color: colorData['name'] == 'White'
                                          ? _accent(context)
                                          : Colors.white,
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      // Size selection
                      Text(
                        'Select Size',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _strongText(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedSize,
                        style: TextStyle(
                          color: _mutedText(context),
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
                                    ? _surfaceLow(context)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? _accent(context)
                                      : _border(context),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                size,
                                style: TextStyle(
                                  color: isSelected
                                      ? _accent(context)
                                      : _strongText(context),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quantity',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _strongText(context),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Add up to 9 at once',
                                  style: TextStyle(
                                    color: _mutedText(context),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          _buildQuantityStepper(),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Description
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _strongText(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        product?.description ??
                            'Premium quality ${(product?.name ?? 'product').toLowerCase()} made with high-quality materials. Features a modern fit and comfortable design perfect for everyday wear. Available in multiple colors and sizes to suit your style.',
                        style: TextStyle(
                          color: _mutedText(context),
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
                          backgroundColor: _accent(context),
                          foregroundColor: _accentForeground(context),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _addToCart(goToCheckout: true),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accent(context),
                          side: BorderSide(color: _accent(context)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Buy Now',
                            style: TextStyle(fontWeight: FontWeight.w600),
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
          style: TextStyle(
            color: _mutedText(context),
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
                      color: isSelected ? _accent(context) : _border(context),
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _accent(context).withValues(alpha: 0.14),
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
                          Container(color: _surfaceLow(context)),
                      errorWidget: (context, url, error) => Container(
                        color: _surfaceLow(context),
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

  Widget _buildQuantityStepper() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _surfaceLow(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Decrease quantity',
            onPressed: _quantity == 1 ? null : () => _updateQuantity(-1),
            icon: const Icon(Icons.remove, size: 18),
            color: _accent(context),
            disabledColor: AppTheme.gray400,
            constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$_quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _strongText(context),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Increase quantity',
            onPressed: _quantity == 9 ? null : () => _updateQuantity(1),
            icon: const Icon(Icons.add, size: 18),
            color: _accent(context),
            disabledColor: AppTheme.gray400,
            constraints: const BoxConstraints.tightFor(width: 42, height: 42),
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
          color: _surfaceLow(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: _accent(context), size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: _mutedText(context)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
