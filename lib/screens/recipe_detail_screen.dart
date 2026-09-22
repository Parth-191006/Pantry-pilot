import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../ui/animations.dart';
import 'grocery_list_screen.dart';

/// Shows the raw recipe; the CTA runs the offline parser and animates into
/// the categorized grocery list via a shared-axis transition.
class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  bool _converting = false;

  Future<void> _generateList() async {
    if (_converting) return;
    setState(() => _converting = true);

    final app = context.app;
    // Parser runs synchronously but is wrapped in a microtask so the CTA
    // can paint its pressed state first — no jank on entry.
    await Future<void>.delayed(const Duration(milliseconds: 220));
    await app.convertRecipe(widget.recipe);

    if (!mounted) return;
    Navigator.of(context).push(
      sharedAxisRoute(page: const GroceryListScreen()),
    );
    setState(() => _converting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipe = widget.recipe;

    return Scaffold(
      appBar: AppBar(title: Text(recipe.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(recipe.emoji, style: const TextStyle(fontSize: 36)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${recipe.ingredients.length} ingredients',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Ingredients', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          // Raw lines — intentionally NOT parsed here, so the "aha" moment
          // happens on the conversion screen.
          for (var i = 0; i < recipe.ingredients.length; i++)
            StaggeredEntrance(
              index: i,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        recipe.ingredients[i],
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomSheet: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              // Icon swaps from a wand to a cart with a rotation fade.
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: Tween(begin: 0.5, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: _converting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome, key: ValueKey('wand')),
              ),
              label: Text(_converting ? 'Parsing…' : 'Generate grocery list'),
              onPressed: _generateList,
            ),
          ),
        ),
      ),
    );
  }
}
