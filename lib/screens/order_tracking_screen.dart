import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final VoidCallback onBack;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.onBack,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final OrderService _orderService = OrderService.instance;

  Order? get _order => _orderService.findById(widget.orderId);

  String get _trackingNumber {
    return 'TRK${widget.orderId.hashCode.abs().toString().padLeft(9, '0')}';
  }

  String get _estimatedDelivery {
    final deliveryDate = (_order?.date ?? DateTime.now()).add(
      const Duration(days: 5),
    );
    return _formatDate(deliveryDate);
  }

  int get _currentStatus {
    final status = _order?.status ?? 'In Transit';
    switch (status) {
      case 'Order Placed':
        return 0;
      case 'Delivered':
        return 4;
      case 'Cancelled':
        return 0;
      case 'In Transit':
      default:
        return 2;
    }
  }

  List<Map<String, dynamic>> get _trackingHistory {
    final orderDate = _order?.date ?? DateTime.now();
    final completedUntil = _currentStatus;

    Map<String, dynamic> item(
      int index,
      String status,
      String description,
      DateTime date,
    ) {
      return {
        'status': status,
        'description': description,
        'date': _formatDate(date),
        'time': index <= completedUntil ? _formatTime(date) : 'Expected',
        'completed': index <= completedUntil,
      };
    }

    return [
      item(0, 'Order Placed', 'Your order has been confirmed', orderDate),
      item(
        1,
        'Order Packed',
        'Your order is being packed',
        orderDate.add(const Duration(days: 1)),
      ),
      item(
        2,
        'Shipped',
        'Package is on the way',
        orderDate.add(const Duration(days: 2)),
      ),
      item(
        3,
        'Out for Delivery',
        'Package will arrive soon',
        orderDate.add(const Duration(days: 4)),
      ),
      item(
        4,
        'Delivered',
        'Package has been delivered',
        orderDate.add(const Duration(days: 5)),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _orderService.addListener(_refresh);
    _orderService.loadOrders();
  }

  @override
  void dispose() {
    _orderService.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  void _copyTrackingNumber() {
    Clipboard.setData(ClipboardData(text: _trackingNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tracking number copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showIssueMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_orderService.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBack,
          ),
          title: const Text('Track Order'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Order not found',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'This order is not available on your account yet.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Track Order',
              style: TextStyle(
                color: Theme.of(context).textTheme.titleLarge?.color,
                fontSize: 20,
              ),
            ),
            Text(
              widget.orderId,
              style: const TextStyle(color: AppTheme.gray500, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: Theme.of(context).iconTheme.color),
            onPressed: () => _showIssueMessage('Share coming soon.'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 24),
            _buildTrackingInfo(),
            const SizedBox(height: 24),
            _buildTrackingTimeline(),
            const SizedBox(height: 24),
            _buildDeliveryInfo(),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.atelierDarkGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_shipping,
              size: 48,
              color: AppTheme.atelierMidnight,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _trackingHistory[_currentStatus]['status'],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _trackingHistory[_currentStatus]['description'],
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Estimated Delivery: ',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  _estimatedDelivery,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tracking Number',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _trackingNumber,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.atelierSurfaceLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.copy, color: AppTheme.atelierMidnight),
              onPressed: _copyTrackingNumber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingTimeline() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tracking History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 20),
          ..._trackingHistory.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return _buildTimelineItem(
              item,
              isCompleted: item['completed'],
              isLast: index == _trackingHistory.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    Map<String, dynamic> item, {
    required bool isCompleted,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppTheme.atelierMidnight
                    : AppTheme.gray200,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? Colors.transparent : AppTheme.gray300,
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppTheme.atelierMidnight
                      : AppTheme.gray200,
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['status'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCompleted
                        ? Theme.of(context).textTheme.bodyLarge?.color
                        : AppTheme.gray400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: isCompleted ? AppTheme.gray600 : AppTheme.gray400,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: isCompleted ? AppTheme.gray500 : AppTheme.gray400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item['date']} | ${item['time']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCompleted
                            ? AppTheme.gray500
                            : AppTheme.gray400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryInfo() {
    final order = _order;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Address',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.atelierSurfaceLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: AppTheme.atelierMidnight,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order?.addressName ?? 'Delivery Address',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order?.address ?? ''}\n${order?.city ?? ''}\n${order?.phone ?? ''}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.gray600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.atelierMidnight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ElevatedButton.icon(
            onPressed: () => _showIssueMessage(
              'Delivery support will use this order ID: ${widget.orderId}',
            ),
            icon: const Icon(Icons.support_agent, color: Colors.white),
            label: const Text(
              'Contact Delivery Partner',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 0),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () =>
              _showIssueMessage('Issue report created for ${widget.orderId}.'),
          icon: const Icon(Icons.help_outline),
          label: const Text('Report an Issue'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.atelierMidnight,
            side: const BorderSide(color: AppTheme.atelierMidnight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size(double.infinity, 0),
          ),
        ),
      ],
    );
  }
}
