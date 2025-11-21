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