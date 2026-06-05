import 'dart:async';

import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/product_photo.dart';
import '../services/saved_tryon_service.dart';
import '../services/supabase_products_service.dart';
import '../services/virtual_tryon_service.dart';
import '../theme/app_theme.dart';

class VirtualTryOnScreen extends StatefulWidget {
  final VoidCallback onBack;

  const VirtualTryOnScreen({super.key, required this.onBack});

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  static const Color _atelierBg = Color(0xFF000C1D);
  static const Color _atelierPanel = Color(0xFF122336);
  static const Color _atelierAccent = Color(0xFFC4C1FB);
  static const Color _atelierMuted = Color(0xFF7A8AA2);
  static const String _previewImageUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuClIiuItSJyXWfb-KhOQvgLqJ7BfZWeOTgEubfMhlflCz8q52hELdZFWugyxSGxQYTT-gpniusuFaz47Id8_8XXeyOkaN31tv5AFt8J2w2zXuW8UGUedYHxSxcyaJvnufso5DQQwW3E7LaCTDLmgIyYCSUk-0_jPiVtsuwfIZ5Cre-ivwP1xrH9bgPHTq_INAwrdJsqIzytLp0_ppkWU2SsvQabGDMUKtVEk3BIGvBU0YqLv6qRCLC4xbG_ihTjVtFBcX6NaqacHw';

  final ImagePicker _picker = ImagePicker();
  final SupabaseProductsService _productsService = SupabaseProductsService();
  final VirtualTryOnService _tryOnService = VirtualTryOnService();
  final SavedTryOnService _savedTryOnService = SavedTryOnService.instance;
  List<ProductPhoto> _products = [];
  bool _isLoadingProducts = false;
  String? _productsError;

  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  Uint8List? _capturedImageBytes;
  Uint8List? _resultImageBytes;
  bool _cameraActive = false;
  bool _isReviewingCapturedPhoto = false;
  bool _isCameraInitializing = false;
  bool _isProcessingTryOn = false;
  CameraLensDirection _preferredLensDirection = CameraLensDirection.front;
  int? _selectedProductId;

