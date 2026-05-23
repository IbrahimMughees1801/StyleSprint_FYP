import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/cart_service.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';

class OrderHistoryScreen extends StatefulWidget {
  final VoidCallback onBack;
  final Function(String) onOrderClick;

  const OrderHistoryScreen({
    super.key,
    required this.onBack,
    required this.onOrderClick,
  });

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OrderService _orderService = OrderService.instance;

  List<Order> get _orders => _orderService.orders;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _orderService.addListener(_refreshOrders);
    _orderService.loadOrders();
  }

  @override
  void dispose() {
    _orderService.removeListener(_refreshOrders);
    _tabController.dispose();
    super.dispose();
  }

  void _refreshOrders() {
    if (mounted) setState(() {});
  }

  List<Order> get _filteredOrders {
    final index = _tabController.index;
    if (index == 0) return _orders; // All
    if (index == 1) {
      return _orders.where((o) => o.status == 'In Transit').toList();
    }
    if (index == 2) {
      return _orders.where((o) => o.status == 'Delivered').toList();
    }
    if (index == 3) {
      return _orders.where((o) => o.status == 'Cancelled').toList();
    }
    return _orders;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Order Placed':
        return AppTheme.atelierMidnight;
      case 'In Transit':
        return AppTheme.blue500;
      case 'Delivered':
        return AppTheme.green500;
      case 'Cancelled':
        return AppTheme.red500;
      default:
        return AppTheme.gray500;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Order Placed':
        return Icons.receipt_long;
      case 'In Transit':
        return Icons.local_shipping;
      case 'Delivered':
        return Icons.check_circle;
      case 'Cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _buyAgain(Order order) {
    for (final item in order.items) {
      CartService.instance.addItem(item.copyWith());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${order.itemCount} item(s) added to cart'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          'Orders',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: AppTheme.gray500,
          indicatorColor: Theme.of(context).colorScheme.primary,
          onTap: (index) => setState(() {}),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'In Transit'),
            Tab(text: 'Delivered'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _orderService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orderService.error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _orderService.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.red500),
                ),
              ),
            )
          : _filteredOrders.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _filteredOrders.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildOrderCard(_filteredOrders[index]),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 64,
                color: AppTheme.gray400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Orders Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your order history will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppTheme.gray600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return GestureDetector(
      onTap: () => widget.onOrderClick(order.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _getStatusIcon(order.status),
                      color: _getStatusColor(order.status),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(
                          order.status,
                        ).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(order.status),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatDate(order.date),
                  style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Order ID
            Text(
              order.id,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 12),
            // Product images
            Row(
              children: [
                ...order.itemImages
                    .take(3)
                    .map(
                      (image) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            image,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                if (order.itemImages.length > 3)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.gray100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '+${order.itemImages.length - 3}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.gray600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            // Footer row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.itemCount} ${order.itemCount == 1 ? 'Item' : 'Items'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.gray500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.totalLabel,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (order.status == 'In Transit')
                      OutlinedButton(
                        onPressed: () => widget.onOrderClick(order.id),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppTheme.atelierMidnight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Track Order',
                          style: TextStyle(color: AppTheme.atelierMidnight),
                        ),
                      ),
                    if (order.status == 'Delivered')
                      OutlinedButton(
                        onPressed: () => _buyAgain(order),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppTheme.atelierMidnight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Buy Again',
                          style: TextStyle(color: AppTheme.atelierMidnight),
                        ),
                      ),
                    if (order.status != 'In Transit' &&
                        order.status != 'Delivered')
                      OutlinedButton(
                        onPressed: () => widget.onOrderClick(order.id),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.gray300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(color: AppTheme.gray600),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
