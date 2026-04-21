import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product_photo.dart';
import '../services/supabase_products_service.dart';
import '../theme/app_theme.dart';

class VirtualTryOnScreen extends StatefulWidget {
  final VoidCallback onBack;

  const VirtualTryOnScreen({super.key, required this.onBack});

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  final ImagePicker _picker = ImagePicker();
  final SupabaseProductsService _productsService = SupabaseProductsService();
  List<ProductPhoto> _products = [];
  bool _isLoadingProducts = false;
  String? _productsError;

  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  File? _capturedImage;
  bool _cameraActive = false;
  bool _isCameraInitializing = false;
  CameraLensDirection _preferredLensDirection = CameraLensDirection.front;
  int? _selectedProductId;

  @override
  void initState() {
    super.initState();
    _loadAvailableCameras();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });

    try {
      final items = await _productsService.fetchProducts();
      if (!mounted) return;

      setState(() {
        _products = items;
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productsError = 'Failed to load products: $e';
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _loadAvailableCameras() async {
    try {
      _availableCameras = await availableCameras();
    } catch (_) {
      _availableCameras = [];
    }
  }

  Future<void> _openCamera({CameraLensDirection? preferredLensDirection}) async {
    if (_isCameraInitializing) return;

    setState(() {
      _isCameraInitializing = true;
    });

    try {
      if (_availableCameras.isEmpty) {
        await _loadAvailableCameras();
      }

      if (_availableCameras.isEmpty) {
        throw Exception('No camera was found on this device.');
      }

      final direction = preferredLensDirection ?? _preferredLensDirection;

      final camera = _availableCameras.firstWhere(
        (c) => c.lensDirection == direction,
        orElse: () => _availableCameras.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await _cameraController?.dispose();

      setState(() {
        _cameraController = controller;
        _capturedImage = null;
        _cameraActive = true;
        _preferredLensDirection = camera.lensDirection;
        _isCameraInitializing = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraInitializing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open camera: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_isCameraInitializing || _availableCameras.length < 2) return;

    final nextDirection = _preferredLensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;

    await _cameraController?.dispose();
    if (!mounted) return;

    setState(() {
      _cameraController = null;
      _capturedImage = null;
      _cameraActive = false;
    });

    await _openCamera(preferredLensDirection: nextDirection);
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      final photo = await controller.takePicture();
      if (!mounted) return;

      setState(() {
        _capturedImage = File(photo.path);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo captured! Select a product to try on.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to capture photo: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (photo != null && mounted) {
        setState(() {
          _capturedImage = File(photo.path);
          _cameraActive = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

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
              description: 'Open live camera preview',
              gradient: AppTheme.purplePinkGradient,
              onTap: () async {
                Navigator.pop(context);
                await _openCamera();
              },
            ),
            const SizedBox(height: 12),
            _buildOptionButton(
              icon: Icons.photo_library,
              label: 'Choose from Gallery',
              description: 'Select an existing photo',
              gradient: AppTheme.blueCyanGradient,
              onTap: () async {
                Navigator.pop(context);
                await _pickFromGallery();
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
  void dispose() {
    unawaited(_cameraController?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (!_cameraActive) _buildWelcomeScreen() else _buildCameraView(),
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
                      child: const Icon(Icons.arrow_back, color: Colors.white),
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
                      child: GestureDetector(
                        onTap: _showTryOnOptions,
                        child: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
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
                border: Border.all(color: AppTheme.purple600.withOpacity(0.3), width: 4),
              ),
              child: const Icon(Icons.camera_alt, size: 96, color: Colors.white),
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
              ),
              child: ElevatedButton(
                onPressed: _showTryOnOptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        if (_capturedImage != null)
          Image.file(_capturedImage!, fit: BoxFit.cover)
        else if (_cameraController != null && _cameraController!.value.isInitialized)
          CameraPreview(_cameraController!)
        else
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.gray800, AppTheme.gray900],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: _isCameraInitializing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.camera_alt, size: 72, color: AppTheme.purple600),
            ),
          ),
        Center(
          child: Container(
            width: 256,
            height: 384,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        if (_cameraController != null && _cameraController!.value.isInitialized)
          Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: Center(
              child: GestureDetector(
                onTap: _capturePhoto,
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5),
                    color: AppTheme.purple600.withOpacity(0.85),
                  ),
                  child: const Icon(Icons.camera, color: Colors.white, size: 34),
                ),
              ),
            ),
          ),
        if (_cameraController != null && _cameraController!.value.isInitialized)
          Positioned(
            right: 20,
            bottom: 120,
            child: FloatingActionButton.small(
              heroTag: 'swap-camera',
              onPressed: _switchCamera,
              backgroundColor: Colors.black.withOpacity(0.75),
              child: const Icon(Icons.flip_camera_ios, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomControls() {
    ProductPhoto? selectedProduct;
    if (_selectedProductId != null) {
      for (final product in _products) {
        if (product.id == _selectedProductId) {
          selectedProduct = product;
          break;
        }
      }
    }

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
                  if (selectedProduct != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Text(
                        'Selected product: ${selectedProduct.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_productsError != null) ...[
                    Text(
                      _productsError!,
                      style: const TextStyle(color: AppTheme.red500, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    height: 80,
                    child: _isLoadingProducts
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              final isSelected = _selectedProductId == product.id;
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: index < _products.length - 1 ? 12 : 0,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedProductId = product.id;
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
                                        imageUrl: product.imageUrl,
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text('Save Photo', style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                        label: const Text('Add to Cart', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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