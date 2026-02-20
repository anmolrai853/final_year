import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService().init();
  runApp(const SmartStudentApp());
}

class SmartStudentApp extends StatefulWidget {
  const SmartStudentApp({super.key});

  @override
  State<SmartStudentApp> createState() => _SmartStudentAppState();
}

class _SmartStudentAppState extends State<SmartStudentApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final settings = await StorageService().loadSettings();
    setState(() {
      switch (settings['themeMode']) {
        case 'light':  _themeMode = ThemeMode.light;  break;
        case 'system': _themeMode = ThemeMode.system; break;
        default:       _themeMode = ThemeMode.dark;
      }
    });
  }

  void _onThemeChanged(ThemeMode mode) =>
      setState(() => _themeMode = mode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Student Navigator',
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF020617),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF020617),
          foregroundColor: Colors.white,
        ),
      ),
      home: HomeScreen(onThemeChanged: _onThemeChanged),
    );
  }
}
