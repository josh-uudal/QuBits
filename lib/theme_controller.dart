import 'package:flutter/material.dart';

class ThemeController {
  static final ValueNotifier<ThemeMode> themeMode =
  ValueNotifier(ThemeMode.system);

  static void setTheme(ThemeMode mode) {
    themeMode.value = mode;
  }
}
