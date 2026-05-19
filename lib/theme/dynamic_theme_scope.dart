import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'expressive_theme.dart';

/// Wraps the app with Android / Material You dynamic colors when available.
class DynamicThemeScope extends StatelessWidget {
  const DynamicThemeScope({
    super.key,
    required this.builder,
    this.useDynamicColors = true,
  });

  final bool useDynamicColors;
  final Widget Function({
    required ThemeData lightTheme,
    required ThemeData darkTheme,
  }) builder;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightTheme = ExpressiveTheme.light(
          platformColorScheme: useDynamicColors ? lightDynamic : null,
        );
        final darkTheme = ExpressiveTheme.dark(
          platformColorScheme: useDynamicColors ? darkDynamic : null,
        );
        return builder(
          lightTheme: lightTheme,
          darkTheme: darkTheme,
        );
      },
    );
  }
}
