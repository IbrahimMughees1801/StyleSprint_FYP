import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_photo.dart';

class SupabaseProductsService {
  Future<List<ProductPhoto>> fetchProducts() async {
    final response = await Supabase.instance.client
        .from('products')
        .select('id, name, image_url')
        .order('id');

    final items = response as List<dynamic>;
    return items
        .map((item) => ProductPhoto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ProductPhoto?> fetchProductById(int id) async {
    final response = await Supabase.instance.client
        .from('products')
        .select('id, name, image_url')
        .eq('id', id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return ProductPhoto.fromJson(response as Map<String, dynamic>);
  }
}
