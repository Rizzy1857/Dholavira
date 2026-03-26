import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'theme/app_theme.dart';
import 'screens/build_safe_map.dart';
import 'screens/alerts_screen.dart';
import 'screens/tips_screen.dart';

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
    const PlaceholderScreen(title: 'DTN Mesh SOS (Offline)'),
    const BuildSafeMapScreen(),
    const AlertsScreen(),
    const TipsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.darkText, width: AppTheme.borderWidth)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.wifi_tethering), label: 'SOS Mesh'),
            BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Build Safe'),
            BottomNavigationBarItem(icon: Icon(Icons.warning_amber_rounded), label: 'Alerts'),
            BottomNavigationBarItem(icon: Icon(Icons.eco_outlined), label: 'Tips'),
          ],
        ),
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppTheme.borderWidth),
          child: Container(color: AppTheme.darkText, height: AppTheme.borderWidth),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.secondary,
                border: Border.all(color: AppTheme.darkText, width: AppTheme.borderWidth),
                boxShadow: AppTheme.buildShadow(),
              ),
              child: Text(
                'Coming Soon',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ).animate().fade(duration: 400.ms).scale(curve: Curves.easeOutBack),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Simulate Action'),
            ).animate().shimmer(delay: 1.seconds, duration: 1.5.seconds),
          ],
        ),
      ),
    );
  }
}
