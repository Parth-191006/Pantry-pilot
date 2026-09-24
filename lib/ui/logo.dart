import 'package:flutter/material.dart';

// ============================================================================
// THE RECIPE PILOT MARK
// ============================================================================
// One artwork, three surfaces: the launcher icon (rendered to PNG at build
// time), the in-app logo badge, and the small app-bar mark. Fully vector —
// crisp at 20 px and at 1024 px, no image assets, works offline forever.
//
// The shape: a **single minimalist leaf** — two arcs meeting at tip and base,
// one vein, one stem. Fresh, quiet, instantly readable at any size.
//
// Two colorways, same geometry:
//  • default — brand-green leaf for light surfaces (app bar, cards);
//  • bright  — warm-white leaf for the deep-green logo plate (splash, icons).
// ============================================================================

/// Bare mark: the leaf, no background plate. App bars and small badges.
/// [bright] switches to the warm-white colorway for dark surfaces.
class RecipePilotMark extends StatelessWidget {
  const RecipePilotMark({super.key, this.size = 32, this.bright = false});

  final double size;

  /// Warm-white leaf — for use on dark green/scrims (hero chips, splash).
  final bool bright;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: RecipePilotMarkPainter(bright: bright),
    );
  }
}

/// Full logo: the bright leaf on its brand-green squircle — the same composite
/// as the launcher icon, so in-app branding matches the phone's home screen.
class RecipePilotLogo extends StatelessWidget {
  const RecipePilotLogo({
    super.key,
    this.size = 96,
    this.glow = false,
  });

  final double size;

  /// Adds a soft outer light — used on the splash screen and in dark mode.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF43A047), Color(0xFF1B5E20), Color(0xFF10331A)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: const Color(0xFF43A047).withValues(alpha: 0.45),
                  blurRadius: size * 0.30,
                  spreadRadius: size * 0.02,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: size * 0.18,
                  offset: Offset(0, size * 0.06),
                ),
              ]
            : null,
      ),
      child: CustomPaint(painter: const RecipePilotMarkPainter(bright: true)),
    );
  }
}

/// Paints the minimalist leaf in a unit square, scaled to the canvas.
class RecipePilotMarkPainter extends CustomPainter {
  const RecipePilotMarkPainter({this.bright = false});

  /// True → warm-white leaf for dark green plates; false → brand-green leaf
  /// for light app surfaces.
  final bool bright;

  // ---- Geometry, all fractions of the shortest side ----------------------
  // The leaf axis runs diagonally (tip up-right, base down-left). The body is
  // two quadratic arcs through tip and base; their controls sit at ±2·halfW
  // along the perpendicular, which lands the arc exactly halfWidth from the
  // axis at the midpoint.
  static const Offset _leafCenter = Offset(0.5, 0.46);
  static const double _leafLength = 0.62;
  static const double _leafHalfWidth = 0.16;
  static const double _stemLength = 0.09;

  // Precomputed unit axis (−55°) so all points below are constants.
  static const Offset _axis = Offset(0.574, -0.819);
  static const Offset _perp = Offset(0.819, 0.574);

  static Offset get _tip =>
      _leafCenter + _axis * (_leafLength / 2);
  static Offset get _base =>
      _leafCenter - _axis * (_leafLength / 2);
  static Offset get _ctrlA =>
      _leafCenter + _perp * (_leafHalfWidth * 2);
  static Offset get _ctrlB =>
      _leafCenter - _perp * (_leafHalfWidth * 2);
  static Offset get _veinCtrl =>
      _leafCenter + _perp * 0.06; // a gentle organic bow

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;

    Offset at(Offset p) => Offset(p.dx * side, p.dy * side);
    final tip = at(_tip);
    final base = at(_base);
    final ctrlA = at(_ctrlA);
    final ctrlB = at(_ctrlB);
    final veinCtrl = at(_veinCtrl);
    final stemEnd = at(_base - _axis * _stemLength);

    // ---- Colors ------------------------------------------------------------
    final Color leafTop;
    final Color leafBottom;
    final Color veinColor;
    if (bright) {
      leafTop = const Color(0xFFFDFBF3);
      leafBottom = const Color(0xFFE3EDD6);
      veinColor = const Color(0xFF1B5E20).withValues(alpha: 0.55);
    } else {
      leafTop = const Color(0xFF66BB6A);
      leafBottom = const Color(0xFF1B5E20);
      veinColor = Colors.white.withValues(alpha: 0.92);
    }

    final Rect leafRect = Rect.fromPoints(
      Offset(base.dx - side * _leafHalfWidth, tip.dy - side * 0.02),
      Offset(tip.dx + side * _leafHalfWidth, stemEnd.dy + side * 0.02),
    );
    final leafShader = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [leafTop, leafBottom],
    ).createShader(leafRect);

    // ---- Stem (part of the silhouette, drawn first) -------------------------
    final stem = Paint()
      ..shader = leafShader
      ..strokeCap = StrokeCap.round
      ..strokeWidth = side * 0.032;
    canvas.drawLine(base, stemEnd, stem);

    // ---- Leaf body: two arcs meeting at tip and base ------------------------
    final body = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(ctrlA.dx, ctrlA.dy, tip.dx, tip.dy)
      ..quadraticBezierTo(ctrlB.dx, ctrlB.dy, base.dx, base.dy)
      ..close();
    canvas.drawPath(body, Paint()..shader = leafShader);

    // ---- Vein ----------------------------------------------------------------
    final vein = Paint()
      ..color = veinColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = side * 0.026;
    final veinPath = Path()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(veinCtrl.dx, veinCtrl.dy, tip.dx, tip.dy);
    canvas.drawPath(veinPath, vein);
  }

  @override
  bool shouldRepaint(covariant RecipePilotMarkPainter oldDelegate) =>
      oldDelegate.bright != bright;
}

/// Reusable brand chip: mark + wordmark, used in the app bar and splash.
class RecipePilotWordmark extends StatelessWidget {
  const RecipePilotWordmark({
    super.key,
    required this.text,
    this.markSize = 24,
    this.style,
    this.spacing = 8,
  });

  final String text;
  final double markSize;
  final TextStyle? style;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RecipePilotMark(size: markSize),
        SizedBox(width: spacing),
        Text(
          text,
          style: style ??
              Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    // Explicit: inside an AppBar this Text replaces the
                    // titleTextStyle, so it must carry the ink colour itself.
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
        ),
      ],
    );
  }
}
