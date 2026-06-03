import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material 3 Expressive theming for ExpenseSplit Pro (mobile).
///
/// On Android 12+ (including Android 16), pass the OS [platformColorScheme]
/// from [DynamicColorBuilder] to follow the system / wallpaper palette.
/// Other platforms use an expressive seed-based fallback.
abstract final class ExpressiveTheme {
  /// Brand fallback when dynamic color is unavailable (iOS, web, older Android).
  /// Brand fallback when dynamic color is unavailable (iOS, web, older Android).
  static const Color seedColor = Color(0xFF115E59);

  static final ColorScheme _darkScheme = const ColorScheme.dark(
    primary: Color(0xFF0D9488), // Teal primary
    onPrimary: Colors.white,
    secondary: Color(0xFFDCAEBA), // Muted pink/purple support
    onSecondary: Color(0xFF4C1D24),
    surface: Color(0xFF090D16), // Dark slate background
    onSurface: Color(0xFFE2E8F0), // Muted off-white text
    surfaceContainer: Color(0xFF131B2E), // Slate cards background
    surfaceContainerHigh: Color(0xFF1E293B), // Higher contrast elements (input fields)
    surfaceContainerHighest: Color(0xFF334155),
    onSurfaceVariant: Color(0xFF94A3B8), // Sleek muted slate text
    outline: Color(0xFF475569),
    outlineVariant: Color(0xFF2C354D), // Sleek outline borders
    error: Color(0xFFEF4444),
    onError: Colors.white,
  );

  static final ColorScheme _lightScheme = const ColorScheme.light(
    primary: Color(0xFF0057C3),
    onPrimary: Colors.white,
    secondary: Color(0xFF006D36),
    onSecondary: Colors.white,
    tertiary: Color(0xFF7D5400),
    onTertiary: Colors.white,
    surface: Color(0xFFFAF9F5),
    onSurface: Color(0xFF1B1C1A),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF4F4F0),
    surfaceContainer: Color(0xFFEFEEEA),
    surfaceContainerHigh: Color(0xFFE9E8E4),
    surfaceContainerHighest: Color(0xFFE3E2DF),
    onSurfaceVariant: Color(0xFF424754),
    outline: Color(0xFF727786),
    outlineVariant: Color(0xFFC2C6D7),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
  );

  static ThemeData light({ColorScheme? platformColorScheme}) =>
      _build(Brightness.light, platformColorScheme: platformColorScheme);

  static ThemeData dark({ColorScheme? platformColorScheme}) =>
      _build(Brightness.dark, platformColorScheme: platformColorScheme);

  static ColorScheme resolveColorScheme(
    Brightness brightness, {
    ColorScheme? platformColorScheme,
  }) {
    if (platformColorScheme != null) {
      return platformColorScheme;
    }
    return brightness == Brightness.dark ? _darkScheme : _lightScheme;
  }

  static ThemeData _build(
    Brightness brightness, {
    ColorScheme? platformColorScheme,
  }) {
    final colorScheme = resolveColorScheme(
      brightness,
      platformColorScheme: platformColorScheme,
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
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(shapes.extraLarge)),
        ),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.medium)),
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onInverseSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(shapes.medium)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.medium),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(shapes.medium),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shapes.full),
            side: BorderSide(color: colorScheme.outline.withOpacity(0.35), width: 1.5),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shapes.full),
            side: BorderSide(color: colorScheme.outline.withOpacity(0.3), width: 1.5),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shapes.full),
            side: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.full)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.large)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onSecondaryContainer, size: 26);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final base = textTheme.labelMedium;
          if (states.contains(WidgetState.selected)) {
            return base?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w700);
          }
          return base?.copyWith(color: colorScheme.onSurfaceVariant);
        }),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.small)),
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: textTheme.labelMedium,
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, thickness: 1),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(shapes.medium)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
      extensions: [
        BrandSurfaces.forScheme(
          colorScheme,
          usesPlatformPalette: platformColorScheme != null,
        ),
      ],
    );
  }

  static TextTheme _textTheme(Brightness brightness, ColorScheme scheme) {
    final base = brightness == Brightness.dark
        ? ThemeData(brightness: Brightness.dark).textTheme
        : ThemeData(brightness: Brightness.light).textTheme;
    final googleTheme = GoogleFonts.plusJakartaSansTextTheme(base);
    return googleTheme.copyWith(
      bodyLarge: googleTheme.bodyLarge?.copyWith(color: scheme.onSurface),
      bodyMedium: googleTheme.bodyMedium?.copyWith(color: scheme.onSurface),
      bodySmall: googleTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      labelLarge: googleTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
      labelMedium: googleTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      labelSmall: googleTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
      titleLarge: googleTheme.titleLarge?.copyWith(color: scheme.onSurface),
      titleMedium: googleTheme.titleMedium?.copyWith(color: scheme.onSurface),
      titleSmall: googleTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
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

/// Brand surfaces derived from the active [ColorScheme] (system or fallback).
class BrandSurfaces extends ThemeExtension<BrandSurfaces> {
  const BrandSurfaces({
    required this.headerGradient,
    required this.accent,
    required this.usesPlatformPalette,
  });

  final LinearGradient headerGradient;
  final Color accent;
  final bool usesPlatformPalette;

  static BrandSurfaces forScheme(
    ColorScheme scheme, {
    bool usesPlatformPalette = false,
  }) {
    final isDark = scheme.brightness == Brightness.dark;
    if (usesPlatformPalette) {
      return BrandSurfaces(
        headerGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  scheme.surface,
                  scheme.surfaceContainerLow,
                  scheme.primary.withOpacity(0.12),
                ]
              : [
                  scheme.primaryContainer,
                  scheme.primary.withOpacity(0.85),
                ],
        ),
        accent: scheme.primary,
        usesPlatformPalette: true,
      );
    }
    return BrandSurfaces(
      headerGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [
                Color(0xFF090D16),
                Color(0xFF131D30),
              ]
            : const [
                Color(0xFF0D9488),
                Color(0xFF0F766E),
              ],
      ),
      accent: scheme.primary,
      usesPlatformPalette: false,
    );
  }

  @override
  BrandSurfaces copyWith({
    LinearGradient? headerGradient,
    Color? accent,
    bool? usesPlatformPalette,
  }) {
    return BrandSurfaces(
      headerGradient: headerGradient ?? this.headerGradient,
      accent: accent ?? this.accent,
      usesPlatformPalette: usesPlatformPalette ?? this.usesPlatformPalette,
    );
  }

  @override
  BrandSurfaces lerp(ThemeExtension<BrandSurfaces>? other, double t) {
    if (other is! BrandSurfaces) return this;
    return t < 0.5 ? this : other;
  }
}
