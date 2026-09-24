import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme/app_theme.dart';
import '../ui/animations.dart';
import '../ui/glow.dart';

/// The payoff screen: parser output organized into aisle sections with
/// tactile check-off interactions. The header meter recomputes
/// (checked / total) on every toggle and animates its fill via
/// [LinearProgressMeter].
class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({super.key});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  bool _celebrate = false;

  void _onToggled(bool nowComplete) {
    if (nowComplete && !_celebrate) {
      setState(() => _celebrate = true);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _celebrate = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final scheme = Theme.of(context).colorScheme;

    // Rows the parser refused to guess at are stored like any other item (so
    // they persist), but they're hoisted into their own bucket instead of
    // sitting in an aisle with an invented amount next to them.
    final review = app.list?.reviewItems ?? const <GroceryItem>[];
    final sections = <GrocerySection>[
      for (final s in app.list?.sections ?? const <GrocerySection>[])
        if (s.items.any((i) => !i.needsReview))
          GrocerySection(
            category: s.category,
            items: [
              for (final i in s.items)
                if (!i.needsReview) i,
            ],
          ),
    ];
    final empty = sections.isEmpty && review.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery List'),
        actions: [
          IconButton(
            tooltip: 'Uncheck all',
            icon: const Icon(Icons.restart_alt),
            onPressed: empty ? null : app.resetChecked,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Soft tinted backdrop so sections float like cards.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primaryContainer.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          if (empty)
            _EmptyList(onBack: () => Navigator.of(context).popUntil((r) => r.isFirst))
          else
            Center(
              child: ConstrainedBox(
                // Same comfortable reading width as the home screen.
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  itemCount: sections.length + 1 + (review.isEmpty ? 0 : 1),
                  itemBuilder: (context, i) {
                    if (i == 0) return const _MeterHeader();
                    if (review.isNotEmpty && i == 1) {
                      return _ReviewCard(items: review);
                    }
                    final section = sections[i - (review.isEmpty ? 1 : 2)];
                    return StaggeredEntrance(
                      index: i,
                      baseDelay: const Duration(milliseconds: 120),
                      child: _SectionCard(
                        section: section,
                        onToggled: _onToggled,
                      ),
                    );
                  },
                ),
              ),
            ),
          SectionConfetti(playing: _celebrate),
        ],
      ),
    );
  }
}

/// Header: progress ring + "3 of 12 picked up" + live % + the animated
/// linear meter. All of it rebuilds on every toggle because it reads
/// [AppController] through the scoped InheritedNotifier.
class _MeterHeader extends StatelessWidget {
  const _MeterHeader();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final theme = Theme.of(context);
    final done = app.progress >= 1.0;
    final percent = (app.progress * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(progress: app.progress),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${app.checkedCount} of ${app.totalCount} picked up',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        done
                            ? 'Shopping complete — nice. 🎉'
                            : '$percent% of the list in your basket',
                        key: ValueKey(done),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // THE METER: width animates fluidly on every check/uncheck. The key
          // exposes live progress to tests (meter-<checked>-of-<total>).
          LinearProgressMeter(
            key: ValueKey('meter-${app.checkedCount}-of-${app.totalCount}'),
            progress: app.progress,
          ),
        ],
      ),
    );
  }
}

/// Card for lines the parser could not read confidently.
///
/// The bargain the parser makes: it never invents a quantity, unit or name.
/// Anything it cannot split honestly lands here with the recipe's own text, so
/// the fix is an edit to the recipe rather than a silently wrong shopping row.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.items});

  final List<GroceryItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Card(
        key: const ValueKey('needs_review'),
        color: scheme.errorContainer.withValues(alpha: 0.4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.help_outline_rounded,
                      size: 18, color: scheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Needs review (${items.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Too messy to split safely — shown exactly as written instead '
                'of as a guessed amount. Edit the recipe to list them.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer.withValues(alpha: 0.85),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.edit_note_rounded,
                          size: 16,
                          color: scheme.onErrorContainer.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.onToggled,
  });

  final GrocerySection section;
  final void Function(bool nowComplete) onToggled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.app;
    final total = section.items.length;
    final doneCount = section.items.where((i) => i.checked).length;
    final remaining = total - doneCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Section header: emoji, title, mini meter, remaining count ---
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Row(
                children: [
                  GlowEmoji(emoji: section.category.emoji, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.category.label,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Text(
                      remaining == 0 ? 'Done ✓' : '$remaining left',
                      key: ValueKey(remaining),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: remaining == 0
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Per-section mini meter — mirrors the global one.
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: LinearProgressMeter(progress: total == 0 ? 0 : doneCount / total, height: 5),
            ),
            const Divider(indent: 18, endIndent: 18),
            // --- Items ---
            for (final item in section.items)
              _ItemRow(
                key: ValueKey(item.id),
                item: item,
                onToggle: () {
                  app.toggleItem(item.id);
                  // Celebration only when the LAST item flips to checked.
                  onToggled(app.totalCount > 0 && app.checkedCount >= app.totalCount);
                },
                onDelete: () => _dismissWithUndo(context, app, item),
              ),
          ],
        ),
      ),
    );
  }

  void _dismissWithUndo(BuildContext context, AppController app, GroceryItem item) {
    app.deleteItem(item.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed ${item.name}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // Re-insert: simplest correct path is re-saving the whole list
              // with the item back — store keeps items as flat map.
              app.restoreItem(item);
            },
          ),
        ),
      );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({super.key, required this.item, required this.onToggle, required this.onDelete});

  final GroceryItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final checked = app.checkedIdSet.contains(item.id);

    return CheckedItemAnimator(
      checked: checked,
      child: Dismissible(
        key: ValueKey('dismiss_${item.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.onErrorContainer),
        ),
        onDismissed: (_) => onDelete(),
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                StrikeCheckbox(checked: checked, onChanged: onToggle),
                const SizedBox(width: 14),
                AmountPill(item: item),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedStrikeText(
                    checked: checked,
                    text: item.name,
                    style: Theme.of(context).textTheme.bodyLarge,
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

/// Empty state after the user clears their list — illustrated, with a
/// one-tap way back.
class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.onBack});

  final VoidCallback onBack;

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
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                const GlowEmoji(emoji: '🛒', size: 46),
                Positioned(
                  top: 0,
                  right: 16,
                  child: Transform.rotate(
                    angle: 0.3,
                    child: const Text('🥬', style: TextStyle(fontSize: 22)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('List cleared', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Convert a recipe to build a fresh,\ncategorized shopping list.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.terracotta,
                foregroundColor: Colors.white,
              ),
              onPressed: onBack,
              icon: const Icon(Icons.menu_book_rounded),
              label: const Text('Pick a recipe'),
            ),
          ],
        ),
      ),
    );
  }
}
