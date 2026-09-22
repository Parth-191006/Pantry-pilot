import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'ingredient_parser.dart';
import 'models.dart';
import 'seed_recipes.dart';

/// Thin persistence layer over Hive. We store plain JSON-ish maps, so there
/// are no generated TypeAdapters — dropping in MMKV/SQLite later means
/// rewriting only this class.
///
/// Pass [GroceryStore.new] with `inMemory: true` for widget tests: real
/// dart:io file I/O doesn't play well with the fake-async test zone.
class GroceryStore {
  GroceryStore({bool inMemory = false}) : _inMemory = inMemory;

  static const _recipesBox = 'recipes';
  static const _listBox = 'grocery_list';
  static const _settingsBox = 'settings';

  final bool _inMemory;
  final _memoryBoxes = <String, Map<dynamic, dynamic>>{};

  bool _initialized = false;

  /// [storagePath] overrides the default app-documents directory.
  Future<void> init({String? storagePath}) async {
    if (_initialized) return;
    if (_inMemory) {
      _initialized = true;
      return;
    }
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

  Iterable<dynamic> _values(String name) =>
      _inMemory ? _mem(name).values : Hive.box(name).values;

  Map<dynamic, dynamic> _mem(String name) =>
      _memoryBoxes.putIfAbsent(name, () => <dynamic, dynamic>{});

  // ---- Recipes ----

  Future<List<Recipe>> loadRecipes() async {
    if (_values(_recipesBox).isEmpty) {
      // First launch (offline): seed built-in recipes.
      for (final r in seedRecipes) {
        await _put(_recipesBox, r.id, r.toMap());
      }
    }
    return _values(_recipesBox)
        .map((m) => Recipe.fromMap(Map<dynamic, dynamic>.from(m as Map)))
        .toList();
  }

  Future<void> saveRecipe(Recipe recipe) =>
      _put(_recipesBox, recipe.id, recipe.toMap());

  // ---- Generated grocery list ----

  Future<void> saveList(GroceryListResult result) async {
    await _clear(_listBox);
    final entries = <String, Map<String, dynamic>>{};
    for (final section in result.sections) {
      for (final item in section.items) {
        entries[item.id] = item.toMap();
      }
    }
    await _putAll(_listBox, entries);
  }

  Future<GroceryListResult> loadList(IngredientParser parser) async {
    final items = _values(_listBox)
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

  Future<void> clearList() => _clear(_listBox);

  Future<void> setItemChecked(String itemId, bool checked) =>
      _update(_listBox, itemId,
          (m) => {...Map<dynamic, dynamic>.from(m as Map), 'checked': checked});

  Future<void> removeItem(String itemId) => _delete(_listBox, itemId);

  Future<void> saveItem(GroceryItem item) =>
      _put(_listBox, item.id, item.toMap());

  // ---- Settings ----

  Future<bool> loadDarkMode() async =>
      _get(_settingsBox, 'dark', false) as bool;

  Future<void> saveDarkMode(bool dark) => _put(_settingsBox, 'dark', dark);

  // ---- Unified Hive / in-memory primitives ----

  Future<void> _put(String name, dynamic key, dynamic value) async {
    if (_inMemory) {
      _mem(name)[key] = value;
    } else {
      await Hive.box(name).put(key, value);
    }
  }

  Future<void> _putAll(String name, Map<dynamic, dynamic> entries) async {
    if (_inMemory) {
      _mem(name).addAll(entries);
    } else {
      await Hive.box(name).putAll(entries);
    }
  }

  Future<void> _clear(String name) async {
    if (_inMemory) {
      _mem(name).clear();
    } else {
      await Hive.box(name).clear();
    }
  }

  Future<void> _update(
      String name, dynamic key, dynamic Function(dynamic) callback) async {
    if (_inMemory) {
      final box = _mem(name);
      box[key] = callback(box[key]);
    } else {
      // Box.update() isn't available in hive 2.x — get+put is equivalent.
      final box = Hive.box(name);
      await box.put(key, callback(box.get(key)));
    }
  }

  Future<void> _delete(String name, dynamic key) async {
    if (_inMemory) {
      _mem(name).remove(key);
    } else {
      await Hive.box(name).delete(key);
    }
  }

  dynamic _get(String name, dynamic key, dynamic defaultValue) =>
      _inMemory ? (_mem(name)[key] ?? defaultValue) : Hive.box(name).get(key, defaultValue: defaultValue);
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

  int get checkedCount {
    final l = list;
    if (l == null) return 0;
    return l.sections.fold(0, (s, sec) => s + sec.items.where((i) => i.checked).length);
  }

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
