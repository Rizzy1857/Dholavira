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

  static const List<String> _keralaDistricts = [
    'Thiruvananthapuram',
    'Kollam',
    'Pathanamthitta',
    'Alappuzha',
    'Kottayam',
    'Idukki',
    'Ernakulam',
    'Thrissur',
    'Palakkad',
    'Malappuram',
    'Kozhikode',
    'Wayanad',
    'Kannur',
    'Kasaragod',
  ];

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
          _error = null;
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
        onPressed: _openReportAlertForm,
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
        final alert = (_alerts[index] as Map).cast<String, dynamic>();
        final title = alert['title']?.toString() ?? 'Unknown Alert';
        final description = alert['description']?.toString() ?? 'No description provided';
        final type = (alert['alert_type']?.toString() ?? 'general').toUpperCase();
        final district = alert['district']?.toString() ?? 'Unknown District';
        final severity = alert['severity']?.toString() ?? 'info';
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

  Future<void> _openReportAlertForm() async {
    final titleCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    final reportedByCtrl = TextEditingController();
    String selectedType = ApiClient.alertTypes.first;
    String selectedSeverity = ApiClient.alertSeverities[1];
    String selectedDistrict = _keralaDistricts.first;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> submit() async {
              final title = titleCtrl.text.trim();
              final description = descriptionCtrl.text.trim();
              final reporter = reportedByCtrl.text.trim();

              if (title.length < 5 || description.length < 10) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Title/description too short for backend validation.')),
                );
                return;
              }

              setModalState(() => isSubmitting = true);
              try {
                await _apiClient.createAlert(
                  title: title,
                  description: description,
                  alertType: selectedType,
                  severity: selectedSeverity,
                  district: selectedDistrict,
                  reportedBy: reporter.isEmpty ? null : reporter,
                );
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to report alert: $e')),
                  );
                }
              } finally {
                if (ctx.mounted) setModalState(() => isSubmitting = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  border: Border.all(color: AppTheme.darkText, width: AppTheme.borderWidth),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Report Community Alert', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title (min 5 chars)')),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descriptionCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Description (min 10 chars)'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(labelText: 'Alert Type'),
                        items: ApiClient.alertTypes
                            .map((v) => DropdownMenuItem(value: v, child: Text(v.toUpperCase())))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => selectedType = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSeverity,
                        decoration: const InputDecoration(labelText: 'Severity'),
                        items: ApiClient.alertSeverities
                            .map((v) => DropdownMenuItem(value: v, child: Text(v.toUpperCase())))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => selectedSeverity = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: selectedDistrict,
                        decoration: const InputDecoration(labelText: 'District'),
                        items: _keralaDistricts
                            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => selectedDistrict = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: reportedByCtrl, decoration: const InputDecoration(labelText: 'Reporter Name (optional)')),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: isSubmitting ? null : submit,
                        child: Text(isSubmitting ? 'SUBMITTING...' : 'SUBMIT ALERT'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    descriptionCtrl.dispose();
    reportedByCtrl.dispose();

    if (submitted == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert submitted successfully.')),
        );
      }
      await _loadAlerts();
    }
  }
}
