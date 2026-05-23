import 'package:flutter/material.dart';

import '../main.dart';
import '../services/firebase_auth_service.dart';
import '../services/order_service.dart';
import '../services/wishlist_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSignOut;
  final Function(AppScreen)? onNavigate;
  final Function(ThemeMode)? onThemeChange;

  const ProfileScreen({
    super.key,
    required this.onBack,
    required this.onSignOut,
    this.onNavigate,
    this.onThemeChange,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = FirebaseAuthService();
  final _orderService = OrderService.instance;
  final _wishlistService = WishlistService.instance;

  @override
  void initState() {
    super.initState();
    _orderService.addListener(_refresh);
    _wishlistService.addListener(_refresh);
    _orderService.loadOrders();
    _wishlistService.load();
  }

  @override
  void dispose() {
    _orderService.removeListener(_refresh);
    _wishlistService.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _handleSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldSignOut != true) return;

    try {
      await _authService.signOut();
      if (mounted) widget.onSignOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: AppTheme.red600,
        ),
      );
    }
  }

  void _showSupportSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Help & Support',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _buildSupportAction(
                  Icons.mail_outline,
                  'Email support',
                  'stylesprint.support@example.com',
                ),
                _buildSupportAction(
                  Icons.local_shipping_outlined,
                  'Order help',
                  'Open orders to track or review a purchase.',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNavigate?.call(AppScreen.orderHistory);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSupportAction(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.atelierDarkGradient,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 86),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: widget.onBack,
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            user?.displayName ?? 'StyleSprint User',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user?.email ?? 'user@email.com',
                            style: const TextStyle(
                              color: AppTheme.atelierAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildStatsCard(),
                        const SizedBox(height: 18),
                        _buildMenuItem(
                          icon: Icons.shopping_bag_outlined,
                          label: 'My Orders',
                          description: 'Track and view your orders',
                          onTap: () =>
                              widget.onNavigate?.call(AppScreen.orderHistory),
                        ),
                        _buildMenuItem(
                          icon: Icons.favorite_border,
                          label: 'Wishlist',
                          description: 'View saved products',
                          onTap: () =>
                              widget.onNavigate?.call(AppScreen.wishlist),
                        ),
                        _buildMenuItem(
                          icon: Icons.rate_review_outlined,
                          label: 'My Reviews',
                          description: 'Reviews will appear after delivery',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No reviews yet. Delivered orders can be reviewed here soon.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.location_on_outlined,
                          label: 'Saved Addresses',
                          description: 'Manage delivery addresses',
                          onTap: () {},
                        ),
                        _buildMenuItem(
                          icon: Icons.credit_card,
                          label: 'Payment Methods',
                          description: 'Cash on delivery and saved cards',
                          onTap: () {},
                        ),
                        _buildThemeToggle(isDarkMode),
                        _buildMenuItem(
                          icon: Icons.help_outline,
                          label: 'Help & Support',
                          description: 'Get help and contact us',
                          onTap: _showSupportSheet,
                        ),
                        _buildMenuItem(
                          icon: Icons.logout,
                          label: 'Sign Out',
                          description: 'Log out from your account',
                          destructive: true,
                          onTap: _handleSignOut,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: AppTheme.gray400,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 118),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNav(onNavigate: widget.onNavigate ?? (_) {}),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat('${_orderService.orderCount}', 'Orders'),
          Container(
            width: 1,
            height: 36,
            color: Theme.of(context).dividerColor,
          ),
          _buildStat('${_wishlistService.count}', 'Wishlist'),
          Container(
            width: 1,
            height: 36,
            color: Theme.of(context).dividerColor,
          ),
          _buildStat('0', 'Reviews'),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.gray500),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive
        ? AppTheme.red600
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: destructive
                      ? AppTheme.red500.withValues(alpha: 0.1)
                      : Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.gray400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dark Mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isDarkMode
                        ? 'Switch to light theme'
                        : 'Switch to dark theme',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isDarkMode,
              onChanged: (value) {
                widget.onThemeChange?.call(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
              },
              activeThumbColor: AppTheme.atelierMidnight,
            ),
          ],
        ),
      ),
    );
  }
}
