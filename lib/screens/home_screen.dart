import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_info.dart';
import '../app_scope.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme/app_theme.dart';
import '../ui/animations.dart';
import '../ui/glow.dart';
import '../ui/greeting.dart';
import '../ui/logo.dart';
import 'add_recipe_screen.dart';
import 'grocery_list_screen.dart';
import 'recipe_detail_screen.dart';
import 'settings_screen.dart';

/// Entry screen — the cookbook dashboard.
///
/// Reading order, top to bottom: a photographic hero, the library at a glance,
/// three one-tap actions, a "Ready in 30" carousel, then the filterable shelf
/// itself. Everything below the hero is width-capped so tablets and desktop
/// windows keep a comfortable column instead of stretching.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Comfortable reading width on tablets/desktop; content stays centered.
  static const double _maxContentWidth = 560;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Marks the "Your recipes" header so the hero CTA can scroll to it.
  /// (Keys must live on State — a const constructor's class cannot
  /// initialize non-const fields.)
  final GlobalKey _libraryKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final recipes = app.visibleRecipes;
    final filters = app.availableTags;

    // "Ready in 30": the fast wins, shortest first. Hidden while a filter is
    // active so the filtered shelf is never duplicated above it.
    final quickPicks = app.recipes
        .where((r) => r.minutes != null && r.minutes! <= 30)
        .toList()
      ..sort((a, b) => a.minutes!.compareTo(b.minutes!));
    final showQuickPicks = app.activeTag == AppController.allTag &&
        app.recipes.length > 3 &&
        quickPicks.length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: RecipePilotWordmark(text: appName),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              sharedAxisRoute(page: const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: app.recipes.isEmpty
          ? _EmptyState(onAdd: _openAddRecipe)
          : Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: HomeScreen._maxContentWidth),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                  children: [
                    _HeroCard(onExplore: () => _explorePantry(context)),
                    _StatsStrip(recipes: app.recipes),
                    _QuickActions(
                      onAdd: _openAddRecipe,
                      onSurprise: _surpriseMe,
                      onList: app.hasList ? _openList : null,
                      listProgress: app.hasList
                          ? '${app.checkedCount}/${app.totalCount}'
                          : '',
                    ),
                    if (showQuickPicks) _QuickPicks(recipes: quickPicks.take(6).toList()),
                    _FilterPills(
                      tags: filters,
                      activeTag: app.activeTag,
                      onSelected: app.setActiveTag,
                    ),
                    _SectionTitle(
                      key: _libraryKey,
                      icon: Icons.menu_book_rounded,
                      color: AppTheme.checkGreen,
                      title: 'Your recipes',
                      trailing: _CountBadge(count: recipes.length),
                    ),
                    const SizedBox(height: 10),
                    if (recipes.isEmpty)
                      _NoMatches(tag: app.activeTag, onShowAll: () => app.setActiveTag(null))
                    else
                      for (var i = 0; i < recipes.length; i++)
                        StaggeredEntrance(
                          // Keyed by filter+id so switching pills replays a
                          // fresh slide-up cascade on the new set.
                          key: ValueKey('${app.activeTag}:${recipes[i].id}'),
                          index: i,
                          baseDelay: const Duration(milliseconds: 90),
                          child: _RecipeCard(recipe: recipes[i]),
                        ),
                    const SizedBox(height: 6),
                    _TipCard(onAdd: _openAddRecipe),
                  ],
                ),
              ),
            ),
      floatingActionButton: BorderBeam(
        radius: 22,
        child: FilledButton.icon(
          key: const ValueKey('new_recipe_fab'),
          onPressed: _openAddRecipe,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.terracotta,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('New recipe',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  // ---- Navigation --------------------------------------------------------

  Future<void> _openAddRecipe() async {
    final saved = await Navigator.of(context).push<Recipe>(
      sharedAxisRoute(page: const AddRecipeScreen()),
    );
    if (!mounted || saved == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Saved “${saved.title}”'),
          action: SnackBarAction(
            label: 'Cook it',
            onPressed: () {
              if (!mounted) return;
              Navigator.of(context).push(
                sharedAxisRoute(page: RecipeDetailScreen(recipe: saved)),
              );
            },
          ),
        ),
      );
  }

  void _surpriseMe() {
    final all = context.app.recipes;
    if (all.isEmpty) return;
    final pick = all[math.Random().nextInt(all.length)];
    Navigator.of(context).push(
      sharedAxisRoute(page: RecipeDetailScreen(recipe: pick)),
    );
  }

  void _openList() {
    Navigator.of(context).push(sharedAxisRoute(page: const GroceryListScreen()));
  }

  /// CTA target: scrolls the recipe shelf into view.
  void _explorePantry(BuildContext context) {
    final headerContext = _libraryKey.currentContext;
    if (headerContext != null) {
      Scrollable.ensureVisible(
        headerContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    } else {
      _openAddRecipe();
    }
  }
}

// ---------------------------------------------------------------------------
// Hero: a hand-painted cartoon kitchen scene — sun, hills, a steaming pot and
// a row of smiling-shape vegetables — under a soft scrim, with the greeting,
// shiny tagline and CTA on top. Pure CustomPainter: zero image assets, works
// offline forever, and the palette swaps to a dusk variant in dark mode.
// ---------------------------------------------------------------------------

class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.onExplore});

  final VoidCallback onExplore;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void initState() {
    super.initState();
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = timeGreeting(DateTime.now());
    final dark = theme.brightness == Brightness.dark;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 18),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 212,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // --- The cartoon scene itself (steam drifts, veggies bob) ---
                    CustomPaint(
                      painter: _CartoonKitchenPainter(
                        t: _c.value,
                        dark: dark,
                      ),
                    ),
                    // --- Scrim: bottom-heavy so the text always reads ---
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.45, 1.0],
                          colors: dark
                              ? const [
                                  Colors.black12,
                                  Color(0x660A140E),
                                  Color(0xE60A140E),
                                ]
                              : const [
                                  Colors.black12,
                                  Colors.black26,
                                  Color(0xB3101510),
                                ],
                        ),
                      ),
                    ),
                    // --- Brand chip ---
                    Positioned(
                      left: 18,
                      top: 16,
                      child: Row(
                        children: [
                          const RecipePilotMark(size: 20),
                          const SizedBox(width: 7),
                          Text(
                            appName.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // --- Foreground content ---
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const ShinyText(
                            text: appTagline,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: dark
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.terracotta
                                            .withValues(alpha: 0.45),
                                        blurRadius: 22,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: FilledButton.icon(
                              onPressed: widget.onExplore,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.terracotta,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.shopping_basket_rounded,
                                  size: 18),
                              label: const Text('Browse recipes',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The cartoon kitchen: everything is circles, capsules and arcs so the scene
/// stays crisp at any card width. [t] (0..1, looping) drives the steam rise,
/// the vegetable bob and the sparkle twinkle; [dark] swaps to a night palette.
class _CartoonKitchenPainter extends CustomPainter {
  const _CartoonKitchenPainter({required this.t, required this.dark});

  final double t;
  final bool dark;

  static const _tomato = Color(0xFFE53935);
  static const _tomatoShade = Color(0xFFC62828);
  static const _leaf = Color(0xFF2E7D32);
  static const _leafLight = Color(0xFF66BB6A);
  static const _broccoli = Color(0xFF43A047);
  static const _carrot = Color(0xFFFB8C00);
  static const _eggplant = Color(0xFF8E24AA);
  static const _eggplantShade = Color(0xFF6A1B9A);
  static const _cheese = Color(0xFFFDD835);
  static const _potColor = Color(0xFF37474F);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bob = math.sin(t * 2 * math.pi) * h * 0.012; // gentle veggie bob

    // ---- Sky ----
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0xFF122A1F), Color(0xFF0C1A14)]
              : const [Color(0xFFFFF3D6), Color(0xFFE3F2D9)],
        ).createShader(Offset.zero & size),
    );

    // ---- Sun (day) / moon (night) with a soft halo ----
    final orbC = Offset(w * 0.84, h * 0.20);
    final orbR = h * 0.085;
    canvas.drawCircle(
      orbC,
      orbR * 2.1,
      Paint()
        ..color = (dark ? const Color(0xFFCFD8DC) : const Color(0xFFFFD54F))
            .withValues(alpha: dark ? 0.10 : 0.28),
    );
    canvas.drawCircle(
      orbC,
      orbR,
      Paint()
        ..shader = RadialGradient(colors: dark
                ? const [Color(0xFFF5F5F5), Color(0xFFB0BEC5)]
                : const [Color(0xFFFFE082), Color(0xFFFFB300)])
            .createShader(Rect.fromCircle(center: orbC, radius: orbR)),
    );
    if (dark) {
      // Craters so the night orb reads as a moon.
      final crater = Paint()..color = const Color(0xFF90A4AE).withValues(alpha: 0.5);
      canvas.drawCircle(orbC - Offset(orbR * 0.3, orbR * 0.2), orbR * 0.18, crater);
      canvas.drawCircle(orbC + Offset(orbR * 0.35, orbR * 0.25), orbR * 0.12, crater);
    }

    // ---- Sparkles (twinkle with the loop) ----
    final sparkle = Paint()
      ..color = Colors.white.withValues(alpha: 0.30 + 0.22 * math.sin(t * 2 * math.pi))
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final (x, y, r) in const [(0.14, 0.16, 5.0), (0.30, 0.30, 4.0), (0.62, 0.12, 4.5), (0.72, 0.32, 3.5)]) {
      final c = Offset(x * w, y * h);
      canvas.drawLine(c - Offset(r, 0), c + Offset(r, 0), sparkle);
      canvas.drawLine(c - Offset(0, r), c + Offset(0, r), sparkle);
    }

    // ---- Hills ----
    final backHill = Paint()
      ..color = dark ? const Color(0xFF1E4028) : const Color(0xFFA8D5A2);
    canvas.drawCircle(Offset(w * 0.22, h * 1.28), h * 0.62, backHill);
    final frontHill = Paint()
      ..color = dark ? const Color(0xFF2E5D38) : const Color(0xFF7FC47F);
    canvas.drawCircle(Offset(w * 0.78, h * 1.42), h * 0.72, frontHill);

    // ---- Cheese wedge on the back hill ----
    _cheeseWedge(canvas, Offset(w * 0.09, h * 0.66), h * 0.085);

    // ---- Steaming pot on the front hill (left) ----
    _pot(canvas, Offset(w * 0.20, h * 0.80), w * 0.115, h * 0.155, bob);

    // ---- Vegetable row (right), each bobbing on its own phase ----
    _tomatoVeg(canvas, Offset(w * 0.46, h * 0.87 + bob), h * 0.075);
    _broccoliVeg(canvas, Offset(w * 0.60, h * 0.86 - bob), h * 0.085);
    _carrotVeg(canvas, Offset(w * 0.74, h * 0.88 + bob), h * 0.09);
    _eggplantVeg(canvas, Offset(w * 0.885, h * 0.87 - bob), h * 0.10);
  }

  // ----- Scene pieces ------------------------------------------------------

  void _cheeseWedge(Canvas canvas, Offset tip, double r) {
    final path = Path()
      ..moveTo(tip.dx, tip.dy - r * 0.7)
      ..lineTo(tip.dx + r * 1.5, tip.dy + r * 0.5)
      ..lineTo(tip.dx - r * 0.9, tip.dy + r * 0.5)
      ..close();
    canvas.drawPath(path, Paint()..color = _cheese);
    final hole = Paint()..color = const Color(0xFFF9A825);
    canvas.drawCircle(tip + Offset(r * 0.15, r * 0.1), r * 0.16, hole);
    canvas.drawCircle(tip + Offset(-r * 0.25, r * 0.32), r * 0.10, hole);
  }

  void _pot(Canvas canvas, Offset center, double rw, double rh, double bob) {
    // Body + lid + handles.
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: rw * 2, height: rh),
      Radius.circular(rh * 0.24),
    );
    canvas.drawRRect(body, Paint()..color = _potColor);
    canvas.drawCircle(
      Offset(center.dx, center.dy - rh * 0.5),
      rw * 0.98,
      Paint()
        ..color = const Color(0xFF455A64)
        ..style = PaintingStyle.stroke
        ..strokeWidth = rh * 0.22,
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy - rh * 0.62),
      rh * 0.10,
      Paint()..color = AppTheme.terracotta,
    );
    for (final dir in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(center.dx + dir * rw * 1.12, center.dy - rh * 0.1),
            width: rw * 0.26,
            height: rh * 0.16,
          ),
          Radius.circular(rh * 0.08),
        ),
        Paint()..color = _potColor,
      );
    }

    // Steam: two wavy columns rising and fading on offset loop phases.
    for (final phase in [t, (t + 0.5) % 1.0]) {
      final rise = phase * rh * 1.5;
      final alpha = (0.42 * (1 - phase)).clamp(0.0, 1.0);
      final steam = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = rh * 0.10;
      for (final dx in [-rw * 0.35, rw * 0.35]) {
        final sway = math.sin((phase + dx) * 2 * math.pi) * rw * 0.14;
        final base = Offset(center.dx + dx, center.dy - rh * 0.75);
        final path = Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(
            base.dx + sway, base.dy - rise * 0.5,
            base.dx + sway * 0.4, base.dy - rise,
          );
        canvas.drawPath(path, steam);
      }
    }
  }

  void _tomatoVeg(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = _tomato);
    canvas.drawCircle(
      c + Offset(-r * 0.28, -r * 0.30),
      r * 0.26,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    final leaf = Paint()..color = _leaf;
    for (final angle in [-0.6, -0.2, 0.2, 0.6]) {
      final dir = Offset(math.sin(angle), -math.cos(angle));
      canvas.drawCircle(c + dir * r * 0.92, r * 0.14, leaf);
    }
    canvas.drawCircle(c - Offset(0, r * 0.85), r * 0.16, leaf);
  }

  void _broccoliVeg(Canvas canvas, Offset c, double r) {
    // Stem, then the floret cloud.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c + Offset(0, r * 0.85),
          width: r * 0.6,
          height: r * 0.9,
        ),
        Radius.circular(r * 0.2),
      ),
      Paint()..color = const Color(0xFFA5D6A7),
    );
    final cloud = Paint()..color = _broccoli;
    canvas.drawCircle(c - Offset(r * 0.55, r * 0.15), r * 0.52, cloud);
    canvas.drawCircle(c + Offset(r * 0.55, r * 0.15), r * 0.52, cloud);
    canvas.drawCircle(c - Offset(0, r * 0.55), r * 0.60, cloud);
    canvas.drawCircle(c, r * 0.55, cloud);
    // Floret texture dots.
    final dot = Paint()..color = _leafLight.withValues(alpha: 0.8);
    for (final (dx, dy) in const [(-0.5, -0.5), (0.1, -0.8), (0.5, -0.3), (-0.1, -0.2)]) {
      canvas.drawCircle(c + Offset(dx * r, dy * r), r * 0.11, dot);
    }
  }

  void _carrotVeg(Canvas canvas, Offset c, double r) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(0.5); // leaning into the scene
    final body = Path()
      ..moveTo(-r * 0.30, -r * 0.4)
      ..quadraticBezierTo(0, -r * 0.62, r * 0.30, -r * 0.4)
      ..lineTo(0, r)
      ..close();
    canvas.drawPath(body, Paint()..color = _carrot);
    final ridge = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = r * 0.06;
    for (final y in [-0.1, 0.2, 0.5]) {
      canvas.drawLine(Offset(-r * 0.14, r * y), Offset(r * 0.14, r * y), ridge);
    }
    final frond = Paint()
      ..color = _leaf
      ..strokeWidth = r * 0.14
      ..strokeCap = StrokeCap.round;
    for (final dx in [-0.22, 0.0, 0.22]) {
      canvas.drawLine(
        Offset(dx * r * 0.6, -r * 0.5),
        Offset(dx * r * 1.6, -r * 1.05),
        frond,
      );
    }
    canvas.restore();
  }

  void _eggplantVeg(Canvas canvas, Offset c, double r) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, r * 0.25), width: r * 0.95, height: r * 1.7),
      Paint()..color = _eggplant,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-r * 0.16, r * 0.05),
        width: r * 0.22,
        height: r * 0.85,
      ),
      Paint()..color = _eggplantShade.withValues(alpha: 0.55),
    );
    // Leafy cap.
    final cap = Paint()..color = _leaf;
    canvas.drawCircle(Offset(0, -r * 0.62), r * 0.26, cap);
    for (final dx in [-0.5, 0.0, 0.5]) {
      canvas.drawCircle(Offset(dx * r * 0.5, -r * 0.52), r * 0.16, cap);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CartoonKitchenPainter old) =>
      old.t != t || old.dark != dark;
}

