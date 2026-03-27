import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/api_client.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  final ApiClient _apiClient = ApiClient();
  Map<String, dynamic>? _tipsData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTips();
  }

  Future<void> _loadTips() async {
    try {
      final data = await _apiClient.fetchCurrentTips();
      if (mounted) {
        setState(() {
          _tipsData = data;
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
        title: const Text('Seasonal Tips'),
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

    if (_tipsData == null) {
      return const Center(child: Text('No tips available.'));
    }

    final currentMonthId = _tipsData!['month'] as int;
    final seasonName = _tipsData!['label'] as String;
    final description = _tipsData!['overview'] as String;
    final tips = _tipsData!['tips'] as List<dynamic>;

    final monthMap = {1: 'Jan', 2: 'Feb', 3: 'Mar', 4: 'Apr', 5: 'May', 6: 'Jun', 7: 'Jul', 8: 'Aug', 9: 'Sep', 10: 'Oct', 11: 'Nov', 12: 'Dec'};
    final currentMonth = monthMap[currentMonthId] ?? 'Month';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.secondary,
            border: Border.all(color: AppTheme.darkText, width: AppTheme.borderWidth),
            boxShadow: AppTheme.buildShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SEASON', style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 2, fontWeight: FontWeight.bold)),
                  Text(currentMonth.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 8),
              Text(seasonName.toUpperCase().replaceAll('_', ' '), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: AppTheme.primary)),
              const SizedBox(height: 16),
              Text(description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ).animate().slideY(begin: -0.2).fade(),
        const SizedBox(height: 32),
        Text('SURVIVAL CHECKLIST', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        ...tips.map((tipMap) {
          final tip = tipMap as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.darkText, width: AppTheme.borderWidth),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_box_outlined, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tip['title'] ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text(tip['description'] ?? '', style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList().animate(interval: 100.ms).slideX(begin: 1, curve: Curves.easeOutQuad).fade(),
      ],
    );
  }
}
