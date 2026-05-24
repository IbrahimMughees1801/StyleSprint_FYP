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

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _surfaceLow(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1A2A3A) : AppTheme.gray100;

  Color _accent(BuildContext context) =>
      _isDark(context) ? AppTheme.atelierAccent : AppTheme.atelierMidnight;

  Color _mutedText(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.color ??
      (_isDark(context) ? AppTheme.gray400 : AppTheme.gray600);

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
      return _orders
          .where((o) => o.status == 'Order Placed' || o.status == 'In Transit')
          .toList();
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
          unselectedLabelColor: _mutedText(context),
          indicatorColor: Theme.of(context).colorScheme.primary,
          onTap: (index) => setState(() {}),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Delivered'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _orderService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orderService.error != null && _orders.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: AppTheme.red500,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _orderService.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.red500),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () => _orderService.loadOrders(force: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _filteredOrders.isEmpty
          ? _buildEmptyState()
          : _buildOrdersList(),
    );
  }

  Widget _buildOrdersList() {
    final error = _orderService.error;
    final hasWarning = error != null && _orders.isNotEmpty;

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _filteredOrders.length + (hasWarning ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasWarning && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildSyncWarning(error),
          );
        }

        final orderIndex = index - (hasWarning ? 1 : 0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildOrderCard(_filteredOrders[orderIndex]),
        );
      },
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
              style: TextStyle(fontSize: 16, color: _mutedText(context)),
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
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 50,
                                height: 50,
                                color: _surfaceLow(context),
                                child: const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: AppTheme.gray400,
                                  size: 22,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                if (order.itemImages.length > 3)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _surfaceLow(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '+${order.itemImages.length - 3}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _mutedText(context),
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
            Wrap(
              spacing: 14,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${order.itemCount} ${order.itemCount == 1 ? 'Item' : 'Items'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _mutedText(context),
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
                if (order.status == 'Order Placed' ||
                    order.status == 'In Transit')
                  OutlinedButton(
                    onPressed: () => widget.onOrderClick(order.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent(context),
                      side: BorderSide(color: _accent(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Track Order',
                      style: TextStyle(color: _accent(context)),
                    ),
                  ),
                if (order.status == 'Delivered')
                  OutlinedButton(
                    onPressed: () => _buyAgain(order),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent(context),
                      side: BorderSide(color: _accent(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Buy Again',
                      style: TextStyle(color: _accent(context)),
                    ),
                  ),
                if (order.status != 'Order Placed' &&
                    order.status != 'In Transit' &&
                    order.status != 'Delivered')
                  OutlinedButton(
                    onPressed: () => widget.onOrderClick(order.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _mutedText(context),
                      side: BorderSide(color: _mutedText(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'View Details',
                      style: TextStyle(color: _mutedText(context)),
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
