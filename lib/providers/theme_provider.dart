import 'package:flutter/material.dart';
import '../storage/auth_storage.dart';
import '../ui/slide_transition_builder.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final isDarkMode = await AuthStorage.getDarkMode();
    if (isDarkMode != null) {
      _isDarkMode = isDarkMode;
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await AuthStorage.saveDarkMode(_isDarkMode);
    notifyListeners();
  }

  ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF5555FF),
      brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      fontFamily: 'SF Pro',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        displaySmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
        bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          // apply to all platforms
          TargetPlatform.android: const SlideRightPageTransitionsBuilder(),
          TargetPlatform.iOS: const SlideRightPageTransitionsBuilder(),
          TargetPlatform.windows: const SlideRightPageTransitionsBuilder(),
          TargetPlatform.linux: const SlideRightPageTransitionsBuilder(),
          TargetPlatform.macOS: const SlideRightPageTransitionsBuilder(),
        },
      ),
    );
  }
}