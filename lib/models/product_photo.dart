class ProductPhoto {
  final int id;
  final String name;
  final String imageUrl;

  const ProductPhoto({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  factory ProductPhoto.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final intId = rawId is int
        ? rawId
        : rawId is String
            ? int.tryParse(rawId) ?? 0
            : 0;

    return ProductPhoto(
      id: intId,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String,
    );
  }
}
