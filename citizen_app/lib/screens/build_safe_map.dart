import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';

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
  String _selectedBuildingType = ApiClient.buildingTypes.first;

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
      // Hit the AI risk assessment endpoint
      final result = await _apiClient.assessLocationRisk(
        latitude: point.latitude,
        longitude: point.longitude,
        buildingType: _selectedBuildingType,
      );
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
      case 'critical': return AppTheme.primary;
      case 'catastrophic': return AppTheme.darkText;
      default: return AppTheme.darkText;
    }
  }

  void _showFeasibilityResult(LatLng point, Map<String, dynamic> result) {
    final floodRisk = result['flood_risk']?.toString() ?? '0.5';
    final landslideRisk = result['landslide_risk']?.toString() ?? '0.5';
    final cycloneRisk = result['cyclone_risk']?.toString() ?? '0.3';
    final buildingType = result['building_type']?.toString() ?? _selectedBuildingType;
    
    // Determine overall risk
    double flood = double.tryParse(floodRisk) ?? 0.5;
    double landslide = double.tryParse(landslideRisk) ?? 0.5;
    double cyclone = double.tryParse(cycloneRisk) ?? 0.3;
    double maxRisk = [flood, landslide, cyclone].reduce((a, b) => a > b ? a : b);
    
    String overallRisk = 'MODERATE';
    if (maxRisk > 0.6) {
      overallRisk = 'CRITICAL';
    } else if (maxRisk > 0.4) {
      overallRisk = 'HIGH';
    } else if (maxRisk < 0.2) {
      overallRisk = 'LOW';
    }
    
    final riskColor = _getRiskColor(overallRisk);

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
                'MULTI-HAZARD ASSESSMENT',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(letterSpacing: 2, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Coordinates: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 24),
              Text(
                'Building Type: ${buildingType.toUpperCase()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.darkText, width: AppTheme.borderWidth),
                  boxShadow: AppTheme.buildShadow(),
                ),
                child: Column(
                  children: [
                    Row(
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
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.water_outlined, color: Colors.blue, size: 28),
                            const SizedBox(height: 6),
                            Text('Flood', style: Theme.of(context).textTheme.bodySmall),
                            Text(floodRisk, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.terrain_outlined, color: Colors.brown, size: 28),
                            const SizedBox(height: 6),
                            Text('Landslide', style: Theme.of(context).textTheme.bodySmall),
                            Text(landslideRisk, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(Icons.cloud_outlined, color: Colors.grey, size: 28),
                            const SizedBox(height: 6),
                            Text('Cyclone', style: Theme.of(context).textTheme.bodySmall),
                            Text(cycloneRisk, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOutQuad),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CLOSE'),
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
        title: const Text('Check Location Safety'),
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
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                  'TAP any location on the map to check if it\'s safe to shelter there',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ).animate().fade(duration: 500.ms).slideY(begin: -0.5),
            ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.darkText, width: AppTheme.borderWidth),
                boxShadow: AppTheme.buildShadow(),
              ),
              child: Text(
                'Checking: ${_selectedBuildingType.toUpperCase()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
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
