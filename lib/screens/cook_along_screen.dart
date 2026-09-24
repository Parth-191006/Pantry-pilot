import 'dart:async';

import 'package:clock/clock.dart';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import '../ui/animations.dart';
import '../ui/greeting.dart';
import '../ui/logo.dart';

/// Cook-along mode: one step at a time, huge text you can read from across
/// the kitchen, an optional per-step countdown, and screen keep-awake so the
/// display never sleeps mid-recipe.
///
/// Timer model (deliberately simple, never drifts): one 1 Hz ticker drives
/// everything, and countdowns are wall-clock deadlines captured when the
/// timer starts — pausing can't accumulate drift, and every rebuild within a
/// second renders the same remaining value. Untimed steps show a stopwatch
/// chip that tracks ambient time without demanding any. Completing the last
/// step fires the grocery-list confetti rain.
///
/// [WakelockPlus] only toggles the platform keep-screen-on flag; it is a
/// no-op under `flutter test` (no platform channel).
class CookAlongScreen extends StatefulWidget {
  const CookAlongScreen({super.key, required this.recipe});

  final Recipe recipe;

  /// Whether cook-along makes sense for this recipe (drives the detail CTA).
  static bool availableFor(Recipe recipe) => recipe.steps.isNotEmpty;

  /// Key on the big step text — tests assert on it.
  static const stepKey = ValueKey('cook_step');

  @override
  State<CookAlongScreen> createState() => _CookAlongScreenState();
}

/// Visual state of the countdown on the current step.
enum _TimerMode { idle, running, paused, expired }

class _CookAlongScreenState extends State<CookAlongScreen> {
  int _index = 0;
  bool _finished = false;
  bool _started = false; // the current step's timer has been started once

  // Countdown: a wall-clock end while running, a frozen remainder otherwise.
  DateTime? _countdownEnd;
  Duration _countdownRemaining = Duration.zero;

  // Stopwatch for untimed steps (freezes on pause).
  DateTime? _stopwatchStart;
  Duration _stopwatchElapsed = Duration.zero;

  Timer? _ticker;

  Recipe get recipe => widget.recipe;
  List<RecipeStep> get _steps => recipe.steps;
  RecipeStep get _step => _steps[_index];
  bool get _timed => _step.seconds != null;
  bool get _isLast => _index == _steps.length - 1;
  bool get _timerRunning => _countdownEnd != null || _stopwatchStart != null;

  _TimerMode get _timerMode {
    if (_timerRunning) return _TimerMode.running;
    if (_started && _timed && _countdownRemaining == Duration.zero) {
      return _TimerMode.expired;
    }
    if (_started) return _TimerMode.paused;
    return _TimerMode.idle;
  }

  @override
  void initState() {
    super.initState();
    _resetTimersForStep();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Keep the screen on. The platform channel is unavailable under
      // `flutter test` (MissingPluginException) — swallow it; this is also
      // why catchError, not try/catch: the failure is asynchronous.
      unawaited(WakelockPlus.enable().catchError((Object _) {}));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // Async release — catchError for the same test-environment reason as in
    // initState (a synchronous try/catch cannot catch a Future's error).
    unawaited(WakelockPlus.disable().catchError((Object _) {}));
    super.dispose();
  }

