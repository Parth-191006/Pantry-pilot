import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../ui/animations.dart';
import 'recipe_detail_screen.dart';

/// Entry screen — recipe library. Everything runs from local storage, so the
/// grid is instant even in airplane mode.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final recipes = app.recipes;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pantry Pilot'),
        actions: [
          IconButton(
            tooltip: 'Toggle dark mode',
            // Animated swap between sun/moon icons.
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  RotationTransition(turns: anim, child: FadeTransition(opacity: anim, child: child)),
              child: Icon(
                app.darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                key: ValueKey(app.darkMode),
              ),
            ),
            onPressed: app.toggleDarkMode,
          ),
        ],
      ),
      body: recipes.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: recipes.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return const _HeaderBlock();
                final recipe = recipes[i - 1];
                return StaggeredEntrance(
                  index: i - 1,
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

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cook it, then shop for it.', style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Pick a recipe and Pantry Pilot turns it into a categorized grocery list — fully offline.',
            style: text.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            sharedAxisRoute(page: RecipeDetailScreen(recipe: recipe)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(recipe.emoji, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '${recipe.ingredients.length} ingredients',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
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
