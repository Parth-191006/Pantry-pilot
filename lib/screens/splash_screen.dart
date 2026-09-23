import 'package:flutter/material.dart';

import '../app_info.dart';
import '../ui/animations.dart';
import '../ui/logo.dart';
import 'home_screen.dart';

/// Animated brand splash: deep-kitchen aurora, the logo breathing in on the
/// brand green, the wordmark catching a sweep of light — then a cross-fade
/// into [HomeScreen].
///
/// Pure Flutter (no native splash files needed) — works identically on every
/// platform and with our CI-generated android/ folder.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _pulse;

  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.3, curve: Curves.easeOut),
  );
  late final Animation<double> _logoScale = Tween(begin: 0.55, end: 1.0).animate(
    CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.55, curve: Curves.easeOutBack),
    ),
  );
  late final Animation<double> _nameFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
  );
  late final Animation<double> _taglineFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
  );

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Slow glow pulse — the logo "breathes" while the app boots.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat(reverse: true);

    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_navigated && mounted) {
        _navigated = true;
        Navigator.of(context).pushReplacement(_fadeRoute());
      }
    });
    _c.forward();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1D5C2B), Color(0xFF0A2113)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned.fill(
              child: AuroraBackdrop(
                intensity: 0.22,
                colors: [
                  Color(0xFF7BD389),
                  Color(0xFF2E7D32),
                  Color(0xFFE2571E),
                  Color(0xFFF9A825),
                ],
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) => Transform.scale(
                          // Gentle breathing so the mark feels alive.
                          scale: 1.0 + 0.035 * _pulse.value,
                          child: child,
                        ),
                        child: const RecipePilotLogo(size: 112, glow: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  FadeTransition(
                    opacity: _nameFade,
                    child: const ShinyText(
                      text: appName,
                      period: Duration(milliseconds: 2600),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeTransition(
                    opacity: _taglineFade,
                    child: Text(
                      appTagline,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 28,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _taglineFade,
                child: Text(
                  'v$appVersion · offline-first',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Route<void> _fadeRoute() {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (_, __, ___) => const HomeScreen(),
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}
