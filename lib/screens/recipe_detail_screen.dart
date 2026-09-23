import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../ui/animations.dart';
import '../ui/glow.dart';
import '../ui/greeting.dart';
import 'grocery_list_screen.dart';

/// Shows the raw recipe; the CTA runs the offline parser and animates into
/// the categorized grocery list via a shared-axis transition.
///
/// Recipes you created yourself (`user_…` ids) can also be deleted here — the
/// only place the library shrinks. Built-ins are re-seeded on every launch, so
/// deleting one would silently resurrect it; the menu simply isn't offered.
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

  Future<void> _confirmDelete() async {
    final app = context.app;
    final scheme = Theme.of(context).colorScheme;
    final title = widget.recipe.title;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this recipe?'),
        content: Text('“$title” will be removed from your library.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await app.deleteRecipe(widget.recipe.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Deleted “$title”')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipe = widget.recipe;
    final isUserRecipe = recipe.id.startsWith('user_');

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          if (isUserRecipe)
            PopupMenuButton<String>(
              tooltip: 'Recipe options',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'delete') _confirmDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Delete recipe'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlowTile(
                    color: AppTheme.checkGreen,
                    size: 76,
                    radius: 22,
                    child: Text(recipe.emoji, style: const TextStyle(fontSize: 38)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaChip(
                          icon: Icons.list_alt_rounded,
                          label: '${recipe.ingredients.length} ingredients',
                        ),
                        if (recipe.minutes != null)
                          _MetaChip(
                            icon: Icons.schedule_rounded,
                            label: formatMinutes(recipe.minutes!),
                          ),
                        for (final tag in recipe.tags)
                          _MetaChip(
                            icon: Icons.local_offer_rounded,
                            label: tag,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text('Ingredients',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
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
        ),
      ),
      bottomSheet: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox(
                width: double.infinity,
                child: BorderBeam(
                  radius: 20,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome,
                              key: ValueKey('wand')),
                    ),
                    label: Text(_converting ? 'Parsing…' : 'Generate grocery list'),
                    onPressed: _generateList,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small metadata pill used for ingredient count, cook time and tags.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlowIcon(icon: icon, color: scheme.primary, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
          ),
        ],
      ),
    );
  }
}
