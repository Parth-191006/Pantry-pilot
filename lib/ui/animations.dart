import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';

// ============================================================================
// 1. SHARED-AXIS ROUTE — "Recipe View → Grocery List" transition
// ============================================================================
// Material shared-axis pattern: the outgoing screen slides + fades one way,
// the incoming slides + fades the other way, with a small scale settle.
// Zero packages — pure MaterialPageRoute-style PageRouteBuilder.

Route<T> sharedAxisRoute<T>({
  required Widget page,
  bool forward = true,
}) {
  const curve = Cubic(0.2, 0.0, 0.0, 1.0); // emphasized decelerate
  const duration = Duration(milliseconds: 340);

  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: curve, reverseCurve: curve.flipped);
      final slide = Tween<Offset>(
        begin: forward ? const Offset(0, 0.06) : const Offset(-0.06, 0),
        end: Offset.zero,
      ).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: slide,
          child: ScaleTransition(
            scale: Tween(begin: 0.98, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

// ============================================================================
// 2. THE SATISFYING CHECKBOX — tint, pop, confetti micro-burst
// ============================================================================
// One stateful widget orchestrates three feedback channels:
//   • Row background tint + slight dim (AnimatedContainer/Opacity)
//   • Checkbox scale pop (spring-ish curve) + custom checkmark sweep
//   • 5-particle confetti micro-burst behind the checkbox (CustomPainter)
// All driven by a single AnimationController → cheap, 60fps, repaints only
// this row thanks to RepaintBoundary.

class CheckedItemAnimator extends StatefulWidget {
  const CheckedItemAnimator({
    super.key,
    required this.checked,
    required this.child,
  });

  final bool checked;
  final Widget child;

  @override
  State<CheckedItemAnimator> createState() => _CheckedItemAnimatorState();
}

class _CheckedItemAnimatorState extends State<CheckedItemAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: widget.checked ? 1.0 : 0.0,
  );

  @override
  void didUpdateWidget(covariant CheckedItemAnimator old) {
    super.didUpdateWidget(old);
    if (old.checked != widget.checked) {
      if (widget.checked) {
        _controller.forward(from: 0);
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkedBg = theme.colorScheme.primaryContainer.withValues(alpha: 0.45);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return Container(
            decoration: BoxDecoration(
              color: Color.lerp(Colors.transparent, checkedBg, t),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Opacity(
              opacity: 1.0 - (0.45 * t), // dim to 55% as the check lands
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// The checkbox itself: tappable, paints a sweeping Material checkmark and a
/// micro confetti burst exactly when [checked] flips true.
class StrikeCheckbox extends StatefulWidget {
  const StrikeCheckbox({
    super.key,
    required this.checked,
    required this.onChanged,
    this.size = 26,
  });

  final bool checked;
  final VoidCallback onChanged;
  final double size;

  @override
  State<StrikeCheckbox> createState() => _StrikeCheckboxState();
}

class _StrikeCheckboxState extends State<StrikeCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  late final Animation<double> _fill = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _check = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _pop = Tween(begin: 1.0, end: 1.25).animate(
    CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack)),
  );
  late final Animation<double> _confetti = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.05, 0.75, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    if (widget.checked) _c.value = 1; // restored-from-storage items appear settled
  }

  @override
  void didUpdateWidget(covariant StrikeCheckbox old) {
    super.didUpdateWidget(old);
    if (old.checked != widget.checked) {
      if (widget.checked) {
        _c.forward(from: 0);
      } else {
        _c.reverse();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onChanged,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final box = BoxDecoration(
              color: Color.lerp(Colors.transparent, scheme.primary, _fill.value),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.checked ? scheme.primary : scheme.outline,
                width: 2,
              ),
            );
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (_confetti.value > 0 && _confetti.value < 1)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ConfettiBurst(progress: _confetti.value),
                    ),
                  ),
                Transform.scale(
                  scale: _pop.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: box,
                    child: _check.value > 0
                        ? CustomPaint(
                            painter: _CheckmarkPainter(progress: _check.value),
                          )
                        : null,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  _CheckmarkPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Sweep the two segments of the ✓ according to progress.
    final p1 = Offset(size.width * 0.24, size.height * 0.54);
    final p2 = Offset(size.width * 0.44, size.height * 0.74);
    final p3 = Offset(size.width * 0.78, size.height * 0.3);

    final path = Path()..moveTo(p1.dx, p1.dy);
    if (progress <= 0.5) {
      final t = progress / 0.5;
      path.lineTo(p1.dx + (p2.dx - p1.dx) * t, p1.dy + (p2.dy - p1.dy) * t);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final t = (progress - 0.5) / 0.5;
      path.lineTo(p2.dx + (p3.dx - p2.dx) * t, p2.dy + (p3.dy - p2.dy) * t);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) => old.progress != progress;
}

class _ConfettiBurst extends CustomPainter {
  _ConfettiBurst({required this.progress});
  final double progress;

  static const _colors = [
    Color(0xFF43A047), Color(0xFFFBC02D), Color(0xFFE53935),
    Color(0xFF1E88E5), Color(0xFF8E24AA),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint();
    final rand = math.Random(7); // deterministic burst
    for (var i = 0; i < 10; i++) {
      final angle = (i / 10) * 2 * math.pi + rand.nextDouble() * 0.4;
      final dist = 8 + progress * (20 + rand.nextDouble() * 14);
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      paint.color = _colors[i % _colors.length]
          .withValues(alpha: (1 - progress).clamp(0.0, 1.0).toDouble());
      final r = 2.2 * (1 - progress * 0.5);
      canvas.drawCircle(pos, r, paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiBurst old) => old.progress != progress;
}

// ============================================================================
// 3. STRIKETHROUGH TEXT — animates the line drawing across the words
// ============================================================================

class AnimatedStrikeText extends StatelessWidget {
  const AnimatedStrikeText({
    super.key,
    required this.checked,
    required this.text,
    this.style,
  });

  final bool checked;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? Theme.of(context).textTheme.bodyLarge!).copyWith(
      color: checked
          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)
          : Theme.of(context).colorScheme.onSurface,
    );
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      style: base.copyWith(
        decoration: checked ? TextDecoration.lineThrough : TextDecoration.none,
        decorationColor: base.color,
        decorationThickness: 2,
      ),
      child: Text(text),
    );
  }
}

// ============================================================================
// 4. PROGRESS RING — subtle springy tick at 100%
// ============================================================================

class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.progress, this.size = 44});

  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: progress.clamp(0.0, 1.0).toDouble()),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final scheme = Theme.of(context).colorScheme;
        return CustomPaint(
          size: Size.square(size),
          painter: _RingPainter(
            progress: value,
            track: scheme.surfaceContainerHighest,
            color: scheme.primary,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                value >= 0.999 ? '🎉' : '${(value * 100).round()}%',
                key: ValueKey(value >= 0.999),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });

  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.11;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at 12 o'clock
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ============================================================================
// 5. STAGGERED ENTRANCE — sections/items slide in sequence on first build
// ============================================================================

