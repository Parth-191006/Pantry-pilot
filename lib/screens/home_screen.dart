import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_info.dart';
import '../app_scope.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../ui/animations.dart';
import '../ui/greeting.dart';
import 'recipe_detail_screen.dart';
import 'settings_screen.dart';

/// Entry screen — recipe library. The hero leads with a bundled photograph of
/// fresh produce under a dark scrim (readable in both themes, zero network),
/// followed by a time-aware greeting and the recipe cards.
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
    final recipes = app.recipes;

    return Scaffold(
      appBar: AppBar(
        title: Text(appName),
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
      body: recipes.isEmpty
          ? _EmptyState(
              onAdd: () => _showAddSheet(context),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                  itemCount: recipes.length + 2,
                  itemBuilder: (context, i) {
                    if (i == 0) return _HeroPhotoCard(onExplore: () => _explorePantry(context));
                    if (i == 1) {
                      return _LibraryHeader(key: _libraryKey, count: recipes.length);
                    }
                    final recipe = recipes[i - 2];
                    return StaggeredEntrance(
                      index: i - 2,
                      baseDelay: const Duration(milliseconds: 160),
                      child: _RecipeCard(recipe: recipe),
                    );
                  },
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.receipt_long),
        label: const Text('Paste a recipe'),
        backgroundColor: AppTheme.terracotta,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddRecipeSheet(),
    );
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
      _showAddSheet(context);
    }
  }
}

// ---------------------------------------------------------------------------
// Hero: bundled photo + dark scrim + greeting + CTA + slow Ken Burns drift.
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
    final scheme = theme.colorScheme;
    final greeting = timeGreeting(DateTime.now());

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 22),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = _c.value;
            // Ken Burns: a slow, subtle zoom+drift so the still photo feels alive.
            final scale = 1.0 + 0.06 * t;
            final drift = Offset(6 * math.sin(t * math.pi), 4 * math.cos(t * math.pi));

            return ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 200,
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
                    // --- Scrim: bottom-heavy dark gradient keeps text WCAG-readable ---
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
                          const Text(
                            'Cook it, then shop for it.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          PressableScale(
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
                              icon: const Icon(Icons.shopping_basket_rounded, size: 18),
                              label: const Text('Explore Pantry',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
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
// produce (tomato red, basil green, avocado, cream). Used until a real photo
// is bundled at assets/images/hero_produce.jpg — zero asset dependencies.
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
// Library header + recipe cards
// ---------------------------------------------------------------------------

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: Row(
        children: [
          Text(
            'Your recipes',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
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
          ),
        ],
      ),
    );
  }
}

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
    final accent = _accents[recipe.id.hashCode.abs() % _accents.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PressableScale(
        onTap: () => Navigator.of(context).push(
          sharedAxisRoute(page: RecipeDetailScreen(recipe: recipe)),
        ),
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).push(
              sharedAxisRoute(page: RecipeDetailScreen(recipe: recipe)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Text(recipe.emoji, style: const TextStyle(fontSize: 28)),
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
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe.ingredients.length} ingredients',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state: clean illustration + helpful prompt.
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
            // Simple "illustration": layered emoji composition, no image files.
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                const Text('🥕', style: TextStyle(fontSize: 40)),
                Positioned(
                  top: 2,
                  right: 14,
                  child: Transform.rotate(
                    angle: 0.35,
                    child: const Text('🍅', style: TextStyle(fontSize: 26)),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  left: 16,
                  child: Transform.rotate(
                    angle: -0.3,
                    child: const Text('🧄', style: TextStyle(fontSize: 22)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Your pantry is empty',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Paste any recipe below and it becomes a tidy,\ncategorized shopping list — instantly.',
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
              icon: const Icon(Icons.receipt_long),
              label: const Text('Paste your first recipe'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for pasting raw ingredient lines — parser does the rest.
class _AddRecipeSheet extends StatefulWidget {
  const _AddRecipeSheet();

  @override
  State<_AddRecipeSheet> createState() => _AddRecipeSheetState();
}

class _AddRecipeSheetState extends State<_AddRecipeSheet> {
  final _title = TextEditingController();
  final _lines = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _lines.dispose();
    super.dispose();
  }

  void _submit() {
    final ingredients = _lines.text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (_title.text.trim().isEmpty || ingredients.isEmpty) return;

    final app = context.app;
    app.addRecipe(Recipe(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      title: _title.text.trim(),
      emoji: '🥘',
      ingredients: ingredients,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New recipe', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lines,
            maxLines: 6,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Ingredients (one per line)',
              hintText: '2 cups spinach, chopped\n4 cloves garlic, minced',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.terracotta,
              foregroundColor: Colors.white,
            ),
            onPressed: _submit,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Save recipe'),
          ),
        ],
      ),
    );
  }
}
