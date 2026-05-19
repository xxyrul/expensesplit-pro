import 'package:flutter/material.dart';

import 'expressive_theme.dart';

extension BrandTheme on BuildContext {
  ColorScheme get appColors => Theme.of(this).colorScheme;

  BrandSurfaces get brandSurfaces =>
      Theme.of(this).extension<BrandSurfaces>() ??
      BrandSurfaces.forScheme(appColors);

  /// Header gradient synced with the active [ColorScheme] (system or fallback).
  LinearGradient get brandHeaderGradient => brandSurfaces.headerGradient;

  bool get usesAndroidSystemPalette => brandSurfaces.usesPlatformPalette;
}