class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.baseDelay = Duration.zero,
  });

  final int index;
  final Widget child;
  final Duration baseDelay;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    // Cancellable timer: the old Future.delayed leaked (its callback still
    // fired after dispose) and left dangling timers under fake_async in
    // widget tests. Cancelling on dispose fixes both.
    _delayTimer = Timer(widget.baseDelay + Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didUpdateWidget(covariant StaggeredEntrance old) {
    super.didUpdateWidget(old);
    // Same index+delay → nothing to do. Different index or delay (reused
    // element in a recycled list slot) → reschedule.
    if (old.index != widget.index || old.baseDelay != widget.baseDelay) {
      _delayTimer?.cancel();
      _delayTimer = Timer(widget.baseDelay + Duration(milliseconds: 60 * widget.index), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(_a),
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// 6. SECTION CONFETTI — big burst when the whole list is complete
// ============================================================================

class SectionConfetti extends StatelessWidget {
  const SectionConfetti({super.key, required this.playing});

  final bool playing;

  @override
  Widget build(BuildContext context) {
    if (!playing) return const SizedBox.shrink();
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1600),
        builder: (context, value, _) => CustomPaint(
          size: MediaQuery.sizeOf(context),
          painter: _RainPainter(progress: value),
        ),
      ),
    );
  }
}

class _RainPainter extends CustomPainter {
  _RainPainter({required this.progress});
  final double progress;

  static const _colors = [
    Color(0xFF43A047), Color(0xFFFBC02D), Color(0xFFE53935),
    Color(0xFF1E88E5), Color(0xFF8E24AA), Color(0xFFFF7043),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rand = math.Random(42);
    for (var i = 0; i < 70; i++) {
      final x = rand.nextDouble() * size.width;
      final startY = -40 - rand.nextDouble() * 160;
      final fall = progress * (size.height + 260);
      final y = startY + fall;
      final sway = math.sin(progress * 8 + i) * 12;
      paint.color = _colors[i % _colors.length]
          .withValues(alpha: (1 - progress).clamp(0.0, 1.0).toDouble());
      canvas.drawCircle(Offset(x + sway, y), 3.0 + rand.nextDouble() * 2.0, paint);
    }
  }

  @override
  bool shouldRepaint(_RainPainter old) => old.progress != progress;
}

/// Small shared widget: colored pill used for item quantities.
class AmountPill extends StatelessWidget {
  const AmountPill({super.key, required this.item});

  final GroceryItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        item.amountLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSecondaryContainer,
            ),
      ),
    );
  }
}

