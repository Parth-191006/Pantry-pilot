import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../theme/app_theme.dart';
import '../ui/animations.dart';

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
    final app = context.app;
    if (nowComplete && !_celebrate && app.celebrationsOn) {
      setState(() => _celebrate = true);
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _celebrate = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final sections = app.list?.sections ?? const <GrocerySection>[];
    final scheme = Theme.of(context).colorScheme;
    final empty = sections.isEmpty;

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
                  itemCount: sections.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) return const _MeterHeader();
                    final section = sections[i - 1];
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
                  Text(section.category.emoji, style: const TextStyle(fontSize: 20)),
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
                const Text('🛒', style: TextStyle(fontSize: 46)),
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
