import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';

class CheckoutScreen extends StatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<String> onOrderPlaced;

  const CheckoutScreen({
    super.key,
    required this.onBack,
    required this.onOrderPlaced,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressFormKey = GlobalKey<FormState>();
  final _paymentFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  int _currentStep = 0;
  int _selectedPaymentIndex = 0;
  bool _isPlacingOrder = false;

  final CartService _cartService = CartService.instance;
  final OrderService _orderService = OrderService.instance;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'name': 'Cash on Delivery',
      'subtitle': 'Pay in cash when your order arrives',
      'icon': Icons.payments_outlined,
      'requiresCard': false,
    },
    {
      'name': 'Credit / Debit Card',
      'subtitle': 'Use a card for this demo checkout',
      'icon': Icons.credit_card,
      'requiresCard': true,
    },
    {
      'name': 'Digital Wallet',
      'subtitle': 'Wallet payment placeholder',
      'icon': Icons.account_balance_wallet_outlined,
      'requiresCard': false,
    },
  ];

  List<CartItem> get _cartItems => _cartService.items;
  double get _subtotal => _cartService.subtotal;
  double get _shipping => _cartService.shipping;
  double get _tax => _cartService.tax;
  double get _total => _cartService.total;
  bool get _isCardSelected =>
      _paymentMethods[_selectedPaymentIndex]['requiresCard'] == true;
  String get _selectedPayment =>
      _paymentMethods[_selectedPaymentIndex]['name'] as String;

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _pageBackground(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  Color _surface(BuildContext context) => Theme.of(context).colorScheme.surface;

  Color _surfaceLow(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1A2A3A) : AppTheme.atelierSurfaceLow;

  Color _border(BuildContext context) =>
      _isDark(context) ? AppTheme.gray700 : AppTheme.gray200;

  Color _accent(BuildContext context) =>
      _isDark(context) ? AppTheme.atelierAccent : AppTheme.atelierMidnight;

  Color _accentForeground(BuildContext context) =>
      _isDark(context) ? AppTheme.atelierDark : Colors.white;

  Color _strongText(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.color ??
      (_isDark(context) ? Colors.white : AppTheme.gray900);

  Color _mutedText(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.color ??
      (_isDark(context) ? AppTheme.gray400 : AppTheme.gray600);

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _cardNumberController.dispose();
    _cardNameController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_isPlacingOrder) return;

    if (_currentStep == 0) {
      if (!(_addressFormKey.currentState?.validate() ?? false)) return;
    }

    if (_currentStep == 1 && _isCardSelected) {
      if (!(_paymentFormKey.currentState?.validate() ?? false)) return;
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      return;
    }

    await _placeOrder();
  }

  Future<void> _placeOrder() async {
    setState(() => _isPlacingOrder = true);

    try {
      final order = await _orderService.placeOrder(
        items: _cartItems,
        subtotal: _subtotal,
        shipping: _shipping,
        tax: _tax,
        total: _total,
        paymentMethod: _selectedPayment,
        paymentDetails: _cardPaymentDetails(),
        address: {
          'name': _nameController.text.trim(),
          'address': _addressController.text.trim(),
          'city': _cityController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
      );

      _cartService.clear();
      if (!mounted) return;
      widget.onOrderPlaced(order.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not place order: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
      }
    }
  }

  Map<String, dynamic> _cardPaymentDetails() {
    if (!_isCardSelected) return const {};
    final digits = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : '';
    return {
      'type': 'card',
      'brand': _cardBrand(digits),
      'last4': last4,
      'cardholderName': _cardNameController.text.trim(),
      'expiry': _expiryController.text.trim(),
      'demoOnly': true,
    };
  }

  String _cardBrand(String digits) {
    if (digits.startsWith('4')) return 'Visa';
    if (digits.startsWith('5')) return 'Mastercard';
    if (digits.startsWith('3')) return 'Amex';
    if (digits.startsWith('6')) return 'Discover';
    return 'Card';
  }

  String _cardSummary() {
    final details = _cardPaymentDetails();
    final last4 = details['last4'] as String? ?? '';
    final brand = details['brand'] as String? ?? 'Card';
    final expiry = details['expiry'] as String? ?? '';
    if (last4.isEmpty) return 'Card details saved for this demo order.';
    return '$brand ending $last4${expiry.isEmpty ? '' : ' | Expires $expiry'}';
  }

  @override
  Widget build(BuildContext context) {
    if (_cartItems.isEmpty) {
      return Scaffold(
        backgroundColor: _pageBackground(context),
        appBar: _buildAppBar(),
        body: const Center(child: Text('Your cart is empty.')),
      );
    }

    return Scaffold(
      backgroundColor: _pageBackground(context),
      appBar: _buildAppBar(),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _pageBackground(context),
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
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: _pageBackground(context),
      child: Row(
        children: [
          _buildStepCircle(0, 'Address', Icons.location_on_outlined),
          _buildStepLine(0),
          _buildStepCircle(1, 'Payment', Icons.payment_outlined),
          _buildStepLine(1),
          _buildStepCircle(2, 'Confirm', Icons.receipt_long_outlined),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label, IconData icon) {
    final isActive = _currentStep >= step;
    final accent = _accent(context);
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? accent : _surfaceLow(context),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isActive ? _accentForeground(context) : _mutedText(context),
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? accent : _mutedText(context),
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
        color: isActive ? _accent(context) : _surfaceLow(context),
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
    return Form(
      key: _addressFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _strongText(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the name, address, and contact number for this order.',
            style: TextStyle(color: _mutedText(context)),
          ),
          const SizedBox(height: 18),
          _buildTextField(
            controller: _nameController,
            label: 'Full name',
            icon: Icons.person_outline,
            textInputAction: TextInputAction.next,
            validator: (value) => _required(value, 'Enter the receiver name'),
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _phoneController,
            label: 'Contact number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\-\s]')),
            ],
            textInputAction: TextInputAction.next,
            validator: _validatePhone,
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _addressController,
            label: 'Street address',
            icon: Icons.home_outlined,
            maxLines: 2,
            textInputAction: TextInputAction.next,
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return 'Enter the delivery address';
              if (text.length < 8) return 'Address is too short';
              return null;
            },
          ),
          const SizedBox(height: 14),
          _buildTextField(
            controller: _cityController,
            label: 'City / area',
            icon: Icons.location_city_outlined,
            textInputAction: TextInputAction.done,
            validator: (value) => _required(value, 'Enter the city or area'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _strongText(context),
          ),
        ),
        const SizedBox(height: 16),
        ..._paymentMethods.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPaymentCard(entry.value, entry.key),
          );
        }),
        if (_isCardSelected) ...[const SizedBox(height: 6), _buildCardForm()],
      ],
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> method, int index) {
    final isSelected = _selectedPaymentIndex == index;
    return GestureDetector(
      onTap: _isPlacingOrder
          ? null
          : () => setState(() => _selectedPaymentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _accent(context) : _border(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _surfaceLow(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(method['icon'] as IconData, color: _accent(context)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method['name'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _strongText(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    method['subtitle'] as String,
                    style: TextStyle(fontSize: 12, color: _mutedText(context)),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked_outlined,
              color: isSelected ? _accent(context) : _mutedText(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardForm() {
    return Form(
      key: _paymentFormKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border(context)),
        ),
        child: Column(
          children: [
            _buildTextField(
              controller: _cardNameController,
              label: 'Name on card',
              icon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
              validator: (value) => _required(value, 'Enter cardholder name'),
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _cardNumberController,
              label: 'Card number',
              icon: Icons.credit_card,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
              ],
              textInputAction: TextInputAction.next,
              validator: _validateCardNumber,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _expiryController,
                    label: 'MM/YY',
                    icon: Icons.calendar_month_outlined,
                    keyboardType: TextInputType.datetime,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                      LengthLimitingTextInputFormatter(5),
                    ],
                    textInputAction: TextInputAction.next,
                    validator: (value) => _required(value, 'Required'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _cvvController,
                    label: 'CVV',
                    icon: Icons.lock_outline,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.length < 3) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
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
        Text(
          'Confirm Order',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _strongText(context),
          ),
        ),
        const SizedBox(height: 16),
        _buildItemsSummary(),
        const SizedBox(height: 16),
        _buildInfoPanel(
          title: 'Delivery Details',
          icon: Icons.location_on_outlined,
          children: [
            Text(
              _nameController.text.trim(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(_phoneController.text.trim()),
            Text(_addressController.text.trim()),
            Text(_cityController.text.trim()),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoPanel(
          title: 'Payment Method',
          icon: Icons.payments_outlined,
          children: [
            Text(
              _selectedPayment,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              _isCardSelected
                  ? _cardSummary()
                  : _selectedPayment == 'Cash on Delivery'
                  ? 'Collect payment when the order is delivered.'
                  : 'Wallet payment selected for this demo order.',
              style: TextStyle(color: _mutedText(context)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildItemsSummary() {
    return _buildInfoPanel(
      title: 'Items',
      icon: Icons.shopping_bag_outlined,
      children: _cartItems.map((item) {
        return Padding(
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
                  errorWidget: (context, url, error) => Container(
                    width: 60,
                    height: 60,
                    color: _surfaceLow(context),
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _strongText(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Qty ${item.quantity} | Size: ${item.size} | Color: ${item.color}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _mutedText(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _strongText(context),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoPanel({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _accent(context)),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _strongText(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
              _buildSummaryRow('Subtotal', _subtotal),
              const SizedBox(height: 8),
              _buildSummaryRow('Shipping', _shipping),
              const SizedBox(height: 8),
              _buildSummaryRow('Tax', _tax),
              const Divider(height: 24),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _strongText(context),
                  ),
                ),
                Text(
                  '\$${_total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _strongText(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_currentStep > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isPlacingOrder
                          ? null
                          : () => setState(() => _currentStep--),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _accent(context),
                        side: BorderSide(color: _accent(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Back',
                        style: TextStyle(color: _accent(context), fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _accent(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: _isPlacingOrder ? null : _continue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isPlacingOrder
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _accentForeground(context),
                                ),
                              ),
                            )
                          : Text(
                              _currentStep < 2 ? 'Continue' : 'Confirm Order',
                              style: TextStyle(
                                color: _accentForeground(context),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      obscureText: obscureText,
      validator: validator,
      style: TextStyle(color: _strongText(context)),
      cursorColor: _accent(context),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _mutedText(context)),
        floatingLabelStyle: TextStyle(color: _accent(context)),
        prefixIcon: Icon(icon, color: _mutedText(context)),
        filled: true,
        fillColor: _surface(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _accent(context), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.red500),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.red500, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: _mutedText(context))),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: _strongText(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String? _required(String? value, String message) {
    return (value?.trim().isEmpty ?? true) ? message : null;
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return 'Enter a valid contact number';
    return null;
  }

  String? _validateCardNumber(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length < 12) return 'Enter a valid card number';
    return null;
  }
}
