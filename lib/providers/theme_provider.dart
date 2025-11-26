import 'package:flutter/material.dart';
import '../storage/auth_storage.dart';
import '../ui/slide_transition_builder.dart';

class ThemeProvider extends ChangeNotifier {
  static const _primaryColor = Color(0xFF264653);
  static const _accentColor = Color(0xFFE9C46A);
  static const _dangerColor = Color(0xFFE76F51);
  static const _successColor = Color(0xFF2A9D8F);

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
    final brightness = _isDarkMode ? Brightness.dark : Brightness.light;
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _primaryColor,
          brightness: brightness,
        ).copyWith(
          primary: _primaryColor,
          secondary: _accentColor,
          tertiary: _successColor,
          error: _dangerColor,
          onSecondary: const Color(0xFF1F1F1F),
        );

    final textTheme =
        const TextTheme(
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
        ).apply(
          bodyColor: isDark ? Colors.white : const Color(0xFF1B262C),
          displayColor: isDark ? Colors.white : const Color(0xFF1B262C),
        );

    final buttonBackgroundColor = isDark ? Colors.white : colorScheme.primary;
    final buttonForegroundColor = isDark
        ? _primaryColor
        : colorScheme.onPrimary;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'Segoe UI',
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0F1B1D)
          : const Color(0xFFF4F5F0),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF162326) : Colors.white,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        centerTitle: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonBackgroundColor,
          foregroundColor: buttonForegroundColor,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: buttonBackgroundColor,
          foregroundColor: buttonForegroundColor,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          side: BorderSide(color: colorScheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF1C2A2E) : Colors.white,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return null;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.secondary,
        thumbColor: colorScheme.secondary,
        overlayColor: colorScheme.secondary.withOpacity(0.1),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: const SlideRightPageTransitionsBuilder(),
          TargetPlatform.iOS: const SlideRightPageTransitionsBuilder(),
          TargetPlatform.windows: const SlideRightPageTransitionsBuilder(),
          TargetPlatform.linux: const SlideRightPageTransitionsBuilder(),
          TargetPlatform.macOS: const SlideRightPageTransitionsBuilder(),
        },
      ),
      textTheme: textTheme,
    );
  }
}
