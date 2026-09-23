import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pantry_pilot/data/emoji_suggest.dart';
import 'package:pantry_pilot/data/ingredient_parser.dart';
import 'package:pantry_pilot/data/models.dart';
import 'package:pantry_pilot/data/store.dart';
import 'package:pantry_pilot/main.dart';

import 'helpers.dart';

void main() {
  group('suggestEmoji (offline keyword map)', () {
    test('maps dish keywords to glyphs', () {
      expect(suggestEmoji('Creamy Garlic Pasta'), '🍝');
      expect(suggestEmoji('Chicken Fajita Bowl'), '🌯');
      expect(suggestEmoji('Weeknight Pad Thai'), '🍜');
      expect(suggestEmoji('Classic Beef Tacos'), '🌮');
      expect(suggestEmoji('Mediterranean Greek Salad'), '🥗');
      expect(suggestEmoji('Lemon Herb Salmon'), '🐟');
      expect(suggestEmoji('Margherita Flatbread'), '🍕');
    });

    test('specific dishes beat generic ingredients', () {
      expect(suggestEmoji('Eggplant Parmigiana'), '🍆');
      expect(suggestEmoji('Lasagna al Forno'), '🍝');
      expect(suggestEmoji('Chicken Curry'), '🍛');
    });

    test('is case- and punctuation-insensitive', () {
      expect(suggestEmoji('GRANDMA\'S SOUP!'), '🍲');
      expect(suggestEmoji('smoothie bowl'), '🥤');
    });

    test('falls back to a neutral plate for unknown titles', () {
      expect(suggestEmoji('Sunday Special'), defaultRecipeEmoji);
      expect(suggestEmoji(''), defaultRecipeEmoji);
    });
  });

  group('user recipe lifecycle', () {
    test('add then delete persists across controllers on the same store',
        () async {
      final store = GroceryStore(inMemory: true);
      final controller = AppController(
        store: store,
        parser: const IngredientParser(),
      );
      await controller.bootstrap();
      expect(controller.recipes.length, 10); // seeds

      await controller.addRecipe(const Recipe(
        id: 'user_test_rice',
        title: 'Test Rice Bowl',
        emoji: '🍚',
        ingredients: ['1 cup rice', '2 tbsp soy sauce'],
      ));
      expect(controller.recipes.length, 11);

      await controller.deleteRecipe('user_test_rice');
      expect(controller.recipes.length, 10);
      expect(controller.recipes.any((r) => r.id == 'user_test_rice'), isFalse);

      // Reopening the store must not resurrect the deleted recipe, and adding
      // new ones must not disturb the built-in catalog.
      final reopened = AppController(
        store: store,
        parser: const IngredientParser(),
      );
      await reopened.bootstrap();
      expect(reopened.recipes.length, 10);
      expect(reopened.recipes.any((r) => r.id == 'user_test_rice'), isFalse);
    });
  });

  testWidgets('studio: auto emoji → live aisle preview → saves to library',
      (tester) async {
    final controller = makeController();
    await controller.bootstrap();
    await pumpIntoHome(tester, RecipePilotApp(controller: controller));

    // Home → the beam-ringed "New recipe" action.
    await tester.tap(find.byKey(const ValueKey('new_recipe_fab')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));

    // Typing the title suggests an emoji offline — no picker needed.
    await tester.enterText(
        find.byKey(const ValueKey('recipe_title')), 'Creamy Garlic Pasta');
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('🍝'), findsWidgets);

    // The REAL parser runs as you type: each line shows its aisle.
    await tester.enterText(
        find.byKey(const ValueKey('ing_0')), '2 cups spinach, chopped');
    await tester.pump(const Duration(milliseconds: 80));
    await tester.enterText(
        find.byKey(const ValueKey('ing_1')), '1 cup parmesan cheese, grated');
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Produce'), findsOneWidget);
    expect(find.text('Dairy & Eggs'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save_recipe')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final saved =
        controller.recipes.where((r) => r.title == 'Creamy Garlic Pasta');
    expect(saved.length, 1);
    expect(saved.single.emoji, '🍝');
    expect(saved.single.ingredients.length, 2);
    // Back home, the save is confirmed.
    expect(find.text('Saved “Creamy Garlic Pasta”'), findsOneWidget);
    await flushTimers(tester);
  });

  testWidgets('studio: pasting a block splits it into ingredient rows',
      (tester) async {
    final controller = makeController();
    await controller.bootstrap();
    await pumpIntoHome(tester, RecipePilotApp(controller: controller));

    await tester.tap(find.byKey(const ValueKey('new_recipe_fab')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Paste a block'));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.enterText(
      find.byKey(const ValueKey('bulk_paste')),
      '2 cups spinach, chopped\n'
      '4 cloves garlic, minced\n'
      '1/2 cup parmesan cheese',
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Split into 3 ingredients'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('split_bulk')));
    await tester.pump(const Duration(milliseconds: 250));

    // Rows mode came back, pre-filled and editable.
    expect(find.byKey(const ValueKey('ing_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('ing_2')), findsOneWidget);
    expect(find.text('2 cups spinach, chopped'), findsOneWidget);
    await flushTimers(tester);
  });
}
