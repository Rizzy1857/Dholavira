import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';
import 'xai_report_screen.dart';

class BuildSafeMapScreen extends StatefulWidget {
  const BuildSafeMapScreen({super.key});

  @override
  State<BuildSafeMapScreen> createState() => _BuildSafeMapScreenState();
}

class _BuildSafeMapScreenState extends State<BuildSafeMapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _selectedLocation;
  bool _isAnalyzing = false;
  final ApiClient _apiClient = ApiClient();

  // Center of Kerala as default
  final LatLng _keralaCenter = const LatLng(10.8505, 76.2711);

  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _selectedLocation = point;
      _isAnalyzing = true;
    });

    // Animate map to the tapped point
    _animatedMapMove(point, 13.0);

    try {
      // Hit the DRI_CA Node.js API
      final result = await _apiClient.checkFeasibility(point.latitude, point.longitude);
      if (mounted) {
        setState(() => _isAnalyzing = false);
        _showFeasibilityResult(point, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.primary),
        );
      }
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(begin: _mapController.camera.center.latitude, end: destLocation.latitude);
    final lngTween = Tween<double>(begin: _mapController.camera.center.longitude, end: destLocation.longitude);
    final zoomTween = Tween<double>(begin: _mapController.camera.zoom, end: destZoom);

    final animationController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    final Animation<double> animation = CurvedAnimation(parent: animationController, curve: Curves.easeInOutCubic);

    animationController.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
        animationController.dispose();
      }
    });

    animationController.forward();
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'none': return Colors.green;
      case 'low': return Colors.yellow.shade700;
      case 'moderate': return Colors.orange;
      case 'high': return AppTheme.primary;
      case 'catastrophic': return AppTheme.darkText;
      default: return AppTheme.darkText;
    }
  }

  void _showFeasibilityResult(LatLng point, Map<String, dynamic> result) {
    final overallRisk = (result['overallRisk'] as String).toUpperCase();
    final riskColor = _getRiskColor(overallRisk);
    final int checkId = result['checkId'] ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.background,
            border: Border.all(color: AppTheme.darkText, width: AppTheme.borderWidth),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'SITE DETECTED',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 2, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Coordinates: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.darkText, width: AppTheme.borderWidth),
                  boxShadow: AppTheme.buildShadow(),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.analytics_outlined, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Overall Risk', style: Theme.of(context).textTheme.bodyMedium),
                          Text(overallRisk, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: riskColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOutQuad),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (checkId > 0) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => XaiReportScreen(
                          checkId: checkId,
                          title: 'Site Analysis',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('VIEW XAI REPORT'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Build Safe'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppTheme.borderWidth),
          child: Container(color: AppTheme.darkText, height: AppTheme.borderWidth),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _keralaCenter,
              initialZoom: 7.0,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.dholavira.echo',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 60,
                      height: 60,
                      alignment: Alignment.topCenter,
                      child: const _AnimatedPin(),
                    ),
                  ],
                ),
            ],
          ),
          if (_selectedLocation == null)
            Positioned(
              top: 24,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.secondary,
                  border: Border.all(color: AppTheme.darkText, width: AppTheme.borderWidth),
                  boxShadow: AppTheme.buildShadow(),
                ),
                child: Text(
                  'Tap anywhere on the map to run a PostGIS Feasibility & XAI Check.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ).animate().fade(duration: 500.ms).slideY(begin: -0.5),
            ),
          if (_isAnalyzing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      border: Border.all(color: AppTheme.darkText, width: AppTheme.borderWidth * 2),
                      boxShadow: AppTheme.buildShadow(AppTheme.primary),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.darkText, strokeWidth: 4),
                        const SizedBox(height: 24),
                        Text(
                          'RUNNING XAI ENGINE',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 200.ms),
            ),
        ],
      ),
    );
  }
}

class _AnimatedPin extends StatelessWidget {
  const _AnimatedPin();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.location_pin,
      color: AppTheme.primary,
      size: 60,
      shadows: [Shadow(color: AppTheme.darkText, blurRadius: 0, offset: Offset(3, 3))],
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .moveY(begin: 0, end: -10, duration: 600.ms, curve: Curves.easeInOut);
  }
}