  // ---- Timing -------------------------------------------------------------

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _stopTickerIfIdle() {
    if (!_timerRunning) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  /// The single heartbeat: repaint once per second, and fire the bell exactly
  /// once when a running countdown crosses its deadline.
  void _onTick() {
    if (!mounted) return;
    final end = _countdownEnd;
    if (end != null && clock.now().isBefore(end)) {
      setState(() {}); // repaint remaining time
      return;
    }
    if (end != null) {
      // Countdown just expired: freeze at zero, celebrate once. The ambient
      // stopwatch freezes too — otherwise _timerRunning stays true and the
      // status would keep saying "Cooking…" instead of "Time's up".
      setState(() {
        _countdownEnd = null;
        _countdownRemaining = Duration.zero;
        if (_stopwatchStart != null) {
          _stopwatchElapsed += clock.now().difference(_stopwatchStart!);
          _stopwatchStart = null;
        }
      });
      _stopTickerIfIdle();
      HapticFeedback.heavyImpact();
      _showSnackBar('Time — move on to the next step 🔔');
      return;
    }
    if (_stopwatchStart != null) setState(() {}); // stopwatch repaint
  }

  void _startTimer() {
    setState(() {
      _started = true;
      final now = clock.now();
      if (_timed) {
        // After an expiry, Start re-runs the step's full countdown.
        if (_countdownRemaining == Duration.zero) {
          _countdownRemaining = Duration(seconds: _step.seconds ?? 0);
        }
        _countdownEnd = now.add(_countdownRemaining);
      }
      _stopwatchStart ??= now;
    });
    _startTicker();
  }

  void _pauseTimer() {
    setState(() {
      final now = clock.now();
      final rem = _countdownEnd?.difference(now);
      _countdownRemaining = rem == null || rem.isNegative ? Duration.zero : rem;
      _countdownEnd = null;
      if (_stopwatchStart != null) {
        _stopwatchElapsed += now.difference(_stopwatchStart!);
        _stopwatchStart = null;
      }
    });
    _stopTickerIfIdle();
  }

  /// Entering a step resets all timer state: a fresh (paused) countdown at
  /// the step's full duration. Untimed steps start their ambient stopwatch
  /// immediately — it ticks on its own and never demands attention.
  void _resetTimersForStep() {
    _countdownRemaining = Duration(seconds: _step.seconds ?? 0);
    _countdownEnd = null;
    _stopwatchStart = null;
    _stopwatchElapsed = Duration.zero;
    _started = false;
    if (!_timed) {
      _stopwatchStart = clock.now();
      _started = true;
      _startTicker();
    } else {
      _stopTickerIfIdle();
    }
  }

  void _finish() {
    // The done view is static — stop the heartbeat so nothing is left running.
    _ticker?.cancel();
    _ticker = null;
    HapticFeedback.mediumImpact();
    setState(() => _finished = true);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ---- Derived ------------------------------------------------------------

  Duration get _remaining {
    final end = _countdownEnd;
    if (end != null) {
      final d = end.difference(clock.now());
      return d.isNegative ? Duration.zero : d;
    }
    return _countdownRemaining;
  }

  Duration get _elapsed {
    final start = _stopwatchStart;
    if (start != null) {
      return _stopwatchElapsed + clock.now().difference(start);
    }
    return _stopwatchElapsed;
  }

  // ---- Build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Cook along · ${recipe.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position:
                Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: _finished
            ? _DoneView(
                key: const ValueKey('cook_done'),
                recipeTitle: recipe.title,
                emoji: recipe.emoji,
                totalMinutes: recipe.minutes,
                onExit: () => Navigator.of(context).pop(),
              )
            : _StepView(
                key: ValueKey('step-$_index'),
                step: _step,
                stepNumber: _index + 1,
                totalSteps: _steps.length,
                timed: _timed,
                mode: _timerMode,
                remaining: _remaining,
                elapsed: _elapsed,
                onStartTimer: _startTimer,
                onPauseTimer: _pauseTimer,
                onNext: () {
                  if (_isLast) {
                    _finish();
                  } else {
                    setState(() => _index++);
                    _resetTimersForStep();
                  }
                },
                onBack: _index == 0
                    ? null
                    : () {
                        setState(() => _index--);
                        _resetTimersForStep();
                      },
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One step: progress header, timer ring / stopwatch, big instruction, nav.
// ---------------------------------------------------------------------------

class _StepView extends StatelessWidget {
  const _StepView({
    super.key,
    required this.step,
    required this.stepNumber,
    required this.totalSteps,
    required this.timed,
    required this.mode,
    required this.remaining,
    required this.elapsed,
    required this.onStartTimer,
    required this.onPauseTimer,
    required this.onNext,
    required this.onBack,
  });

  final RecipeStep step;
  final int stepNumber;
  final int totalSteps;
  final bool timed;
  final _TimerMode mode;
  final Duration remaining;
  final Duration elapsed;
  final VoidCallback onStartTimer;
  final VoidCallback onPauseTimer;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProgressHeader(stepNumber: stepNumber, totalSteps: totalSteps),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (timed) ...[
                            _TimerRing(
                              remaining: remaining,
                              total: Duration(seconds: step.seconds ?? 0),
                              mode: mode,
                            ),
                            const SizedBox(height: 20),
                            _TimerControls(
                              mode: mode,
                              onStart: onStartTimer,
                              onPause: onPauseTimer,
                            ),
                          ] else
                            _StopwatchChip(elapsed: elapsed),
                          const SizedBox(height: 28),
                          Text(
                            step.text,
                            key: CookAlongScreen.stepKey,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.displaySmall?.copyWith(
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _NavButtons(
                  onBack: onBack,
                  onNext: onNext,
                  isLast: stepNumber == totalSteps,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress header: "Step 3 of 8" + dot strip + linear meter.
// ---------------------------------------------------------------------------

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.stepNumber, required this.totalSteps});

  final int stepNumber;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dotCount = totalSteps.clamp(0, 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Step $stepNumber of $totalSteps',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
            const Spacer(),
            for (var i = 0; i < dotCount; i++)
              Container(
                width: i == stepNumber - 1 ? 22 : 7,
                height: 7,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: i < stepNumber ? scheme.primary : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressMeter(progress: stepNumber / totalSteps),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Countdown ring.
// ---------------------------------------------------------------------------

class _TimerRing extends StatelessWidget {
  const _TimerRing({
    required this.remaining,
    required this.total,
    required this.mode,
  });

  final Duration remaining;
  final Duration total;
  final _TimerMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fraction = total.inSeconds <= 0
        ? 0.0
        : (1.0 - remaining.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final (label, accent) = switch (mode) {
      _TimerMode.running => ('Cooking…', AppTheme.terracotta),
      _TimerMode.paused => ('Paused', const Color(0xFF5C6BC0)),
      _TimerMode.expired => ("Time's up 🔔", AppTheme.checkGreen),
      _TimerMode.idle => ('Ready to start', const Color(0xFF5C6BC0)),
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(end: fraction),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, v, _) => Container(
        width: 190,
        height: 190,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(190),
              painter: _RingPainter(progress: v, accent: accent),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _fmt(remaining),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const stroke = 10.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accent != accent;
}

// ---------------------------------------------------------------------------
// Play/pause pill under the ring.
// ---------------------------------------------------------------------------

class _TimerControls extends StatelessWidget {
  const _TimerControls({
    required this.mode,
    required this.onStart,
    required this.onPause,
  });

  final _TimerMode mode;
  final VoidCallback onStart;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final (icon, label, action) = switch (mode) {
      _TimerMode.running => (Icons.pause_rounded, 'Pause', onPause),
      _TimerMode.paused => (Icons.play_arrow_rounded, 'Resume', onStart),
      _TimerMode.expired => (Icons.replay_rounded, 'Restart', onStart),
      _TimerMode.idle => (Icons.play_arrow_rounded, 'Start timer', onStart),
    };
    return FilledButton.tonalIcon(
      onPressed: action,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ---------------------------------------------------------------------------
// Untimed steps: a stopwatch chip keeps ambient time without demanding any.
// ---------------------------------------------------------------------------

class _StopwatchChip extends StatelessWidget {
  const _StopwatchChip({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label =
        '${elapsed.inMinutes.toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              fontWeight: FontWeight.w700,
              color: scheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Back / next buttons.
// ---------------------------------------------------------------------------

class _NavButtons extends StatelessWidget {
  const _NavButtons({
    required this.onBack,
    required this.onNext,
    required this.isLast,
  });

  final VoidCallback? onBack;
  final VoidCallback onNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          height: 54,
          width: 54,
          child: OutlinedButton(
            onPressed: onBack,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(color: scheme.outlineVariant),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isLast ? AppTheme.checkGreen : scheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: onNext,
              child: Text(
                isLast ? 'Done cooking 🎉' : 'Next step',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Completion view.
// ---------------------------------------------------------------------------

class _DoneView extends StatelessWidget {
  const _DoneView({
    super.key,
    required this.recipeTitle,
    required this.emoji,
    required this.totalMinutes,
    required this.onExit,
  });

  final String recipeTitle;
  final String emoji;
  final int? totalMinutes;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Stack(
      children: [
        const Positioned.fill(child: SectionConfetti(playing: true)),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const RecipePilotMark(size: 56),
                  const SizedBox(height: 24),
                  Text(emoji, style: const TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  Text(
                    "You're done!",
                    style: theme.textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$recipeTitle is ready to plate'
                    '${totalMinutes != null ? ' — about ${formatMinutes(totalMinutes!)} total' : ''}.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.terracotta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    ),
                    onPressed: onExit,
                    child: const Text(
                      'Back to recipe',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
