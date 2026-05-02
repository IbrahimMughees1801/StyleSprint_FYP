import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_photo.dart';

class SupabaseProductsService {
  Future<List<ProductPhoto>> fetchProducts() async {
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select('id, name, image_url')
          .order('id')
          .timeout(const Duration(seconds: 10));

      final items = response as List<dynamic>;
      return items
          .map((item) => ProductPhoto.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Supabase fetchProducts failed: $e');
    }
  }

  Future<ProductPhoto?> fetchProductById(int id) async {
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select('id, name, image_url')
          .eq('id', id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (response == null) {
        return null;
      }

      return ProductPhoto.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Supabase fetchProductById failed: $e');
    }
  }
}
