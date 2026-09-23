import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_scope.dart';

/// Glow is the dark-mode signature of Recipe Pilot: icons emit a soft colored
/// halo, tones warm up, and the UI reads like a lit kitchen rather than a grey
/// slab. In light mode the same widgets stay almost flat so the cream canvas
/// keeps its crispness.
///
/// Everything respects **Settings → Glow effects**, so people who prefer calm
/// or are low on battery can switch the halos off in one tap.
bool glowEnabledFor(BuildContext context) =>
    AppScope.maybeOf(context)?.glowEffects ?? true;

/// How strongly a glow should render: full in dark, a whisper in light.
double glowStrengthFor(BuildContext context) {
  if (!glowEnabledFor(context)) return 0;
  return Theme.of(context).brightness == Brightness.dark ? 1.0 : 0.22;
}

/// Icon with a soft colored halo behind it.
class GlowIcon extends StatelessWidget {
  const GlowIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 21,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final strength = glowStrengthFor(context);
    if (strength == 0) return Icon(icon, size: size, color: color);

    final dark = Theme.of(context).brightness == Brightness.dark;
    final glyph = dark ? Color.lerp(color, Colors.white, 0.34)! : color;

    return SizedBox(
      width: size * 1.7,
      height: size * 1.7,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Blurred copy = the halo.
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: size * 0.42,
              sigmaY: size * 0.42,
            ),
            child: Icon(
              icon,
              size: size * 1.3,
              color: color.withValues(alpha: 0.55 * strength),
            ),
          ),
          Icon(icon, size: size, color: glyph),
        ],
      ),
    );
  }
}

/// Emoji variant of [GlowIcon] — used by the grocery aisles, where the icon is
/// a fruit/meat glyph rather than a Material icon.
class GlowEmoji extends StatelessWidget {
  const GlowEmoji({super.key, required this.emoji, this.size = 20});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final strength = glowStrengthFor(context);
    if (strength == 0) return Text(emoji, style: TextStyle(fontSize: size));

    final color = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    return SizedBox(
      width: size * 1.8,
      height: size * 1.8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: size * 0.38,
              sigmaY: size * 0.38,
            ),
            child: Opacity(
              opacity: 0.5 * strength,
              child: Text(emoji, style: TextStyle(fontSize: size * 1.2)),
            ),
          ),
          Text(emoji, style: TextStyle(fontSize: size)),
          // Faint light source behind the emoji so it reads as emissive.
          Container(
            width: size * 1.15,
            height: size * 1.15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.10 * strength),
                  blurRadius: size * 0.7,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Square tile with a colored glyph inside — the row/stat building block used
/// by Settings, the stats strip and the quick-action chips. In dark mode the
/// tile casts a soft colored light, like a small lamp.
class GlowTile extends StatelessWidget {
  const GlowTile({
    super.key,
    required this.color,
    required this.child,
    this.size = 40,
    this.radius = 12,
  });

  final Color color;
  final Widget child;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final strength = glowStrengthFor(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.17 : 0.14),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: color.withValues(alpha: dark ? 0.42 : 0.28),
        ),
        boxShadow: strength == 0
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.42 * strength),
                  blurRadius: 18 * strength,
                  spreadRadius: 0.5,
                ),
                BoxShadow(
                  // Inner-ish lift: a tight halo right at the edge.
                  color: color.withValues(alpha: 0.25 * strength),
                  blurRadius: 6 * strength,
                ),
              ],
      ),
      child: Center(child: child),
    );
  }
}
