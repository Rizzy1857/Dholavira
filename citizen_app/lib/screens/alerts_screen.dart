import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final ApiClient _apiClient = ApiClient();
  List<dynamic> _alerts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final alerts = await _apiClient.fetchAlerts();
      if (mounted) {
        setState(() {
          _alerts = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'info': return Colors.blue;
      case 'advisory': return Colors.yellow.shade700;
      case 'warning': return Colors.orange;
      case 'critical': return AppTheme.primary;
      default: return AppTheme.darkText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Alerts'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppTheme.borderWidth),
          child: Container(color: AppTheme.darkText, height: AppTheme.borderWidth),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Open Report Incident Form
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report Form Coming Soon')));
        },
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_alert_rounded, color: Colors.white),
        label: const Text('REPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppTheme.darkText, width: AppTheme.borderWidth),
        ),
      ).animate().slideY(begin: 2, curve: Curves.easeOutCubic, delay: 500.ms),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: const CircularProgressIndicator(color: AppTheme.darkText, strokeWidth: 4).animate().fade(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              border: Border.all(color: AppTheme.darkText, width: AppTheme.borderWidth),
            ),
            child: Text('ERROR: $_error', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    if (_alerts.isEmpty) {
      return const Center(child: Text('No active community alerts.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _alerts.length,
      itemBuilder: (context, index) {
        final alert = _alerts[index];
        final title = alert['title'] ?? 'Unknown Alert';
        final description = alert['description'] ?? 'No description provided';
        final type = (alert['alert_type'] as String).toUpperCase();
        final district = alert['district'] ?? 'Unknown District';
        final severity = alert['severity'] ?? 'info';
        final isVerified = alert['is_verified'] == true;
        final color = _getSeverityColor(severity);

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              border: Border.all(color: AppTheme.darkText, width: AppTheme.borderWidth),
              boxShadow: AppTheme.buildShadow(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: color,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        type,
                        style: TextStyle(
                          color: (severity == 'advisory' || severity == 'info') ? AppTheme.darkText : Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      if (isVerified)
                        Row(
                          children: [
                            Icon(Icons.verified, color: (severity == 'advisory' || severity == 'info') ? AppTheme.darkText : Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text('VERIFIED', style: TextStyle(color: (severity == 'advisory' || severity == 'info') ? AppTheme.darkText : Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16),
                          const SizedBox(width: 4),
                          Text(district, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text(description, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().slideX(begin: 1, duration: 400.ms, delay: (index * 100).ms, curve: Curves.easeOutQuad),
        );
      },
    );
  }
}
