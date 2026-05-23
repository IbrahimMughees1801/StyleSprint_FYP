class ProductPhoto {
  final int id;
  final String name;
  final String imageUrl;
  final String brand;
  final String? category;
  final String? productType;
  final double price;
  final String? description;
  final bool tryOnReady;
  final List<ProductImage> images;

  const ProductPhoto({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.brand = 'StyleSprint',
    this.category,
    this.productType,
    this.price = 49.99,
    this.description,
    this.tryOnReady = true,
    this.images = const [],
  });

  List<String> get galleryImageUrls {
    final urls = <String>[imageUrl, ...images.map((image) => image.imageUrl)];

    return urls.where((url) => url.trim().isNotEmpty).toSet().toList();
  }

  String get tryOnImageUrl {
    for (final image in images) {
      if (image.imageKind == 'tryon' && image.imageUrl.trim().isNotEmpty) {
        return image.imageUrl;
      }
    }
    return imageUrl;
  }

  factory ProductPhoto.fromJson(Map<String, dynamic> json) {
    final rawId = json['catalog_id'] ?? json['id'];
    final intId = rawId is int
        ? rawId
        : rawId is String
        ? int.tryParse(rawId) ?? 0
        : 0;
    final rawImages = json['product_images'];
    final images = rawImages is List
        ? rawImages
              .map(
                (item) => ProductImage.fromJson(item as Map<String, dynamic>),
              )
              .toList()
        : <ProductImage>[];
    final rawPrice = json['price'];

    return ProductPhoto(
      id: intId,
      name: json['name'] as String? ?? 'Product',
      imageUrl: json['image_url'] as String? ?? '',
      brand: json['brand'] as String? ?? 'StyleSprint',
      category: json['category'] as String?,
      productType: json['product_type'] as String?,
      price: rawPrice is num
          ? rawPrice.toDouble()
          : rawPrice is String
          ? double.tryParse(rawPrice) ?? 49.99
          : 49.99,
      description: json['description'] as String?,
      tryOnReady: json['tryon_ready'] as bool? ?? true,
      images: images,
    );
  }
}

class ProductImage {
  final int id;
  final String imageUrl;
  final String imageKind;
  final int sortOrder;

  const ProductImage({
    required this.id,
    required this.imageUrl,
    this.imageKind = 'gallery',
    this.sortOrder = 0,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final rawSortOrder = json['sort_order'];

    return ProductImage(
      id: rawId is int
          ? rawId
          : rawId is String
          ? int.tryParse(rawId) ?? 0
          : 0,
      imageUrl: json['image_url'] as String? ?? '',
      imageKind: json['image_kind'] as String? ?? 'gallery',
      sortOrder: rawSortOrder is int
          ? rawSortOrder
          : rawSortOrder is String
          ? int.tryParse(rawSortOrder) ?? 0
          : 0,
    );
  }
}
