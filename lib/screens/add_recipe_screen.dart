import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../data/emoji_suggest.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../ui/animations.dart';
import '../ui/glow.dart';

/// The add-recipe studio — the fastest honest way to get a recipe into the
/// library from a phone.
///
/// Three ideas make it painless:
///  • **Auto-emoji** — the title is scanned offline for a food keyword and the
///    matching glyph is pre-selected (tap the tile to override).
///  • **Paste a block, split into rows** — drop a messy ingredient list and one
///    tap turns it into individual, editable lines.
///  • **Live aisle preview** — the real parser runs as you type, so you can
///    see exactly how each line will be sorted before you save.
class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  static const List<String> _tagChoices = [
    'Quick & Easy',
    'Dinner',
    'Lunch',
    'Breakfast',
    'Vegetarian',
    'High Protein',
    'Dessert',
    'Snack',
  ];
  static const List<int> _timeChoices = [10, 20, 30, 45, 60];

  final TextEditingController _title = TextEditingController();
  final TextEditingController _bulk = TextEditingController();
  final List<TextEditingController> _lines = [];

  String _emoji = defaultRecipeEmoji;
  bool _emojiPickedManually = false;
  int? _minutes;
  final Set<String> _tags = <String>{};
  bool _pasteMode = false;

  @override
  void initState() {
    super.initState();
    _title.addListener(_onChanged);
    _bulk.addListener(_onChanged);
    for (var i = 0; i < 3; i++) {
      _lines.add(TextEditingController()..addListener(_onChanged));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _bulk.dispose();
    for (final c in _lines) {
      c.removeListener(_onChanged);
      c.dispose();
    }
    super.dispose();
  }

  /// Single change hook for every field: refreshes the preview, the save
  /// button, and (until the user overrides it) the suggested emoji.
  void _onChanged() {
    if (!mounted) return;
    if (!_emojiPickedManually) {
      final suggested = suggestEmoji(_title.text);
      if (suggested != _emoji) {
        setState(() => _emoji = suggested);
        return;
      }
    }
    setState(() {});
  }

  // ---- Derivations -------------------------------------------------------

  List<String> get _ingredients => _lines
      .map((c) => c.text.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  List<String> get _bulkLines => _bulk.text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList(growable: false);

  bool get _canSave =>
      _title.text.trim().isNotEmpty && _ingredients.isNotEmpty;

  /// Runs the REAL parser over the first few lines so the preview can never
  /// drift from what the grocery list will actually show.
  List<GroceryItem> get _previewItems {
    final lines = _ingredients.take(6).toList(growable: false);
    if (lines.isEmpty) return const [];
    final result = context.app.parser.parse(
      Recipe(id: 'preview', title: '', emoji: _emoji, ingredients: lines),
    );
    return result.sections
        .expand((section) => section.items)
        .take(3)
        .toList(growable: false);
  }

  // ---- Mutations ---------------------------------------------------------

  void _addLine() {
    setState(() => _lines.add(TextEditingController()..addListener(_onChanged)));
  }

  void _removeLine(int index) {
    setState(() {
      final removed = _lines.removeAt(index);
      removed.removeListener(_onChanged);
      removed.dispose();
      if (_lines.isEmpty) {
        _lines.add(TextEditingController()..addListener(_onChanged));
      }
    });
  }

  /// Turns a pasted block into individual ingredient rows.
  void _splitBulkIntoRows() {
    final lines = _bulkLines;
    if (lines.isEmpty) return;
    setState(() {
      for (final c in _lines) {
        c.removeListener(_onChanged);
        c.dispose();
      }
      _lines
        ..clear()
        ..addAll(
          lines.map((l) => TextEditingController(text: l)..addListener(_onChanged)),
        );
      // Always leave one spare empty row for the next ingredient.
      _lines.add(TextEditingController()..addListener(_onChanged));
      _bulk.clear();
      _pasteMode = false;
    });
  }

  void _save() {
    if (!_canSave) return;
    final recipe = Recipe(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      title: _title.text.trim(),
      emoji: _emoji,
      minutes: _minutes,
      tags: _tags.toList(growable: false),
      ingredients: _ingredients,
    );
    context.app.addRecipe(recipe); // fire-and-forget persistence
    Navigator.of(context).pop(recipe);
  }

  void _pickEmoji() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick a cover emoji',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final choice in emojiChoices)
                    PressableScale(
                      onTap: () {
                        setState(() {
                          _emoji = choice;
                          _emojiPickedManually = true;
                        });
                        Navigator.of(sheetContext).pop();
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _emoji == choice
                              ? scheme.primaryContainer
                              : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _emoji == choice
                                ? scheme.primary
                                : scheme.outlineVariant,
                            width: _emoji == choice ? 1.6 : 1,
                          ),
                        ),
                        child: Text(choice,
                            style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preview = _previewItems;

    return Scaffold(
      appBar: AppBar(title: const Text('New recipe')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
            children: [
              // ---- Title + emoji ------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      PressableScale(
                        onTap: _pickEmoji,
                        child: GlowTile(
                          color: AppTheme.terracotta,
                          size: 58,
                          radius: 18,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_emoji, style: const TextStyle(fontSize: 26)),
                              const SizedBox(height: 1),
                              Icon(Icons.expand_more_rounded,
                                  size: 12,
                                  color: scheme.onSurface.withValues(alpha: 0.5)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('recipe_title'),
                          controller: _title,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Recipe title',
                            hintText: 'Creamy garlic pasta',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ---- Time ----------------------------------------------------
              _SectionLabel(
                icon: Icons.schedule_rounded,
                color: const Color(0xFF5C6BC0),
                title: 'How long does it take?',
                subtitle: 'Optional — powers the “Ready in 30” shelf',
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final minutes in _timeChoices)
                        _ChoicePill(
                          label: minutes == 60 ? '1 h+' : '$minutes min',
                          selected: _minutes == minutes,
                          onTap: () => setState(
                            () => _minutes = _minutes == minutes ? null : minutes,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ---- Tags ----------------------------------------------------
              _SectionLabel(
                icon: Icons.local_offer_rounded,
                color: AppTheme.checkGreen,
                title: 'Tags',
                subtitle: 'They become the filter pills on the home screen',
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in _tagChoices)
                        _ChoicePill(
                          label: tag,
                          selected: _tags.contains(tag),
                          onTap: () => setState(() {
                            if (!_tags.remove(tag)) _tags.add(tag);
                          }),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ---- Ingredients --------------------------------------------
              _SectionLabel(
                icon: Icons.list_alt_rounded,
                color: AppTheme.terracotta,
                title: 'Ingredients',
                subtitle: 'One per line — as you\'d read them in the recipe',
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ChoicePill(
                              key: const ValueKey('mode_rows'),
                              label: 'One per line',
                              selected: !_pasteMode,
                              onTap: () => setState(() => _pasteMode = false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ChoicePill(
                              key: const ValueKey('mode_paste'),
                              label: 'Paste a block',
                              selected: _pasteMode,
                              onTap: () => setState(() => _pasteMode = true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_pasteMode) ..._bulkField(theme) else ..._rowFields(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ---- Live preview -------------------------------------------
              _SectionLabel(
                icon: Icons.auto_awesome_rounded,
                color: const Color(0xFFF9A825),
                title: 'How it will shop',
                subtitle: 'Generated by the offline parser, as you type',
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: preview.isEmpty
                      ? Text(
                          'Add an ingredient and its aisle appears here — no account, '
                          'no internet, no waiting.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                            height: 1.4,
                          ),
                        )
                      : Column(
                          children: [
                            for (final item in preview)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    GlowEmoji(
                                      emoji: item.category.emoji,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    AmountPill(item: item),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: scheme.primaryContainer
                                            .withValues(alpha: 0.55),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        item.category.label,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: scheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_ingredients.length > 6)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '+ ${_ingredients.length - 6} more ingredients',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurface.withValues(alpha: 0.55),
                                  ),
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
            // heightFactor: 1 shrink-wraps the sheet vertically — without it
            // Center expands to the Scaffold's full loose height and the CTA
            // floats in the middle of the screen (covering the form).
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('save_recipe'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.terracotta,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _canSave ? _save : null,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    _canSave ? 'Save recipe' : 'Add a title and an ingredient',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _rowFields() {
    return [
      for (var i = 0; i < _lines.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('ing_$i'),
                  controller: _lines[i],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    // Prefixed with "e.g." so a hint can never be mistaken for
                    // real content — a hint that reads like a filled row is
                    // both worse UX and a trap for tests looking up the text.
                    hintText: i == 0
                        ? 'e.g. 2 cups spinach, chopped'
                        : 'Ingredient ${i + 1}',
                  ),
                ),
              ),
              if (_lines.length > 1)
                IconButton(
                  tooltip: 'Remove ingredient',
                  onPressed: () => _removeLine(i),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45),
                  ),
                ),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('add_row'),
          onPressed: _addLine,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add ingredient'),
        ),
      ),
    ];
  }

  List<Widget> _bulkField(ThemeData theme) {
    final count = _bulkLines.length;
    return [
      TextField(
        key: const ValueKey('bulk_paste'),
        controller: _bulk,
        minLines: 5,
        maxLines: 9,
        textInputAction: TextInputAction.newline,
        decoration: const InputDecoration(
          hintText:
              'Paste straight from a recipe site:\n2 cups spinach, chopped\n4 cloves garlic, minced\n1/2 cup parmesan, grated',
        ),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          key: const ValueKey('split_bulk'),
          onPressed: count == 0 ? null : _splitBulkIntoRows,
          icon: const Icon(Icons.call_split_rounded, size: 18),
          label: Text(
            count == 0
                ? 'Paste some lines first'
                : 'Split into $count ingredient${count == 1 ? '' : 's'}',
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Commas, bullets and “minced/julienned” notes are stripped by the parser, '
        'so messy lines are welcome.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          height: 1.35,
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Building blocks (kept local — the studio is the only consumer)
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: GlowIcon(icon: icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
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

/// Selectable pill — same visual language as the home-screen filter pills, so
/// the studio feels like the rest of the app.
class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected
                    ? scheme.onPrimary
                    : scheme.onSurface.withValues(alpha: 0.75),
              ),
        ),
      ),
    );
  }
}
