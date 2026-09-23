import 'package:flutter/material.dart';

/// Single-source Material 3 theming. Both modes are generated from one seed
/// color, then hand-tuned so light/dark always feel like the same brand:
///
///  • Light: crisp cream canvas, charcoal ink, white cards with a hairline
///    edge — the "recipe card on the kitchen counter" look.
///  • Dark: deep forest-charcoal plates (never pure black), a raised card
///    tone with a visible edge, and a lighter sage primary so meters, pills
///    and glowing icons read like small lamps in a night kitchen.
///
/// The app never reads `MediaQuery.platformBrightness` directly — it flips a
/// single [ThemeMode].
class AppTheme {
  static const Color seed = Color(0xFF2E7D32); // "Recipe Pilot" green

  /// Fresh sage green — success/meter color that reads in both modes.
  static const Color checkGreen = Color(0xFF43A047);

  /// Warm terracotta — appetizing accent for CTAs and small highlights.
  static const Color terracotta = Color(0xFFD84315);

  /// Crisp off-white/cream canvas for light mode.
  static const Color cream = Color(0xFFFAF8F3);

  /// Dark charcoal text/canvas anchor.
  static const Color charcoal = Color(0xFF15171A);

  // ---- Dark mode surfaces (hand-tuned, deliberately green-leaning) ----
  static const Color _darkCanvas = Color(0xFF0B120E);
  static const Color _darkSurfaceLow = Color(0xFF121B15);
  static const Color _darkCard = Color(0xFF19251D);
  static const Color _darkEdge = Color(0xFF2B3D31);
  static const Color _darkInk = Color(0xFFE8F0E8);

  // ---- Light mode surfaces ----
  static const Color _lightCard = Color(0xFFF3F0E7);
  static const Color _lightEdge = Color(0xFFE4DFD1);
  static const Color _lightInk = Color(0xFF1F2421);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ColorScheme _scheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    if (isDark) {
      return base.copyWith(
        surface: _darkCanvas,
        surfaceContainerLow: _darkSurfaceLow,
        surfaceContainerHighest: _darkCard,
        onSurface: _darkInk,
        outlineVariant: _darkEdge,
        primaryContainer: const Color(0xFF1F3D28),
        onPrimaryContainer: const Color(0xFFBAE9C0),
      );
    }
    return base.copyWith(
      surface: cream,
      surfaceContainerLow: const Color(0xFFF6F3EA),
      surfaceContainerHighest: _lightCard,
      onSurface: _lightInk,
      outlineVariant: _lightEdge,
    );
  }

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = _scheme(brightness);

    final cardColor = isDark ? _darkCard : _lightCard;
    final edgeColor = isDark ? _darkEdge : _lightEdge;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? _darkCanvas : cream,
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
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          // Hairline edge: gives dark cards definition without shadows,
          // and keeps light cards from floating on the cream canvas.
          side: BorderSide(color: edgeColor),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        space: 1,
        thickness: 1,
      ),
      // Form fields (the add-recipe studio is field-heavy): filled, rounded,
      // and readable in both modes.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _darkSurfaceLow : Colors.white.withValues(alpha: 0.7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: edgeColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: edgeColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
        ),
        labelStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.65),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF223026) : const Color(0xFF26302A),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
      // Modern switches: pill track, thumb tints, gentle motion everywhere.
      switchTheme: SwitchThemeData(
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
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
