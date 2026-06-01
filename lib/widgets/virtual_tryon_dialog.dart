import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/saved_tryon_service.dart';
import '../services/virtual_tryon_service.dart';

class VirtualTryOnDialog extends StatefulWidget {
  final String productImageUrl;
  final String productName;
  final String? productCategory;
  final String? productType;

  const VirtualTryOnDialog({
    super.key,
    required this.productImageUrl,
    required this.productName,
    this.productCategory,
    this.productType,
  });

  @override
  State<VirtualTryOnDialog> createState() => _VirtualTryOnDialogState();
}

class _VirtualTryOnDialogState extends State<VirtualTryOnDialog> {
  final VirtualTryOnService _tryOnService = VirtualTryOnService();
  final SavedTryOnService _savedTryOnService = SavedTryOnService.instance;
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedPersonImage;
  Uint8List? _selectedPersonImageBytes;
  bool _isProcessing = false;
  String? _errorMessage;
  Uint8List? _resultImageBytes;

  Future<Uint8List> _downloadProductImage(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download product image');
    }
    return response.bodyBytes;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 768,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final imageBytes = await image.readAsBytes();
        setState(() {
          _selectedPersonImage = image;
          _selectedPersonImageBytes = imageBytes;
          _errorMessage = null;
          _resultImageBytes = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
      });
    }
  }

  Future<void> _processTryOn() async {
    if (_selectedPersonImageBytes == null) {
      setState(() {
        _errorMessage = 'Please select your photo first';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Check if server is available
      final isAvailable = await _tryOnService.isServerAvailable();
      if (!isAvailable) {
        throw Exception(
          'Server is not available. Please make sure the backend is running.',
        );
      }

      final clothImageBytes = await _downloadProductImage(
        widget.productImageUrl,
      );

      final result = await _tryOnService.processBase64Images(
        personImageBytes: _selectedPersonImageBytes!,
        clothImageBytes: clothImageBytes,
        productCategory: widget.productCategory,
        productType: widget.productType,
      );

      if (!result.success || result.sessionId.isEmpty) {
        throw Exception(result.message);
      }

      await _savedTryOnService.addProcessingTryOn(
        sessionId: result.sessionId,
        productName: widget.productName,
        productImageUrl: widget.productImageUrl,
      );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _isProcessing = false);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Try-on is processing in the background.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _tryOnService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Virtual Try-On',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Upload your photo to see how ${widget.productName} looks on you',
              style: const TextStyle(color: AppTheme.gray600, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(child: _buildContent()),

            // Actions
            const SizedBox(height: 24),
            if (!_isProcessing && _resultImageBytes == null) ...[
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: Text(
                  _selectedPersonImage == null
                      ? 'Select Your Photo'
                      : 'Change Photo',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_selectedPersonImage != null) ...[
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.atelierMidnight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _processTryOn,
                    icon: const Icon(Icons.auto_awesome, color: Colors.white),
                    label: const Text(
                      'Try It On',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.red500),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.red600),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              'Processing your try-on...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can close this and keep browsing',
              style: TextStyle(color: AppTheme.gray600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_resultImageBytes != null) {
      return Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_resultImageBytes!, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedPersonImage = null;
                      _selectedPersonImageBytes = null;
                      _resultImageBytes = null;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: OutlinedButton.styleFrom(
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
                  onPressed: () {
                    // TODO: Save or share image
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Looks Good!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.atelierMidnight,
                    foregroundColor: Colors.white,
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
      );
    }

    if (_selectedPersonImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(_selectedPersonImageBytes!, fit: BoxFit.contain),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.atelierSurfaceLow,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              size: 64,
              color: AppTheme.atelierMidnight,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Upload Your Photo',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take or select a full-body photo\nfor the best results',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.gray600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
