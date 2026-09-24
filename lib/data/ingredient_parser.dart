import 'models.dart';

/// Rule-based, offline ingredient parser.
///
/// Deterministic by construction — no network, no model, no clock, no random
/// ids: the same recipe text always yields the same sections and the same
/// persisted ids, so animations and check-off state stay stable.
///
/// Pipeline, per line (every stage is a small rule you can point a test at):
///   1. cleanup   — bullets, "1." numbering, section headers
///   2. splitting — "," segments (a tail with its own count is a 2nd item) and
///                  bare "and" joins ("salt and pepper" → two staples)
///   3. amount    — 2, 1/2, 1 1/2, ½, 1½, 1.5, and 2-3 ranges
///   4. container — "1 (14 oz) can", "2 15-ounce cans", "1 large onion"
///   5. unit      — curated alias table → one canonical spelling
///   6. name      — prep/size words stripped, synonyms folded, merged by
///                  singular key so "1 carrot" + "2 carrots" is one row
///   7. confidence— a line whose leftovers still contain digits/brackets, or
///                  two ingredients sharing one quantity, becomes a
///                  [GroceryItem.needsReview] row carrying the untouched text
///                  instead of a silently wrong amount.
class IngredientParser {
  const IngredientParser();

  GroceryListResult parse(Recipe recipe) {
    final buckets = <GroceryItem>[];
    final byKey = <String, int>{}; // merge key → index in buckets

    for (final raw in recipe.ingredients) {
      for (final item in _itemsForLine(raw)) {
        final key =
            item.needsReview ? 'review:${item.id}' : _mergeKey(item.name);
        final existing = byKey[key];
        if (existing == null) {
          byKey[key] = buckets.length;
          buckets.add(item);
        } else {
          buckets[existing] = _merge(buckets[existing], item);
        }
      }
    }

    // Group by category in enum order (produce first) → stable section order.
    final sections = <GrocerySection>[];
    for (final cat in GroceryCategory.values) {
      final items = buckets.where((i) => i.category == cat).toList();
      if (items.isNotEmpty) {
        sections.add(GrocerySection(category: cat, items: items));
      }
    }
    return GroceryListResult(sections: sections);
  }

  /// One recipe line → zero, one or many grocery items.
  ///
  /// The try/catch is deliberate: parsing runs on text a user pasted from
  /// anywhere, so a hostile line must degrade into a review row — never into a
  /// crash and never into a silent drop.
  List<GroceryItem> _itemsForLine(String raw) {
    try {
      return _parseLine(raw);
    } catch (_) {
      final review = _reviewItem(raw);
      return review == null ? const <GroceryItem>[] : [review];
    }
  }

  // ---- Stage 1: cleanup and header detection -----------------------------

  List<GroceryItem> _parseLine(String raw) {
    var line = raw.trim();
    if (line.isEmpty) return const [];
    // Bullets/dashes, then a leading "1." / "2)" list number.
    line = line.replaceFirst(RegExp(r'^[-–—•*·‣▪\s]+'), '');
    line = line.replaceFirst(RegExp(r'^\d+\s*[.)]\s+'), '').trim();
    if (line.isEmpty) return const [];

    // Section headers ("For the sauce:", "Ingredients") belong to the recipe
    // prose, not to a shopping list. A line that starts with a quantity is
    // never treated as a header.
    if (_hasLeadingAmount(line) == false && _headerLine.hasMatch(line)) {
      return const [];
    }

    var items = <GroceryItem>[];
    for (final segment in _splitSegments(line)) {
      if (segment.reviewOnly) {
        final review = _reviewItem(segment.text);
        if (review != null) items.add(review);
        continue;
      }
      items.addAll(_parseSegment(segment.text, raw));
    }

    // Not one usable row came out of the segments: the commas probably joined
    // adjectives rather than prep text ("4 skinless, boneless chicken
    // thighs"). Retry the whole line as a single run-on name before flagging.
    if (line.contains(',') && !items.any((i) => !i.needsReview)) {
      final retry = _parseSingle(line, raw);
      if (retry != null && !retry.needsReview) items = <GroceryItem>[retry];
    }

    // Nothing survived: hand the original line to the user rather than
    // pretending we understood it.
    if (items.isEmpty) {
      final review = _reviewItem(raw);
      return review == null ? const [] : [review];
    }
    return items;
  }