// ---------------------------------------------------------------------------
// Stats strip — the library at a glance, with rolling numbers
// ---------------------------------------------------------------------------

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.recipes});

  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    final ingredientCount =
        recipes.fold<int>(0, (sum, r) => sum + r.ingredients.length);
    final minuteCount = recipes.fold<int>(0, (sum, r) => sum + (r.minutes ?? 0));

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.menu_book_rounded,
              color: AppTheme.checkGreen,
              value: recipes.length,
              label: 'recipes',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              icon: Icons.local_grocery_store_rounded,
              color: AppTheme.terracotta,
              value: ingredientCount,
              label: 'ingredients',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              icon: Icons.schedule_rounded,
              color: const Color(0xFF5C6BC0),
              value: minuteCount,
              label: 'min cooking',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.55 : 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Column(
        children: [
          GlowIcon(icon: icon, color: color, size: 17),
          const SizedBox(height: 2),
          CountUp(
            value: value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.55),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions — the three things people actually do here
// ---------------------------------------------------------------------------

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAdd,
    required this.onSurprise,
    required this.onList,
    required this.listProgress,
  });

  final VoidCallback onAdd;
  final VoidCallback onSurprise;

  /// Null when there is no saved list yet — the chip is then omitted rather
  /// than shown dead.
  final VoidCallback? onList;
  final String listProgress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(
            child: _ActionChip(
              icon: Icons.add_rounded,
              color: AppTheme.terracotta,
              label: 'New recipe',
              subtitle: 'Type or paste',
              onTap: onAdd,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionChip(
              icon: Icons.shuffle_rounded,
              color: const Color(0xFF8E24AA),
              label: 'Surprise me',
              subtitle: 'Pick for me',
              onTap: onSurprise,
            ),
          ),
          if (onList != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: _ActionChip(
                icon: Icons.shopping_basket_rounded,
                color: AppTheme.checkGreen,
                label: 'My list',
                subtitle: listProgress.isEmpty ? 'Resume' : '$listProgress done',
                onTap: onList!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return PressableScale(
      onTap: onTap,
      pressedScale: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 0.55 : 0.72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
        ),
        child: Column(
          children: [
            GlowTile(
              color: color,
              size: 36,
              radius: 11,
              child: GlowIcon(icon: icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.5),
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Ready in 30" — horizontal carousel of fast recipes
// ---------------------------------------------------------------------------

class _QuickPicks extends StatelessWidget {
  const _QuickPicks({required this.recipes});

  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.bolt_rounded,
            color: Color(0xFFF9A825),
            title: 'Ready in 30',
            subtitle: 'Fast wins for busy nights',
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 152,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 4),
              itemCount: recipes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => StaggeredEntrance(
                index: i,
                child: _QuickPickCard(recipe: recipes[i]),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _QuickPickCard extends StatelessWidget {
  const _QuickPickCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SizedBox(
      width: 152,
      child: PressableScale(
        onTap: () => Navigator.of(context).push(
          sharedAxisRoute(page: RecipeDetailScreen(recipe: recipe)),
        ),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(recipe.emoji, style: const TextStyle(fontSize: 24)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        formatMinutes(recipe.minutes ?? 0),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  recipe.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${recipe.ingredients.length} ingredients',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
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
// Section header, count badge, tip card, no-match state
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: GlowIcon(icon: icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GlowTile(
              color: AppTheme.terracotta,
              size: 44,
              radius: 14,
              child: GlowIcon(
                icon: Icons.auto_awesome_rounded,
                color: AppTheme.terracotta,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paste it once, shop it forever',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Drop in any recipe — the parser sorts it into aisles for you.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              key: const ValueKey('tip_add_recipe'),
              onPressed: onAdd,
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.tag, required this.onShowAll});

  final String tag;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            GlowEmoji(emoji: '🔍', size: 30),
            const SizedBox(height: 12),
            Text(
              'No “$tag” recipes yet',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Try another pill, or add a recipe and tag it “$tag”.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: onShowAll,
              child: const Text('Show all recipes'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter pills
// ---------------------------------------------------------------------------

/// Horizontal category filter pills. Selected pill fills with the sage
/// primary (and glows in dark mode); unselected ones are tonal surfaces.
class _FilterPills extends StatelessWidget {
  const _FilterPills({
    required this.tags,
    required this.activeTag,
    required this.onSelected,
  });

  final List<String> tags;
  final String activeTag;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 10),
        children: [
          _pill(
            context,
            label: AppController.allTag,
            selected: activeTag == AppController.allTag,
            onTap: () => onSelected(AppController.allTag),
          ),
          for (final tag in tags)
            _pill(
              context,
              label: tag,
              selected: activeTag == tag,
              onTap: () => onSelected(tag),
            ),
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strength = selected ? glowStrengthFor(context) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressableScale(
        onTap: onTap,
        pressedScale: 0.94,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
            boxShadow: strength == 0
                ? null
                : [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.5 * strength),
                      blurRadius: 16 * strength,
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? (isDark ? Colors.white : scheme.onPrimary)
                        : scheme.onSurface.withValues(alpha: 0.75),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recipe cards
// ---------------------------------------------------------------------------

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});

  final Recipe recipe;

  // Per-recipe accent so the shelf feels colorful but coherent.
  static const _accents = [
    Color(0xFFE65100), Color(0xFF2E7D32), Color(0xFF1565C0),
    Color(0xFF6A1B9A), Color(0xFFB71C1C), Color(0xFF00695C),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accents[(recipe.id.hashCode & 0x7fffffff) % _accents.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PressableScale(
        onTap: () => Navigator.of(context).push(
          sharedAxisRoute(page: RecipeDetailScreen(recipe: recipe)),
        ),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Someone else's recipe (pasted or added by hand) gets a
                    // little pencil so the shelf distinguishes it at a glance.
                    GlowTile(
                      color: accent,
                      size: 56,
                      radius: 16,
                      child: Text(recipe.emoji,
                          style: const TextStyle(fontSize: 28)),
                    ),
                    if (recipe.id.startsWith('user_'))
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Icon(Icons.edit_rounded,
                              size: 11,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.list_alt,
                              size: 14,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.ingredients.length} ingredients',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                          if (recipe.minutes != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.schedule,
                                size: 14,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Text(
                              formatMinutes(recipe.minutes!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (recipe.tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              recipe.tags.first,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.brightness == Brightness.dark
                                    ? Color.lerp(accent, Colors.white, 0.45)
                                    : accent,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 130,
              height: 130,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: ColoredBox(
                      color: scheme.primaryContainer.withValues(alpha: 0.45),
                      child: const AuroraBackdrop(intensity: 0.32),
                    ),
                  ),
                  const RecipePilotMark(size: 74),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Your cookbook is empty',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Add any recipe and it becomes a tidy,\ncategorized shopping list — instantly.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.terracotta,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add your first recipe'),
            ),
          ],
        ),
      ),
    );
  }
}
