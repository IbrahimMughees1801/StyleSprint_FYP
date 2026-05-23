import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key});

  static const _imageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuDK7KZn_vdUZI1y5l61FV7nXt6OMkomUaIwmGDLNAbKJsiSfOYFmGhfIzAcVA2N6Q9T3IVhq5eHs_CG5iKQYvmqL7Iywc6Jde7kUP0if4K3uVu4N2qY2erLsyEUS1GWXXXcRZhdjdcvNJMekEopKEGaS9yEXY4YZeXuG7MLH-R9a5ISgb5aw9QoylwtM-GCM-JA4K_QSwCYflHBp9UxT5L1yy1wjZNKmbY8PXHs6ERezdSU3KNSj-YEs-HPP1RoY_iv_g7YfHeKSg';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: _imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: const Color(0xFFE9EDFF)),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFFE9EDFF),
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00070235),
                      Color(0x11070235),
                      Color(0xCC070235),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 28,
                right: 28,
                bottom: 28,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LIMITED EDITION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'New Collection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF070235),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'EXPLORE NOW',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 20,
                top: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'TRY-ON READY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
