import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../ui/animations.dart';
import '../ui/glow.dart';
import '../ui/greeting.dart';
import 'cook_along_screen.dart';
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

  Future<void> _startCookAlong() async {
    // Shared-axis forward beat keeps the two CTAs feeling like one motion.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    await Navigator.of(context).push(
      sharedAxisRoute(page: CookAlongScreen(recipe: widget.recipe)),
    );
    if (mounted) setState(() {});
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
    final scheme = theme.colorScheme;
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
              // Cook-along steps, with their per-step timers. Only shown when
              // the recipe carries steps — user-pasted recipes may not have any.
              if (recipe.steps.isNotEmpty) ...[
                const SizedBox(height: 26),
                Text('Steps',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (var i = 0; i < recipe.steps.length; i++)
                  StaggeredEntrance(
                    index: recipe.ingredients.length + i,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              recipe.steps[i].text,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          if (recipe.steps[i].seconds != null) ...[
                            const SizedBox(width: 8),
                            _StepTimeChip(seconds: recipe.steps[i].seconds!),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      bottomSheet: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Center(
            // heightFactor: 1 shrink-wraps the sheet vertically, so the CTAs
            // hug the bottom of the screen instead of floating over the
            // ingredient list (Center expands into the Scaffold's loose
            // height constraint otherwise).
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (CookAlongScreen.availableFor(recipe))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('cook_along'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _startCookAlong,
                        icon: const Icon(Icons.outdoor_grill_rounded),
                        label: const Text(
                          'Cook along',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  BorderBeam(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-step duration chip shown next to timed cook-along steps.
class _StepTimeChip extends StatelessWidget {
  const _StepTimeChip({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final label = m > 0 ? '$m min' : '$s s';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined,
              size: 12, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSecondaryContainer,
                ),
          ),
        ],
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
