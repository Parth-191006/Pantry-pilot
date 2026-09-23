import 'package:flutter/material.dart';

/// Single-source Material 3 theming. Both modes are generated from one seed
/// color, so light/dark always feel like the same brand. The app never reads
/// `MediaQuery.platformBrightness` directly — it flips a single [ThemeMode].
class AppTheme {
  static const Color seed = Color(0xFF2E7D32); // "Pantry" green

  /// Fresh sage green — success/meter color that reads in both modes.
  static const Color checkGreen = Color(0xFF43A047);

  /// Warm terracotta — appetizing accent for CTAs and small highlights.
  static const Color terracotta = Color(0xFFD84315);

  /// Crisp off-white/cream canvas for light mode.
  static const Color cream = Color(0xFFFAF8F3);

  /// Dark charcoal text/canvas anchor.
  static const Color charcoal = Color(0xFF15171A);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF101410) : cream,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: isDark ? 0.45 : 0.6,
        ),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      // Modern switches: pill track, thumb tints, gentle motion everywhere.
      switchTheme: SwitchThemeData(
        trackHeight: 32 / 14,
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return Colors.grey;
          return states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest;
        }),
      ),
    );
  }
}
