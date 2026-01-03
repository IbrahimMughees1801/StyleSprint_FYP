import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onSignOut;
  final Function(AppScreen)? onNavigate;

  const ProfileScreen({
    super.key,
    required this.onBack,
    required this.onSignOut,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.gray50,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with gradient
            Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.purplePinkGradient,
              ),
              child: Stack(
                children: [
                  // Decorative elements
                  Positioned(
                    top: 40,
                    right: 40,
                    child: Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 40,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 48, 24, 96),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            onPressed: onBack,
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 4),
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'John Doe',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'john.doe@email.com',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Stats card
            Transform.translate(
              offset: const Offset(0, -64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat('12', 'Orders'),
                      Container(width: 1, height: 40, color: AppTheme.gray200),
                      _buildStat('8', 'Wishlist'),
                      Container(width: 1, height: 40, color: AppTheme.gray200),
                      _buildStat('5', 'Reviews'),
                    ],
                  ),
                ),
              ),
            ),
            // Menu items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.shopping_bag_outlined,
                    label: 'My Orders',
                    description: 'Track and view your orders',
                    color: AppTheme.blue600,
                    bgColor: AppTheme.blue600.withOpacity(0.1),
                    onTap: () => onNavigate?.call(AppScreen.orderHistory),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.location_on_outlined,
                    label: 'Saved Addresses',
                    description: 'Manage delivery addresses',
                    color: AppTheme.green600,
                    bgColor: AppTheme.green600.withOpacity(0.1),
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.credit_card,
                    label: 'Payment Methods',
                    description: 'Manage payment options',
                    color: AppTheme.purple600,
                    bgColor: AppTheme.purple600.withOpacity(0.1),
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    description: 'Manage your preferences',
                    color: AppTheme.orange600,
                    bgColor: AppTheme.orange600.withOpacity(0.1),
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    description: 'App preferences',
                    color: AppTheme.gray600,
                    bgColor: AppTheme.gray100,
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.help_outline,
                    label: 'Help & Support',
                    description: 'Get help and contact us',
                    color: AppTheme.pink600,
                    bgColor: AppTheme.pink600.withOpacity(0.1),
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.logout,
                    label: 'Sign Out',
                    description: 'Log out from your account',
                    color: AppTheme.red600,
                    bgColor: AppTheme.red600.withOpacity(0.1),
                    onTap: onSignOut,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      color: AppTheme.gray400,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.gray900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.gray500,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
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
    );
  }
}
