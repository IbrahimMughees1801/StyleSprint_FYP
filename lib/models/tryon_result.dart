class TryOnResult {
  final bool success;
  final String message;
  final String sessionId;
  final String? resultImageUrl;
  final double? processingTime;

  TryOnResult({
    required this.success,
    required this.message,
    required this.sessionId,
    this.resultImageUrl,
    this.processingTime,
  });

  factory TryOnResult.fromJson(Map<String, dynamic> json) {
    return TryOnResult(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      sessionId: json['session_id'] ?? '',
      resultImageUrl: json['result_image_url'],
      processingTime: json['processing_time']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'session_id': sessionId,
      'result_image_url': resultImageUrl,
      'processing_time': processingTime,
    };
  }
}

class TryOnStatus {
  final String status; // 'processing', 'completed', 'failed'
  final String sessionId;
  final String? resultUrl;

  TryOnStatus({
    required this.status,
    required this.sessionId,
    this.resultUrl,
  });

  factory TryOnStatus.fromJson(Map<String, dynamic> json) {
    return TryOnStatus(
      status: json['status'] ?? 'unknown',
      sessionId: json['session_id'] ?? '',
      resultUrl: json['result_url'],
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isProcessing => status == 'processing';
  bool get isFailed => status == 'failed';
}
