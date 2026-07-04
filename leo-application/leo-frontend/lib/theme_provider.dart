import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = true;
  Color _accentColor = const Color(0xFF35A2FF);
  bool _isHighContrast = false;
  bool _isCompactLayout = false;

  bool get isDarkMode => _isDarkMode;
  Color get accentColor => _accentColor;
  bool get isHighContrast => _isHighContrast;
  bool get isCompactLayout => _isCompactLayout;

  Color get scaffoldBg => _isHighContrast
      ? (_isDarkMode ? Colors.black : Colors.white)
      : (_isDarkMode ? const Color(0xFF070D14) : Colors.grey[100]!);
  Color get cardBg => _isDarkMode ? const Color(0xFF0D161F) : Colors.white;
  Color get textColor => _isHighContrast
      ? (_isDarkMode ? Colors.white : Colors.black)
      : (_isDarkMode ? Colors.white : Colors.black87);
  Color get subTextColor => _isHighContrast
      ? (_isDarkMode ? Colors.grey[300]! : Colors.grey[800]!)
      : (_isDarkMode ? const Color(0xFF5A6E85) : Colors.grey[600]!);
  Color get surfaceBg =>
      _isDarkMode ? const Color(0xFF070D14) : Colors.grey[200]!;

  ThemeProvider() {
    _loadSettings();
  }

  // Load saved choices when app starts
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    final colorValue =
        prefs.getInt('accentColor') ?? const Color(0xFF35A2FF).value;
    _accentColor = Color(colorValue);
    _isHighContrast = prefs.getBool('isHighContrast') ?? false;
    _isCompactLayout = prefs.getBool('isCompactLayout') ?? false;
    notifyListeners(); // Tells the app to redraw with saved settings
  }

  // Call this to update and save the dark mode status
  Future<void> toggleDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  // Call this to update and save the accent highlight color
  Future<void> updateAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accentColor', color.value);
  }

  // Call this to update and save the high contrast status
  Future<void> toggleHighContrast(bool value) async {
    _isHighContrast = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isHighContrast', value);
  }

  // Call this to update and save the compact layout status
  Future<void> toggleCompactLayout(bool value) async {
    _isCompactLayout = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isCompactLayout', value);
  }
}
