import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/app_theme.dart';

class AiWebViewScreen extends StatefulWidget {
  const AiWebViewScreen({super.key});

  @override
  State<AiWebViewScreen> createState() => _AiWebViewScreenState();
}

class _AiWebViewScreenState extends State<AiWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  String? _error;

  String get _aiUrl {
    if (kIsWeb) return 'http://127.0.0.1:5001';
    if (Platform.isAndroid) return 'http://10.0.2.2:5001';
    return 'http://127.0.0.1:5001';
  }

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() => _progress = progress);
            }
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            setState(() {
              _error = error.description;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(_aiUrl));
  }

  Future<void> _reload() async {
    setState(() {
      _error = null;
      _progress = 0;
    });
    await _controller.loadRequest(Uri.parse(_aiUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Console'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppTheme.borderWidth),
          child: Container(color: AppTheme.darkText, height: AppTheme.borderWidth),
        ),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload AI view',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100)
            LinearProgressIndicator(
              value: _progress / 100,
              color: AppTheme.primary,
              backgroundColor: AppTheme.secondary,
              minHeight: 3,
            ),
          if (_error != null)
            Container(
              width: double.infinity,
              color: AppTheme.primary,
              padding: const EdgeInsets.all(12),
              child: Text(
                'AI view unavailable: $_error\nStart AI service at $_aiUrl and tap refresh.',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
