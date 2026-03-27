import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final ApiClient _api = ApiClient();
  bool _loading = false;
  String _message = '';
  bool _sosTriggered = false;
  List<dynamic> _recentSos = [];

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().split('.').first);
  }

  @override
  void initState() {
    super.initState();
    _loadRecentSos();
  }

  Future<void> _loadRecentSos() async {
    try {
      final items = await _api.fetchRecentSos();
      if (mounted) {
        setState(() => _recentSos = items);
      }
    } catch (e) {
      // Silently fail - network might be down
    }
  }

  Future<void> _triggerSos() async {
    setState(() {
      _loading = true;
      _message = '';
    });

    try {
      await _api.triggerCivilianSos(
        emergencyCode: 1,
        gatewayId: 'citizen-app',
        batteryPct: 50,
      );

      if (!mounted) return;

      setState(() {
        _sosTriggered = true;
        _message = 'SOS SENT ✓\n\n'
            'Emergency services have been notified.\n'
            'Your location: [Map coordinates]\n'
            'Status: WAITING FOR RESPONSE\n\n'
            'Stay in a safe location.\n'
            'Keep your phone powered if possible.';
      });

      // Reload recent SOS
      _loadRecentSos();

      // Auto-dismiss after 5 seconds
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _sosTriggered = false;
          _message = '';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'SOS FAILED: ${e.toString()}\n\n'
            'Network may be unavailable.\n'
            'Try again or use alternative communication.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: AppTheme.primary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppTheme.borderWidth),
          child: Container(color: AppTheme.darkText, height: AppTheme.borderWidth),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Big red SOS button
                GestureDetector(
                  onTap: _loading ? null : _triggerSos,
                  child: Container(
                    width: 200,
                    height: 200,
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary,
                      border: Border.all(
                        color: AppTheme.darkText,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SOS',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'TAP TO SEND',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().scale(
                    curve: Curves.elasticOut,
                    duration: 600.ms,
                  ),
                ),
                const SizedBox(height: 40),

                if (_message.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _sosTriggered ? Colors.green : AppTheme.primary,
                      border: Border.all(
                        color: AppTheme.darkText,
                        width: AppTheme.borderWidth,
                      ),
                      boxShadow: AppTheme.buildShadow(),
                    ),
                    child: Text(
                      _message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(),

                if (_recentSos.isNotEmpty) ...[
                  const SizedBox(height: 40),
                  Text(
                    'Recent Emergency Reports',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._recentSos.take(5).map((item) {
                    final sos = (item as Map).cast<String, dynamic>();
                    final ts = _toInt(sos['received_at_unix_ms']);
                    final timestamp = ts != null
                        ? DateTime.fromMillisecondsSinceEpoch(ts).toLocal().toString().split('.').first
                        : 'Unknown time';
                    final latE7 = _toInt(sos['lat_e7']);
                    final lonE7 = _toInt(sos['lon_e7']);
                    final location = (latE7 != null && lonE7 != null)
                        ? '${(latE7 / 1e7).toStringAsFixed(4)}, ${(lonE7 / 1e7).toStringAsFixed(4)}'
                        : 'Unknown location';
                    final status = 'RECEIVED';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        border: Border.all(
                          color: AppTheme.darkText,
                          width: AppTheme.borderWidth,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                status,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 1,
                                ),
                              ),
                              Text(
                                timestamp,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            location,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],

                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary,
                    border: Border.all(
                      color: AppTheme.darkText,
                      width: AppTheme.borderWidth,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How SOS Works',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '• Your location is sent to nearest emergency responders\n'
                        '• Works offline via mesh relay network\n'
                        '• Priority signal even with low battery\n'
                        '• Response time depends on network availability\n'
                        '• Always try traditional emergency services first: 100 (Police), 101 (Fire), 108 (Ambulance)',
                        style: TextStyle(fontSize: 13, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            Container(
              color: Colors.black26,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    border: Border.all(
                      color: AppTheme.darkText,
                      width: AppTheme.borderWidth * 2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: AppTheme.darkText,
                        strokeWidth: 4,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'SENDING SOS...',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
