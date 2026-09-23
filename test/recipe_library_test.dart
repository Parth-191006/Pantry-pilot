import 'package:flutter_test/flutter_test.dart';

import 'package:pantry_pilot/data/ingredient_parser.dart';
import 'package:pantry_pilot/data/models.dart';
import 'package:pantry_pilot/data/store.dart';

void main() {
  AppController makeApp() => AppController(
        store: GroceryStore(inMemory: true),
        parser: const IngredientParser(),
      );

  group('recipe catalog & filters', () {
    test('ships 10 diverse seeded recipes across cuisines', () async {
      final app = makeApp();
      await app.bootstrap();

      expect(app.recipes.length, 10);
      final tags = app.recipes.expand((r) => r.tags).toSet();
      for (final cuisine in ['Italian', 'Mexican', 'Asian', 'Mediterranean']) {
        expect(tags.contains(cuisine), isTrue, reason: 'missing $cuisine');
      }
      // Every seed carries time metadata for the card row.
      expect(app.recipes.every((r) => r.minutes != null), isTrue);
    });

    test('filter pills narrow the list and All restores it', () async {
      final app = makeApp();
      await app.bootstrap();

      expect(app.activeTag, 'All');
      expect(app.visibleRecipes.length, 10);

      app.setActiveTag('Vegetarian');
      expect(app.activeTag, 'Vegetarian');
      expect(
        app.visibleRecipes,
        everyElement(
          predicate<Recipe>((r) => r.tags.contains('Vegetarian')),
        ),
      );
      expect(app.visibleRecipes.length, lessThan(10));

      app.setActiveTag('All');
      expect(app.visibleRecipes.length, 10);
    });

    test('active filter with no matches yields an empty shelf (header 0)',
        () async {
      final app = makeApp();
      await app.bootstrap();
      app.setActiveTag('Desserts');
      expect(app.visibleRecipes, isEmpty);
      app.setActiveTag(null); // null is accepted and means All
      expect(app.visibleRecipes.length, 10);
    });

    test('availableTags prioritizes the curated four, then alphabetical',
        () async {
      final app = makeApp();
      await app.bootstrap();
      final tags = app.availableTags;
      expect(
        tags.take(4),
        ['Quick & Easy', 'Dinner', 'Vegetarian', 'High Protein'],
      );
      expect(
        tags.toSet(),
        containsAll(['Italian', 'Mexican', 'Asian', 'Mediterranean']),
      );
    });
  });

  group('seed merge on existing installs', () {
    test('new seeds appear; old built-ins refresh; user recipes preserved',
        () async {
      final store = GroceryStore(inMemory: true);

      // Simulate an install from before the metadata era: a built-in saved
      // without minutes/tags keys, plus a user-pasted recipe.
      await store.debugPutRaw('recipes', 'r_garlic_pasta', <dynamic, dynamic>{
        'id': 'r_garlic_pasta',
        'title': 'Garlic Butter Pasta',
        'emoji': '🍝',
        'ingredients': ['8 oz pasta'],
      });
      await store.debugPutRaw('recipes', 'r_user_custom', <dynamic, dynamic>{
        'id': 'r_user_custom',
        'title': 'Grandma Soup',
        'emoji': '🍲',
        'ingredients': ['3 cups broth'],
      });

      final app = AppController(store: store, parser: const IngredientParser());
      await app.bootstrap();

      // New seed recipes arrived alongside the two stored ones.
      expect(app.recipes.length, 11);

      // The old built-in was refreshed with the new metadata.
      final pasta = app.recipes.firstWhere((r) => r.id == 'r_garlic_pasta');
      expect(pasta.minutes, 20);
      expect(pasta.tags, contains('Italian'));

      // The user-pasted recipe survived untouched.
      final user = app.recipes.firstWhere((r) => r.id == 'r_user_custom');
      expect(user.title, 'Grandma Soup');
      expect(user.minutes, isNull);
    });
  });
}
