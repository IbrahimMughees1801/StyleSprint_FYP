import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import '../services/cart_service.dart';

class Header extends StatelessWidget {
  final Function(AppScreen) onNavigate;

  const Header({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CartService.instance,
      builder: (context, _) {
        final count = CartService.instance.itemCount;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.menu,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () => onNavigate(AppScreen.profile),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'StyleSprint',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shopping_bag_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () => onNavigate(AppScreen.cart),
                    ),
                    if (count > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: AppTheme.red600,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
