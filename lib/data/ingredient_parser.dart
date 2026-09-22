import 'models.dart';

/// Rule-based, offline ingredient parser.
///
/// Strategies, in order:
///  1. Exact synonyms ("green onions" → "scallions") so merging works across
///     naming conventions found in scraped recipes.
///  2. Curated keyword rules (freshest matches first) covering the common
///     aisles: produce, dairy, meat, pantry, spices, baking.
///  3. Conservative fallback → [GroceryCategory.other] (never guesses badly).
///
/// Output is deterministic: same input always yields the same sections, which
/// keeps list animations stable across rebuilds.
class IngredientParser {
  const IngredientParser();

  GroceryListResult parse(Recipe recipe) {
    final buckets = <GroceryItem>[];
    final byKey = <String, int>{}; // normalized name → index in buckets

    for (final raw in recipe.ingredients) {
      final item = _parseLine(raw);
      if (item == null) continue;
      final key = _mergeKey(item.name);
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = buckets.length;
        buckets.add(item);
      } else {
        buckets[existing] = _merge(buckets[existing], item);
      }
    }

    // Group by category in enum order (produce first) → stable section order.
    final sections = <GrocerySection>[];
    for (final cat in GroceryCategory.values) {
      final items = buckets.where((i) => i.category == cat).toList();
      if (items.isNotEmpty) sections.add(GrocerySection(category: cat, items: items));
    }
    return GroceryListResult(sections: sections);
  }

  GroceryItem? _parseLine(String raw) {
    var line = raw.trim();
    if (line.isEmpty) return null;

    // Strip leading bullets/dashes and everything after instruction commas
    // ("2 cups spinach, chopped" → "2 cups spinach").
    line = line.replaceFirst(RegExp(r'^[-•*·\s]+'), '');
    final comma = line.indexOf(',');
    if (comma > 0) line = line.substring(0, comma);

    String quantity = '';
    String unit = '';

    final qtyMatch = RegExp(
      r'^(\d+[/\d.,\s]*\d|\d+|\d+\s*/\s*\d+)',
    ).firstMatch(line);
    if (qtyMatch != null) {
      quantity = _normalizeFraction(qtyMatch.group(1)!);
      line = line.substring(qtyMatch.end).trim();
    }

    final unitWords = <String, String>{
      'cups': 'cups', 'cup': 'cups', 'c': 'cups',
      'tbsp': 'tbsp', 'tablespoons': 'tbsp', 'tablespoon': 'tbsp',
      'tsp': 'tsp', 'teaspoons': 'tsp', 'teaspoon': 'tsp',
      'oz': 'oz', 'ounce': 'oz', 'ounces': 'oz',
      'lb': 'lb', 'lbs': 'lb', 'pound': 'lb', 'pounds': 'lb',
      'g': 'g', 'gram': 'g', 'grams': 'g',
      'kg': 'kg', 'ml': 'ml', 'l': 'L', 'litre': 'L', 'liter': 'L',
      'cloves': 'cloves', 'clove': 'cloves',
      'can': 'can', 'cans': 'can',
    };
    final unitMatch = RegExp(
      '^(${unitWords.keys.map(RegExp.escape).join('|')})\\.?\\b',
      caseSensitive: false,
    ).firstMatch(line);
    if (unitMatch != null) {
      unit = unitWords[unitMatch.group(1)!.toLowerCase()]!;
      line = line.substring(unitMatch.end).trim();
    }
    // Remove prep words so "finely chopped onion" and "onion" merge together.
    line = line
        .replaceAll(
            RegExp(
              r'\b(finely|roughly|coarsely|diced|chopped|minced|sliced|grated|'
              r'shredded|packed|heaping|level|large|small|medium|fresh|freshly|'
              r'dried|ground|toasted|softened|melted|crushed|drained|rinsed|'
              r'room temperature|optional|to taste)\b',
              caseSensitive: false,
            ),
            '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (line.isEmpty) return null;
    line = line[0].toUpperCase() + line.substring(1);
    line = _synonyms[line.toLowerCase()] ?? line;

    return GroceryItem(
      id: '${raw.hashCode}_${line.hashCode}',
      name: line,
      category: _categorize(line.toLowerCase()),
      quantity: quantity,
      unit: unit,
      checked: false,
    );
  }

  GroceryItem _merge(GroceryItem a, GroceryItem b) {
    final qA = double.tryParse(a.quantity) ?? 0;
    final qB = double.tryParse(b.quantity) ?? 0;
    final total = qA + qB;
    return a.copyWith(
      quantity: total > 0 ? _prettyNumber(total) : a.quantity,
      unit: a.unit.isEmpty ? b.unit : a.unit,
    );
  }  String _normalizeFraction(String raw) {
    final t = raw.trim();
    if (t.contains('/')) {
      final tokens = t.split(RegExp(r'\s+'));
      var total = 0.0;
      for (final token in tokens) {
        if (token.contains('/')) {
          final p = token.split('/');
          final n = int.tryParse(p[0]);
          final d = int.tryParse(p[1]);
          if (n == null || d == null || d == 0) return t; // bail: keep raw
          total += n / d;
        } else {
          final w = double.tryParse(token);
          if (w == null) return t; // bail: keep raw
          total += w;
        }
      }
      return _prettyNumber(total);
    }
    final unicode = <String, String>{
      '½': '0.5', '¼': '0.25', '¾': '0.75', '⅓': '0.33', '⅔': '0.67',
    };
    return unicode[t] ?? t;
  }

  String _prettyNumber(double n) =>
      n == n.roundToDouble() && n < 10 ? n.toInt().toString() : n.toStringAsFixed(1);

  String _mergeKey(String name) => name.toLowerCase().trim();

  GroceryCategory _categorize(String n) {
    for (final r in _rules) {
      if (r.keywords.any(n.contains)) return r.category;
    }
    return GroceryCategory.other;
  }

  static const Map<String, String> _synonyms = {
    'green onions': 'Scallions',
    'green onion': 'Scallions',
    'spring onions': 'Scallions',
    'bell pepper': 'Bell pepper',
    'bell peppers': 'Bell pepper',
    'capsicum': 'Bell pepper',
    'garlic cloves': 'Garlic',
    'garlic clove': 'Garlic',
    'clove garlic': 'Garlic',
    'coriander': 'Cilantro',
    'fresh coriander': 'Cilantro',
    'aubergine': 'Eggplant',
    'courgette': 'Zucchini',
  };

  // Narrowest rules first: "bell pepper" must beat the spice "pepper",
  // and "chili powder" must beat the produce "chili".
  static const List<_CatRule> _rules = [
    _CatRule(GroceryCategory.produce, ['bell']),
    _CatRule(GroceryCategory.spices, [
      'salt', 'pepper', 'cumin', 'paprika', 'turmeric', 'cinnamon', 'nutmeg',
      'oregano', 'thyme', 'rosemary', 'chili powder', 'cayenne', 'curry',
      'coriander powder', 'cardamom', 'cloves', 'bay leaf', 'chili flake',
      'vanilla', 'baking powder', 'baking soda', 'yeast',
    ]),
    _CatRule(GroceryCategory.dairy, [
      'milk', 'butter', 'cheese', 'parmesan', 'mozzarella', 'cheddar', 'feta',
      'yogurt', 'yoghurt', 'cream', 'egg', 'mayonnaise', 'mayo', 'ghee',
    ]),
    _CatRule(GroceryCategory.meat, [
      'chicken', 'beef', 'pork', 'bacon', 'sausage', 'turkey', 'lamb',
      'shrimp', 'salmon', 'fish', 'tuna', 'steak', 'ground meat', 'mince',
    ]),
    _CatRule(GroceryCategory.produce, [
      'onion', 'garlic', 'tomato', 'spinach', 'kale', 'lettuce', 'carrot',
      'potato', 'sweet potato', 'pepper', 'bell', 'broccoli', 'cauliflower',
      'zucchini', 'cucumber', 'celery', 'mushroom', 'scallion', 'leek',
      'cilantro', 'parsley', 'basil', 'mint', 'ginger', 'avocado', 'lime',
      'lemon', 'apple', 'banana', 'berry', 'berries', 'grape', 'mango',
      'pineapple', 'orange', 'cabbage', 'corn', 'peas', 'green bean',
      'eggplant', 'beet', 'radish', 'asparagus', 'chili', 'jalapeño',
    ]),
    _CatRule(GroceryCategory.pantry, [
      'flour', 'sugar', 'rice', 'pasta', 'noodle', 'bread', 'oil', 'olive oil',
      'vinegar', 'soy sauce', 'stock', 'broth', 'beans', 'chickpea', 'lentil',
      'quinoa', 'oats', 'honey', 'maple', 'peanut butter', 'tomato paste',
      'coconut milk', 'tortilla', 'tortillas', 'salsa', 'mustard', 'ketchup',
      'wraps', 'couscous', 'cornstarch', 'corn starch', 'chocolate', 'cocoa',
    ]),
  ];
}

class _CatRule {
  const _CatRule(this.category, this.keywords);
  final GroceryCategory category;
  final List<String> keywords;
}

class GroceryListResult {
  const GroceryListResult({required this.sections});
  final List<GrocerySection> sections;

  int get totalItems =>
      sections.fold(0, (sum, s) => sum + s.items.length);
}
