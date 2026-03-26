import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';

class XaiReportScreen extends StatefulWidget {
  final int checkId;
  final String title;

  const XaiReportScreen({super.key, required this.checkId, required this.title});

  @override
  State<XaiReportScreen> createState() => _XaiReportScreenState();
}

class _XaiReportScreenState extends State<XaiReportScreen> {
  final ApiClient _apiClient = ApiClient();
  Map<String, dynamic>? _report;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    try {
      final res = await _apiClient.fetchXaiReport(widget.checkId);
      if (mounted) {
        setState(() {
          _report = res;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('XAI Remediation Report'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppTheme.borderWidth),
          child: Container(color: AppTheme.darkText, height: AppTheme.borderWidth),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 4),
            const SizedBox(height: 24),
            Text('Generating recommendations...', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          ],
        ).animate().fade(),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              border: Border.all(color: AppTheme.darkText, width: AppTheme.borderWidth),
              boxShadow: AppTheme.buildShadow(),
            ),
            child: Text('ERROR: $_error', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      );
    }

    if (_report == null) return const SizedBox();

    final summary = _report!['summary'] as String;
    final recs = _report!['recommendations'] as List<dynamic>;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.secondary,
            border: Border.all(color: AppTheme.darkText, width: AppTheme.borderWidth),
            boxShadow: AppTheme.buildShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EXECUTIVE SUMMARY', style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(summary, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ).animate().slideX(duration: 400.ms),
        const SizedBox(height: 32),
        Text('RECOMMENDATIONS', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        ...recs.map((rec) => _buildRecommendationCard(rec)).toList().animate(interval: 150.ms).slideY(begin: 0.5, curve: Curves.easeOutQuad).fade(),
      ],
    );
  }

  Widget _buildRecommendationCard(Map<String, dynamic> rec) {
    final title = rec['title']?.toString() ?? 'Recommendation';
    final simplified = rec['simplified']?.toString() ?? 'No simplified explanation available.';
    final hazard = (rec['hazard_type']?.toString() ?? 'SYSTEM').toUpperCase();
    final source = rec['source']?.toString() ?? 'Kerala State Guidelines';
    final confVal = (rec['confidence'] as num?)?.toDouble() ?? 0.85;
    final confidence = (confVal * 100).toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
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
              color: AppTheme.darkText,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(hazard, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Text('$confidence% MATCH', style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Text(simplified, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.darkText, thickness: AppTheme.borderWidth / 2),
                  const SizedBox(height: 8),
                  Text('Source: $source', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
