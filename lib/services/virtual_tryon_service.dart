import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/tryon_result.dart';

class VirtualTryOnService {
  // Update this to your backend server URL
  // For local development: http://localhost:8000
  // For production: https://your-backend-domain.com
  static const String baseUrl = 'http://localhost:8000';
  
  final http.Client _client = http.Client();
  final _uuid = const Uuid();

  /// Upload person and clothing images as files
  Future<TryOnResult> uploadImages({
    required File personImage,
    required File clothImage,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/tryon/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add person image
      request.files.add(await http.MultipartFile.fromPath(
        'person_image',
        personImage.path,
      ));

      // Add cloth image
      request.files.add(await http.MultipartFile.fromPath(
        'cloth_image',
        clothImage.path,
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TryOnResult.fromJson(data);
      } else {
        throw Exception('Failed to process images: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error uploading images: $e');
    }
  }

  /// Process images using base64 encoding (alternative method)
  Future<TryOnResult> processBase64Images({
    required Uint8List personImageBytes,
    required Uint8List clothImageBytes,
  }) async {
    try {
      final sessionId = _uuid.v4();
      final uri = Uri.parse('$baseUrl/api/tryon/process-base64');

      final personBase64 = base64Encode(personImageBytes);
      final clothBase64 = base64Encode(clothImageBytes);

      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': sessionId,
          'person_image_base64': personBase64,
          'cloth_image_base64': clothBase64,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TryOnResult.fromJson(data);
      } else {
        throw Exception('Failed to process images: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error processing images: $e');
    }
  }

  /// Check the status of a try-on session
  Future<TryOnStatus> checkStatus(String sessionId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/tryon/status/$sessionId');
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TryOnStatus.fromJson(data);
      } else {
        throw Exception('Failed to check status: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error checking status: $e');
    }
  }

  /// Get the result image as bytes
  Future<Uint8List> getResultImage(String sessionId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/tryon/result/$sessionId');
      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to get result image: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting result image: $e');
    }
  }

  /// Get the full URL for a result image
  String getResultImageUrl(String sessionId) {
    return '$baseUrl/api/tryon/result/$sessionId';
  }

  /// Clean up session data on the server
  Future<void> cleanupSession(String sessionId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/tryon/cleanup/$sessionId');
      await _client.delete(uri);
    } catch (e) {
      print('Error cleaning up session: $e');
    }
  }

  /// Check if the backend server is available
  Future<bool> isServerAvailable() async {
    try {
      final uri = Uri.parse('$baseUrl/');
      final response = await _client.get(uri).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}