  static final RegExp _headerLine = RegExp(
    r'^(?:ingredients?|directions?|instructions?|method|steps?|notes?|you\s+will\s+need)\b|:$',
    caseSensitive: false,
  );

  static final RegExp _joinedIngredients =
      RegExp(r'\s(?:and|&|plus)\s', caseSensitive: false);

  // ---- Stage 2: splitting -------------------------------------------------

  /// Splits one line into ingredient segments.
  ///
  /// Commas usually introduce prep text ("2 cups spinach, chopped") which is
  /// dropped, but a tail carrying its own count is a second ingredient and
  /// must not vanish ("1 cup milk, 2 tbsp butter"). A tail like "plus 2 tbsp
  /// for dusting" is neither cleanly parsable nor droppable — it is kept as a
  /// review row so the user sees it.
  List<_Segment> _splitSegments(String line) {
    final parts = line.split(',');
    final out = <_Segment>[_Segment(parts.first.trim())];
    for (final part in parts.skip(1)) {
      final tail = part.trim();
      if (tail.isEmpty) continue;
      if (_hasLeadingAmount(tail)) {
        out.add(_Segment(tail));
      } else if (RegExp(r'^(?:plus|and|or|then)\b', caseSensitive: false)
              .hasMatch(tail) &&
          RegExp(r'\d').hasMatch(tail)) {
        out.add(_Segment(tail, reviewOnly: true));
      }
      // Otherwise it is prep text ("chopped", "to taste", "divided").
    }
    return out.where((s) => s.text.isNotEmpty).toList(growable: false);
  }

  List<GroceryItem> _parseSegment(String segment, String rawLine) {
    final andParts = _splitAnd(segment);
    if (andParts == null) {
      final item = _parseSingle(segment, rawLine);
      return item == null ? const [] : [item];
    }
    final out = <GroceryItem>[];
    for (final part in andParts) {
      final item = _parseSingle(part, rawLine);
      if (item != null) out.add(item);
    }
    return out;
  }

  /// "salt and pepper" → ["salt", "pepper"], so one line of staples becomes two
  /// rows. Returns null whenever splitting would be unsafe:
  ///  • the line carries a quantity (which half would own it?), or
  ///  • either half isn't recognisable on its own — "sweet and sour sauce" and
  ///    "macaroni and cheese" are single products, not two ingredients.
  List<String>? _splitAnd(String line) {
    if (_digitLike.hasMatch(line)) return null;
    final m = RegExp(r'^(.*?)\s+(?:and|&)\s+(.*)$', caseSensitive: false)
        .firstMatch(line);
    if (m == null) return null;
    final a = m.group(1)!.trim();
    final b = m.group(2)!.trim();
    if (!_plausibleName(a) || !_plausibleName(b)) return null;
    if (_categorize(a.toLowerCase()) == GroceryCategory.other) return null;
    if (_categorize(b.toLowerCase()) == GroceryCategory.other) return null;
    return [a, b];
  }

  // ---- Stage 3-8: a single ingredient ------------------------------------

