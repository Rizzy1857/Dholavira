import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'screens/sos_screen.dart';
import 'screens/build_safe_map.dart';
import 'screens/alerts_screen.dart';
import 'screens/tips_screen.dart';
import 'screens/ai_web_view_screen.dart';
import 'widgets/service_status_banner.dart';

void main() {
  runApp(const ProviderScope(child: DholaviraApp()));
}

class DholaviraApp extends StatelessWidget {
  const DholaviraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECHO Citizen App',
      theme: AppTheme.lightTheme,
      home: const MainShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const SosScreen(),
    const BuildSafeMapScreen(),
    const AlertsScreen(),
    const TipsScreen(),
    const AiWebViewScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ServiceStatusBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.darkText, width: AppTheme.borderWidth)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.emergency_outlined), label: 'SOS'),
            BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Build Safe'),
            BottomNavigationBarItem(icon: Icon(Icons.warning_amber_rounded), label: 'Alerts'),
            BottomNavigationBarItem(icon: Icon(Icons.safety_check_outlined), label: 'Safety'),
            BottomNavigationBarItem(icon: Icon(Icons.web), label: 'AI View'),
          ],
        ),
      ),
    );
  }
}
