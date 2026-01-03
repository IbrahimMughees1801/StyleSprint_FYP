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
    'Hoodies',
    'Dresses',
    'Shoes',
    'Jackets',
    'T-Shirts',
    'Jeans',
  ];

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 44),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedIndex == index;
          return Padding(
            padding: EdgeInsets.only(right: index < _categories.length - 1 ? 12 : 0),
            child: ChoiceChip(
              label: Text(_categories[index]),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              backgroundColor: AppTheme.gray100,
              selectedColor: AppTheme.purple600,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.gray700,
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }
}
