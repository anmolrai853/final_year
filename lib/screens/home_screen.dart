import 'package:flutter/material.dart';
import 'timetable_page.dart';
import 'planner_page.dart';
import 'settings_page.dart';

class HomeScreen extends StatefulWidget {
  final void Function(ThemeMode) onThemeChanged;
  const HomeScreen({super.key, required this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Map<String, dynamic>> studySessions = [];

  @override
  Widget build(BuildContext context) {
    final pages = [
      TimetablePage(studySessions: studySessions),
      PlannerPage(studySessions: studySessions),
      const MapPage(),
      SettingsPage(onThemeChanged: widget.onThemeChanged),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF0F172A),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today), label: 'Timetable'),
          BottomNavigationBarItem(
              icon: Icon(Icons.school), label: 'Planner'),
          BottomNavigationBarItem(
              icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        title: const Text('Campus Map'),
      ),
      body: const Center(
        child: Text('Map coming soon…',
            style: TextStyle(fontSize: 18, color: Colors.white70)),
      ),
    );
  }
}
