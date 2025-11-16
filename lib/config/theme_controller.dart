import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  static final ValueNotifier<Color> seedColor = ValueNotifier<Color>(
    Colors.teal,
  );

  static void toggle() {
    final current = themeMode.value;
    if (current == ThemeMode.system) {
      themeMode.value = ThemeMode.light;
    } else if (current == ThemeMode.light) {
      themeMode.value = ThemeMode.dark;
    } else {
      themeMode.value = ThemeMode.system;
    }
  }

  static void setSeedColor(Color color) {
    seedColor.value = color;
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
}
