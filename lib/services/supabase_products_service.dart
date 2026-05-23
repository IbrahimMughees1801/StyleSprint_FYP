import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_photo.dart';

class SupabaseProductsService {
  Future<List<ProductPhoto>> fetchProducts() async {
    try {
      return await _fetchProductsWithImages();
    } catch (e) {
      try {
        return await _fetchLegacyProducts();
      } catch (_) {
        throw Exception('Supabase fetchProducts failed: $e');
      }
    }
  }

  Future<ProductPhoto?> fetchProductById(int id) async {
    try {
      return await _fetchProductByIdWithImages(id);
    } catch (e) {
      try {
        return await _fetchLegacyProductById(id);
      } catch (_) {
        throw Exception('Supabase fetchProductById failed: $e');
      }
    }
  }

  Future<List<ProductPhoto>> _fetchProductsWithImages() async {
    final response = await Supabase.instance.client
        .from('products')
        .select(
          'catalog_id, name, image_url, brand, category, price, description, tryon_ready, '
          'product_type, '
          'product_images(id, image_url, image_kind, sort_order)',
        )
        .order('catalog_id', ascending: true)
        .order('sort_order', referencedTable: 'product_images', ascending: true)
        .timeout(const Duration(seconds: 10));

    final items = response as List<dynamic>;
    return items
        .map((item) => ProductPhoto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ProductPhoto?> _fetchProductByIdWithImages(int id) async {
    final response = await Supabase.instance.client
        .from('products')
        .select(
          'catalog_id, name, image_url, brand, category, price, description, tryon_ready, '
          'product_type, '
          'product_images(id, image_url, image_kind, sort_order)',
        )
        .eq('catalog_id', id)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    if (response == null) {
      return null;
    }

    return ProductPhoto.fromJson(response);
  }

  Future<List<ProductPhoto>> _fetchLegacyProducts() async {
    final response = await Supabase.instance.client
        .from('products')
        .select('id, name, image_url')
        .order('id', ascending: true)
        .timeout(const Duration(seconds: 10));

    final items = response as List<dynamic>;
    return items
        .map((item) => ProductPhoto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ProductPhoto?> _fetchLegacyProductById(int id) async {
    final response = await Supabase.instance.client
        .from('products')
        .select('id, name, image_url')
        .eq('id', id)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));

    if (response == null) {
      return null;
    }

    return ProductPhoto.fromJson(response);
  }
}
