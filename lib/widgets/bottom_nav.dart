import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_theme.dart';

class BottomNav extends StatefulWidget {
  final Function(AppScreen) onNavigate;

  const BottomNav({super.key, required this.onNavigate});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.storefront_outlined,
                selectedIcon: Icons.storefront,
                label: 'Shop',
                index: 0,
                onTap: () => widget.onNavigate(AppScreen.home),
              ),
              _buildNavItem(
                icon: Icons.explore_outlined,
                selectedIcon: Icons.explore,
                label: 'Discover',
                index: 1,
                onTap: () => widget.onNavigate(AppScreen.search),
              ),
              _buildNavItem(
                icon: Icons.favorite_border,
                selectedIcon: Icons.favorite,
                label: 'Wishlist',
                index: 2,
                onTap: () => widget.onNavigate(AppScreen.wishlist),
              ),
              _buildNavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                label: 'Profile',
                index: 3,
                onTap: () => widget.onNavigate(AppScreen.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : AppTheme.gray500,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : AppTheme.gray500,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
