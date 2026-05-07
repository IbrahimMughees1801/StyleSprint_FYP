import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../main.dart';

class CheckoutScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(AppScreen)? onNavigate;

  const CheckoutScreen({
    super.key,
    required this.onBack,
    this.onNavigate,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  late ConfettiController _confettiController;

  final _shippingKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  final _cardController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  String _selectedPayment = 'card';
  bool _orderPlaced = false;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _cardController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      setState(() => _orderPlaced = true);
      _confettiController.play();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  static const _steps = ['Shipping', 'Payment', 'Review'];
  static const _stepIcons = [
    Icons.local_shipping_outlined,
    Icons.credit_card,
    Icons.check_circle_outline
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: _orderPlaced
              ? () => widget.onNavigate?.call(AppScreen.home)
              : widget.onBack,
        ),
        title: Text(
          _orderPlaced ? 'Order Placed!' : 'Checkout',
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_orderPlaced)
            _buildOrderSuccess()
          else
            Column(
              children: [
                // Step indicator
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  child: Row(
                    children: List.generate(_steps.length, (i) {
                      final isActive = i <= _currentStep;
                      final isCompleted = i < _currentStep;
                      return Expanded(
                        child: Row(
                          children: [
                            Column(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: isActive
                                        ? const LinearGradient(colors: [
                                            Color(0xFF7C3AED),
                                            Color(0xFFEC4899)
                                          ])
                                        : null,
                                    color: isActive
                                        ? null
                                        : const Color(0xFFE5E7EB),
                                    shape: BoxShape.circle,
                                    boxShadow: isActive
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF7C3AED)
                                                  .withOpacity(0.3),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Icon(
                                    isCompleted ? Icons.check : _stepIcons[i],
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF9CA3AF),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _steps[i],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isActive
                                        ? const Color(0xFF7C3AED)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                            if (i < _steps.length - 1)
                              Expanded(
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 3,
                                      margin:
                                          const EdgeInsets.only(bottom: 18),
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 400),
                                      height: 3,
                                      margin:
                                          const EdgeInsets.only(bottom: 18),
                                      width: isCompleted ? 200.0 : 0,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF7C3AED),
                                            Color(0xFFEC4899)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),

                // Step content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: anim, curve: Curves.easeOut)),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: SingleChildScrollView(
                      key: ValueKey(_currentStep),
                      padding: const EdgeInsets.all(16),
                      child: _buildStepContent(),
                    ),
                  ),
                ),
              ],
            ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.05,
              colors: const [
                Color(0xFF7C3AED),
                Color(0xFFEC4899),
                Color(0xFFFBBF24),
                Colors.white,
                Colors.green,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildShippingForm();
      case 1:
        return _buildPaymentForm();
      case 2:
        return _buildReviewOrder();
      default:
        return const SizedBox();
    }
  }

  Widget _buildShippingForm() {
    return _FormCard(
      title: 'Shipping Information',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _buildFloatingField(
                      'Full Name', Icons.person_outline, _nameController)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildFloatingField('Email', Icons.mail_outline,
                      _emailController,
                      keyboardType: TextInputType.emailAddress)),
            ],
          ),
          const SizedBox(height: 16),
          _buildFloatingField('Street Address', Icons.location_on_outlined,
              _addressController),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildFloatingField('City',
                      Icons.location_city_outlined, _cityController)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildFloatingField(
                      'ZIP Code', Icons.local_post_office_outlined, _zipController,
                      keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 24),
          _buildNextButton('Continue to Payment'),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return _FormCard(
      title: 'Payment Information',
      child: Column(
        children: [
          Row(
            children: ['card', 'paypal', 'apple'].map((method) {
              final isSelected = _selectedPayment == method;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPayment = method),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF7C3AED).withOpacity(0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFFD1D5DB),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          method == 'card'
                              ? Icons.credit_card
                              : method == 'paypal'
                                  ? Icons.payment
                                  : Icons.phone_iphone,
                          color: isSelected
                              ? const Color(0xFF7C3AED)
                              : const Color(0xFF6B7280),
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          method[0].toUpperCase() + method.substring(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _buildFloatingField('Card Number', Icons.credit_card, _cardController,
              keyboardType: TextInputType.number,
              hint: '1234 5678 9012 3456'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildFloatingField('Expiry Date',
                      Icons.calendar_today_outlined, _expiryController,
                      hint: 'MM/YY')),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildFloatingField(
                      'CVV', Icons.lock_outline, _cvvController,
                      keyboardType: TextInputType.number, hint: '123')),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildOutlineButton('Back', _prevStep)),
              const SizedBox(width: 12),
              Expanded(child: _buildNextButton('Review Order')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewOrder() {
    return _FormCard(
      title: 'Review Your Order',
      child: Column(
        children: [
          _buildReviewSection('Shipping Address', [
            _nameController.text.isNotEmpty ? _nameController.text : 'John Doe',
            _addressController.text.isNotEmpty
                ? _addressController.text
                : '123 Main Street',
            '${_cityController.text.isNotEmpty ? _cityController.text : 'New York'}, ${_zipController.text.isNotEmpty ? _zipController.text : '10001'}',
          ]),
          const SizedBox(height: 16),
          _buildReviewSection('Payment Method', [
            'Card ending in ${_cardController.text.length >= 4 ? _cardController.text.replaceAll(' ', '').substring((_cardController.text.replaceAll(' ', '').length - 4).clamp(0, _cardController.text.length)) : '****'}',
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C3AED).withOpacity(0.1),
                  const Color(0xFFEC4899).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                  ).createShader(bounds),
                  child: const Text(
                    '\$2,397.80',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildOutlineButton('Back', _prevStep)),
              const SizedBox(width: 12),
              Expanded(child: _buildNextButton('Place Order')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.check, color: Colors.white, size: 60),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 32),
            const Text(
              'Order Placed! 🎉',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
            const SizedBox(height: 12),
            const Text(
              'Your order has been confirmed and will be delivered soon.',
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 48),
            GestureDetector(
              onTap: () => widget.onNavigate?.call(AppScreen.home),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Continue Shopping',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingField(
    String label,
    IconData icon,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF7C3AED), width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        floatingLabelStyle:
            const TextStyle(color: Color(0xFF7C3AED)),
      ),
    );
  }

  Widget _buildNextButton(String label) {
    return GestureDetector(
      onTap: _nextStep,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlineButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewSection(String title, List<String> lines) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...lines.map((line) => Text(
                line,
                style: const TextStyle(
                    color: Color(0xFF6B7280), fontSize: 13),
              )),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _FormCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
