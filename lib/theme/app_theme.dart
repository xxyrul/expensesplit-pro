import 'package:flutter/material.dart';

import 'expressive_theme.dart';

/// Legacy entry point — prefer [ExpressiveTheme.light] / [ExpressiveTheme.dark].
class AppTheme {
  static ThemeData get lightTheme => ExpressiveTheme.light();

  static ThemeData get darkTheme => ExpressiveTheme.dark();
}
