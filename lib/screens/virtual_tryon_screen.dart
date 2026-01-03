import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class VirtualTryOnScreen extends StatefulWidget {
  final VoidCallback onBack;

  const VirtualTryOnScreen({super.key, required this.onBack});

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  bool _cameraActive = false;
  int? _selectedProductId;

  final List<Map<String, dynamic>> _quickSelectProducts = [
    {
      'id': 1,
      'name': 'White Hoodie',
      'image': 'https://images.unsplash.com/photo-1711387718409-a05f62a3dc39?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    },
    {
      'id': 2,
      'name': 'Summer Dress',
      'image': 'https://images.unsplash.com/photo-1610202631408-fa6ba0f39ca3?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    },
    {
      'id': 3,
      'name': 'Winter Jacket',
      'image': 'https://images.unsplash.com/photo-1706765779494-2705542ebe74?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&w=400',
    },
  ];

  void _showTryOnOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Choose Try-On Method',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select how you want to try on the products',
              style: TextStyle(color: AppTheme.gray600),
            ),
            const SizedBox(height: 24),
            _buildOptionButton(
              icon: Icons.camera_alt,
              label: 'Open Camera',
              description: 'Try on in real-time',
              gradient: AppTheme.purplePinkGradient,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _cameraActive = true;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildOptionButton(
              icon: Icons.photo_library,
              label: 'Use Profile Photo',
              description: 'Try on with your photo',
              gradient: AppTheme.blueCyanGradient,
              onTap: () {
                Navigator.pop(context);
                // For now, just activate camera - can be enhanced later
                setState(() {
                  _cameraActive = true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required String description,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera view or welcome screen
          if (!_cameraActive) _buildWelcomeScreen() else _buildCameraView(),
          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_cameraActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: AppTheme.purplePinkGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'AI Try-On Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_cameraActive)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Bottom controls (only when camera active)
          if (_cameraActive) _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                gradient: AppTheme.purplePinkGradient,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.purple600.withOpacity(0.3),
                  width: 4,
                ),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 96,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Ready to Try On?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Position yourself in front of the camera\nand let our AI work its magic',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.purplePinkGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.purple600.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _showTryOnOptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Start Camera',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Simulated camera feed
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.gray800, AppTheme.gray900],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.purple600,
                      width: 4,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 64,
                    color: AppTheme.purple600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Camera feed would appear here',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Guide frame
        Center(
          child: Container(
            width: 256,
            height: 384,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        // Product applied indicator
        if (_selectedProductId != null)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.green600.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 20, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Product Applied',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quick select products
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Select Products',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _quickSelectProducts.length,
                      itemBuilder: (context, index) {
                        final product = _quickSelectProducts[index];
                        final isSelected = _selectedProductId == product['id'];
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index < _quickSelectProducts.length - 1 ? 12 : 0,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedProductId = product['id'];
                              });
                            },
                            child: Container(
                              width: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.purple600
                                      : Colors.white.withOpacity(0.3),
                                  width: isSelected ? 3 : 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: CachedNetworkImage(
                                  imageUrl: product['image'],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text(
                        'Save Photo',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.purplePinkGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.shopping_cart, color: Colors.white),
                        label: const Text(
                          'Add to Cart',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
