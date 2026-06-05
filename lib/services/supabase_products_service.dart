import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_photo.dart';

class SupabaseProductsService {
  static const Duration _requestTimeout = Duration(seconds: 25);
  static List<ProductPhoto>? _productCache;

  Future<List<ProductPhoto>> fetchProducts() async {
    final cached = _productCache;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    try {
      final products = await _fetchProductsWithImages();
      _productCache = products;
      return products;
    } catch (e) {
      debugPrint('Supabase fetchProducts primary query failed: $e');
      try {
        final products = await _fetchLegacyProducts();
        _productCache = products;
        return products;
      } catch (fallbackError) {
        debugPrint(
          'Supabase fetchProducts fallback query failed: $fallbackError',
        );
        throw Exception('Supabase fetchProducts failed: $e');
      }
    }
  }

  Future<ProductPhoto?> fetchProductById(int id) async {
    try {
      return await _fetchProductByIdWithImages(id);
    } catch (e) {
      debugPrint('Supabase fetchProductById primary query failed: $e');
      try {
        return await _fetchLegacyProductById(id);
      } catch (fallbackError) {
        debugPrint(
          'Supabase fetchProductById fallback query failed: $fallbackError',
        );
        throw Exception('Supabase fetchProductById failed: $e');
      }
    }
  }

  Future<List<ProductPhoto>> _fetchProductsWithImages() async {
    final products = await Supabase.instance.client
        .from('products')
        .select(
          'id, catalog_id, name, image_url, brand, category, price, description, tryon_ready, product_type',
        )
        .order('catalog_id', ascending: true)
        .limit(100)
        .timeout(_requestTimeout);

    final productItems = products as List<dynamic>;

    return _parseProducts(
      productItems.map((item) {
        final product = Map<String, dynamic>.from(item as Map);
        product['product_images'] = const [];
        return product;
      }).toList(),
    );
  }

  Future<ProductPhoto?> _fetchProductByIdWithImages(int id) async {
    final response = await Supabase.instance.client
        .from('products')
        .select(
          'id, catalog_id, name, image_url, brand, category, price, description, tryon_ready, product_type',
        )
        .eq('catalog_id', id)
        .maybeSingle()
        .timeout(_requestTimeout);

    if (response == null) {
      return null;
    }

    final product = Map<String, dynamic>.from(response);
    final productId = product['id'] as String?;
    final imagesByProductId = await _fetchImagesByProductId(
      productId == null ? const [] : [productId],
    );
    product['product_images'] = imagesByProductId[productId] ?? [];

    return ProductPhoto.fromJson(product);
  }

  Future<List<ProductPhoto>> _fetchLegacyProducts() async {
    final response = await Supabase.instance.client
        .from('products')
        .select('id, catalog_id, name, image_url, brand, category, price')
        .order('catalog_id', ascending: true)
        .limit(100)
        .timeout(_requestTimeout);

    final items = response as List<dynamic>;
    return _parseProducts(items);
  }

  Future<ProductPhoto?> _fetchLegacyProductById(int id) async {
    final response = await Supabase.instance.client
        .from('products')
        .select('id, catalog_id, name, image_url, brand, category, price')
        .eq('catalog_id', id)
        .maybeSingle()
        .timeout(_requestTimeout);

    if (response == null) {
      return null;
    }

    return ProductPhoto.fromJson(response);
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchImagesByProductId(
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) return {};

    try {
      final response = await Supabase.instance.client
          .from('product_images')
          .select('id, product_id, image_url, image_kind, sort_order')
          .inFilter('product_id', productIds)
          .order('sort_order', ascending: true)
          .timeout(_requestTimeout);

      final imagesByProductId = <String, List<Map<String, dynamic>>>{};
      for (final item in response as List<dynamic>) {
        final image = Map<String, dynamic>.from(item as Map);
        final productId = image['product_id'] as String?;
        if (productId == null) continue;
        imagesByProductId.putIfAbsent(productId, () => []).add(image);
      }
      return imagesByProductId;
    } catch (e) {
      debugPrint('Supabase product_images query failed: $e');
      return {};
    }
  }

  List<ProductPhoto> _parseProducts(List<dynamic> items) {
    final products = <ProductPhoto>[];

    for (final item in items) {
      try {
        final product = ProductPhoto.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
        if (product.imageUrl.trim().isEmpty) continue;
        products.add(product);
      } catch (e) {
        debugPrint('Skipping malformed Supabase product row: $e');
      }
    }

    return products;
  }
}
