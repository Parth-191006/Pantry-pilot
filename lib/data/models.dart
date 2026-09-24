import 'package:flutter/material.dart';

/// Core domain model: a grocery item belongs to an aisle category, has a
/// quantity and unit parsed from the recipe text, and tracks checked state
/// (persisted locally by the store).
@immutable
class GroceryItem {
  const GroceryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.checked,
  });

  final String id;
  final String name;
  final GroceryCategory category;
  final String quantity; // "2", "1½", "" for unspecified
  final String unit; // "cups", "g", "" for countable items
  final bool checked;

  /// Label shown in the leading pill, e.g. "2 cups" or "3".
  String get amountLabel {
    final q = quantity.trim();
    final u = unit.trim();
    if (q.isEmpty && u.isEmpty) return '1';
    if (q.isEmpty) return u;
    if (u.isEmpty) return q;
    return '$q $u';
  }

  GroceryItem copyWith({bool? checked, String? quantity, String? unit}) {
    return GroceryItem(
      id: id,
      name: name,
      category: category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      checked: checked ?? this.checked,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category.index,
        'quantity': quantity,
        'unit': unit,
        'checked': checked,
      };

  factory GroceryItem.fromMap(Map<dynamic, dynamic> map) => GroceryItem(
        id: map['id'] as String,
        name: map['name'] as String,
        category: GroceryCategory.values[map['category'] as int],
        quantity: (map['quantity'] ?? '') as String,
        unit: (map['unit'] ?? '') as String,
        checked: (map['checked'] ?? false) as bool,
      );
}

/// Display-only grouping of items under one aisle header.
@immutable
class GrocerySection {
  const GrocerySection({required this.category, required this.items});
  final GroceryCategory category;
  final List<GroceryItem> items;
}

enum GroceryCategory {
  produce('Produce', '🥬'),
  dairy('Dairy & Eggs', '🧈'),
  meat('Meat & Seafood', '🥩'),
  pantry('Pantry', '🥫'),
  spices('Spices & Baking', '🧂'),
  other('Other', '🛒');

  const GroceryCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

@immutable
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.emoji,
    required this.ingredients,
    this.minutes,
    this.tags = const [],
    this.steps = const [],
  });

  final String id;
  final String title;
  final String emoji;

  /// Raw ingredient lines exactly as a user would paste them.
  final List<String> ingredients;

  /// Approximate total time in minutes (null → unknown; user-pasted recipes).
  final int? minutes;

  /// Free-form category labels for the home-screen filter pills
  /// (e.g. 'Dinner', 'Vegetarian', 'High Protein'). Seeds ship curated tags;
  /// user-pasted recipes start untagged and match "All" only.
  final List<String> tags;

  /// Ordered cooking instructions. Built-ins ship hand-written steps with
  /// per-step timings; user recipes may have none (cook-along then stays
  /// disabled for them).
  final List<RecipeStep> steps;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'ingredients': ingredients,
        'minutes': minutes,
        'tags': tags,
        'steps': [for (final s in steps) s.toMap()],
      };

  factory Recipe.fromMap(Map<dynamic, dynamic> map) => Recipe(
        id: map['id'] as String,
        title: map['title'] as String,
        emoji: (map['emoji'] ?? '🍽️') as String,
        ingredients:
            (map['ingredients'] as List? ?? const []).map((e) => '$e').toList(),
        minutes: map['minutes'] as int?,
        tags: (map['tags'] as List? ?? const [])
            .map((e) => '$e')
            .toList(growable: false),
        steps: (map['steps'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => RecipeStep.fromMap(Map<dynamic, dynamic>.from(m)))
            .toList(growable: false),
      );
}

/// One cook-along instruction with an optional countdown. `seconds == null`
/// means "work at your own pace" — the step card shows a hand timer instead
/// of a number; a stopwatch-style chip still tracks elapsed time.
@immutable
class RecipeStep {
  const RecipeStep({required this.text, this.seconds});

  final String text;
  final int? seconds;

  Map<String, dynamic> toMap() => {'text': text, 'seconds': seconds};

  factory RecipeStep.fromMap(Map<dynamic, dynamic> map) => RecipeStep(
        text: (map['text'] ?? '') as String,
        seconds: map['seconds'] as int?,
      );

  /// Matches a trailing duration like "…, 10 min" / "… 45 seconds" / "… 2 h".
  static final RegExp _trailingDuration = RegExp(
    r'^(.*?)[,;\s]*\b(\d+)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)\.?$',
    caseSensitive: false,
  );

  /// Parses a user-typed step line: a trailing duration becomes the cook-
  /// along timer ("Simmer the sauce, 10 min" → text "Simmer the sauce",
  /// 600 s); anything else stays plain text cooked at your own pace.
  static RecipeStep parseLine(String raw) {
    final line = raw.trim();
    final m = _trailingDuration.firstMatch(line);
    if (m == null) return RecipeStep(text: line);
    final text = m.group(1)!.trim();
    final n = int.parse(m.group(2)!);
    final unit = m.group(3)!.toLowerCase();
    final seconds =
        unit.startsWith('h') ? n * 3600 : (unit.startsWith('s') ? n : n * 60);
    return RecipeStep(text: text.isEmpty ? line : text, seconds: seconds);
  }
}
