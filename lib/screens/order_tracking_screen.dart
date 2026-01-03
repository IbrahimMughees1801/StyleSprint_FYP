import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final String _trackingNumber = 'TRK123456789';
  final String _estimatedDelivery = 'Dec 25, 2024';
  int _currentStatus = 2; // 0: Order Placed, 1: Packed, 2: Shipped, 3: Out for Delivery, 4: Delivered

  final List<Map<String, dynamic>> _trackingHistory = [
    {
      'status': 'Order Placed',
      'description': 'Your order has been confirmed',
      'date': 'Dec 20, 2024',
      'time': '10:30 AM',
      'completed': true,
    },
    {
      'status': 'Order Packed',
      'description': 'Your order has been packed',
      'date': 'Dec 21, 2024',
      'time': '02:15 PM',
      'completed': true,
    },
    {
      'status': 'Shipped',
      'description': 'Package is on the way',
      'date': 'Dec 22, 2024',
      'time': '09:00 AM',
      'completed': true,
    },
    {
      'status': 'Out for Delivery',
      'description': 'Package will arrive today',
      'date': 'Dec 23, 2024',
      'time': 'Expected',
      'completed': false,
    },
    {
      'status': 'Delivered',
      'description': 'Package has been delivered',
      'date': 'Dec 23, 2024',
      'time': 'Expected',
      'completed': false,
    },
  ];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.gray900),
          onPressed: widget.onBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Track Order',
              style: TextStyle(color: AppTheme.gray900, fontSize: 20),
            ),
            Text(
              widget.orderId,
              style: const TextStyle(color: AppTheme.gray500, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.gray700),
            onPressed: () {},
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
        gradient: AppTheme.purplePinkGradient,
        borderRadius: BorderRadius.circular(20),
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
              color: AppTheme.purple600,
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
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Estimated Delivery: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tracking Number',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.gray500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _trackingNumber,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.gray900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.purple600.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.copy, color: AppTheme.purple600),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tracking History',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.gray900,
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
                gradient: isCompleted ? AppTheme.purplePinkGradient : null,
                color: isCompleted ? null : AppTheme.gray200,
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
                  gradient: isCompleted ? AppTheme.purplePinkGradient : null,
                  color: isCompleted ? null : AppTheme.gray200,
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
                    color: isCompleted ? AppTheme.gray900 : AppTheme.gray400,
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
                      '${item['date']} • ${item['time']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCompleted ? AppTheme.gray500 : AppTheme.gray400,
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Address',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.gray900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.purple600.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: AppTheme.purple600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Home',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.gray900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '123 Main Street, Apartment 4B\nNew York, NY 10001',
                      style: TextStyle(
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
            gradient: AppTheme.purplePinkGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ElevatedButton.icon(
            onPressed: () {},
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
          onPressed: () {},
          icon: const Icon(Icons.help_outline),
          label: const Text('Report an Issue'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.purple600,
            side: const BorderSide(color: AppTheme.purple600),
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
