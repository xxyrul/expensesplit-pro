import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material 3 Expressive theming for the admin governance dashboard.
abstract final class ExpressiveTheme {
  static const Color seedColor = Color(0xFF4edea3); // Stitch Primary Emerald Green

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = brightness == Brightness.dark 
      ? const ColorScheme.dark(
          primary: Color(0xFF4edea3),
          onPrimary: Color(0xFF003824),
          primaryContainer: Color(0xFF10b981),
          onPrimaryContainer: Color(0xFF00422b),
          secondary: Color(0xFFffb95f),
          onSecondary: Color(0xFF472a00),
          secondaryContainer: Color(0xFFee9800),
          onSecondaryContainer: Color(0xFF5b3800),
          tertiary: Color(0xFFd0bcff),
          onTertiary: Color(0xFF3c0091),
          error: Color(0xFFffb4ab),
          onError: Color(0xFF690005),
          surface: Color(0xFF0b1326), // Stitch bg-surface
          onSurface: Color(0xFFdae2fd),
          surfaceContainerHighest: Color(0xFF2d3449),
          surfaceContainerHigh: Color(0xFF222a3d),
          surfaceContainer: Color(0xFF171f33),
          surfaceContainerLow: Color(0xFF131b2e),
          surfaceContainerLowest: Color(0xFF060e20),
          onSurfaceVariant: Color(0xFFbbcabf),
          outline: Color(0xFF86948a),
          outlineVariant: Color(0xFF3c4a42),
        )
      : ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        );

    final textTheme = _textTheme(brightness, colorScheme);
    final shapes = _shapes();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(
            backgroundColor: colorScheme.surface,
          ),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapes.large),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.extraLarge)),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(colorScheme.surfaceContainerHigh),
        dataRowMinHeight: 52,
        dataRowMaxHeight: 52,
        headingRowHeight: 52,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.medium)),
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onInverseSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(shapes.medium)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.medium),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.medium),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.full)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.full)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.full)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.small)),
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: textTheme.labelMedium,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.secondaryContainer,
        selectedIconTheme: IconThemeData(color: colorScheme.onSecondaryContainer),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        labelType: NavigationRailLabelType.all,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
      extensions: [BrandSurfaces.forScheme(colorScheme)],
    );
  }

  static TextTheme _textTheme(Brightness brightness, ColorScheme scheme) {
    final base = brightness == Brightness.dark
        ? ThemeData(brightness: Brightness.dark).textTheme
        : ThemeData(brightness: Brightness.light).textTheme;
    return GoogleFonts.plusJakartaSansTextTheme(base).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
  }

  static _ExpressiveShapes _shapes() => const _ExpressiveShapes();
}

class _ExpressiveShapes {
  const _ExpressiveShapes();

  double get small => 8;
  double get medium => 12;
  double get large => 16;
  double get extraLarge => 28;
  double get full => 999;
}

class BrandSurfaces extends ThemeExtension<BrandSurfaces> {
  const BrandSurfaces({
    required this.headerGradient,
    required this.accent,
  });

  final LinearGradient headerGradient;
  final Color accent;

  static BrandSurfaces forScheme(ColorScheme scheme) {
    return BrandSurfaces(
      headerGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(scheme.primary.withValues(alpha: 0.85), const Color(0xFF042F2E)),
          scheme.primary,
          scheme.tertiary.withValues(alpha: 0.85),
        ],
      ),
      accent: scheme.primary,
    );
  }

  @override
  BrandSurfaces copyWith({LinearGradient? headerGradient, Color? accent}) {
    return BrandSurfaces(
      headerGradient: headerGradient ?? this.headerGradient,
      accent: accent ?? this.accent,
    );
  }

  @override
  BrandSurfaces lerp(ThemeExtension<BrandSurfaces>? other, double t) {
    if (other is! BrandSurfaces) return this;
    return t < 0.5 ? this : other;
  }
}