// ============================================================================
// 7. LINEAR PROGRESS METER — the animated ingredient-meter bar
// ============================================================================
// Implicitly animated: every time [progress] changes (a checkbox toggled),
// the fill glides to its new width instead of snapping. Driven by
// TweenAnimationBuilder, so it needs no controller and unchecking reverses
// just as smoothly.

class LinearProgressMeter extends StatelessWidget {
  const LinearProgressMeter({
    super.key,
    required this.progress,
    this.height = 8,
  });

  /// 0..1 — recompute as (checked / total) on every toggle.
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = progress.clamp(0.0, 1.0).toDouble();
    final complete = clamped >= 1.0;

    return TweenAnimationBuilder<double>(
      // begin: null → the first frame jumps straight to the current value;
      // later changes animate from the old value to the new one.
      tween: Tween<double>(end: clamped),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: Stack(
              children: [
                // Track.
                ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: const SizedBox.expand(),
                ),
                // Fill — width animates with [value].
                FractionallySizedBox(
                  widthFactor: value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: complete
                            ? const [AppTheme.checkGreen, Color(0xFF66BB6A)]
                            : [scheme.primary, scheme.primary.withValues(alpha: 0.75)],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// 8. PRESSABLE SCALE — springy press-down micro-interaction for cards/buttons
// ============================================================================

class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// 9. SHINY TEXT — a light sweeps across the words
// ============================================================================
// Hand-rolled Flutter answer to React Bits' "Shiny Text"
// (reactbits.dev/components/shiny-text): a masked gradient travels across the
// glyphs on a loop. One controller, one ShaderMask, zero packages — and because
// the highlight is a shader it costs nothing extra on the raster thread.

class ShinyText extends StatefulWidget {
  const ShinyText({
    super.key,
    required this.text,
    this.style,
    this.shineColor = const Color(0xFFFFE9B0),
    this.period = const Duration(milliseconds: 3400),
  });

  final String text;
  final TextStyle? style;

  /// Color of the travelling highlight — warm cream reads well on dark
  /// imagery; pass a darker tint for light surfaces if needed.
  final Color shineColor;
  final Duration period;

  @override
  State<ShinyText> createState() => _ShinyTextState();
}

class _ShinyTextState extends State<ShinyText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // Sweep during the middle of the cycle and hold off-screen outside it,
        // so the highlight never parks in the middle of a word.
        final t = ((_c.value - 0.18) / 0.64).clamp(0.0, 1.0);
        final x = -2.6 + 3.6 * t;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(x - 0.55, 0),
            end: Alignment(x + 0.55, 0),
            colors: [
              const Color(0x00000000),
              widget.shineColor.withValues(alpha: 0.9),
              const Color(0x00000000),
            ],
          ).createShader(bounds),
          child: child,
        );
      },
      child: Text(widget.text, style: widget.style),
    );
  }
}

