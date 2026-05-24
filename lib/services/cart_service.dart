import 'package:flutter/foundation.dart';

import '../models/product.dart';

class CartService extends ChangeNotifier {
  CartService._();

  static final CartService instance = CartService._();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get distinctItemCount => _items.length;

  int get itemCount {
    return _items.fold(0, (sum, item) => sum + item.quantity);
  }

  double get subtotal {
    return _items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  double get shipping {
    if (_items.isEmpty || subtotal >= 150) return 0;
    return 10;
  }

  double get tax => subtotal * 0.08;

  double get total => subtotal + shipping + tax;

  void addItem(CartItem item) {
    final index = _items.indexWhere(
      (cartItem) => cartItem.lineId == item.lineId,
    );

    if (index == -1) {
      _items.add(item.copyWith(quantity: item.quantity.clamp(1, 99).toInt()));
    } else {
      final quantity = (_items[index].quantity + item.quantity)
          .clamp(1, 99)
          .toInt();
      _items[index] = _items[index].copyWith(quantity: quantity);
    }

    notifyListeners();
  }

  void updateQuantity(String lineId, int delta) {
    final index = _items.indexWhere((item) => item.lineId == lineId);
    if (index == -1) return;

    final quantity = (_items[index].quantity + delta).clamp(1, 99).toInt();
    _items[index] = _items[index].copyWith(quantity: quantity);
    notifyListeners();
  }

  void removeItem(String lineId) {
    _items.removeWhere((item) => item.lineId == lineId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
