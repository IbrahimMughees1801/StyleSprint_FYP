import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/product_photo.dart';
import 'cart_service.dart';
import 'supabase_products_service.dart';

class WishlistService extends ChangeNotifier {
  WishlistService._() {
    _auth.authStateChanges().listen((user) {
      _loadedUid = null;
      _productIds.clear();
      if (user == null) {
        notifyListeners();
      } else {
        load(force: true);
      }
    });

    if (_auth.currentUser != null) {
      load();
    }
  }

  static final WishlistService instance = WishlistService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SupabaseProductsService _productsService = SupabaseProductsService();
  final Set<int> _productIds = <int>{};

  String? _loadedUid;
  bool _isLoading = false;
  String? _error;

  List<int> get productIds => List.unmodifiable(_productIds);
  int get count => _productIds.length;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool contains(int productId) => _productIds.contains(productId);

  Future<void> load({bool force = false}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    if (!force && _loadedUid == uid) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      final rawIds = data?['wishlistProductIds'];

      _productIds
        ..clear()
        ..addAll(_parseIds(rawIds));
      _loadedUid = uid;
    } catch (e) {
      _error = 'Failed to load wishlist: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> toggle(ProductPhoto product) async {
    await load();

    final wasAdded = _productIds.add(product.id);
    if (!wasAdded) {
      _productIds.remove(product.id);
    }

    notifyListeners();
    await _sync();
    return wasAdded;
  }

  Future<void> remove(int productId) async {
    await load();
    if (!_productIds.remove(productId)) return;
    notifyListeners();
    await _sync();
  }

  Future<List<ProductPhoto>> fetchItems() async {
    await load();
    if (_productIds.isEmpty) return [];

    final products = await _productsService.fetchProducts();
    return products
        .where((product) => _productIds.contains(product.id))
        .toList();
  }

  void addProductToCart(ProductPhoto product) {
    CartService.instance.addItem(
      CartItem(
        id: product.id,
        name: product.name,
        store: product.brand,
        price: product.price,
        image: product.imageUrl,
        size: 'M',
        color: 'Default',
        quantity: 1,
      ),
    );
  }

  void addProductsToCart(Iterable<ProductPhoto> products) {
    for (final product in products) {
      addProductToCart(product);
    }
  }

  Future<void> _sync() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _firestore.collection('users').doc(uid).set({
        'wishlistProductIds': _productIds.toList(),
        'wishlistUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _error = null;
    } catch (e) {
      _error = 'Wishlist updated locally, but cloud sync failed: $e';
      notifyListeners();
    }
  }

  Iterable<int> _parseIds(Object? rawIds) {
    if (rawIds is! List) return const [];
    return rawIds
        .map((id) {
          if (id is int) return id;
          if (id is String) return int.tryParse(id) ?? 0;
          return 0;
        })
        .where((id) => id > 0);
  }
}
