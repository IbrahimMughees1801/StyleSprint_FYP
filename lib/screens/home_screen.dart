import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/hero_banner.dart';
import '../widgets/category_bar.dart';
import '../widgets/virtual_tryon_card.dart';
import '../widgets/product_grid.dart';
import '../widgets/bottom_nav.dart';
import '../main.dart';

class HomeScreen extends StatelessWidget {
  final Function(AppScreen) onNavigate;
  final Function(int) onProductClick;

  const HomeScreen({
    super.key,
    required this.onNavigate,
    required this.onProductClick,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Scrollable content
          CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(child: Header(onNavigate: onNavigate)),
              // Hero Banner
              const SliverToBoxAdapter(child: HeroBanner()),
              // Content sections
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 72),
                    VirtualTryOnCard(
                      onTryNow: () => onNavigate(AppScreen.tryon),
                    ),
                    const SizedBox(height: 72),
                    const CategoryBar(),
                    const SizedBox(height: 72),
                    ProductGrid(onProductClick: onProductClick),
                    const SizedBox(height: 128),
                  ]),
                ),
              ),
            ],
          ),
          // Bottom Navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNav(onNavigate: onNavigate),
          ),
        ],
      ),
    );
  }
}
