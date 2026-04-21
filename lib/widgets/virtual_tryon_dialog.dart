import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/virtual_tryon_service.dart';
import '../models/tryon_result.dart';

class VirtualTryOnDialog extends StatefulWidget {
  final String productImageUrl;
  final String productName;

  const VirtualTryOnDialog({
    super.key,
    required this.productImageUrl,
    required this.productName,
  });

  @override
  State<VirtualTryOnDialog> createState() => _VirtualTryOnDialogState();
}

class _VirtualTryOnDialogState extends State<VirtualTryOnDialog> {
  final VirtualTryOnService _tryOnService = VirtualTryOnService();
  final ImagePicker _picker = ImagePicker();

  File? _selectedPersonImage;
  bool _isProcessing = false;
  String? _errorMessage;
  TryOnResult? _result;
  Uint8List? _resultImageBytes;

  Future<File> _downloadProductImage(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download product image');
    }

    final tempDir = Directory.systemTemp;
    final file = File(
      '${tempDir.path}/tryon_cloth_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
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
        setState(() {
          _selectedPersonImage = File(image.path);
          _errorMessage = null;
          _result = null;
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
    if (_selectedPersonImage == null) {
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
        throw Exception('Server is not available. Please make sure the backend is running.');
      }

      final clothImage = await _downloadProductImage(widget.productImageUrl);

      final result = await _tryOnService.uploadImages(
        personImage: _selectedPersonImage!,
        clothImage: clothImage,
      );

      setState(() {
        _result = result;
      });

      if (result.success && result.sessionId.isNotEmpty) {
        // Poll for completion
        await _pollForResult(result.sessionId);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
    }
  }

  Future<void> _pollForResult(String sessionId) async {
    int attempts = 0;
    const maxAttempts = 60; // 60 attempts * 2 seconds = 2 minutes max

    while (attempts < maxAttempts) {
      try {
        final status = await _tryOnService.checkStatus(sessionId);

        if (status.isCompleted) {
          // Get result image
          final imageBytes = await _tryOnService.getResultImage(sessionId);
          setState(() {
            _resultImageBytes = imageBytes;
            _isProcessing = false;
          });
          break;
        } else if (status.isFailed) {
          throw Exception('Processing failed');
        }

        // Wait before next poll
        await Future.delayed(const Duration(seconds: 2));
        attempts++;
      } catch (e) {
        setState(() {
          _errorMessage = 'Error checking status: $e';
          _isProcessing = false;
        });
        break;
      }
    }

    if (attempts >= maxAttempts) {
      setState(() {
        _errorMessage = 'Processing timed out. Please try again.';
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
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
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
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
              style: const TextStyle(
                color: AppTheme.gray600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _buildContent(),
            ),

            // Actions
            const SizedBox(height: 24),
            if (!_isProcessing && _resultImageBytes == null) ...[
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library),
                label: Text(_selectedPersonImage == null
                    ? 'Select Your Photo'
                    : 'Change Photo'),
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
                    gradient: AppTheme.purplePinkGradient,
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
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.red500,
            ),
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This may take 1-2 minutes',
              style: TextStyle(
                color: AppTheme.gray600,
                fontSize: 14,
              ),
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
              child: Image.memory(
                _resultImageBytes!,
                fit: BoxFit.contain,
              ),
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
                      _resultImageBytes = null;
                      _result = null;
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
                    backgroundColor: AppTheme.purple600,
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
        child: Image.file(
          _selectedPersonImage!,
          fit: BoxFit.contain,
        ),
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
              color: AppTheme.purple600.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              size: 64,
              color: AppTheme.purple600,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Upload Your Photo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Take or select a full-body photo\nfor the best results',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.gray600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