// ============================================================================
// 10. COUNT UP — numbers that roll up instead of snapping
// ============================================================================
// React Bits' "Count Up", Flutter flavour: any stat can animate from 0 (or
// from its previous value) with a single implicit tween. No timers, so widget
// tests never see a dangling async gap.

class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final num value;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

// ============================================================================
// 11. BORDER BEAM — a light running around a button's edge
// ============================================================================
// The Flutter equivalent of React Bits' "Border Beam" / conic border: a
// rotating sweep-gradient stroke hugging the child's outline, plus a blurred
// copy behind it so it glows. Used on the primary "New recipe" action.

class BorderBeam extends StatefulWidget {
  const BorderBeam({
    super.key,
    required this.child,
    this.radius = 22,
    this.thickness = 1.8,
    this.inset = 3,
    this.colors = const [
      Color(0x00000000),
      Color(0xFF8BE49B), // sage light
      Color(0xFFFF8A4C), // terracotta light
      Color(0x00000000),
    ],
    this.period = const Duration(milliseconds: 3600),
  });

  final Widget child;
  final double radius;
  final double thickness;

  /// Gap between the beam and the child's edge.
  final double inset;
  final List<Color> colors;
  final Duration period;

  @override
  State<BorderBeam> createState() => _BorderBeamState();
}

class _BorderBeamState extends State<BorderBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => CustomPaint(
          painter: _BeamPainter(
            t: _c.value,
            radius: widget.radius,
            thickness: widget.thickness,
            inset: widget.inset,
            colors: widget.colors,
          ),
          child: child,
        ),
        child: Padding(
          padding: EdgeInsets.all(widget.inset + widget.thickness),
          child: widget.child,
        ),
      ),
    );
  }
}

class _BeamPainter extends CustomPainter {
  _BeamPainter({
    required this.t,
    required this.radius,
    required this.thickness,
    required this.inset,
    required this.colors,
  });

  final double t;
  final double radius;
  final double thickness;
  final double inset;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(inset + thickness / 2),
      Radius.circular(radius),
    );

    final shader = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: colors,
      stops: const [0.0, 0.25, 0.5, 0.75],
      transform: GradientRotation(t * math.pi * 2),
    ).createShader(rect);

    // Halo pass, then the crisp beam on top.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness * 2.4
        ..shader = shader
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_BeamPainter old) =>
      old.t != t || old.colors != colors || old.radius != radius;
}

// ============================================================================
// 12. AURORA BACKDROP — drifting color field behind a hero surface
// ============================================================================
// Inspired by React Bits' "Aurora"/"Gradient Blobs": a handful of blurred
// circles orbiting slowly. Painted once per frame into a RepaintBoundary, so
// it never repaints its siblings.

class AuroraBackdrop extends StatefulWidget {
  const AuroraBackdrop({
    super.key,
    this.colors = const [
      Color(0xFF43A047),
      Color(0xFF1B5E20),
      Color(0xFFE2571E),
      Color(0xFFF9A825),
    ],
    this.intensity = 0.28,
    this.period = const Duration(seconds: 18),
  });

  final List<Color> colors;
  final double intensity;
  final Duration period;

  @override
  State<AuroraBackdrop> createState() => _AuroraBackdropState();
}

class _AuroraBackdropState extends State<AuroraBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _AuroraPainter(
            t: _c.value,
            colors: widget.colors,
            intensity: widget.intensity,
          ),
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t,
    required this.colors,
    required this.intensity,
  });

  final double t;
  final List<Color> colors;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = size.shortestSide;
    for (var i = 0; i < colors.length; i++) {
      final phase = t * 2 * math.pi + i * 1.7;
      final cx = size.width * (0.5 + 0.34 * math.sin(phase + i * 0.4));
      final cy = size.height * (0.5 + 0.28 * math.cos(phase * 0.8 + i));
      final radius = shortest * (0.44 + 0.10 * math.sin(phase * 0.6 + i));
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = colors[i].withValues(alpha: intensity)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, math.max(8, radius * 0.45)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}
