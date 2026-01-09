import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StorePartners extends StatelessWidget {
  const StorePartners({super.key});

  final List<Map<String, String>> _stores = const [
    {'name': 'Zara', 'logo': '🏬'},
    {'name': 'H&M', 'logo': '👕'},
    {'name': 'Nike', 'logo': '👟'},
    {'name': 'Adidas', 'logo': '⚡'},
    {'name': 'Uniqlo', 'logo': '🎽'},
    {'name': "Levi's", 'logo': '👖'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Our Store Partners',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _stores.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: index < _stores.length - 1 ? 12 : 0),
                child: Container(
                  width: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _stores[index]['logo']!,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _stores[index]['name']!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
