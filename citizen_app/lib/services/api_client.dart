import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late final Dio _dio;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    // 10.0.2.2 is the special alias for Android Emulators to hit the host machine.
    // Web and Desktop (Windows/Mac/Linux) can just use localhost.
    String baseUrl = 'http://127.0.0.1:4000/api/v1';
    
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        baseUrl = 'http://10.0.2.2:4000/api/v1';
      }
    }
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Optional: Add logging interceptor for debugging
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  /// POST /feasibility
  /// Runs the PostGIS spatial intersection against the coordinates
  Future<Map<String, dynamic>> checkFeasibility(double lat, double lng, {String buildingType = 'residential'}) async {
    try {
      final response = await _dio.post('/feasibility', data: {
        'latitude': lat,
        'longitude': lng,
        'buildingType': buildingType,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      throw Exception('API returned failure: ${response.data}');
    } on DioException catch (e) {
      throw Exception('Network Error: ${e.message}');
    }
  }

  /// POST /remediation
  /// Fetches the XAI Explanations for a given check ID
  Future<Map<String, dynamic>> fetchXaiReport(int checkId) async {
    try {
      final response = await _dio.post('/remediation', data: {
        'checkId': checkId,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      throw Exception('API returned failure: ${response.data}');
    } on DioException catch (e) {
      throw Exception('Network Error: ${e.message}');
    }
  }

  /// GET /alerts
  /// Fetches paginated community alerts
  Future<List<dynamic>> fetchAlerts({int page = 1, int limit = 20}) async {
    try {
      final response = await _dio.get('/alerts', queryParameters: {
        'page': page,
        'limit': limit,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'] as List<dynamic>;
      }
      throw Exception('API returned failure: ${response.data}');
    } on DioException catch (e) {
      throw Exception('Network Error: ${e.message}');
    }
  }

  /// GET /tips/current
  /// Fetches actionable seasonal awareness tips
  Future<Map<String, dynamic>> fetchCurrentTips() async {
    try {
      final response = await _dio.get('/tips/current');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }
      throw Exception('API returned failure: ${response.data}');
    } on DioException catch (e) {
      throw Exception('Network Error: ${e.message}');
    }
  }
}
