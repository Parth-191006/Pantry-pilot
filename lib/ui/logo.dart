import 'dart:math' as math;

import 'package:flutter/material.dart';

// ============================================================================
// THE RECIPE PILOT MARK
// ============================================================================
// One artwork, three surfaces: the launcher icon (rendered to PNG at build
// time), the in-app logo badge, and the small app-bar mark. Fully vector —
// crisp at 20 px and at 1024 px, no image assets, works offline forever.
//
// Story of the shape: a **leaf** (fresh food, a recipe's raw ingredients)
// with a **terracotta check badge** (the shopping list, ticked off).
// ============================================================================

/// Bare mark: leaf + check badge, no background plate. Used in the app bar.
class RecipePilotMark extends StatelessWidget {
  const RecipePilotMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: const RecipePilotMarkPainter(),
    );
  }
}

/// Full logo: the mark on its brand-green squircle — the same composite as the
/// launcher icon, so in-app branding matches the phone's home screen.
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
      child: CustomPaint(painter: const RecipePilotMarkPainter()),
    );
  }
}

/// Paints the leaf + check badge in a unit square, scaled to the canvas.
class RecipePilotMarkPainter extends CustomPainter {
  const RecipePilotMarkPainter();

  // Leaf geometry (fractions of the shortest side).
  static const double _leafAngle = -38 * math.pi / 180;
  static const Offset _leafCenter = Offset(0.45, 0.41);
  static const double _leafHalfLength = 0.265;
  static const double _leafHalfWidth = 0.155;

  // Check badge geometry.
  static const Offset _badgeCenter = Offset(0.735, 0.725);
  static const double _badgeRadius = 0.208;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    _paintLeaf(canvas, side);
    _paintBadge(canvas, side);
  }

  // -------------------------------------------------------------------------
  // Leaf: a lens built from two quadratic curves, plus a midrib + side veins.
  // -------------------------------------------------------------------------
  void _paintLeaf(Canvas canvas, double side) {
    final axis = Offset(math.cos(_leafAngle), math.sin(_leafAngle));
    // Perpendicular (normal) — screen y grows downward, so this is the
    // "lower-right" direction when the axis points up-right.
    final normal = Offset(-axis.dy, axis.dx);

    final center = Offset(_leafCenter.dx * side, _leafCenter.dy * side);
    final halfLength = _leafHalfLength * side;
    final halfWidth = _leafHalfWidth * side;

    final tipA = center + axis * halfLength;
    final tipB = center - axis * halfLength;
    // Quadratic control points at 2× the target width: the curve's midpoint
    // sits exactly half-way to the control, giving the intended half-width.
    final ctrlA = center + normal * (halfWidth * 2);
    final ctrlB = center - normal * (halfWidth * 2);

    final leaf = Path()
      ..moveTo(tipB.dx, tipB.dy)
      ..quadraticBezierTo(ctrlB.dx, ctrlB.dy, tipA.dx, tipA.dy)
      ..quadraticBezierTo(ctrlA.dx, ctrlA.dy, tipB.dx, tipB.dy)
      ..close();

    // Drop shadow for depth (kept subtle so the mark reads at 20 px).
    canvas.drawPath(
      leaf.shift(Offset(0, side * 0.018)),
      Paint()
        ..color = const Color(0xFF06301A).withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.022),
    );

    canvas.drawPath(
      leaf,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFBFEFA), Color(0xFFD8EBD3)],
        ).createShader(Offset.zero & Size.square(side)),
    );

    // Midrib + three side veins, clipped to the leaf so nothing pokes out.
    canvas.save();
    canvas.clipPath(leaf);
    final vein = Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = side * 0.020;

    final rib = Path()
      ..moveTo((center - axis * (halfLength * 0.84)).dx,
          (center - axis * (halfLength * 0.84)).dy)
      ..lineTo((center + axis * (halfLength * 0.86)).dx,
          (center + axis * (halfLength * 0.86)).dy);
    canvas.drawPath(rib, vein);

    final branchPaint = Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = side * 0.013;

    for (final t in const [-0.42, 0.02, 0.46]) {
      final onAxis = center + axis * (halfLength * t);
      // Lens width at this station (ellipse approximation of the lens).
      final local = halfWidth * math.sqrt(math.max(0.0, 1 - t * t * 0.9));
      for (final dir in const [1.0, -1.0]) {
        final end = onAxis +
            normal * (local * 0.72 * dir) +
            axis * (halfLength * 0.16);
        canvas.drawPath(
          Path()
            ..moveTo(onAxis.dx, onAxis.dy)
            ..lineTo(end.dx, end.dy),
          branchPaint,
        );
      }
    }
    canvas.restore();
  }

  // -------------------------------------------------------------------------
  // Badge: terracotta disc + white check, ringed in deep green so it reads
  // against both the leaf and the logo's green plate.
  // -------------------------------------------------------------------------
  void _paintBadge(Canvas canvas, double side) {
    final center = Offset(_badgeCenter.dx * side, _badgeCenter.dy * side);
    final radius = _badgeRadius * side;

    canvas.drawCircle(
      center,
      radius * 1.11,
      Paint()..color = const Color(0xFF06251A).withValues(alpha: 0.38),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFA56B), Color(0xFFE2571E)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    // Glossy top highlight — tiny detail, big perceived quality.
    canvas.drawCircle(
      center - Offset(0, radius * 0.34),
      radius * 0.62,
      Paint()..color = Colors.white.withValues(alpha: 0.14),
    );

    final check = Path()
      ..moveTo(center.dx - radius * 0.40, center.dy - radius * 0.02)
      ..lineTo(center.dx - radius * 0.10, center.dy + radius * 0.32)
      ..lineTo(center.dx + radius * 0.42, center.dy - radius * 0.34);

    canvas.drawPath(
      check,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.052
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant RecipePilotMarkPainter oldDelegate) => false;
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
