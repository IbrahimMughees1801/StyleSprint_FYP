import 'dart:convert';
import 'dart:typed_data';

class SavedTryOn {
  final String sessionId;
  final String productName;
  final String? productImageUrl;
  final String status;
  final int createdAt;
  final int? completedAt;
  final String? resultImageBase64;
  final String? error;

  const SavedTryOn({
    required this.sessionId,
    required this.productName,
    required this.status,
    required this.createdAt,
    this.productImageUrl,
    this.completedAt,
    this.resultImageBase64,
    this.error,
  });

  factory SavedTryOn.fromMap(Map<String, dynamic> map) {
    return SavedTryOn(
      sessionId: map['sessionId'] as String? ?? '',
      productName: map['productName'] as String? ?? 'Try-on',
      productImageUrl: map['productImageUrl'] as String?,
      status: map['status'] as String? ?? 'processing',
      createdAt:
          map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      completedAt: map['completedAt'] as int?,
      resultImageBase64: map['resultImageBase64'] as String?,
      error: map['error'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'productName': productName,
      'productImageUrl': productImageUrl,
      'status': status,
      'createdAt': createdAt,
      'completedAt': completedAt,
      'resultImageBase64': resultImageBase64,
      'error': error,
    };
  }

  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  Uint8List? get resultImageBytes {
    final raw = resultImageBase64;
    if (raw == null || raw.isEmpty) return null;
    return base64Decode(raw);
  }

  SavedTryOn copyWith({
    String? productName,
    String? productImageUrl,
    String? status,
    int? completedAt,
    String? resultImageBase64,
    String? error,
  }) {
    return SavedTryOn(
      sessionId: sessionId,
      productName: productName ?? this.productName,
      productImageUrl: productImageUrl ?? this.productImageUrl,
      status: status ?? this.status,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
      resultImageBase64: resultImageBase64 ?? this.resultImageBase64,
      error: error ?? this.error,
    );
  }
}
