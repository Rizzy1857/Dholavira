import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late final Dio _dio;
  static const List<String> buildingTypes = [
    'residential',
    'commercial',
    'industrial',
    'institutional',
    'agricultural',
  ];

  static const List<String> alertTypes = [
    'flood',
    'landslide',
    'heavy_rain',
    'cyclone',
    'earthquake',
    'tsunami',
    'dam_release',
    'road_block',
    'evacuation',
    'relief_camp',
    'general',
  ];

  static const List<String> alertSeverities = [
    'info',
    'advisory',
    'warning',
    'critical',
  ];

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

    // Android emulator uses 10.0.2.2 for host machine access.
    String baseUrl = 'http://127.0.0.1:3000';
    
    if (!kIsWeb) {
      if (Platform.isAndroid) {
        baseUrl = 'http://10.0.2.2:3000';
      }
    }

    if (configuredBaseUrl.trim().isNotEmpty) {
      baseUrl = configuredBaseUrl.trim();
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

  T _unwrapData<T>(Response response) {
    final raw = response.data;
    if (raw is! Map<String, dynamic>) {
      throw Exception('Invalid API response format');
    }

    if (raw['success'] == true) {
      return raw['data'] as T;
    }

    final error = raw['error'];
    if (error is Map<String, dynamic>) {
      final message = error['message']?.toString() ?? 'API request failed';
      throw Exception(message);
    }

    throw Exception('API request failed');
  }

  String _mapDioError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final err = data['error'];
      if (err is Map<String, dynamic>) {
        return err['message']?.toString() ?? error.message ?? 'Network error';
      }
    }
    return error.message ?? 'Network error';
  }

  /// POST /feasibility
  /// Runs the PostGIS spatial intersection against the coordinates
  Future<Map<String, dynamic>> checkFeasibility(
    double lat,
    double lng, {
    String buildingType = 'residential',
  }) async {
    try {
      final response = await _dio.post('/api/v1/feasibility', data: {
        'latitude': lat,
        'longitude': lng,
        'buildingType': buildingType,
      });

      return _unwrapData<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  /// POST /remediation
  /// Fetches the XAI Explanations for a given check ID
  Future<Map<String, dynamic>> fetchXaiReport(int checkId) async {
    try {
      final response = await _dio.post('/api/v1/remediation', data: {
        'checkId': checkId,
      });

      return _unwrapData<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> generateRemediation({
    required String buildingType,
    required String overallRisk,
    bool floodRisk = false,
    bool landslideRisk = false,
    bool coastalRisk = false,
    double latitude = 10.8505,
    double longitude = 76.2711,
  }) async {
    try {
      final response = await _dio.post('/api/v1/remediation', data: {
        'latitude': latitude,
        'longitude': longitude,
        'buildingType': buildingType,
        'overallRisk': overallRisk,
        'floodRisk': {
          'found': floodRisk,
          'zones': floodRisk ? [{'risk_level': overallRisk}] : <Map<String, dynamic>>[],
        },
        'landslideRisk': {
          'found': landslideRisk,
          'zones': landslideRisk ? [{'susceptibility_level': overallRisk}] : <Map<String, dynamic>>[],
        },
        'coastalRisk': {
          'found': coastalRisk,
          'zones': coastalRisk ? [{'risk_level': overallRisk}] : <Map<String, dynamic>>[],
        },
      });

      return _unwrapData<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  /// GET /alerts
  /// Fetches paginated community alerts
  Future<List<dynamic>> fetchAlerts({
    int page = 1,
    int limit = 20,
    String? type,
    String? district,
    String? severity,
  }) async {
    try {
      final response = await _dio.get('/api/v1/alerts', queryParameters: {
        'page': page,
        'limit': limit,
        if (type != null && type.isNotEmpty) 'type': type,
        if (district != null && district.isNotEmpty) 'district': district,
        if (severity != null && severity.isNotEmpty) 'severity': severity,
      });

      return _unwrapData<List<dynamic>>(response);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> createAlert({
    required String title,
    required String description,
    required String alertType,
    required String severity,
    required String district,
    double? latitude,
    double? longitude,
    String? reportedBy,
  }) async {
    try {
      final response = await _dio.post('/api/v1/alerts', data: {
        'title': title,
        'description': description,
        'alert_type': alertType,
        'severity': severity,
        'district': district,
        ...?latitude?.let((value) => {'latitude': value}),
        ...?longitude?.let((value) => {'longitude': value}),
        ...?((reportedBy != null && reportedBy.isNotEmpty) ? {'reported_by': reportedBy} : null),
      });

      return _unwrapData<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> verifyAlert(int alertId) async {
    try {
      final response = await _dio.patch('/api/v1/alerts/$alertId/verify');
      return _unwrapData<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  /// GET /tips/current
  /// Fetches actionable seasonal awareness tips
  Future<Map<String, dynamic>> fetchCurrentTips() async {
    try {
      final response = await _dio.get('/api/v1/tips/current');

      return _unwrapData<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<List<dynamic>> fetchTipSeasons() async {
    try {
      final response = await _dio.get('/api/v1/tips/seasons');
      return _unwrapData<List<dynamic>>(response);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> fetchTipsBySeason(String seasonKey) async {
    try {
      final response = await _dio.get('/api/v1/tips/$seasonKey');
      return _unwrapData<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> fetchZonesStats() async {
    try {
      final response = await _dio.get('/api/v1/zones/stats');
      return _unwrapData<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> simplifyText(String text) async {
    try {
      final response = await _dio.post('/api/v1/simplify', data: {'text': text});
      return _unwrapData<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> translateText({
    required String text,
    String sourceLang = 'en',
    String targetLang = 'ml',
  }) async {
    try {
      final response = await _dio.post('/api/v1/translate', data: {
        'text': text,
        'sourceLang': sourceLang,
        'targetLang': targetLang,
      });
      return _unwrapData<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> ttsText({
    required String text,
    String lang = 'ml',
    String gender = 'female',
  }) async {
    try {
      final response = await _dio.post('/api/v1/translate/tts', data: {
        'text': text,
        'lang': lang,
        'gender': gender,
      });
      return _unwrapData<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> fetchSupportedLanguages() async {
    try {
      final response = await _dio.get('/api/v1/translate/languages');
      return _unwrapData<Map<String, dynamic>>(response);
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await _dio.get('/healthz');
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw Exception('Invalid health response');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> ingestSos({
    required String payloadB64,
    required String pubkeyB64,
    required String sigB64,
    int? rssi,
    String? gatewayId,
  }) async {
    try {
      final response = await _dio.post('/v1/ingest/sos', data: {
        'payload_b64': payloadB64,
        'pubkey_b64': pubkeyB64,
        'sig_b64': sigB64,
        ...?rssi?.let((value) => {'rssi': value}),
        ...?((gatewayId != null && gatewayId.isNotEmpty) ? {'gateway_id': gatewayId} : null),
      });
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw Exception('Invalid SOS response');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> triggerCivilianSos({
    double? lat,
    double? lon,
    int emergencyCode = 1,
    String gatewayId = 'citizen-app',
    int batteryPct = 50,
  }) async {
    try {
      final response = await _dio.post('/v1/sos/panic', data: {
        ...?(lat?.let((value) => {'lat': value})),
        ...?(lon?.let((value) => {'lon': value})),
        'emergency_code': emergencyCode,
        'gateway_id': gatewayId,
        'battery_pct': batteryPct,
      });
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw Exception('Invalid panic SOS response');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<List<dynamic>> fetchRecentSos({int? sinceUnixMs}) async {
    try {
      final response = await _dio.get('/v1/sos/recent', queryParameters: {
        ...?sinceUnixMs?.let((value) => {'since': value}),
      });
      final data = response.data;
      if (data is Map<String, dynamic> && data['items'] is List<dynamic>) {
        return data['items'] as List<dynamic>;
      }
      throw Exception('Invalid recent SOS response');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> fetchDeviceBatteryState(String deviceId) async {
    try {
      final encoded = Uri.encodeComponent(deviceId);
      final response = await _dio.get('/v1/device/battery/$encoded');
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw Exception('Invalid battery state response');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> fetchOptimizeConfig(String powerState) async {
    try {
      final response = await _dio.get('/v1/optimize/config', queryParameters: {
        'power_state': powerState,
      });
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw Exception('Invalid optimize config response');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> fetchBatteryStats({
    required String deviceId,
    int hours = 24,
  }) async {
    try {
      final response = await _dio.get('/v1/stats/battery', queryParameters: {
        'device_id': deviceId,
        'hours': hours,
      });
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw Exception('Invalid battery stats response');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> fetchNetworkBatteryStatus() async {
    try {
      final response = await _dio.get('/v1/admin/battery-status');
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw Exception('Invalid battery status response');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> recordBatteryStats({
    required String deviceId,
    required num batteryPct,
    num messagesSuppressed = 0,
    num messagesForwarded = 0,
    num powerSavedPct = 0,
  }) async {
    try {
      final response = await _dio.post('/v1/stats/battery/record', data: {
        'device_id': deviceId,
        'battery_pct': batteryPct,
        'messages_suppressed': messagesSuppressed,
        'messages_forwarded': messagesForwarded,
        'power_saved_pct': powerSavedPct,
      });
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw Exception('Invalid battery record response');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> runAllocationV2({
    required List<dynamic> nodes,
    required List<dynamic> edges,
    required List<dynamic> scenarios,
    String mode = 'static',
    int rollingSteps = 1,
    Map<String, dynamic>? hitlOverrides,
  }) async {
    try {
      final response = await _dio.post('/v1/allocate/v2', data: {
        'nodes': nodes,
        'edges': edges,
        'scenarios': scenarios,
        'mode': mode,
        'rolling_steps': rollingSteps,
        ...?hitlOverrides?.let((value) => {'hitl_overrides': value}),
      });
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw Exception('Invalid allocation v2 response');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  Future<Map<String, dynamic>> runAllocationCompare({
    required List<dynamic> nodes,
    required List<dynamic> edges,
    required List<dynamic> scenarios,
    int rollingSteps = 1,
    Map<String, dynamic>? hitlOverrides,
  }) async {
    try {
      final response = await _dio.post('/v1/allocate/compare', data: {
        'nodes': nodes,
        'edges': edges,
        'scenarios': scenarios,
        'rolling_steps': rollingSteps,
        ...?hitlOverrides?.let((value) => {'hitl_overrides': value}),
      });
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      throw Exception('Invalid allocation compare response');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  // ── AI ENDPOINTS ──────────────────────────────────────────────────────
  /// GET /api/v1/ai/risk-assessment
  /// Assess disaster risk for a given location (flood, landslide, cyclone)
  Future<Map<String, dynamic>> assessLocationRisk({
    required double latitude,
    required double longitude,
    String buildingType = 'residential',
  }) async {
    try {
      final response = await _dio.post('/api/v1/ai/risk-assessment', data: {
        'lat': latitude,
        'lon': longitude,
        'building_type': buildingType,
      });
      
      final raw = response.data;
      if (raw is Map<String, dynamic> && raw['success'] == true) {
        return raw['data'] as Map<String, dynamic>? ?? raw;
      }
      return raw as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  /// POST /api/v1/ai/remediation
  /// Generate remediation strategies based on risks and building type
  Future<Map<String, dynamic>> generateRemediationStrategies({
    required String buildingType,
    required double floodRisk,
    required double landslideRisk,
    required double cycloneRisk,
  }) async {
    try {
      final response = await _dio.post('/api/v1/ai/remediation', data: {
        'building_type': buildingType,
        'flood_risk': floodRisk,
        'landslide_risk': landslideRisk,
        'cyclone_risk': cycloneRisk,
      });
      
      final raw = response.data;
      if (raw is Map<String, dynamic> && raw['success'] == true) {
        return raw['data'] as Map<String, dynamic>? ?? raw;
      }
      return raw as Map<String, dynamic>;
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }

  /// POST /api/v1/ai/predict
  /// Full disaster prediction for a location (fallback to local AI if needed)
  Future<Map<String, dynamic>> predictDisasterRisk({
    required double latitude,
    required double longitude,
    String locationName = 'Selected Location',
  }) async {
    try {
      final response = await _dio.post('/api/v1/ai/predict', data: {
        'lat': latitude,
        'lon': longitude,
        'name': locationName,
      });
      
      final raw = response.data;
      if (raw is Map<String, dynamic>) return raw;
      throw Exception('Invalid prediction response');
    } on DioException catch (e) {
      throw Exception(_mapDioError(e));
    }
  }
}

extension _NullableMapEntry<T> on T? {
  R? let<R>(R Function(T value) mapper) {
    final self = this;
    if (self == null) return null;
    return mapper(self);
  }
}
