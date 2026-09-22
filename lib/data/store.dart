import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'ingredient_parser.dart';
import 'models.dart';
import 'seed_recipes.dart';

/// Thin persistence layer over Hive. We store plain JSON-ish maps, so there
/// are no generated TypeAdapters — dropping in MMKV/SQLite later means
/// rewriting only this class.
class GroceryStore {
  static const _recipesBox = 'recipes';
  static const _listBox = 'grocery_list';
  static const _settingsBox = 'settings';

  bool _initialized = false;

  /// [storagePath] overrides the default app-documents directory — used by
  /// tests, since platform plugins aren't available in the test env.
  Future<void> init({String? storagePath}) async {
    if (_initialized) return;
    if (storagePath != null) {
      Hive.init(storagePath);
    } else {
      await Hive.initFlutter();
    }
    await Hive.openBox(_recipesBox);
    await Hive.openBox(_listBox);
    await Hive.openBox(_settingsBox);
    _initialized = true;
  }

  // ---- Recipes ----

  Future<List<Recipe>> loadRecipes() async {
    final box = Hive.box(_recipesBox);
    if (box.isEmpty) {
      // First launch (offline): seed built-in recipes.
      for (final r in seedRecipes) {
        await box.put(r.id, r.toMap());
      }
    }
    return box.values
        .map((m) => Recipe.fromMap(Map<dynamic, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> saveRecipe(Recipe recipe) =>
      Hive.box(_recipesBox).put(recipe.id, recipe.toMap());

  // ---- Generated grocery list ----

  Future<void> saveList(GroceryListResult result) async {
    final box = Hive.box(_listBox);
    await box.clear();
    final entries = <String, Map<String, dynamic>>{};
    for (final section in result.sections) {
      for (final item in section.items) {
        entries[item.id] = item.toMap();
      }
    }
    await box.putAll(entries);
  }

  Future<GroceryListResult> loadList(IngredientParser parser) async {
    final box = Hive.box(_listBox);
    final items = box.values
        .map((m) => GroceryItem.fromMap(Map<dynamic, dynamic>.from(m as Map)))
        .toList();

    // Rebuild sections in canonical category order; item order stays as saved.
    final sections = <GrocerySection>[];
    for (final cat in GroceryCategory.values) {
      final inCat = items.where((i) => i.category == cat).toList();
      if (inCat.isNotEmpty) {
        sections.add(GrocerySection(category: cat, items: inCat));
      }
    }
    return GroceryListResult(sections: sections);
  }

  Future<void> clearList() => Hive.box(_listBox).clear();

  Future<void> setItemChecked(String itemId, bool checked) =>
      Hive.box(_listBox).update(
        itemId,
        (m) => {...Map<dynamic, dynamic>.from(m as Map), 'checked': checked},
      );

  Future<void> removeItem(String itemId) => Hive.box(_listBox).delete(itemId);

  Future<void> saveItem(GroceryItem item) =>
      Hive.box(_listBox).put(item.id, item.toMap());

  // ---- Settings ----

  Future<bool> loadDarkMode() async =>
      Hive.box(_settingsBox).get('dark', defaultValue: false) as bool;

  Future<void> saveDarkMode(bool dark) =>
      Hive.box(_settingsBox).put('dark', dark);
}

/// Single app-wide observable state, provided via InheritedNotifier.
///
/// Design notes:
///  • Only [Listenable] + a handful of fields — no external state package.
///  • checkedIdSet is rebuilt only when membership actually changes, so list
///    rows don't rebuild on every keystroke/toggle elsewhere.
///  • All persistence is fire-and-forget futures; the UI never awaits disk.
class AppController extends ChangeNotifier {
  AppController({required this.store, required this.parser});

  final GroceryStore store;
  final IngredientParser parser;

  List<Recipe> recipes = [];
  GroceryListResult? list;
  bool darkMode = false;

  bool get hasList => list != null && list!.totalItems > 0;
  int get checkedCount =>
      list?.sections.fold(0, (s, sec) => s + sec.items.where((i) => i.checked).length) ?? 0;
  int get totalCount => list?.totalItems ?? 0;
  double get progress => totalCount == 0 ? 0 : checkedCount / totalCount;

  Set<String> _checkedIds = const {};
  Set<String> get checkedIdSet => _checkedIds;

  Future<void> bootstrap({String? storagePath}) async {
    await store.init(storagePath: storagePath);
    recipes = await store.loadRecipes();
    darkMode = await store.loadDarkMode();
    list = await store.loadList(parser);
    _rebuildChecked();
    notifyListeners();
  }

  /// Parse recipe → structured categorized list, persist, and return it so
  /// the caller can trigger the transition animation with fresh data.
  Future<GroceryListResult> convertRecipe(Recipe recipe) async {
    final result = parser.parse(recipe);
    list = result;
    await store.saveList(result);
    _rebuildChecked();
    notifyListeners();
    return result;
  }

  /// Persists a user-created recipe and reveals it in the library.
  Future<void> addRecipe(Recipe recipe) async {
    await store.saveRecipe(recipe);
    recipes = [...recipes, recipe];
    notifyListeners();
  }

  Future<void> toggleItem(String id) async {
    final current = _checkedIds.contains(id);
    if (current) {
      _checkedIds = {..._checkedIds}..remove(id);
    } else {
      _checkedIds = {..._checkedIds, id};
    }
    notifyListeners();
    await store.setItemChecked(id, !current); // fire-and-forget write
  }

  Future<void> deleteItem(String id) async {
    if (list == null) return;
    final sections = list!.sections
        .map((s) => GrocerySection(
              category: s.category,
              items: s.items.where((i) => i.id != id).toList(),
            ))
        .where((s) => s.items.isNotEmpty)
        .toList();
    list = GroceryListResult(sections: sections);
    notifyListeners();
    await store.removeItem(id);
  }

  /// Undo support: re-insert a previously dismissed item.
  Future<void> restoreItem(GroceryItem item) async {
    if (list == null) {
      list = GroceryListResult(sections: [
        GrocerySection(category: item.category, items: [item]),
      ]);
    } else {
      final sections = [...list!.sections];
      final idx = sections.indexWhere((s) => s.category == item.category);
      if (idx == -1) {
        sections.add(GrocerySection(category: item.category, items: [item]));
      } else {
        final s = sections[idx];
        sections[idx] = GrocerySection(
          category: s.category,
          items: [...s.items, item],
        );
      }
      // Keep sections in canonical enum order after insertion.
      sections.sort((a, b) => a.category.index.compareTo(b.category.index));
      list = GroceryListResult(sections: sections);
    }
    _rebuildChecked();
    notifyListeners();
    await store.saveItem(item);
  }

  Future<void> resetChecked() async {
    if (list == null) return;
    _checkedIds = const {};
    final sections = list!.sections
        .map((s) => GrocerySection(
              category: s.category,
              items: s.items
                  .map((i) => i.copyWith(checked: false))
                  .toList(),
            ))
        .toList();
    list = GroceryListResult(sections: sections);
    notifyListeners();
    await store.saveList(list!);
  }

  Future<void> clearAll() async {
    list = null;
    _checkedIds = const {};
    notifyListeners();
    await store.clearList();
  }

  Future<void> toggleDarkMode() async {
    darkMode = !darkMode;
    notifyListeners();
    await store.saveDarkMode(darkMode);
  }

  void _rebuildChecked() {
    _checkedIds = list == null
        ? const {}
        : list!.sections
            .expand((s) => s.items)
            .where((i) => i.checked)
            .map((i) => i.id)
            .toSet();
  }
}
