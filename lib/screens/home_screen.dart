import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_info.dart';
import '../app_scope.dart';
import '../data/models.dart';
import '../ui/animations.dart';
import 'recipe_detail_screen.dart';
import 'settings_screen.dart';

/// Entry screen — recipe library. Instant, offline, and a bit livelier:
/// gradient hero with floating food art, category legend, rich cards.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final recipes = app.recipes;
    final scheme = Theme.of(context).colorScheme;

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
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
              itemCount: recipes.length + 2,
              itemBuilder: (context, i) {
                if (i == 0) return const _HeroCard();
                if (i == 1) return _LibraryHeader(count: recipes.length);
                final recipe = recipes[i - 2];
                return StaggeredEntrance(
                  index: i - 2,
                  baseDelay: const Duration(milliseconds: 160),
                  child: _RecipeCard(recipe: recipe),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.receipt_long),
        label: const Text('Paste a recipe'),
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
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
}

// ---------------------------------------------------------------------------
// Hero: brand gradient + floating food art + one-line pitch.
// ---------------------------------------------------------------------------

class _HeroCard extends StatefulWidget {
  const _HeroCard();

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    _float.repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _float,
        builder: (context, child) {
          final t = _float.value;
          return Container(
            height: 168,
            margin: const EdgeInsets.only(top: 8, bottom: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [scheme.primary.withValues(alpha: 0.55), scheme.primaryContainer.withValues(alpha: 0.25)]
                    : [scheme.primary, scheme.tertiary],
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: dark ? 0.2 : 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Floating food art — gentle sine bob, seeded scatter.
                Positioned(
                  top: 14 + 6 * math.sin(t * math.pi),
                  right: 26,
                  child: Transform.rotate(
                    angle: -0.18,
                    child: const Text('🍅', style: TextStyle(fontSize: 34)),
                  ),
                ),
                Positioned(
                  bottom: 16 + 5 * math.sin(t * math.pi + 1.4),
                  right: 84,
                  child: Transform.rotate(
                    angle: 0.22,
                    child: const Text('🧄', style: TextStyle(fontSize: 28)),
                  ),
                ),
                Positioned(
                  top: 52 + 7 * math.sin(t * math.pi + 2.8),
                  right: 132,
                  child: Transform.rotate(
                    angle: 0.1,
                    child: const Text('🥑', style: TextStyle(fontSize: 30)),
                  ),
                ),
                Positioned(
                  bottom: 24 + 4 * math.sin(t * math.pi + 0.7),
                  left: 22,
                  child: Text('🥬', style: TextStyle(fontSize: 40)),
                ),
                // Copy.
                Positioned(
                  left: 76,
                  top: 30,
                  right: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cook it,\nthen shop for it.',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Any recipe → tidy aisle-by-aisle list.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.count});

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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🍽️', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text('No recipes yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Paste ingredients below to get started.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
            onPressed: _submit,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Save recipe'),
          ),
        ],
      ),
    );
  }
}
