import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Order {
  final String id;
  final DateTime date;
  final String status;
  final int itemCount;
  final String total;
  final String thumbnail;
  final List<String> itemImages;

  Order({
    required this.id,
    required this.date,
    required this.status,
    required this.itemCount,
    required this.total,
    required this.thumbnail,
    required this.itemImages,
  });
}

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

class _OrderHistoryScreenState extends State<OrderHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final List<Order> _orders = [
    Order(
      id: 'ORD-2024-001',
      date: DateTime.now().subtract(const Duration(days: 2)),
      status: 'In Transit',
      itemCount: 2,
      total: '\$159.98',
      thumbnail: 'https://images.unsplash.com/photo-1523381210434-271e8be1f52b',
      itemImages: [
        'https://images.unsplash.com/photo-1523381210434-271e8be1f52b',
        'https://images.unsplash.com/photo-1525507119028-ed4c629a60a3',
      ],
    ),
    Order(
      id: 'ORD-2024-002',
      date: DateTime.now().subtract(const Duration(days: 5)),
      status: 'Delivered',
      itemCount: 1,
      total: '\$79.99',
      thumbnail: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff',
      itemImages: [
        'https://images.unsplash.com/photo-1542291026-7eec264c27ff',
      ],
    ),
    Order(
      id: 'ORD-2024-003',
      date: DateTime.now().subtract(const Duration(days: 10)),
      status: 'Delivered',
      itemCount: 3,
      total: '\$249.97',
      thumbnail: 'https://images.unsplash.com/photo-1434389677669-e08b4cac3105',
      itemImages: [
        'https://images.unsplash.com/photo-1434389677669-e08b4cac3105',
        'https://images.unsplash.com/photo-1503342394128-c104d54dba01',
        'https://images.unsplash.com/photo-1556821840-3a63f95609a7',
      ],
    ),
    Order(
      id: 'ORD-2024-004',
      date: DateTime.now().subtract(const Duration(days: 20)),
      status: 'Cancelled',
      itemCount: 1,
      total: '\$89.99',
      thumbnail: 'https://images.unsplash.com/photo-1591047139829-d91aecb6caea',
      itemImages: [
        'https://images.unsplash.com/photo-1591047139829-d91aecb6caea',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Order> get _filteredOrders {
    final index = _tabController.index;
    if (index == 0) return _orders; // All
    if (index == 1) return _orders.where((o) => o.status == 'In Transit').toList();
    if (index == 2) return _orders.where((o) => o.status == 'Delivered').toList();
    if (index == 3) return _orders.where((o) => o.status == 'Cancelled').toList();
    return _orders;
  }

  Color _getStatusColor(String status) {
    switch (status) {
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
        title: const Text(
          'Order History',
          style: TextStyle(color: AppTheme.gray900, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.purple600,
          unselectedLabelColor: AppTheme.gray500,
          indicatorColor: AppTheme.purple600,
          onTap: (index) => setState(() {}),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'In Transit'),
            Tab(text: 'Delivered'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _filteredOrders.isEmpty
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
                color: AppTheme.gray100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 64,
                color: AppTheme.gray400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Orders Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your order history will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.gray600,
              ),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status).withOpacity(0.1),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.gray500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Order ID
            Text(
              order.id,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.gray900,
              ),
            ),
            const SizedBox(height: 12),
            // Product images
            Row(
              children: [
                ...order.itemImages.take(3).map((image) => Padding(
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
                    )),
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
                      order.total,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.gray900,
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
                          side: const BorderSide(color: AppTheme.purple600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Track Order',
                          style: TextStyle(color: AppTheme.purple600),
                        ),
                      ),
                    if (order.status == 'Delivered')
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.purple600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Buy Again',
                          style: TextStyle(color: AppTheme.purple600),
                        ),
                      ),
                    if (order.status != 'In Transit' && order.status != 'Delivered')
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
