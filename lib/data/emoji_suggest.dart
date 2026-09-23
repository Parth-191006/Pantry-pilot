/// Offline emoji suggestions for user-created recipes.
///
/// Typing a title is the slowest part of saving a recipe, so Recipe Pilot does
/// the decorating for you: the library title is scanned for a food keyword and
/// the matching glyph is pre-selected. Everything here is a pure function of
/// the title string — no lookups, no network, deterministic in tests.
///
/// Order matters: keys are declared in **priority order** — dish types first
/// (lasagna before pasta), then soups, proteins and produce — and the first
/// key found in the title wins. That is what makes "Chicken Curry" read as 🍛
/// rather than 🍗.
const Map<String, String> _keywords = {
  // Italian / pasta
  'lasagna': '🍝', 'carbonara': '🍝', 'spaghetti': '🍝', 'penne': '🍝',
  'linguine': '🍝', 'macaroni': '🍝', 'pasta': '🍝', 'gnocchi': '🍝',
  // Noodles / asian
  'ramen': '🍜', 'pho': '🍜', 'udon': '🍜', 'soba': '🍜', 'noodle': '🍜',
  'noodles': '🍜', 'thai': '🍜', 'laksa': '🍜',
  'dumpling': '🥟', 'dumplings': '🥟', 'gyoza': '🥟', 'wonton': '🥟',
  'teriyaki': '🍱', 'tofu': '🍱', 'bento': '🍱', 'stirfry': '🍱',
  'sushi': '🍣', 'ramenbowl': '🍜',
  // Curry / Indian
  'curry': '🍛', 'masala': '🍛', 'tikka': '🍛', 'dal': '🍛', 'biryani': '🍛',
  'risotto': '🍚', 'paella': '🍚', 'rice': '🍚',
  // Mexican
  'taco': '🌮', 'tacos': '🌮', 'quesadilla': '🌮',
  'burrito': '🌯', 'fajita': '🌯', 'wrap': '🌯', 'enchilada': '🌯',
  // Pizza / breads
  'pizza': '🍕', 'flatbread': '🍕', 'margherita': '🍕', 'focaccia': '🍕',
  'bread': '🍞', 'loaf': '🍞', 'sourdough': '🍞', 'bagel': '🥯',
  'sandwich': '🥪', 'panini': '🥪', 'toast': '🥪', 'burger': '🍔',
  // Eggs / breakfast
  'shakshuka': '🍳', 'omelet': '🍳', 'omelette': '🍳', 'frittata': '🍳',
  'egg': '🍳', 'eggs': '🍳',
  'pancake': '🥞', 'pancakes': '🥞', 'waffle': '🥞', 'crepe': '🥞',
  'porridge': '🥣', 'oatmeal': '🥣', 'oats': '🥣', 'cereal': '🥣',
  'smoothie': '🥤', 'juice': '🥤', 'shake': '🥤',
  // Soups & salads (dish types, so they outrank the proteins below)
  'soup': '🍲', 'stew': '🍲', 'chili': '🍲', 'broth': '🍲',
  'salad': '🥗', 'slaw': '🥗', 'greek': '🥗',
  // Protein
  'salmon': '🐟', 'tilapia': '🐟', 'cod': '🐟', 'tuna': '🐟', 'fish': '🐟',
  'shrimp': '🍤', 'prawn': '🍤', 'prawns': '🍤', 'scallop': '🍤',
  'chicken': '🍗', 'wings': '🍗', 'turkey': '🍗',
  'meatball': '🥩', 'meatballs': '🥩', 'steak': '🥩', 'beef': '🥩',
  'lamb': '🥩', 'pork': '🥩', 'chops': '🥩',
  // Produce-leaning
  'eggplant': '🍆', 'aubergine': '🍆',
  'broccoli': '🥦', 'veggie': '🥦', 'vegetable': '🥦', 'vegetarian': '🥦',
  'greens': '🥦', 'kale': '🥦',
  'potato': '🥔', 'potatoes': '🥔', 'fries': '🍟',
  'mushroom': '🍄', 'mushrooms': '🍄',
  'tomato': '🍅', 'avocado': '🥑', 'lemon': '🍋', 'corn': '🌽',
  'cheese': '🧀', 'honey': '🍯',
  // Sweet
  'cheesecake': '🍰', 'brownie': '🍰', 'cupcake': '🍰', 'cake': '🍰',
  'dessert': '🍰', 'cookie': '🍪', 'cookies': '🍪', 'biscuit': '🍪',
  'coffee': '☕', 'tea': '🍵',
};

/// Curated palette shown in the emoji picker (also the fallback set).
const List<String> emojiChoices = [
  '🍽️', '🍝', '🍜', '🍛', '🌮', '🌯', '🍕', '🥗',
  '🍳', '🐟', '🍤', '🍗', '🥩', '🍲', '🍚', '🍱',
  '🥘', '🥦', '🥞', '🍰', '🍪', '🍔', '🥪', '🍞',
  '🥯', '🥟', '🥣', '🥤', '🍆', '🥔', '🍅', '🧀',
];

/// Default glyph when nothing matches.
const String defaultRecipeEmoji = '🍽️';

/// Best-guess emoji for [title].
///
/// Pass 1 walks the keyword map in its declared priority order and returns as
/// soon as one of its keys is a whole word of the title. Pass 2 is a forgiving
/// substring sweep (4+ characters) so compounds still land — "shakshuka-ish",
/// "meatloaf".
String suggestEmoji(String title) {
  final tokens = title
      .toLowerCase()
      .split(RegExp(r'[^a-z]+'))
      .where((t) => t.isNotEmpty)
      .toSet();

  for (final entry in _keywords.entries) {
    if (tokens.contains(entry.key)) return entry.value;
  }

  // Substring pass: multi-word dishes often hide keywords inside compounds
  // ("meatloaf", "shakshuka-ish"). Kept conservative with a 4-char minimum so
  // short fragments never misfire.
  for (final token in tokens) {
    if (token.length < 4) continue;
    for (final entry in _keywords.entries) {
      if (entry.key.length >= 4 && token.contains(entry.key)) return entry.value;
    }
  }
  return defaultRecipeEmoji;
}
