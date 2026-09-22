import 'package:flutter_test/flutter_test.dart';

import 'package:pantry_pilot/data/ingredient_parser.dart';
import 'package:pantry_pilot/data/models.dart';

void main() {
  const parser = IngredientParser();

  Recipe recipeOf(List<String> lines) =>
      Recipe(id: 't', title: 'Test', emoji: '🍽️', ingredients: lines);

  group('IngredientParser', () {
    test('categorizes ingredients into expected aisles', () {
      final result = parser.parse(recipeOf([
        '2 cups spinach',
        '1 cup milk',
        '1 lb chicken breast',
        '2 tbsp olive oil',
        '1 tsp cumin',
      ]));

      final cats = <GroceryCategory, String>{};
      for (final s in result.sections) {
        for (final i in s.items) {
          cats[i.category] = i.name;
        }
      }

      expect(cats[GroceryCategory.produce], 'Spinach');
      expect(cats[GroceryCategory.dairy], 'Milk');
      expect(cats[GroceryCategory.meat], 'Chicken breast');
      expect(cats[GroceryCategory.pantry], 'Olive oil');
      expect(cats[GroceryCategory.spices], 'Cumin');
      expect(result.totalItems, 5);
    });

    test('merges duplicate ingredients across naming variants', () {
      final result = parser.parse(recipeOf([
        '1 green onion',
        '3 green onions, sliced',
        '2 cloves garlic, minced',
        '2 garlic cloves',
      ]));

      final names = [
        for (final s in result.sections) ...s.items.map((i) => i.name),
      ];

      expect(names.where((n) => n == 'Scallions'), hasLength(1));
      expect(names.where((n) => n == 'Garlic'), hasLength(1));
    });

    test('adds quantities when the same item appears twice', () {
      final result = parser.parse(recipeOf([
        '1 cup milk',
        '2 cups milk',
      ]));

      final milk = result.sections
          .expand((s) => s.items)
          .firstWhere((i) => i.name == 'Milk');
      expect(milk.quantity, '3');
      expect(milk.unit, 'cups');
    });

    test('parses fractions like 1/2 and 1 1/2', () {
      final result = parser.parse(recipeOf([
        '1 1/2 cups flour',
        '1/2 tsp salt',
      ]));

      final flour = result.sections.expand((s) => s.items).firstWhere((i) => i.name == 'Flour');
      final salt = result.sections.expand((s) => s.items).firstWhere((i) => i.name == 'Salt');

      expect(flour.quantity, '1.5');
      expect(salt.quantity, '0.5');
    });

    test('falls back to Other for unknown items', () {
      final result = parser.parse(recipeOf(['1 jar of mystery goo']));
      final goo = result.sections.expand((s) => s.items).first;
      expect(goo.category, GroceryCategory.other);
    });

    test('strips prep words and instruction commas', () {
      final result = parser.parse(recipeOf([
        '1 onion, finely diced',
        '2 carrots, roughly chopped',
      ]));

      final names = result.sections.expand((s) => s.items).map((i) => i.name).toSet();
      expect(names, contains('Onion'));
      expect(names, contains('Carrots'));
    });
  });
}
