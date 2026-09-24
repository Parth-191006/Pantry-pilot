import 'package:flutter_test/flutter_test.dart';

import 'package:pantry_pilot/data/ingredient_parser.dart';
import 'package:pantry_pilot/data/models.dart';

/// Coverage for the messy-line shapes that real recipe sites actually emit.
///
/// Every group below maps to one audited pattern, followed by lines pulled
/// from the phrasing style of published recipes, plus the degradation rules
/// that stop the parser from ever inventing a quantity.
void main() {
  const parser = IngredientParser();

  Recipe recipeOf(List<String> lines) =>
      Recipe(id: 't', title: 'Test', emoji: '🍽️', ingredients: lines);

  List<GroceryItem> itemsOf(GroceryListResult result) =>
      [for (final section in result.sections) ...section.items];

  List<String> namesOf(GroceryListResult result) =>
      [for (final item in itemsOf(result)) item.name];

  GroceryItem row(GroceryListResult result, String name) =>
      itemsOf(result).firstWhere(
        (i) => i.name == name,
        orElse: () => throw StateError(
          'no row named "$name" (got ${namesOf(result)})',
        ),
      );

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

      final flour = result.sections
          .expand((s) => s.items)
          .firstWhere((i) => i.name == 'Flour');
      final salt = result.sections
          .expand((s) => s.items)
          .firstWhere((i) => i.name == 'Salt');

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

      final names =
          result.sections.expand((s) => s.items).map((i) => i.name).toSet();
      expect(names, contains('Onion'));
      expect(names, contains('Carrots'));
    });
  });

  // ---------------------------------------------------------------------
  // Pattern 1 — no quantity, multiple ingredients joined by "and".
  // ---------------------------------------------------------------------
  group('pattern 1 — staples joined by "and"', () {
    test('"Salt and pepper, to taste" becomes two spice rows', () {
      final result = parser.parse(recipeOf(['Salt and pepper, to taste']));
      expect(result.reviewCount, 0);
      expect(namesOf(result), ['Salt', 'Pepper']);
      expect(row(result, 'Salt').category, GroceryCategory.spices);
      expect(row(result, 'Pepper').category, GroceryCategory.spices);
      expect(row(result, 'Salt').quantity, '');
      expect(row(result, 'Salt').needsReview, isFalse);
    });

    test('joined herbs split too, but a single product does not', () {
      final split =
          parser.parse(recipeOf(['Kosher salt and freshly ground black pepper']));
      expect(namesOf(split), ['Kosher salt', 'Black pepper']);

      // "sweet" is not a shopping item, so the phrase stays whole.
      final whole = parser.parse(recipeOf(['Sweet and sour sauce']));
      expect(namesOf(whole), ['Sweet and sour sauce']);
    });
  });

  // ---------------------------------------------------------------------
  // Pattern 2 — quantity + parenthetical secondary unit + container unit.
  // ---------------------------------------------------------------------
  group('pattern 2 — parenthetical amounts', () {
    test('"1 (14 oz) can diced tomatoes" keeps the can, drops the bracket', () {
      final result = parser.parse(recipeOf(['1 (14 oz) can diced tomatoes']));
      final item = row(result, 'Tomatoes');
      expect(item.quantity, '1');
      expect(item.unit, 'can');
      expect(item.amountLabel, '1 can');
      expect(item.category, GroceryCategory.produce);
      expect(item.needsReview, isFalse);
      expect(result.reviewCount, 0);
    });

    test('a bare bracket weight is used when nothing else is given', () {
      final result = parser.parse(recipeOf(['Diced tomatoes (14 oz)']));
      final item = row(result, 'Tomatoes');
      expect(item.quantity, '14');
      expect(item.unit, 'oz');
    });

    test('"2 15-oz cans black beans" reads as two cans', () {
      final result = parser.parse(
          recipeOf(['2 15-oz cans black beans, rinsed and drained']));
      final item = row(result, 'Black beans');
      expect(item.quantity, '2');
      expect(item.unit, 'can');
      expect(item.amountLabel, '2 cans');
      expect(item.category, GroceryCategory.pantry);
    });
  });

  // ---------------------------------------------------------------------
  // Pattern 3 — quantity sits after the ingredient reference.
  // ---------------------------------------------------------------------
  group('pattern 3 — "juice of N x"', () {
    test('"Juice of 1 lemon" buys the lemon itself', () {
      final result = parser.parse(recipeOf(['Juice of 1 lemon']));
      final item = row(result, 'Lemon');
      expect(item.quantity, '1');
      expect(item.unit, '');
      expect(item.category, GroceryCategory.produce);
      expect(result.reviewCount, 0);
    });

    test('zest and juice merge with the plain fruit', () {
      final result = parser.parse(recipeOf(['Zest of 1 orange', '1 orange']));
      expect(result.totalItems, 1);
      expect(row(result, 'Orange').quantity, '2');
    });

    test('"Juice and zest of 1 lime" is flagged rather than guessed', () {
      const line = 'Juice and zest of 1 lime';
      final result = parser.parse(recipeOf([line]));
      expect(result.reviewCount, 1);
      expect(row(result, line).needsReview, isTrue);
    });
  });

  // ---------------------------------------------------------------------
  // Pattern 4 — unicode fractions and mixed numbers.
  // ---------------------------------------------------------------------
  group('pattern 4 — unicode fractions', () {
    test('"½ cup packed brown sugar"', () {
      final result = parser.parse(recipeOf(['½ cup packed brown sugar']));
      final item = row(result, 'Brown sugar');
      expect(item.quantity, '0.5');
      expect(item.unit, 'cups');
      expect(item.category, GroceryCategory.pantry);
    });

    test('"1½ cups flour" (no space before the fraction)', () {
      final result = parser.parse(recipeOf(['1½ cups flour']));
      final item = row(result, 'Flour');
      expect(item.quantity, '1.5');
      expect(item.unit, 'cups');
    });

    test('unicode and ascii forms add up together', () {
      final result = parser.parse(
          recipeOf(['1½ cups all-purpose flour', '½ cup flour']));
      expect(result.totalItems, 1);
      expect(row(result, 'Flour').quantity, '2');
    });
  });

  // ---------------------------------------------------------------------
  // Pattern 5 — quantity ranges.
  // ---------------------------------------------------------------------
  group('pattern 5 — ranges', () {
    test('"2-3 cloves garlic, minced" keeps the range as written', () {
      final result = parser.parse(recipeOf(['2-3 cloves garlic, minced']));
      final item = row(result, 'Garlic');
      expect(item.quantity, '2–3');
      expect(item.unit, 'cloves');
      expect(item.amountLabel, '2–3 cloves');
    });

    test('a range is never summed into an invented number', () {
      final result =
          parser.parse(recipeOf(['2-3 cloves garlic', '2 cloves garlic']));
      // "2" or "5" would both be fabrications, so the written range wins.
      expect(row(result, 'Garlic').quantity, '2–3');
    });
  });

  // ---------------------------------------------------------------------
  // Pattern 6 — size adjectives before the name.
  // ---------------------------------------------------------------------
  group('pattern 6 — size adjectives', () {
    test('"1 large onion, diced"', () {
      final result = parser.parse(recipeOf(['1 large onion, diced']));
      final item = row(result, 'Onion');
      expect(item.quantity, '1');
      expect(item.unit, '');
      expect(item.category, GroceryCategory.produce);
    });

    test('size adjectives never leak into names or break merging', () {
      final result =
          parser.parse(recipeOf(['2 medium carrots', '2 carrots', '1 lb large shrimp']));
      expect(row(result, 'Carrots').quantity, '4');
      expect(row(result, 'Shrimp').unit, 'lb');
    });
  });

  // ---------------------------------------------------------------------
  // Pattern 7 — plural/singular and synonym collisions.
  // ---------------------------------------------------------------------
  group('pattern 7 — plurals and synonyms', () {
    test('scallion / green onion / spring onion are one row', () {
      final result = parser.parse(recipeOf([
        '2 scallions, sliced',
        '1 green onion',
        '1 spring onion',
      ]));
      expect(result.totalItems, 1);
      final item = row(result, 'Scallions');
      expect(item.quantity, '4');
      expect(item.category, GroceryCategory.produce);
    });

    test('singular and plural spellings merge', () {
      final result = parser.parse(recipeOf(['1 carrot', '2 carrots']));
      expect(result.totalItems, 1);
      expect(row(result, 'Carrot').quantity, '3');
    });

    test('chickpeas, garbanzos and garbanzo beans are one row', () {
      final result = parser.parse(recipeOf([
        '1 can chickpeas, drained',
        '1 cup garbanzo beans',
        '2 cups garbanzos',
      ]));
      final chickpeas = row(result, 'Chickpeas');
      expect(chickpeas.category, GroceryCategory.pantry);
      expect(result.totalItems, 1, reason: namesOf(result).join(', '));
    });

    test('tomatoes and tomato are the same purchase', () {
      final result = parser.parse(recipeOf(['3 tomatoes, chopped', '2 tomato']));
      expect(result.totalItems, 1);
      expect(row(result, 'Tomatoes').quantity, '5');
    });
  });

  // ---------------------------------------------------------------------
  // Pattern 8 — no clear unit at all.
  // ---------------------------------------------------------------------
  group('pattern 8 — countable items', () {
    test('"3 eggs" and "1 lime"', () {
      final result = parser.parse(recipeOf(['3 eggs', '1 lime']));
      expect(row(result, 'Eggs').quantity, '3');
      expect(row(result, 'Eggs').unit, '');
      expect(row(result, 'Eggs').category, GroceryCategory.dairy);
      expect(row(result, 'Lime').quantity, '1');
      expect(row(result, 'Lime').category, GroceryCategory.produce);
      expect(result.reviewCount, 0);
    });

    test('spelled-out counts are understood', () {
      final result = parser.parse(recipeOf([
        'One large onion, halved and sliced',
        'Two 14.5-ounce cans diced tomatoes',
        'a pinch of saffron',
      ]));
      expect(row(result, 'Onion').quantity, '1');
      expect(row(result, 'Tomatoes').quantity, '2');
      expect(row(result, 'Tomatoes').amountLabel, '2 cans');
      expect(row(result, 'Saffron').quantity, '1');
      expect(row(result, 'Saffron').unit, 'pinch');
      expect(result.reviewCount, 0);
    });
  });

  // ---------------------------------------------------------------------
  // Extra messy lines, written in the phrasing style of published recipes.
  // ---------------------------------------------------------------------
  group('messy real-recipe lines', () {
    test('"4 skinless, boneless chicken thighs, trimmed" keeps its name', () {
      final result = parser.parse(
          recipeOf(['4 skinless, boneless chicken thighs, trimmed']));
      final item = row(result, 'Chicken thighs');
      expect(item.quantity, '4');
      expect(item.category, GroceryCategory.meat);
      expect(result.reviewCount, 0);
    });

    test('"1-2 tbsp honey, or to taste" keeps the range', () {
      final result =
          parser.parse(recipeOf(['1-2 tbsp honey, or to taste']));
      final item = row(result, 'Honey');
      expect(item.quantity, '1–2');
      expect(item.unit, 'tbsp');
      expect(item.category, GroceryCategory.pantry);
    });

    test('"14 oz package extra-firm tofu, drained and pressed"', () {
      final result = parser.parse(
          recipeOf(['14 oz package extra-firm tofu, drained and pressed']));
      final item = row(result, 'Tofu');
      expect(item.quantity, '14');
      expect(item.unit, 'oz');
      expect(item.category, GroceryCategory.pantry);
    });

    test('"2 tablespoons extra-virgin olive oil, divided"', () {
      final result = parser.parse(
          recipeOf(['2 tablespoons extra-virgin olive oil, divided']));
      final item = row(result, 'Olive oil');
      expect(item.quantity, '2');
      expect(item.unit, 'tbsp');
      expect(item.category, GroceryCategory.pantry);
    });

    test('"1 (28-ounce) can whole peeled tomatoes, drained"', () {
      final result = parser
          .parse(recipeOf(['1 (28-ounce) can whole peeled tomatoes, drained']));
      final item = row(result, 'Tomatoes');
      expect(item.quantity, '1');
      expect(item.unit, 'can');
    });

    test('"1 packet taco seasoning" is a spice-aisle item', () {
      final result = parser.parse(recipeOf(['1 packet taco seasoning']));
      final item = row(result, 'Taco seasoning');
      expect(item.unit, 'packet');
      expect(item.category, GroceryCategory.spices);
    });

    test('numbered and bulleted paste still parses', () {
      final result = parser.parse(recipeOf([
        '1. 2 cups baby spinach',
        '- 3 cloves garlic, minced',
        '• 1 tbsp soy sauce',
      ]));
      expect(row(result, 'Spinach').quantity, '2');
      expect(row(result, 'Garlic').quantity, '3');
      expect(row(result, 'Soy sauce').category, GroceryCategory.pantry);
      expect(result.reviewCount, 0);
    });
  });

  // ---------------------------------------------------------------------
  // Graceful degradation: the parser must never invent an amount.
  // ---------------------------------------------------------------------
  group('graceful degradation', () {
    test('two ingredients sharing one quantity are flagged verbatim', () {
      const line = '2 cups flour and 1 cup sugar';
      final result = parser.parse(recipeOf([line]));

      expect(result.totalItems, 1);
      expect(result.reviewCount, 1);
      final flagged = result.reviewItems.single;
      expect(flagged.name, line); // the recipe's own words, unchanged
      expect(flagged.quantity, ''); // nothing invented
      expect(flagged.unit, '');
      expect(flagged.category, GroceryCategory.other);
      expect(result.actionableItems, 0);
    });

    test('an unreadable comma tail is kept, not dropped', () {
      final result =
          parser.parse(recipeOf(['1 cup flour, plus 2 tbsp for dusting']));
      expect(namesOf(result), contains('Flour'));
      expect(result.reviewCount, 1);
      expect(result.reviewItems.single.name, 'plus 2 tbsp for dusting');
    });

    test('a second measured ingredient after a comma is never lost', () {
      final result = parser.parse(recipeOf(['1 cup milk, 2 tbsp butter']));
      expect(namesOf(result), ['Milk', 'Butter']);
      expect(result.reviewCount, 0);
    });

    test('structured noise (brackets, stray digits) is flagged', () {
      final result = parser.parse(recipeOf(['1½ cups flour (see note']));
      expect(result.reviewCount, 1);
      expect(row(result, '1½ cups flour (see note').needsReview, isTrue);
    });

    test('section headers are ignored, not listed as groceries', () {
      final result = parser.parse(recipeOf([
        'For the sauce:',
        '1 cup tomato sauce',
        'Ingredients',
        'Salt to taste',
      ]));
      expect(result.reviewCount, 0);
      expect(namesOf(result), ['Tomato sauce', 'Salt']);
    });

    test('an unknown aisle is not the same as an unparsed line', () {
      final result = parser.parse(recipeOf(['1 jar of mystery goo']));
      final item = row(result, 'Mystery goo');
      expect(item.category, GroceryCategory.other);
      expect(item.needsReview, isFalse);
      expect(item.quantity, '1');
      expect(item.unit, 'jar');
    });
  });

  // ---------------------------------------------------------------------
  // Aisle correctness for phrases a broader keyword would misfile.
  // ---------------------------------------------------------------------
  group('categorisation edge cases', () {
    test('phrases beat their broader keywords', () {
      expect(row(parser.parse(recipeOf(['1 can coconut milk'])), 'Coconut milk')
              .category,
          GroceryCategory.pantry);
      expect(
          row(parser.parse(recipeOf(['1 eggplant'])), 'Eggplant').category,
          GroceryCategory.produce);
      expect(
          row(parser.parse(recipeOf(['2 tbsp peanut butter'])), 'Peanut butter')
              .category,
          GroceryCategory.pantry);
      expect(
          row(parser.parse(recipeOf(['1/2 cup tomato sauce'])), 'Tomato sauce')
              .category,
          GroceryCategory.pantry);
      expect(
          row(parser.parse(recipeOf(['2 cups chicken broth'])), 'Chicken broth')
              .category,
          GroceryCategory.pantry);
    });

    test('stable ids: the same recipe always produces the same rows', () {
      final lines = [
        '2 cups spinach',
        '1½ cups flour',
        'Juice of 1 lemon',
        'Salt and pepper, to taste',
      ];
      final first = itemsOf(parser.parse(recipeOf(lines)));
      final second = itemsOf(parser.parse(recipeOf(lines)));

      expect(first.map((i) => i.id).toList(),
          second.map((i) => i.id).toList());
      expect(first.map((i) => i.name).toList(),
          second.map((i) => i.name).toList());
    });

    test('amountLabel pluralises containers only when it should', () {
      const one = GroceryItem(
        id: 'a',
        name: 'Chickpeas',
        category: GroceryCategory.pantry,
        quantity: '1',
        unit: 'can',
        checked: false,
      );
      const two = GroceryItem(
        id: 'b',
        name: 'Chickpeas',
        category: GroceryCategory.pantry,
        quantity: '2',
        unit: 'can',
        checked: false,
      );
      expect(one.amountLabel, '1 can');
      expect(two.amountLabel, '2 cans');
    });
  });
}
