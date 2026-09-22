import 'package:flutter/material.dart';

import '../app_info.dart';
import 'home_screen.dart';

/// Animated brand splash: logo scales in on the brand green, name and tagline
/// fade through, then the whole screen cross-fades into [HomeScreen].
///
/// Pure Flutter (no native splash files needed) — works identically on every
/// platform and with our CI-generated android/ folder.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.3, curve: Curves.easeOut),
  );
  late final Animation<double> _logoScale = Tween(begin: 0.5, end: 1.0).animate(
    CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.5, curve: Curves.easeOutBack),
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
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onBrand = scheme.onPrimary;

    return Scaffold(
      backgroundColor: scheme.primary,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo mark: soft circle + leaf, scales in with a bounce.
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: onBrand.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Center(
                        child: Text('🥬', style: TextStyle(fontSize: 48)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FadeTransition(
                  opacity: _nameFade,
                  child: Text(
                    appName,
                    style: TextStyle(
                      color: onBrand,
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: _taglineFade,
                  child: Text(
                    'Recipe → grocery list → done',
                    style: TextStyle(
                      color: onBrand.withValues(alpha: 0.75),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
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
                'v$appVersion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: onBrand.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
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
