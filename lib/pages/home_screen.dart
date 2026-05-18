import 'package:flutter/material.dart';
import 'timetable_page.dart';
import 'planner_page.dart';
import 'study_page.dart';
import 'map_page.dart';
import 'settings_page.dart';
import '../navigation_state.dart' as nav;

// Global key so any widget can trigger tab switches and map navigation
final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

class HomeScreen extends StatefulWidget {
  HomeScreen() : super(key: homeScreenKey);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final PageController _pageController;

  // Holds a pending navigation destination for the map page
  nav.MapDestination? _pendingDestination;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Called from anywhere to switch to the map tab and navigate to a destination
  void navigateToMap(nav.MapDestination destination) {
    setState(() {
      _pendingDestination = destination;
      _currentIndex = 3; // Map tab index
    });
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _clearPendingDestination() {
    setState(() {
      _pendingDestination = null;
    });
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const TimetablePage(),
      const PlannerPage(),
      const StudyPage(),
      MapPage(
        pendingDestination: _pendingDestination,
        onDestinationHandled: _clearPendingDestination,
      ),
      const SettingsPage(),
    ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
            backgroundColor: Colors.transparent,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_view_week),
                label: 'Timetable',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.menu_book),
                label: 'Planner',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.psychology),
                label: 'Study',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map),
                label: 'Map',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
