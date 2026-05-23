import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';

class OrderSuccessScreen extends StatefulWidget {
  final String orderId;
  final VoidCallback onContinueShopping;
  final VoidCallback onViewOrders;
  final ValueChanged<String> onTrackOrder;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.onContinueShopping,
    required this.onViewOrders,
    required this.onTrackOrder,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen> {
  final OrderService _orderService = OrderService.instance;

  Order? get _order => _orderService.findById(widget.orderId);

  @override
  void initState() {
    super.initState();
    _orderService.addListener(_refresh);
  }

  @override
  void dispose() {
    _orderService.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      backgroundColor: AppTheme.atelierBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 28),
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: const BoxDecoration(
                    color: AppTheme.atelierMidnight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 52),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Order Confirmed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.gray900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.orderId,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.gray500,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),
              if (_orderService.error != null) ...[
                _buildSyncWarning(_orderService.error!),
                const SizedBox(height: 16),
              ],
              _buildSummary(order),
              const SizedBox(height: 24),
              _buildPrimaryButton(
                label: 'Track Order',
                icon: Icons.local_shipping_outlined,
                onPressed: () => widget.onTrackOrder(widget.orderId),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: widget.onViewOrders,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View Orders'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.atelierMidnight,
                  side: const BorderSide(color: AppTheme.atelierMidnight),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onContinueShopping,
                child: const Text('Continue Shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(Order? order) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.atelierSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRow('Status', order?.status ?? 'Order Placed'),
          const SizedBox(height: 12),
          _buildRow('Items', '${order?.itemCount ?? 0}'),
          const SizedBox(height: 12),
          _buildRow('Payment', order?.paymentMethod ?? 'Payment selected'),
          const SizedBox(height: 12),
          _buildRow('Total', order?.totalLabel ?? '--'),
          if (order != null) ...[
            const Divider(height: 28),
            const Text(
              'Delivery',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${order.addressName}\n${order.phone}\n${order.address}\n${order.city}',
              style: const TextStyle(color: AppTheme.gray600, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncWarning(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.yellow400.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.yellow400),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppTheme.gray900,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.gray900,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.gray600)),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.gray900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.atelierMidnight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.atelierMidnight.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
