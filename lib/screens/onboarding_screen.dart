import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onGetStarted;

  const OnboardingScreen({super.key, required this.onGetStarted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;

  static const _heroImages = [
    'https://lh3.googleusercontent.com/aida-public/AB6AXuBnu2IuRnbmxbj3fOJw51TEKk63ToygomUiTizyFPEIsOvSaA_fHnsSFejXdlwjaavD9KrCfjKpSyp35E3OFumYQ4zifNFfCNyJjtoT_lw-suiQk9X1fcb3piJvAd8ySju_A781IGTcG_Gkro1UyqtUb6LlUB3KEVpcxPU3PTJeMD9_md2P04tsCH8icH8hDVy6YcfzKiCxoIHcLNGd4-zLQaRLNP9pXSEw9FHlare1uCdbGCi3rV-S4tlpGctLDNTbG6vs0PXO8A',
    'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=1200&q=80',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: _heroImages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: _heroImages[index],
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: const Color(0xFF141B2B)),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFF141B2B),
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white54,
                    size: 44,
                  ),
                ),
              );
            },
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x11070235),
                  Color(0x33070235),
                  Color(0xF0070235),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'StyleSprint',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Shop your style, try it on virtually.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFE1E8FD),
                      fontSize: 19,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 42),
                  SizedBox(
                    width: double.infinity,
                    height: 72,
                    child: ElevatedButton(
                      onPressed: widget.onGetStarted,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF070235),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 16),
                          Icon(Icons.arrow_forward, size: 26),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: OutlinedButton(
                      onPressed: widget.onGetStarted,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_heroImages.length, (index) {
                      final selected = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: selected ? 36 : 10,
                        height: 5,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.34),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