  @override
  void initState() {
    super.initState();
    _loadAvailableCameras();
    _loadProducts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showTryOnInstructions();
    });
  }

  void _showTryOnInstructions() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.accessibility_new, color: _atelierBg),
              SizedBox(width: 10),
              Expanded(child: Text('For Best Results')),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TryOnInstructionRow(
                icon: Icons.straighten,
                text: 'Stand straight and face the camera.',
              ),
              SizedBox(height: 12),
              _TryOnInstructionRow(
                icon: Icons.pan_tool_alt_outlined,
                text: 'Keep your arms relaxed and down.',
              ),
              SizedBox(height: 12),
              _TryOnInstructionRow(
                icon: Icons.fullscreen,
                text: 'Use a clear full-body photo.',
              ),
              SizedBox(height: 12),
              _TryOnInstructionRow(
                icon: Icons.light_mode_outlined,
                text: 'Choose good lighting and avoid shadows.',
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _atelierBg,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        );
      },
    );
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
        _selectedProductId ??= items.isNotEmpty ? items.first.id : null;
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

  Future<void> _openCamera({
    CameraLensDirection? preferredLensDirection,
  }) async {
    if (_isCameraInitializing) return;

    if (preferredLensDirection == null) {
      await _pickFromCamera();
      return;
    }

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

      final camera = _availableCameras.firstWhere(
        (c) => c.lensDirection == preferredLensDirection,
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
        _capturedImageBytes = null;
        _resultImageBytes = null;
        _cameraActive = true;
        _isReviewingCapturedPhoto = false;
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
      _capturedImageBytes = null;
      _resultImageBytes = null;
      _cameraActive = false;
    });

    await _openCamera(preferredLensDirection: nextDirection);
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      final photo = await controller.takePicture();
      final photoBytes = await photo.readAsBytes();
      if (!mounted) return;

      setState(() {
        _capturedImageBytes = photoBytes;
        _resultImageBytes = null;
        _isReviewingCapturedPhoto = true;
      });

      await _cameraController?.dispose();
      if (!mounted) return;
      setState(() {
        _cameraController = null;
      });
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

  Future<void> _pickFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 768,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo != null && mounted) {
        final photoBytes = await photo.readAsBytes();
        setState(() {
          _capturedImageBytes = photoBytes;
          _resultImageBytes = null;
          _cameraActive = true;
          _isReviewingCapturedPhoto = true;
        });
      }
    } catch (e) {
      if (mounted) {
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

  Future<void> _pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (photo != null && mounted) {
        final photoBytes = await photo.readAsBytes();
        setState(() {
          _capturedImageBytes = photoBytes;
          _resultImageBytes = null;
          _cameraActive = true;
          _isReviewingCapturedPhoto = true;
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

  Future<void> _processSelectedTryOn() async {
    if (_capturedImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Capture or select your photo first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isReviewingCapturedPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use this photo before starting try-on.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ProductPhoto? selectedProduct;
    for (final product in _products) {
      if (product.id == _selectedProductId) {
        selectedProduct = product;
        break;
      }
    }

    if (selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a product first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isProcessingTryOn = true;
    });

    try {
      final isAvailable = await _tryOnService.isServerAvailable();
      if (!isAvailable) {
        throw Exception(
          'Backend is not running at ${VirtualTryOnService.baseUrl}.',
        );
      }

      final clothResponse = await http.get(
        Uri.parse(selectedProduct.tryOnImageUrl),
      );
      if (clothResponse.statusCode != 200) {
        throw Exception('Failed to download selected product image.');
      }

      final result = await _tryOnService.processBase64Images(
        personImageBytes: _capturedImageBytes!,
        clothImageBytes: clothResponse.bodyBytes,
        productCategory: selectedProduct.category,
        productType: selectedProduct.productType,
      );

      if (!result.success || result.sessionId.isEmpty) {
        throw Exception(result.message);
      }

      await _savedTryOnService.addProcessingTryOn(
        sessionId: result.sessionId,
        productName: selectedProduct.name,
        productImageUrl: selectedProduct.tryOnImageUrl,
      );

      if (!mounted) return;
      setState(() {
        _isProcessingTryOn = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating your virtual try-on. You can keep browsing.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Try-on start failed: $e');
      if (!mounted) return;
      setState(() {
        _isProcessingTryOn = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Try-on could not start. Check your connection and try again.',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _useCapturedPhoto() {
    setState(() {
      _isReviewingCapturedPhoto = false;
    });
  }

  Future<void> _retakePhoto() async {
    setState(() {
      _capturedImageBytes = null;
      _resultImageBytes = null;
      _isReviewingCapturedPhoto = false;
      _cameraActive = false;
    });
    await _pickFromCamera();
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
              description: 'Use your camera app, then confirm or retake',
              gradient: AppTheme.atelierDarkGradient,
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
                color: Colors.white.withValues(alpha: 0.2),
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
                      color: Colors.white.withValues(alpha: 0.8),
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
    _tryOnService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _atelierBg,
      body: Stack(
        children: [
          if (!_cameraActive) _buildWelcomeScreen() else _buildCameraView(),
          _buildAtelierTopBar(),
          if (_cameraActive) _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildAtelierTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.menu, color: _atelierAccent, size: 30),
            ),
            const Expanded(
              child: Text(
                'StyleSprint',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFE3DFFF),
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
            IconButton(
              onPressed: _showTryOnOptions,
              icon: const Icon(
                Icons.shopping_bag_outlined,
                color: _atelierAccent,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 94, 24, 132),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VIRTUAL ATELIER',
                        style: TextStyle(
                          color: _atelierMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'AI Try-On',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 46,
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: _atelierPanel,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: _atelierMuted,
                    size: 30,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildAtelierPreview(),
            const SizedBox(height: 42),
            _buildGarmentCarousel(),
            const SizedBox(height: 28),
            _buildProcessButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAtelierPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: _previewImageUrl,
              fit: BoxFit.cover,
              color: Colors.blueGrey.withValues(alpha: 0.5),
              colorBlendMode: BlendMode.saturation,
              placeholder: (context, url) => Container(color: _atelierPanel),
            ),
            Container(color: _atelierBg.withValues(alpha: 0.46)),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.34),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Upload a high-quality portrait for the most accurate results',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF9AA9C1),
                        fontSize: 16,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _buildPreviewButton(
                            icon: Icons.upload,
                            label: 'Upload Photo',
                            filled: true,
                            onTap: _pickFromGallery,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPreviewButton(
                            icon: Icons.photo_camera_outlined,
                            label: 'Camera',
                            filled: false,
                            onTap: () => _openCamera(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 36,
              bottom: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 18, color: Colors.white38),
                      const SizedBox(width: 3),
                      Container(width: 4, height: 28, color: Colors.white70),
                      const SizedBox(width: 3),
                      Container(width: 4, height: 18, color: Colors.white38),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'AI FOCUS LOCK',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewButton({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 62,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: filled
              ? Colors.white
              : Colors.white.withValues(alpha: 0.06),
          foregroundColor: filled ? _atelierBg : Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: filled
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGarmentCarousel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SELECT GARMENT',
              style: TextStyle(
                color: _atelierMuted,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.8,
              ),
            ),
            Text(
              'Browse Collection',
              style: TextStyle(
                color: _atelierAccent,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 174,
          child: _isLoadingProducts
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
              ? Center(
                  child: Text(
                    _productsError ?? 'No Supabase products yet.',
                    style: const TextStyle(color: _atelierMuted),
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _products.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 20),
                  itemBuilder: (context, index) {
                    final product = _products[index];
                    final selected = product.id == _selectedProductId;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedProductId = product.id;
                      }),
                      child: SizedBox(
                        width: 132,
                        child: Column(
                          children: [
                            Container(
                              height: 112,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected
                                      ? _atelierAccent
                                      : Colors.white.withValues(alpha: 0.12),
                                  width: selected ? 3 : 1,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: _atelierAccent.withValues(
                                            alpha: 0.16,
                                          ),
                                          blurRadius: 18,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CachedNetworkImage(
                                      imageUrl: product.tryOnImageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          const _ProductImageSkeleton(),
                                      errorWidget: (context, url, error) =>
                                          const _ProductImageFallback(),
                                    ),
                                    if (selected)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          width: 28,
                                          height: 28,
                                          decoration: const BoxDecoration(
                                            color: _atelierAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: _atelierBg,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected ? Colors.white : _atelierMuted,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${product.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: _atelierMuted,
                                fontSize: 12,
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

  Widget _buildProcessButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        onPressed: _isProcessingTryOn ? null : _processSelectedTryOn,
        icon: _isProcessingTryOn
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _atelierAccent,
                ),
              )
            : const Icon(Icons.auto_fix_high, color: _atelierAccent),
        label: Text(
          _isProcessingTryOn ? 'Processing...' : 'Process Try-On',
          style: const TextStyle(
            color: _atelierAccent,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2B235F),
          foregroundColor: _atelierAccent,
          disabledBackgroundColor: const Color(0xFF2B235F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    final isLiveCamera =
        _cameraController != null && _cameraController!.value.isInitialized;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_resultImageBytes != null)
          _buildFittedTryOnImage(_resultImageBytes!)
        else if (_capturedImageBytes != null)
          _buildFittedTryOnImage(_capturedImageBytes!)
        else if (isLiveCamera)
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
                  : const Icon(
                      Icons.camera_alt,
                      size: 72,
                      color: AppTheme.atelierMidnight,
                    ),
            ),
          ),
        if (isLiveCamera)
          Center(
            child: Container(
              width: 256,
              height: 384,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        if (isLiveCamera)
          Positioned(
            left: 0,
            right: 0,
            bottom: 52,
            child: Center(
              child: GestureDetector(
                onTap: _capturePhoto,
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5),
                    color: AppTheme.atelierMidnight.withValues(alpha: 0.85),
                  ),
                  child: const Icon(
                    Icons.camera,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),
          ),
        if (isLiveCamera)
          Positioned(
            right: 20,
            bottom: 68,
            child: FloatingActionButton.small(
              heroTag: 'swap-camera',
              onPressed: _switchCamera,
              backgroundColor: Colors.black.withValues(alpha: 0.75),
              child: const Icon(Icons.flip_camera_ios, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildFittedTryOnImage(Uint8List imageBytes) {
    return Container(
      color: _atelierBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            imageBytes,
            fit: BoxFit.cover,
            color: Colors.black.withValues(alpha: 0.48),
            colorBlendMode: BlendMode.darken,
          ),
          Container(color: _atelierBg.withValues(alpha: 0.42)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 82, 12, 178),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    if (_isReviewingCapturedPhoto && _capturedImageBytes != null) {
      return _buildPhotoReviewControls();
    }

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
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)],
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
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
                      style: const TextStyle(
                        color: AppTheme.red500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    height: 80,
                    child: _isLoadingProducts
                        ? const _CompactProductSkeletonRow()
                        : _products.isEmpty
                        ? const Center(
                            child: Text(
                              'No Supabase products yet.',
                              style: TextStyle(
                                color: AppTheme.gray400,
                                fontSize: 12,
                              ),
                            ),
                          )
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              final isSelected =
                                  _selectedProductId == product.id;
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
                                            ? AppTheme.atelierAccent
                                            : Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                        width: isSelected ? 3 : 2,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: CachedNetworkImage(
                                        imageUrl: product.imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            const _ProductImageSkeleton(),
                                        errorWidget: (context, url, error) =>
                                            const _ProductImageFallback(),
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
                      onPressed: _resultImageBytes == null
                          ? null
                          : () {
                              setState(() {
                                _capturedImageBytes = null;
                                _resultImageBytes = null;
                                _selectedProductId = null;
                                _isReviewingCapturedPhoto = false;
                                _cameraActive = false;
                              });
                            },
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text(
                        'Reset',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
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
                        color: AppTheme.atelierMidnight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isProcessingTryOn
                            ? null
                            : _processSelectedTryOn,
                        icon: _isProcessingTryOn
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.auto_awesome,
                                color: Colors.white,
                              ),
                        label: Text(
                          _isProcessingTryOn ? 'Trying On...' : 'Try On',
                          style: const TextStyle(color: Colors.white),
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

  Widget _buildPhotoReviewControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.92)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Use this photo?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose this image for try-on or take another shot.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _atelierMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _retakePhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Take Again'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _useCapturedPhoto,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Use Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _atelierAccent,
                        foregroundColor: _atelierBg,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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

class _TryOnInstructionRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TryOnInstructionRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.atelierMidnight),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.25))),
      ],
    );
  }
}

class _ProductImageSkeleton extends StatelessWidget {
  const _ProductImageSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
      ),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.08),
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: AppTheme.gray400,
      ),
    );
  }
}

class _CompactProductSkeletonRow extends StatelessWidget {
  const _CompactProductSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (context, index) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: const SizedBox(width: 80, child: _ProductImageSkeleton()),
        );
      },
    );
  }
}
