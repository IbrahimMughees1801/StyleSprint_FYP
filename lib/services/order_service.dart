import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../models/product.dart';

class OrderService extends ChangeNotifier {
  OrderService._() {
    _auth.authStateChanges().listen((user) {
      if (user == null) {
        _orders.clear();
        _isLoading = false;
        _error = null;
        notifyListeners();
      } else {
        loadOrders(force: true);
      }
    });

    if (_auth.currentUser != null) {
      loadOrders();
    }
  }

  static final OrderService instance = OrderService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final List<Order> _orders = [];

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  List<Order> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  int get orderCount => _orders.length;

  Future<void> loadOrders({bool force = false}) async {
    final user = _auth.currentUser;
    if (user == null || (_isLoading && !force)) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .orderBy('date', descending: true)
          .get()
          .timeout(const Duration(seconds: 5));

      final localOrders = List<Order>.from(_orders);
      final cloudOrders = snapshot.docs.map((doc) {
        final data = doc.data();
        return Order.fromMap({...data, 'id': data['id'] ?? doc.id});
      }).toList();
      final cloudIds = cloudOrders.map((order) => order.id).toSet();
      final unsyncedLocal = localOrders.where(
        (order) => !cloudIds.contains(order.id),
      );

      _orders
        ..clear()
        ..addAll([...cloudOrders, ...unsyncedLocal])
        ..sort((a, b) => b.date.compareTo(a.date));
    } on TimeoutException {
      _error =
          'Orders are taking longer than expected to load. Your local orders are still available.';
    } catch (e) {
      _error = 'Failed to load orders: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Order> placeOrder({
    required List<CartItem> items,
    required double subtotal,
    required double shipping,
    required double tax,
    required double total,
    required String paymentMethod,
    Map<String, dynamic> paymentDetails = const {},
    required Map<String, String> address,
  }) async {
    final now = DateTime.now();
    final order = Order(
      id: _buildOrderId(now),
      date: now,
      status: 'Order Placed',
      itemCount: items.fold(0, (totalQuantity, item) {
        return totalQuantity + item.quantity;
      }),
      subtotal: subtotal,
      shipping: shipping,
      tax: tax,
      total: total,
      paymentMethod: paymentMethod,
      paymentDetails: paymentDetails,
      addressName: address['name'] ?? 'Delivery Address',
      address: address['address'] ?? '',
      city: address['city'] ?? '',
      phone: address['phone'] ?? '',
      items: items.map((item) => item.copyWith()).toList(),
    );

    _orders.insert(0, order);
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _saveOrder(order);
    } finally {
      _isSaving = false;
      notifyListeners();
    }

    return order;
  }

  Order? findById(String id) {
    for (final order in _orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  Future<void> _saveOrder(Order order) async {
    final user = _auth.currentUser;
    if (user == null) {
      _error = 'Order saved locally. Sign in to sync it to your account.';
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .doc(order.id)
          .set(order.toMap(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));
      if (order.paymentDetails.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set({
              'savedPaymentCards': FieldValue.arrayUnion([
                order.paymentDetails,
              ]),
              'savedPaymentCardsUpdatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 4));
      }
      _error = null;
    } on TimeoutException {
      _error =
          'Order confirmed locally. Cloud sync is taking longer than expected.';
    } catch (e) {
      _error = 'Order saved locally, but cloud sync failed: $e';
    }
  }

  static String _buildOrderId(DateTime now) {
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return 'ORD-$y$m$d-$h$min$s$ms';
  }
}
