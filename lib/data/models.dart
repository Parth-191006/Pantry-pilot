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
  });

  final String id;
  final String title;
  final String emoji;

  /// Raw ingredient lines exactly as a user would paste them.
  final List<String> ingredients;

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'ingredients': ingredients,
      };

  factory Recipe.fromMap(Map<dynamic, dynamic> map) => Recipe(
        id: map['id'] as String,
        title: map['title'] as String,
        emoji: (map['emoji'] ?? '🍽️') as String,
        ingredients:
            (map['ingredients'] as List? ?? const []).map((e) => '$e').toList(),
      );
}
