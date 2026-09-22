import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../ui/animations.dart';

/// The payoff screen: parser output organized into aisle sections with
/// tactile check-off interactions.
class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({super.key});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  final GlobalKey _headerKey = GlobalKey();
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
    final list = app.list;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grocery List'),
        actions: [
          IconButton(
            tooltip: 'Uncheck all',
            icon: const Icon(Icons.restart_alt),
            onPressed: app.resetChecked,
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
          if (list == null || list.totalItems == 0)
            const _EmptyList()
          else
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              itemCount: list.sections.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return StaggeredEntrance(
                    index: 0,
                    child: _ProgressHeader(headerKey: _headerKey),
                  );
                }
                final section = list.sections[i - 1];
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
          SectionConfetti(playing: _celebrate),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({this.headerKey});

  final GlobalKey? headerKey;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final theme = Theme.of(context);
    final done = app.progress >= 1.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        key: headerKey,
        children: [
          ProgressRing(progress: app.progress),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${app.checkedCount} of ${app.totalCount} picked up',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  done ? 'Shopping complete — nice. 🎉' : 'Swipe left on an item to remove it.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
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
    final remaining = section.items.where((i) => !i.checked).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Section header: emoji, title, remaining count ---
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
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

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🛒', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text('List cleared', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Convert a recipe to build a new list.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
