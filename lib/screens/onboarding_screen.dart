import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onGetStarted;

  const OnboardingScreen({super.key, required this.onGetStarted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      icon: Icons.shopping_bag_outlined,
      title: 'Shop From\nTop Brands',
      description: 'Access thousands of products from Zara, H&M, Nike, and more in one app',
      gradient: AppTheme.blueCyanGradient,
    ),
    OnboardingSlide(
      icon: Icons.auto_awesome,
      title: 'Virtual\nTry-On',
      description: 'See how clothes look on you with our AI-powered AR technology',
      gradient: AppTheme.purplePinkGradient,
    ),
    OnboardingSlide(
      icon: Icons.bolt,
      title: 'Fast & Easy\nCheckout',
      description: 'Secure payment and quick delivery from all your favorite stores',
      gradient: AppTheme.orangeRedGradient,
    ),
  ];

  void _handleNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onGetStarted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                return _buildSlide(_slides[index]);
              },
            ),
          ),
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildSlide(OnboardingSlide slide) {
    return Container(
      decoration: BoxDecoration(
        gradient: slide.gradient,
      ),
      child: Stack(
        children: [
          // Decorative elements
          Positioned(
            top: 80,
            right: 40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 80,
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
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      slide.icon,
                      size: 96,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    slide.title,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _slides[_currentPage].description,
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.gray600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Pagination dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _slides.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 32 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index ? AppTheme.gray900 : AppTheme.gray300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Next button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gray900,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
          if (_currentPage < _slides.length - 1) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onGetStarted,
              child: Text(
                'Skip',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.gray500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;

  OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });
}
