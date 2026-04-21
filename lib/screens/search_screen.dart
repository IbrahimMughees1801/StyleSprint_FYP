import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../models/product_photo.dart';
import '../services/supabase_products_service.dart';

class SearchScreen extends StatefulWidget {
  final Function(int) onProductClick;
  final VoidCallback? onBack;

  const SearchScreen({
    super.key,
    required this.onProductClick,
    this.onBack,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SupabaseProductsService _productsService = SupabaseProductsService();
  final List<String> _recentSearches = [
    'Summer dresses',
    'Nike sneakers',
    'Denim jackets',
    'Formal shirts',
  ];
  final List<String> _trendingSearches = [
    'Oversized hoodies',
    'Cargo pants',
    'Vintage tees',
    'Running shoes',
    'Leather jackets',
    'Crop tops',
  ];
  
  List<ProductPhoto> _allProducts = [];
  List<ProductPhoto> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedCategory = 'All';
  String _sortBy = 'Relevance';

  final List<String> _categories = ['All', 'Men', 'Women', 'Kids', 'Accessories'];
  final List<String> _sortOptions = ['Relevance', 'Price: Low to High', 'Price: High to Low', 'Rating'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
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
        _allProducts = items;
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      // Simulate search - in real app, this would be an API call
      _searchResults = _allProducts.where((product) {
        return product.name.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchResults = [];
    });
  }

  void _removeRecentSearch(String search) {
    setState(() {
      _recentSearches.remove(search);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            if (_isSearching) ...[
              _buildFilterBar(),
              Expanded(child: _buildSearchResults()),
            ] else ...[
              Expanded(child: _buildSearchSuggestions()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
              onPressed: widget.onBack,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.gray100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                onChanged: _performSearch,
                decoration: InputDecoration(
                  hintText: 'Search products, brands...',
                  hintStyle: const TextStyle(color: AppTheme.gray400),
                  prefixIcon: const Icon(Icons.search, color: AppTheme.gray400),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.gray400),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          if (_isSearching) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: _clearSearch,
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 60,
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    backgroundColor: AppTheme.gray100,
                    selectedColor: AppTheme.purple600,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.gray700,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              onSelected: (value) {
                setState(() {
                  _sortBy = value;
                });
              },
              itemBuilder: (context) => _sortOptions.map((option) {
                return PopupMenuItem<String>(
                  value: option,
                  child: Row(
                    children: [
                      if (_sortBy == option)
                        const Icon(Icons.check, size: 20, color: AppTheme.purple600),
                      if (_sortBy == option) const SizedBox(width: 8),
                      Text(option),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: AppTheme.red500),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppTheme.gray300),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.gray700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.gray500,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildProductCard(_searchResults[index]);
      },
    );
  }

  Widget _buildProductCard(ProductPhoto product) {
    return GestureDetector(
      onTap: () => widget.onProductClick(product.id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.gray100,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppTheme.purplePinkGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.view_in_ar, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'AR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.favorite_border, size: 20),
                      onPressed: () {},
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'StyleSprint',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.gray500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 12, color: AppTheme.yellow400),
                      const SizedBox(width: 4),
                      Text(
                        '4.7',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$49.99',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.gray900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          const Text(
            'Recent Searches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),
          ..._recentSearches.map((search) => _buildSearchItem(
                search,
                Icons.history,
                onTap: () {
                  _searchController.text = search;
                  _performSearch(search);
                },
                onDelete: () => _removeRecentSearch(search),
              )),
          const SizedBox(height: 24),
        ],
        const Text(
          'Trending Searches',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 16),
        ..._trendingSearches.map((search) => _buildSearchItem(
              search,
              Icons.trending_up,
              onTap: () {
                _searchController.text = search;
                _performSearch(search);
              },
            )),
      ],
    );
  }

  Widget _buildSearchItem(
    String text,
    IconData icon, {
    VoidCallback? onTap,
    VoidCallback? onDelete,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.gray400),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.gray700,
                ),
              ),
            ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppTheme.gray400),
                onPressed: onDelete,
              )
            else
              const Icon(Icons.north_west, size: 18, color: AppTheme.gray400),
          ],
        ),
      ),
    );
  }
}
