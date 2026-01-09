import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_app/services/virtual_tryon_service.dart';
import 'package:fyp_app/models/tryon_result.dart';

void main() {
  group('VirtualTryOnService Tests', () {
    late VirtualTryOnService service;

    setUp(() {
      service = VirtualTryOnService();
    });

    tearDown(() {
      service.dispose();
    });

    test('Service can be instantiated', () {
      expect(service, isNotNull);
    });

    test('Result image URL is correctly formatted', () {
      const sessionId = 'test-session-123';
      final url = service.getResultImageUrl(sessionId);
      expect(url, contains('/api/tryon/result/'));
      expect(url, contains(sessionId));
    });

    test('TryOnResult can be created from JSON', () {
      final json = {
        'success': true,
        'message': 'Processing completed',
        'session_id': 'test-123',
        'result_image_url': '/api/tryon/result/test-123',
        'processing_time': 45.5,
      };

      final result = TryOnResult.fromJson(json);

      expect(result.success, true);
      expect(result.message, 'Processing completed');
      expect(result.sessionId, 'test-123');
      expect(result.resultImageUrl, '/api/tryon/result/test-123');
      expect(result.processingTime, 45.5);
    });

    test('TryOnStatus can be created from JSON', () {
      final json = {
        'status': 'completed',
        'session_id': 'test-456',
        'result_url': '/api/tryon/result/test-456',
      };

      final status = TryOnStatus.fromJson(json);

      expect(status.status, 'completed');
      expect(status.sessionId, 'test-456');
      expect(status.resultUrl, '/api/tryon/result/test-456');
      expect(status.isCompleted, true);
      expect(status.isProcessing, false);
      expect(status.isFailed, false);
    });

    test('TryOnStatus processing state is correct', () {
      final json = {
        'status': 'processing',
        'session_id': 'test-789',
      };

      final status = TryOnStatus.fromJson(json);

      expect(status.isCompleted, false);
      expect(status.isProcessing, true);
      expect(status.isFailed, false);
    });
  });
}
