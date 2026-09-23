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
                    _HeroPhotoCard(onExplore: () => _explorePantry(context)),
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
// Hero: bundled photo + dark scrim + greeting + shiny headline + CTA
// ---------------------------------------------------------------------------

class _HeroPhotoCard extends StatefulWidget {
  const _HeroPhotoCard({required this.onExplore});

  final VoidCallback onExplore;

  @override
  State<_HeroPhotoCard> createState() => _HeroPhotoCardState();
}

class _HeroPhotoCardState extends State<_HeroPhotoCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void initState() {
    super.initState();
    _c.repeat(reverse: true);
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
            final t = _c.value;
            // Ken Burns: a slow, subtle zoom+drift so the still photo feels alive.
            final scale = 1.0 + 0.06 * t;
            final drift =
                Offset(6 * math.sin(t * math.pi), 4 * math.cos(t * math.pi));

            return ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 208,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // --- Photo (bundled asset → works fully offline) ---
                    // Drop any produce photo at assets/images/hero_produce.jpg
                    // and it is picked up on the next build — no code change.
                    Transform.translate(
                      offset: drift,
                      child: Transform.scale(
                        scale: scale,
                        child: Image.asset(
                          'assets/images/hero_produce.jpg',
                          fit: BoxFit.cover,
                          // Until a photo is bundled, paint a soft procedural
                          // "bokeh produce" backdrop instead of failing.
                          errorBuilder: (_, __, ___) =>
                              const CustomPaint(painter: _ProduceBackdrop()),
                        ),
                      ),
                    ),
                    // --- Scrim: bottom-heavy dark gradient keeps text readable ---
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.0, 0.45, 1.0],
                          colors: [
                            Colors.black26,
                            Colors.black38,
                            Color(0xCC101510), // ~80% near-black green
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
                              color: Colors.white.withValues(alpha: 0.9),
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
                              color: Colors.white.withValues(alpha: 0.85),
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
                            child: PressableScale(
                              onTap: widget.onExplore,
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

// ---------------------------------------------------------------------------
// Procedural hero backdrop: a soft, blurred color-field sampled from fresh
// produce. Used only if the bundled photo is ever missing.
// ---------------------------------------------------------------------------

class _ProduceBackdrop extends CustomPainter {
  const _ProduceBackdrop();

  @override
  void paint(Canvas canvas, Size size) {
    final blobs = <(Offset, double, Color)>[
      (Offset(size.width * 0.12, size.height * 0.25), size.width * 0.42, const Color(0xFF7CB342)),
      (Offset(size.width * 0.55, size.height * 0.85), size.width * 0.38, const Color(0xFF33691E)),
      (Offset(size.width * 0.82, size.height * 0.2), size.width * 0.34, const Color(0xFFE53935)),
      (Offset(size.width * 0.38, size.height * 0.45), size.width * 0.30, const Color(0xFFEF6C00)),
      (Offset(size.width * 0.95, size.height * 0.65), size.width * 0.30, const Color(0xFFF9A825)),
    ];
    final base = Paint()..color = const Color(0xFF2E7D32);
    canvas.drawRect(Offset.zero & size, base);
    for (final (center, radius, color) in blobs) {
      final paint = Paint()
        ..color = color.withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
