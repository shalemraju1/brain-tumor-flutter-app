import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}

class LoginResponse {
  final int userId;
  final String email;

  LoginResponse({required this.userId, required this.email});
}

class PredictionResponse {
  final Map<String, dynamic> raw;
  final Uint8List? heatmapBytes;

  PredictionResponse({required this.raw, required this.heatmapBytes});
}

class ApiService {
  static const String baseUrl = "https://brain-tumor-api-zg3b.onrender.com";
  static const Duration _requestTimeout = Duration(seconds: 30);

  static Uri buildUri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );
  }

  // Login API wrapper with safe parsing.
  static Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final payload = {'email': email, 'password': password};
      final response = await http
          .post(
            buildUri('/api/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_requestTimeout);

      developer.log('LOGIN RESPONSE [${response.statusCode}]: ${response.body}', name: 'ApiService.login');

      final body = _safeDecode(response.body);
      if (response.statusCode != 200) {
        throw ApiException(_extractError(body, 'Login failed (${response.statusCode})'));
      }

      if (body is! Map) {
        throw ApiException('Unexpected login response format');
      }

      final userId = body['user_id'];
      if (userId is! num) {
        throw ApiException('Missing user_id in login response');
      }

      return LoginResponse(userId: userId.toInt(), email: email.trim());
    } on SocketException {
      throw ApiException('No internet connection. Please check your network and try again.');
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    }
  }

  // Register API wrapper with safe error extraction.
  static Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final payload = {
        'name': username,
        'username': username,
        'email': email,
        'password': password,
      };

      final response = await http
          .post(
            buildUri('/api/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_requestTimeout);

      developer.log('REGISTER RESPONSE [${response.statusCode}]: ${response.body}', name: 'ApiService.register');

      final body = _safeDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return;
      }

      if (response.statusCode == 400) {
        throw ApiException(_extractError(body, 'Invalid input. Please check your details and try again.'));
      }
      if (response.statusCode == 409) {
        throw ApiException(_extractError(body, 'User already exists. Please login instead.'));
      }
      if (response.statusCode >= 500) {
        throw ApiException('Server error. Please try again later.');
      }

      throw ApiException(_extractError(body, 'Registration failed (${response.statusCode})'));
    } on SocketException {
      throw ApiException('No internet connection. Please check your network and try again.');
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    }
  }

  // Predict API wrapper; keeps existing multipart payload and user_id field.
  static Future<PredictionResponse> predict({
    required File image,
    required int userId,
  }) async {
    try {
      final request = http.MultipartRequest('POST', buildUri('/api/predict'));
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      request.fields['user_id'] = userId.toString();

      developer.log('PREDICT REQUEST user_id=$userId file=${image.path}', name: 'ApiService.predict');

      final response = await request.send().timeout(_requestTimeout);
      final responseBody = await response.stream.bytesToString();
      developer.log('PREDICT RESPONSE [${response.statusCode}]: $responseBody', name: 'ApiService.predict');

      final body = _safeDecode(responseBody);

      if (response.statusCode != 200) {
        throw ApiException(_extractError(body, 'Prediction failed (${response.statusCode})'));
      }

      if (body is! Map) {
        throw ApiException('Unexpected prediction response format');
      }

      final parsed = Map<String, dynamic>.from(body);
      Uint8List? heatmap;
      final rawHeatmap = parsed['heatmap'];
      if (rawHeatmap != null) {
        try {
          heatmap = base64Decode(rawHeatmap.toString());
        } catch (_) {
          heatmap = null;
        }
      }

      return PredictionResponse(raw: parsed, heatmapBytes: heatmap);
    } on SocketException {
      throw ApiException('No internet connection. Please check your network and try again.');
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    }
  }

  static Future<List<dynamic>> fetchHistory(int userId) async {
    try {
      final response = await http
          .get(
            buildUri('/api/history', {'user_id': userId}),
          )
          .timeout(_requestTimeout);

      developer.log(
        'HISTORY RESPONSE [${response.statusCode}] user_id=$userId: ${response.body}',
        name: 'ApiService.fetchHistory',
      );

      if (response.statusCode != 200) {
        final error = _extractError(_safeDecode(response.body), 'Failed to load history (${response.statusCode})');
        throw ApiException(error);
      }

      final data = _safeDecode(response.body);
      if (data is List) {
        developer.log('HISTORY DATA user_id=$userId: $data', name: 'ApiService.fetchHistory');
        return data;
      }
      return [];
    } on SocketException {
      throw ApiException('No internet connection. Please check your network and try again.');
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    }
  }

  static Future<List<dynamic>> fetchReports(int userId) async {
    try {
      final response = await http
          .get(
            buildUri('/api/reports', {'user_id': userId}),
          )
          .timeout(_requestTimeout);

      developer.log(
        'REPORTS RESPONSE [${response.statusCode}] user_id=$userId: ${response.body}',
        name: 'ApiService.fetchReports',
      );

      if (response.statusCode != 200) {
        final error = _extractError(_safeDecode(response.body), 'Failed to load reports (${response.statusCode})');
        throw ApiException(error);
      }

      final data = _safeDecode(response.body);
      if (data is List) return data;
      return [];
    } on SocketException {
      throw ApiException('No internet connection. Please check your network and try again.');
    } on TimeoutException {
      throw ApiException('Request timed out. Please try again.');
    }
  }

  static String extractPrediction(Map<String, dynamic> item) {
    return (item['prediction'] ?? item['result'] ?? 'Unknown').toString();
  }

  static double extractConfidence(Map<String, dynamic> item) {
    final value = item['confidence'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static dynamic _safeDecode(String body) {
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  static String _extractError(dynamic decodedBody, String fallback) {
    if (decodedBody is Map && decodedBody['error'] != null) {
      return decodedBody['error'].toString();
    }
    if (decodedBody is String && decodedBody.trim().isNotEmpty) {
      return decodedBody;
    }
    return fallback;
  }
}