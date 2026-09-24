import 'dart:math' as math;

import 'package:flutter/material.dart';

// ============================================================================
// THE RECIPE PILOT MARK
// ============================================================================
// One artwork, three surfaces: the launcher icon (rendered to PNG at build
// time), the in-app logo badge, and the small app-bar mark. Fully vector —
// crisp at 20 px and at 1024 px, no image assets, works offline forever.
//
// Story of the shape: an **open recipe book** — ingredient lines on the left
// page, a plated dish on the right — with a **terracotta fork badge** (the
// cooking that follows the reading). No leaf, no tick: this reads as
// "recipes" at a glance.
// ============================================================================

/// Bare mark: open recipe book + fork badge, no background plate. App bar.
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

/// Paints the recipe book + fork badge in a unit square, scaled to the canvas.
class RecipePilotMarkPainter extends CustomPainter {
  const RecipePilotMarkPainter();

  // ---- Geometry, all fractions of the shortest side ----------------------
  // Book: two pages meeting at a center spine, each tilted ±6° like a real
  // open paperback resting on a table.
  static const Offset _bookCenter = Offset(0.455, 0.485);
  static const double _pageWidth = 0.23; // full width of one page
  static const double _pageHeight = 0.215;
  static const double _pageTilt = 6 * math.pi / 180;
  static const double _pageRadius = 0.035;

  // Fork badge: a plated-dish disc overlapping the book's lower right.
  static const Offset _badgeCenter = Offset(0.735, 0.735);
  static const double _badgeRadius = 0.195;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    _paintPages(canvas, side);
    _paintBadge(canvas, side);
  }

  // -------------------------------------------------------------------------
  // Open book: left + right pages (rounded rects, gently tilted), a deep
  // spine between them, ingredient "lines" on the left page and a small
  // plated dish on the right page.
  // -------------------------------------------------------------------------
  void _paintPages(Canvas canvas, double side) {
    final center = Offset(_bookCenter.dx * side, _bookCenter.dy * side);
    final pageW = _pageWidth * side;
    final pageH = _pageHeight * side;
    final radius = _pageRadius * side;

    // Drop shadow under the whole book — lifts it off the green plate.
    final shadow = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center + Offset(0, side * 0.028),
        width: pageW * 2 + side * 0.012,
        height: pageH + side * 0.012,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      shadow,
      Paint()
        ..color = const Color(0xFF06301A).withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.020),
    );

    for (final dir in const [1.0, -1.0]) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(dir * _pageTilt);

      final pageRect = Rect.fromCenter(
        // Pages sit on either side of the spine; a tiny gap reads as the fold.
        center: Offset(dir * (pageW * 0.5 + side * 0.014), 0),
        width: pageW,
        height: pageH,
      );
      final page = RRect.fromRectAndRadius(pageRect, Radius.circular(radius));

      canvas.drawRRect(
        page,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFDFBF3), Color(0xFFEDE4CF)],
          ).createShader(pageRect),
      );
      // Inner edge darkening near the spine — sells the fold.
      final fold = Rect.fromCenter(
        center: Offset(dir * (pageW * 0.38), 0),
        width: pageW * 0.36,
        height: pageH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(fold, Radius.circular(radius)),
        Paint()
          ..shader = LinearGradient(
            begin: dir > 0 ? Alignment.centerLeft : Alignment.centerRight,
            end: dir > 0 ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              Colors.transparent,
              const Color(0xFF8A7A55).withValues(alpha: 0.22),
            ],
          ).createShader(fold),
      );

      // --- Page contents ---------------------------------------------------
      if (dir < 0) {
        // Left page: the ingredient list — three rounded "lines".
        final line = Paint()
          ..color = const Color(0xFF4E9B5A).withValues(alpha: 0.55)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = side * 0.024;
        final widths = [0.115, 0.085, 0.100];
        for (var i = 0; i < widths.length; i++) {
          final y = pageRect.top + pageH * (0.28 + 0.21 * i);
          final w = widths[i] * side;
          final left = pageRect.left + pageW * 0.20;
          canvas.drawLine(Offset(left, y), Offset(left + w, y), line);
        }
      } else {
        // Right page: a plated dish — terracotta circle on a white plate,
        // riding the upper half of the page so the fork badge never covers it.
        final dishCenter = Offset(pageRect.center.dx + pageW * 0.10,
            pageRect.center.dy - pageH * 0.26);
        final dishR = pageH * 0.19;
        canvas.drawCircle(dishCenter, dishR,
            Paint()..color = const Color(0xFFFDFBF3));
        canvas.drawCircle(
          dishCenter,
          dishR * 0.72,
          Paint()
            ..shader = const RadialGradient(colors: [
              Color(0xFFFFB27A),
              Color(0xFFE2571E),
            ]),
        );
        // A second, smaller serving line under the dish.
        final line = Paint()
          ..color = const Color(0xFF4E9B5A).withValues(alpha: 0.45)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = side * 0.020;
        final y = pageRect.top + pageH * 0.76;
        final left = pageRect.left + pageW * 0.24;
        canvas.drawLine(Offset(left, y), Offset(left + pageW * 0.48, y), line);
      }

      canvas.restore();
    }

    // Spine: a deep capsule down the fold, drawn last so it sits on top.
    final spine = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: side * 0.030,
        height: pageH * 1.04,
      ),
      Radius.circular(side * 0.015),
    );
    canvas.drawRRect(spine, Paint()..color = const Color(0xFF10331A));
  }

  // -------------------------------------------------------------------------
  // Badge: terracotta disc with a white fork, ringed in deep green — the
  // "cook it" half of the story, echoing the check-badge position of the
  // old mark so the silhouette stays familiar.
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

    // The fork: three tines fanning from a crossbar into one handle.
    final fork = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = side * 0.026;

    final tineTop = center.dy - radius * 0.52;
    final crossbar = center.dy - radius * 0.18;
    final handleEnd = center.dy + radius * 0.58;
    for (final dx in const [-0.34, 0.0, 0.34]) {
      canvas.drawLine(
        Offset(center.dx + radius * dx, tineTop),
        Offset(center.dx + radius * dx, crossbar + radius * 0.10),
        fork,
      );
    }
    // Crossbar joining the tines…
    canvas.drawLine(
      Offset(center.dx - radius * 0.34, crossbar),
      Offset(center.dx + radius * 0.34, crossbar),
      fork,
    );
    // …then a single handle dropping to the badge edge.
    canvas.drawLine(
      Offset(center.dx, crossbar),
      Offset(center.dx, handleEnd),
      fork,
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
