import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._();

  static const String _themeKey = 'theme_mode';
  static const String _seedColorKey = 'seed_color';

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  // ✅ التعديل هنا: تغيير اللون الافتراضي إلى الأزرق الملكي الغامق (أكثر فخامة)
  // بدلاً من Colors.teal
  static final ValueNotifier<Color> seedColor = ValueNotifier<Color>(
    const Color(0xFF1565C0), // أزرق ملكي
  );

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString(_themeKey) ?? 'system';
    themeMode.value = _themeModeFromString(themeString);

    // استرجاع اللون المحفوظ، أو استخدام الأزرق الملكي كافتراضي
    final colorValue =
        prefs.getInt(_seedColorKey) ?? const Color(0xFF1565C0).toARGB32();
    seedColor.value = Color(colorValue);
  }

  static Future<void> toggle() async {
    final current = themeMode.value;
    ThemeMode nextMode;
    if (current == ThemeMode.system) {
      nextMode = ThemeMode.light;
    } else if (current == ThemeMode.light) {
      nextMode = ThemeMode.dark;
    } else {
      nextMode = ThemeMode.system;
    }
    themeMode.value = nextMode;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _themeModeToString(nextMode));
  }

  static Future<void> setSeedColor(Color color) async {
    seedColor.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seedColorKey, color.toARGB32());
  }

  static IconData iconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  static ThemeMode _themeModeFromString(String theme) {
    switch (theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    return mode.name;
  }
}
