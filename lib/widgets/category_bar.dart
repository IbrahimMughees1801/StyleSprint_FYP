import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CategoryBar extends StatefulWidget {
  const CategoryBar({super.key});

  @override
  State<CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<CategoryBar> {
  int _selectedIndex = 0;

  final List<String> _categories = [
    'All',
    'Men',
    'Women',
    'Accessories',
    'Outerwear',
    'Essentials',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Categories',
              style: TextStyle(
                color: Color(0xFF070235),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'View All',
              style: TextStyle(
                color: AppTheme.gray600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 34,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedIndex == index;
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _categories.length - 1 ? 12 : 0,
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: const BoxConstraints(minWidth: 62),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF070235)
                          : const Color(0xFFE1E3E4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _categories[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.gray700,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