  GroceryItem? _parseSingle(String segment, String rawLine) {
    var line = segment.trim();
    if (line.isEmpty) return null;

    // 3a. Parentheticals — usually a tin size or drained weight
    //     ("1 (14 oz) can diced tomatoes"). Keep the numbers, drop the words.
    final parens = <String>[];
    line = line
        .replaceAllMapped(RegExp(r'\(([^)]*)\)'), (m) {
          parens.add(m.group(1)!.trim());
          return ' ';
        })
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 3b. "Juice of 1 lemon" / "Zest of 1 orange" — the count trails the part
    //     being used. Skip the verb so what you buy is the fruit itself.
    line = line
        .replaceFirst(
          RegExp(
            r'^(?:the\s+)?(?:juice|zest|rind|peel|flesh|pulp)\s+(?:of|from)\s+'
            r'(?:a|an|one|half\s+an?|couple\s+of)?\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // 3c. Leading amount: 2, 1/2, 1 1/2, ½, 1½, 1.5, 2-3.
    var quantity = '';
    var unit = '';
    final amount = _takeAmount(line);
    if (amount != null) {
      quantity = amount.label;
      line = amount.rest.trim();
    }

    // 3d. Size and package descriptors between the count and the unit:
    //     "1 large onion", "2 15-ounce cans black beans", "1 8-oz pkg ...".
    line = line.replaceFirst(_leadingSize, '').trim();
    line = line.replaceFirst(_packageSize, '').trim();
    line = line.replaceFirst(_leadingSize, '').trim();

    // 3e. Unit (whole-word table lookup — never a substring guess).
    final takenUnit = _takeUnit(line);
    if (takenUnit != null) {
      unit = takenUnit.value;
      line = takenUnit.rest.trim();
    }
    // "14 oz package extra-firm tofu": after a real measure, a container word
    // describes the packaging, not the ingredient.
    if (unit.isNotEmpty && !_containerUnits.contains(unit)) {
      line = line.replaceFirst(_trailingContainer, '').trim();
    }
    // "... of ..." connector: "1 jar of honey", "3 cloves of garlic".
    line = line.replaceFirst(RegExp(r'^(?:of|de)\s+', caseSensitive: false), '').trim();

    // 3f. A bare "(14 oz)" is the only measurement the line gives.
    if (quantity.isEmpty && unit.isEmpty && parens.isNotEmpty) {
      final inner = _takeAmount(parens.first);
      if (inner != null) {
        quantity = inner.label;
        final innerUnit = _takeUnit(inner.rest);
        if (innerUnit != null) unit = innerUnit.value;
      }
    }

    // 9a. Two ingredients sharing one quantity ("2 cups flour and 1 cup sugar")
    //     cannot be divided honestly — refuse to guess.
    if (_joinedIngredients.hasMatch(line)) return _reviewItem(segment);

    // 3g. Prep/state words ("finely chopped", "packed", "room temperature",
    //     "to taste") — stripping them lets "1 onion, diced" and "onion" merge.
    var name = line
        .replaceAll(',', ' ')
        .replaceAll(_prepWords, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    name = name
        .replaceFirst(RegExp(r'^[^A-Za-z0-9]+'), '')
        .replaceFirst(RegExp(r'[^A-Za-z0-9]+$'), '');
    if (name.isEmpty) return _reviewItem(rawLine);

    final display = _capitalize(name);
    final canonical = _synonyms[display.toLowerCase()] ??
        _synonyms[_singularize(display.toLowerCase())] ??
        display;

    // 9b. Confidence: numbers, brackets or fraction glyphs left in the *name*
    //     mean we never really understood the line. Flag it instead of
    //     shipping a wrong amount.
    if (_leftoverNoise.hasMatch(canonical) || _letterCount(canonical) < 2) {
      return _reviewItem(rawLine);
    }

    return GroceryItem(
      id: 'i${_contentId(_mergeKey(canonical))}',
      name: canonical,
      category: _categorize(canonical.toLowerCase()),
      quantity: quantity,
      unit: unit,
      checked: false,
    );
  }

  /// Row shown under "Needs review": the original text is the name, so nothing
  /// is lost or invented. Returns null for blank text and for lines the parser
  /// deliberately ignores (headers), which would just be noise in the UI.
  GroceryItem? _reviewItem(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (_headerLine.hasMatch(text)) return null;
    return GroceryItem(
      id: 'r${_contentId(text)}',
      name: text,
      category: GroceryCategory.other,
      quantity: '',
      unit: '',
      checked: false,
      needsReview: true,
    );
  }

  // ---- Amounts ------------------------------------------------------------

  static const Map<String, double> _wordAmounts = {
    'a': 1, 'an': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'half': 0.5,
  };

  static const Map<String, double> _fractionValues = {
    '¼': 0.25, '½': 0.5, '¾': 0.75,
    '⅐': 1 / 7, '⅑': 1 / 9, '⅒': 0.1,
    '⅓': 1 / 3, '⅔': 2 / 3,
    '⅕': 0.2, '⅖': 0.4, '⅗': 0.6, '⅘': 0.8,
    '⅙': 1 / 6, '⅚': 5 / 6,
    '⅛': 0.125, '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
  };

  static final RegExp _fractionChars =
      RegExp('[${_fractionValues.keys.join()}]');

  static final RegExp _digitLike = RegExp(r'\d');

  /// Anything that would leak into a name if a rule missed it.
  static final RegExp _leftoverNoise =
      RegExp('[0-9${_fractionValues.keys.join()}(),\\[\\]]');

  /// Parses the amount at the head of [line], newest rules last so the most
  /// specific form wins ("1 1/2" must not be read as "1").
  _Amount? _takeAmount(String line) {
    final t = line.trim();
    if (t.isEmpty) return null;

    var m = RegExp('^(\\d+)\\s*([${_fractionValues.keys.join()}])').firstMatch(t);
    if (m != null) {
      return _Amount(
        _formatAmount(
            double.parse(m.group(1)!) + _fractionValues[m.group(2)!]!),
        t.substring(m.end),
      );
    }

    m = RegExp(r'^(\d+)\s+(\d+)\s*/\s*(\d+)').firstMatch(t);
    if (m != null) {
      final d = int.parse(m.group(3)!);
      if (d != 0) {
        return _Amount(
          _formatAmount(int.parse(m.group(1)!) + int.parse(m.group(2)!) / d),
          t.substring(m.end),
        );
      }
    }

    m = RegExp(r'^(\d+)\s*/\s*(\d+)').firstMatch(t);
    if (m != null) {
      final d = int.parse(m.group(2)!);
      if (d != 0) {
        return _Amount(
          _formatAmount(int.parse(m.group(1)!) / d),
          t.substring(m.end),
        );
      }
    }

    // "2-3 cloves garlic" — keep the range as written: showing "2–3" is
    // honest for a shopping list, and merging leaves a ranged count alone
    // instead of inventing a number.
    m = RegExp(r'^(\d+)\s*(?:-|–|—|to)\s*(\d+)\b', caseSensitive: false)
        .firstMatch(t);
    if (m != null) {
      return _Amount('${m.group(1)}–${m.group(2)}', t.substring(m.end),
          isRange: true);
    }

    m = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(t);
    if (m != null) {
      return _Amount(_formatAmount(double.parse(m.group(1)!)), t.substring(m.end));
    }

    m = _fractionChars.firstMatch(t);
    if (m != null && m.start == 0) {
      return _Amount(_formatAmount(_fractionValues[m.group(0)!]!),
          t.substring(m.end));
    }

    // Spelled-out counts show up in magazine-style recipes ("One large onion",
    // "Two 14.5-ounce cans", "a pinch of saffron").
    m = RegExp(
      r'^(one|two|three|four|five|six|seven|eight|nine|ten|half|a|an)\s+'
      r'(?:a\s+|an\s+)?',
      caseSensitive: false,
    ).firstMatch(t);
    if (m != null) {
      return _Amount(
        _formatAmount(_wordAmounts[m.group(1)!.toLowerCase()]!),
        t.substring(m.end),
      );
    }

    return null;
  }

  bool _hasLeadingAmount(String line) => _takeAmount(line) != null;

  /// 2.0 → "2", 1.5 → "1.5", 0.33 → "0.33" (percent-free, locale-free).
  String _formatAmount(double n) {
    if ((n - n.roundToDouble()).abs() < 1e-9) return n.round().toString();
    final fixed = n.toStringAsFixed(2);
    return fixed.endsWith('0')
        ? fixed.substring(0, fixed.length - 1).replaceFirst(RegExp(r'\.$'), '')
        : fixed;
  }

  // ---- Units --------------------------------------------------------------

  /// Measuring units are canonicalised plural (so merged sums read "3 cups"),
  /// countable containers singular (so a single one never reads "1 cans");
  /// [GroceryItem.amountLabel] pluralises containers when the amount isn't 1.
  static const Map<String, String> _units = {
    'cup': 'cups', 'cups': 'cups', 'c': 'cups',
    'tbsp': 'tbsp', 'tbsps': 'tbsp', 'tbs': 'tbsp',
    'tablespoon': 'tbsp', 'tablespoons': 'tbsp',
    'tsp': 'tsp', 'tsps': 'tsp', 'teaspoon': 'tsp', 'teaspoons': 'tsp',
    'ml': 'ml', 'millilitre': 'ml', 'milliliter': 'ml',
    'millilitres': 'ml', 'milliliters': 'ml',
    'l': 'L', 'litre': 'L', 'liter': 'L', 'litres': 'L', 'liters': 'L',
    'quart': 'quarts', 'quarts': 'quarts', 'qt': 'quarts',
    'pint': 'pints', 'pints': 'pints', 'pt': 'pints',
    'g': 'g', 'gram': 'g', 'grams': 'g',
    'kg': 'kg', 'kilo': 'kg', 'kilos': 'kg',
    'kilogram': 'kg', 'kilograms': 'kg',
    'oz': 'oz', 'ounce': 'oz', 'ounces': 'oz',
    'lb': 'lb', 'lbs': 'lb', 'pound': 'lb', 'pounds': 'lb',
    'clove': 'cloves', 'cloves': 'cloves',
    'can': 'can', 'cans': 'can',
    'jar': 'jar', 'jars': 'jar',
    'packet': 'packet', 'packets': 'packet', 'pkg': 'packet',
    'pkgs': 'packet', 'package': 'package', 'packages': 'package',
    'pack': 'pack', 'packs': 'pack',
    'box': 'box', 'boxes': 'box',
    'bottle': 'bottle', 'bottles': 'bottle',
    'carton': 'carton', 'cartons': 'carton',
    'tub': 'tub', 'tubs': 'tub',
    'bag': 'bag', 'bags': 'bag',
    'bunch': 'bunch', 'bunches': 'bunch',
    'sprig': 'sprig', 'sprigs': 'sprig',
    'stalk': 'stalk', 'stalks': 'stalk',
    'head': 'head', 'heads': 'head',
    'stick': 'stick', 'sticks': 'stick',
    'pinch': 'pinch', 'pinches': 'pinch',
    'dash': 'dash', 'dashes': 'dash',
    'handful': 'handful', 'handfuls': 'handful',
    'slice': 'slice', 'slices': 'slice',
    'piece': 'piece', 'pieces': 'piece',
    'sheet': 'sheet', 'sheets': 'sheet',
    'fillet': 'fillet', 'fillets': 'fillet',
    'filet': 'fillet', 'filets': 'fillet',
    'knob': 'knob', 'knobs': 'knob',
    'rib': 'rib', 'ribs': 'rib',
    'ear': 'ear', 'ears': 'ear',
    'drop': 'drop', 'drops': 'drop',
    'envelope': 'envelope', 'envelopes': 'envelope',
    'dozen': 'dozen',
  };

  /// Whole-word lookup of the first token, so "1 L milk" is litres while
  /// "1 Large onion" is not — the substring alternative `l` never fires inside
  /// a real word.
  _Taken<String>? _takeUnit(String line) {
    final t = line.trim();
    final m = RegExp(r'^([A-Za-z]+)\.?').firstMatch(t);
    if (m == null) return null;
    final word = m.group(1)!.toLowerCase();
    // "fl oz" / "fl. oz" reads as one unit.
    if (word == 'fl') {
      final rest = t.substring(m.end).trim();
      final flOz = RegExp(r'^oz\.?\b', caseSensitive: false).firstMatch(rest);
      if (flOz != null) {
        return _Taken('fl oz', rest.substring(flOz.end));
      }
      return null;
    }
    final canonical = _units[word];
    if (canonical == null) return null;
    return _Taken(canonical, t.substring(m.end));
  }

  static final RegExp _leadingSize = RegExp(
    r'^(?:extra[-\s]?large|large|medium|small|jumbo|baby|mini|xl)\b\s*',
    caseSensitive: false,
  );

  /// Container words, so a measure followed by one can drop the packaging
  /// word instead of gluing it onto the name.
  static const Set<String> _containerUnits = {
    'can', 'jar', 'packet', 'package', 'pack', 'box', 'bottle', 'carton', 'tub',
    'bag', 'bunch', 'sprig', 'stalk', 'head', 'stick', 'pinch', 'dash',
    'handful', 'slice', 'piece', 'sheet', 'fillet', 'knob', 'rib', 'ear',
    'drop', 'envelope', 'dozen',
  };

  static final RegExp _trailingContainer = RegExp(
    r'^(?:cans?|jars?|packets?|packages?|pkgs?|packs?|boxes?|bottles?|cartons?|'
    r'tubs?|bags?|containers?)\b\.?\s*',
    caseSensitive: false,
  );

  /// "15-ounce", "8 oz", "500g" between the count and the container word.
  static final RegExp _packageSize = RegExp(
    r'^\d+(?:\.\d+)?\s*[-–]?\s*(?:fl\s*\.?\s*oz|oz|ounce|ounces|g|gram|grams|'
    r'kg|kilo|kilos|kilogram|kilograms|lb|lbs|pound|pounds|ml|l|litre|litres|'
    r'liter|liters)\b\.?\s*',
    caseSensitive: false,
  );

  // ---- Names --------------------------------------------------------------

  /// Words that describe state or prep, never the thing you buy. Kept as one
  /// word-boundary alternation so "green"/"white"/"brown" (which do matter:
  /// green beans, white wine, brown sugar) are deliberately absent.
  static final RegExp _prepWords = RegExp(
    r'\b(?:'
    r'finely|roughly|coarsely|thinly|thickly|lightly|slightly|'
    r'diced|chopped|minced|sliced|grated|shredded|julienned|cubed|quartered|'
    r'halved|peeled|seeded|cored|trimmed|washed|rinsed|drained|patted|dry|'
    r'dried|crumbled|crushed|beaten|whisked|melted|softened|chilled|thawed|'
    r'frozen|cooked|uncooked|raw|firm|silken|extra[-\s]?firm|warm|cold|'
    r'fresh|freshest|freshly|stale|day[-\s]old|leftover|leftovers|'
    r'packed|heaping|level|leveled|scant|generous|about|approximately|'
    r'plus|more|divided|optional|taste|serve|serving|garnish|such|as|'
    r'needed|required|your|favourite|favorite|good|quality|store[-\s]?bought|'
    r'all[-\s]purpose|self[-\s]rising|sifted|unsifted|fine|little|few|pressed|'
    r'homemade|well|mixed|assorted|whole|plain|virgin|extra|unsalted|salted|'
    r'sweetened|unsweetened|boneless|skinless|bone[-\s]in|skin[-\s]on|'
    r'very|thin|thick|small|medium|large|big|baby|jumbo|mini|room|'
    r'temperature|to'
    r')\b',
    caseSensitive: false,
  );

  static const Map<String, String> _synonyms = {
    'green onions': 'Scallions',
    'green onion': 'Scallions',
    'spring onions': 'Scallions',
    'spring onion': 'Scallions',
    'scallions': 'Scallions',
    'scallion': 'Scallions',
    'bell pepper': 'Bell pepper',
    'bell peppers': 'Bell pepper',
    'capsicum': 'Bell pepper',
    'garlic cloves': 'Garlic',
    'garlic clove': 'Garlic',
    'clove garlic': 'Garlic',
    'cloves garlic': 'Garlic',
    'coriander': 'Cilantro',
    'fresh coriander': 'Cilantro',
    'coriander leaves': 'Cilantro',
    'aubergine': 'Eggplant',
    'courgette': 'Zucchini',
    'garbanzo beans': 'Chickpeas',
    'garbanzo bean': 'Chickpeas',
    'garbanzos': 'Chickpeas',
    'garbanzo': 'Chickpeas',
    'chickpeas': 'Chickpeas',
    'chickpea': 'Chickpeas',
    'rocket': 'Arugula',
    'confectioners sugar': 'Powdered sugar',
    'confectioner sugar': 'Powdered sugar',
    'powdered sugar': 'Powdered sugar',
    'icing sugar': 'Powdered sugar',
    'caster sugar': 'Sugar',
    'superfine sugar': 'Sugar',
    'corn starch': 'Cornstarch',
    'tomatoes': 'Tomatoes',
  };

  static const Map<String, String> _irregularPlurals = {
    'leaves': 'leaf',
    'halves': 'half',
    'loaves': 'loaf',
    'chives': 'chive',
  };

  /// Merge key: singular, synonym-folded, so "2 carrots" and "1 carrot" are
  /// the same row (pattern: plural/singular collisions) while display names
  /// stay exactly as the recipe wrote them.
  String _mergeKey(String name) {
    final n = name.toLowerCase().trim();
    final synonym = _synonyms[n] ?? _synonyms[_singularize(n)];
    return _singularize((synonym ?? n).toLowerCase());
  }

  String _singularize(String word) {
    final irregular = _irregularPlurals[word];
    if (irregular != null) return irregular;
    if (word.length > 4 && word.endsWith('ies')) {
      return '${word.substring(0, word.length - 3)}y';
    }
    if (word.length > 4 && word.endsWith('es')) {
      final stem = word.substring(0, word.length - 2);
      if (RegExp(r'(?:sh|ch|x|z|ss|s)$').hasMatch(stem)) return stem;
      if (RegExp(r'(?:tomato|potato|mango|avocado|taco|burrito|pesto)$')
          .hasMatch(stem)) {
        return stem;
      }
    }
    if (word.length > 3 && word.endsWith('s') && !word.endsWith('ss')) {
      final before = word[word.length - 2];
      // "asparagus", "hummus", "couscous", "swiss" are not plurals.
      if (before == 'u' || before == 'i' || before == 's' || before == 'x') {
        return word;
      }
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  bool _plausibleName(String s) =>
      s.length >= 2 && RegExp('[A-Za-z]').hasMatch(s) && !s.contains('(');

  int _letterCount(String s) => RegExp('[A-Za-z]').allMatches(s).length;

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // ---- Merging ------------------------------------------------------------

  GroceryItem _merge(GroceryItem a, GroceryItem b) {
    final qA = double.tryParse(a.quantity);
    final qB = double.tryParse(b.quantity);
    // A ranged count ("2–3") or an unspecified one ("") has no single value,
    // so the written form wins instead of being summed into a number we cannot
    // justify.
    final total = (qA == null || qB == null) ? null : qA + qB;
    return a.copyWith(
      quantity: total != null
          ? _formatAmount(total)
          : (a.quantity.isNotEmpty ? a.quantity : b.quantity),
      unit: a.unit.isEmpty ? b.unit : a.unit,
    );
  }

  // ---- Categorisation -----------------------------------------------------

  /// Deterministic content id. `String.hashCode` is not guaranteed stable
  /// across runs or platforms, and these ids are persisted Hive keys (and the
  /// handle `toggleItem` uses), so the bytes are hashed here instead: same
  /// text → same id, forever.
  static String _contentId(String text) {
    var hash = 0x811c9dc5;
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Phrases that would otherwise land in the wrong aisle because a broader
  /// keyword matched first: "coconut milk" is a tin, not a dairy case; an
  /// aubergine is not an egg; "chicken broth" is not a chicken.
  static const List<_CatRule> _phraseRules = [
    _CatRule(GroceryCategory.produce, [
      'eggplant', 'aubergine', 'bell pepper', 'sweet potato', 'sweet corn',
      'cherry tomato', 'green bean', 'spring onion', 'green onion', 'scallion',
      'shallot', 'snow pea', 'sugar snap', 'butternut', 'zucchini', 'courgette',
      'brussels sprout', 'olives', 'artichoke', 'leek',
    ]),
    _CatRule(GroceryCategory.pantry, [
      'coconut milk', 'coconut cream', 'peanut butter', 'almond butter',
      'nut butter', 'olive oil', 'tomato paste', 'tomato sauce', 'tomato soup',
      'sun-dried tomato', 'chicken broth', 'chicken stock', 'beef broth',
      'beef stock', 'vegetable broth', 'vegetable stock', 'fish sauce',
      'oyster sauce', 'soy milk', 'almond milk', 'oat milk', 'peanut oil',
      'sesame oil', 'tahini', 'tofu', 'tempeh', 'walnut', 'almond', 'pecan',
      'cashew', 'pistachio', 'raisin', 'sesame', 'panko', 'breadcrumb',
      'peanut', 'syrup', 'jam', 'sriracha', 'hot sauce', 'miso', 'taco shell',
      'tortilla', 'cracker', 'stock cube', 'bouillon', 'tamarind',
      'wine', 'beer', 'cornstarch', 'corn starch', 'chocolate', 'cocoa',
      'coconut',
    ]),
    _CatRule(GroceryCategory.dairy, [
      'cream cheese', 'cottage cheese', 'sour cream', 'greek yogurt',
      'heavy cream', 'whipping cream', 'ice cream', 'condensed milk',
      'evaporated milk', 'clarified butter',
    ]),
  ];

  static const List<_CatRule> _rules = [
    _CatRule(GroceryCategory.produce, ['bell']),
    _CatRule(GroceryCategory.spices, [
      'salt', 'pepper', 'cumin', 'paprika', 'turmeric', 'cinnamon', 'nutmeg',
      'oregano', 'thyme', 'rosemary', 'chili powder', 'cayenne', 'curry',
      'coriander powder', 'cardamom', 'cloves', 'bay leaf', 'chili flake',
      'dill', 'vanilla', 'baking powder', 'baking soda', 'yeast', 'seasoning',
      'saffron', 'extract',
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
      'pumpkin', 'squash', 'okra', 'turnip', 'parsnip', 'fennel',
    ]),
    _CatRule(GroceryCategory.pantry, [
      'flour', 'sugar', 'rice', 'pasta', 'noodle', 'macaroni', 'bread', 'oil',
      'vinegar', 'soy sauce', 'stock', 'broth', 'beans', 'chickpea', 'lentil',
      'quinoa', 'oats', 'honey', 'maple', 'peanut butter', 'tomato paste',
      'coconut milk', 'tortilla', 'tortillas', 'salsa', 'mustard', 'ketchup',
      'wraps', 'couscous', 'cornstarch', 'corn starch', 'chocolate', 'cocoa',
      'shell', 'flatbread', 'pita', 'crouton', 'pickle',
    ]),
  ];

  GroceryCategory _categorize(String n) {
    for (final rule in _phraseRules) {
      if (rule.keywords.any(n.contains)) return rule.category;
    }
    for (final rule in _rules) {
      if (rule.keywords.any(n.contains)) return rule.category;
    }
    return GroceryCategory.other;
  }
}

/// One line or line-tail to parse, plus whether it may only be shown for
/// review (never turned into a guessed item).
class _Segment {
  const _Segment(this.text, {this.reviewOnly = false});
  final String text;
  final bool reviewOnly;
}

/// A parsed amount with the text it did not consume.
class _Amount {
  const _Amount(this.label, this.rest, {this.isRange = false});
  final String label;
  final String rest;
  final bool isRange;
}

class _Taken<T> {
  const _Taken(this.value, this.rest);
  final T value;
  final String rest;
}

class _CatRule {
  const _CatRule(this.category, this.keywords);
  final GroceryCategory category;
  final List<String> keywords;
}

class GroceryListResult {
  const GroceryListResult({required this.sections});
  final List<GrocerySection> sections;

  int get totalItems => sections.fold(0, (sum, s) => sum + s.items.length);

  /// Rows the parser refused to guess at, surfaced separately so a wrong
  /// amount is never silently trusted.
  List<GroceryItem> get reviewItems => [
        for (final section in sections)
          ...section.items.where((i) => i.needsReview),
      ];

  int get reviewCount => reviewItems.length;

  /// Items the shopper is actually meant to tick off.
  int get actionableItems => totalItems - reviewCount;
}
