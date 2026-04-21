import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../models/product_photo.dart';
import '../services/supabase_products_service.dart';

class CheckoutScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onOrderPlaced;

  const CheckoutScreen({
    super.key,
    required this.onBack,
    required this.onOrderPlaced,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _currentStep = 0;
  int _selectedAddressIndex = 0;
  int _selectedPaymentIndex = 0;

  final SupabaseProductsService _productsService = SupabaseProductsService();
  bool _isLoadingCart = false;
  String? _cartError;

  final List<Map<String, String>> _addresses = [
    {
      'name': 'Home',
      'address': '123 Main Street, Apartment 4B',
      'city': 'New York, NY 10001',
      'phone': '+1 (555) 123-4567',
    },
    {
      'name': 'Work',
      'address': '456 Business Ave, Floor 12',
      'city': 'New York, NY 10002',
      'phone': '+1 (555) 987-6543',
    },
  ];

  final List<Map<String, String>> _paymentMethods = [
    {
      'type': 'card',
      'name': 'Visa ending in 1234',
      'icon': '💳',
    },
    {
      'type': 'card',
      'name': 'Mastercard ending in 5678',
      'icon': '💳',
    },
    {
      'type': 'paypal',
      'name': 'PayPal',
      'icon': '💵',
    },
    {
      'type': 'cod',
      'name': 'Cash on Delivery',
      'icon': '💰',
    },
  ];

  final List<CartItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    setState(() {
      _isLoadingCart = true;
      _cartError = null;
    });

    try {
      final items = await _productsService.fetchProducts();
      if (!mounted) return;

      _cartItems
        ..clear()
        ..addAll(items.take(2).map((product) => _toCartItem(product)));

      setState(() {
        _isLoadingCart = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cartError = 'Failed to load cart items: $e';
        _isLoadingCart = false;
      });
    }
  }

  CartItem _toCartItem(ProductPhoto product) {
    return CartItem(
      id: product.id,
      name: product.name,
      store: 'StyleSprint',
      price: 49.99,
      image: product.imageUrl,
      size: 'M',
      color: 'Black',
      quantity: 1,
    );
  }

  double get _subtotal {
    return _cartItems.fold(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );
  }

  double get _shipping => 10.00;
  double get _tax => _subtotal * 0.08;
  double get _total => _subtotal + _shipping + _tax;

  void _placeOrder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.purplePinkGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Order Placed!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your order has been placed successfully',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.gray600,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: AppTheme.purplePinkGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onOrderPlaced();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Track Order',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCart) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_cartError != null) {
      return Scaffold(
        body: Center(
          child: Text(
            _cartError!,
            style: const TextStyle(color: AppTheme.red500),
          ),
        ),
      );
    }

    if (_cartItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
            onPressed: widget.onBack,
          ),
          title: Text(
            'Checkout',
            style: TextStyle(
              color: Theme.of(context).textTheme.titleLarge?.color,
              fontSize: 20,
            ),
          ),
        ),
        body: const Center(child: Text('Your cart is empty.')),
      );
    }
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: widget.onBack,
        ),
        title: Text(
          'Checkout',
          style: TextStyle(color: Theme.of(context).textTheme.titleLarge?.color, fontSize: 20),
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentStep(),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          _buildStepCircle(0, 'Address', Icons.location_on),
          _buildStepLine(0),
          _buildStepCircle(1, 'Payment', Icons.payment),
          _buildStepLine(1),
          _buildStepCircle(2, 'Review', Icons.receipt_long),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label, IconData icon) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: isActive ? AppTheme.purplePinkGradient : null,
            color: isActive ? null : AppTheme.gray200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : AppTheme.gray400,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? AppTheme.purple600 : AppTheme.gray400,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final isActive = _currentStep > step;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          gradient: isActive ? AppTheme.purplePinkGradient : null,
          color: isActive ? null : AppTheme.gray200,
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildAddressStep();
      case 1:
        return _buildPaymentStep();
      case 2:
        return _buildReviewStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildAddressStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Address',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 16),
        ..._addresses.asMap().entries.map((entry) {
          final index = entry.key;
          final address = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAddressCard(address, index),
          );
        }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Add New Address'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.purple600,
            side: const BorderSide(color: AppTheme.purple600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 0),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressCard(Map<String, String> address, int index) {
    final isSelected = _selectedAddressIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedAddressIndex = index),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.purple600 : AppTheme.gray200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        address['name']!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.gray900,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: AppTheme.purplePinkGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Selected',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    address['address']!,
                    style: const TextStyle(fontSize: 14, color: AppTheme.gray600),
                  ),
                  Text(
                    address['city']!,
                    style: const TextStyle(fontSize: 14, color: AppTheme.gray600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: AppTheme.gray400),
                      const SizedBox(width: 4),
                      Text(
                        address['phone']!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Radio<int>(
              value: index,
              groupValue: _selectedAddressIndex,
              onChanged: (value) => setState(() => _selectedAddressIndex = value!),
              activeColor: AppTheme.purple600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 16),
        ..._paymentMethods.asMap().entries.map((entry) {
          final index = entry.key;
          final method = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPaymentCard(method, index),
          );
        }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Add New Card'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.purple600,
            side: const BorderSide(color: AppTheme.purple600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 0),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(Map<String, String> method, int index) {
    final isSelected = _selectedPaymentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentIndex = index),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.purple600 : AppTheme.gray200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              method['icon']!,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                method['name']!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900,
                ),
              ),
            ),
            Radio<int>(
              value: index,
              groupValue: _selectedPaymentIndex,
              onChanged: (value) => setState(() => _selectedPaymentIndex = value!),
              activeColor: AppTheme.purple600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Summary',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 16),
        // Items
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Items',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gray900,
                ),
              ),
              const SizedBox(height: 12),
              ..._cartItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: item.image,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Size: ${item.size} | Color: ${item.color}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.gray500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '\$${item.price.toStringAsFixed(2)} x${item.quantity}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Delivery Address
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivery Address',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.gray900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _addresses[_selectedAddressIndex]['name']!,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(_addresses[_selectedAddressIndex]['address']!),
              Text(_addresses[_selectedAddressIndex]['city']!),
              Text(_addresses[_selectedAddressIndex]['phone']!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Payment Method
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Text(
                _paymentMethods[_selectedPaymentIndex]['icon']!,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.gray500,
                      ),
                    ),
                    Text(
                      _paymentMethods[_selectedPaymentIndex]['name']!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentStep == 2) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal', style: TextStyle(color: AppTheme.gray600)),
                  Text('\$${_subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Shipping', style: TextStyle(color: AppTheme.gray600)),
                  Text('\$${_shipping.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tax', style: TextStyle(color: AppTheme.gray600)),
                  Text('\$${_tax.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const Divider(height: 24),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${_total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentStep--),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.purple600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(color: AppTheme.purple600, fontSize: 16),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.purplePinkGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentStep < 2) {
                          setState(() => _currentStep++);
                        } else {
                          _placeOrder();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _currentStep < 2 ? 'Continue' : 'Place Order',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
