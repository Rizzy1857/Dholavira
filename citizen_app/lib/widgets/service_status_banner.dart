import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

class ServiceStatusBanner extends StatefulWidget {
  const ServiceStatusBanner({super.key});

  @override
  State<ServiceStatusBanner> createState() => _ServiceStatusBannerState();
}

class _ServiceStatusBannerState extends State<ServiceStatusBanner> {
  final ApiClient _apiClient = ApiClient();
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
    ),
  );

  Timer? _timer;
  bool _backendUp = false;
  bool _aiUp = false;
  bool _checking = true;

  String get _aiBaseUrl {
    if (kIsWeb) return 'http://127.0.0.1:5001';
    if (Platform.isAndroid) return 'http://10.0.2.2:5001';
    return 'http://127.0.0.1:5001';
  }

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshStatus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dio.close();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final backendFuture = _checkBackend();
    final aiFuture = _checkAi();

    final results = await Future.wait<bool>([backendFuture, aiFuture]);
    if (!mounted) return;

    setState(() {
      _backendUp = results[0];
      _aiUp = results[1];
      _checking = false;
    });
  }

  Future<bool> _checkBackend() async {
    try {
      final health = await _apiClient.getHealth();
      return health['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkAi() async {
    try {
      final response = await _dio.get('$_aiBaseUrl/healthz');
      if (response.statusCode != 200) return false;
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['status'] == 'healthy';
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allUp = _backendUp && _aiUp;
    final bannerColor = _checking
        ? AppTheme.secondary
        : allUp
            ? Colors.green.shade100
            : Colors.orange.shade100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bannerColor,
        border: const Border(
          bottom: BorderSide(color: AppTheme.darkText, width: AppTheme.borderWidth),
        ),
      ),
      child: Row(
        children: [
          _StatusChip(
            label: 'Backend',
            isUp: _backendUp,
            checking: _checking,
          ),
          const SizedBox(width: 8),
          _StatusChip(
            label: 'AI',
            isUp: _aiUp,
            checking: _checking,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _checking
                  ? 'Checking services...'
                  : allUp
                      ? 'All core services online'
                      : 'Some services unavailable',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: _refreshStatus,
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Refresh service status',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.isUp,
    required this.checking,
  });

  final String label;
  final bool isUp;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    final Color bg = checking
        ? Colors.grey.shade200
        : isUp
            ? Colors.green.shade600
            : AppTheme.primary;
    final Color fg = checking ? AppTheme.darkText : Colors.white;

    final String text = checking
        ? '$label: ...'
        : isUp
            ? '$label: UP'
            : '$label: DOWN';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: AppTheme.darkText, width: 2),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
