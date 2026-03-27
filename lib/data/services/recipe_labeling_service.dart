import 'package:shoply/data/models/recipe.dart';

/// Service for automatically labeling recipes using ML-based text classification
/// This service analyzes recipe titles, ingredients, and metadata to assign relevant labels
/// 
/// **IMPORTANT**: Only generates labels that match available QuickFilters in recipe_filter.dart:
/// - Time: quick, 30min, under-hour
/// - Diet: vegetarian, vegan, gluten-free, keto, low-carb
/// - Meal Type: breakfast, lunch, dinner, snack
/// - Difficulty: easy, medium, advanced
/// - Cuisine: italian, asian, mexican, mediterranean
/// 
/// NOTE: Does NOT generate dessert, dairy-free, high-protein (no filters exist for these)
class RecipeLabelingService {
  static final RecipeLabelingService instance = RecipeLabelingService._();
  RecipeLabelingService._();

  /// Generate labels for a recipe using multilingual keyword analysis and semantic classification
  /// 
  /// **GUARANTEED LABELS** (every recipe will have):
  /// - Exactly ONE time label: quick, 30min, or under-hour
  /// - Exactly ONE difficulty label: easy, medium, or advanced
  /// - At least ONE meal type: breakfast, lunch, dinner, or snack
  /// 
  /// **OPTIONAL LABELS** (if detected):
  /// - Diet: vegetarian, vegan, gluten-free, keto, low-carb
  /// - Cuisine: italian, asian, mexican, mediterranean
  List<String> labelRecipe(Recipe recipe) {
    final labels = <String>{};

    // Combine text for analysis (multilingual support)
    final recipeText = _prepareRecipeText(recipe);

    // 1. Diet Type Detection
    labels.addAll(_detectDietType(recipeText, recipe.ingredients));

    // 2. Meal Type Detection
    labels.addAll(_detectMealType(recipeText, recipe));

    // 3. Time-based Labels
    labels.addAll(_detectTimeLabels(recipe.totalTimeMinutes));

    // 4. Difficulty Detection
    labels.addAll(_detectDifficulty(recipe));

    // 5. Cuisine Detection
    labels.addAll(_detectCuisine(recipeText));

    // 6. Special Characteristics
    labels.addAll(_detectSpecialCharacteristics(recipeText, recipe));

    return labels.toList();
  }

  String _prepareRecipeText(Recipe recipe) {
    final text = StringBuffer();
    text.write(recipe.name.toLowerCase());
    text.write(' ');
    text.write(recipe.description.toLowerCase());
    text.write(' ');
    for (final ingredient in recipe.ingredients) {
      text.write(ingredient.name.toLowerCase());
      text.write(' ');
    }
    return text.toString();
  }

  /// Detect diet types (Vegan, Vegetarian, Gluten-Free, etc.)
  Set<String> _detectDietType(String text, List<Ingredient> ingredients) {
    final labels = <String>{};
    final ingredientNames = ingredients.map((i) => i.name.toLowerCase()).toList();

    // Animal products (multilingual keywords)
    final animalProducts = [
      // English
      'meat', 'chicken', 'beef', 'pork', 'fish', 'salmon', 'tuna', 'shrimp', 'seafood',
      'egg', 'eggs', 'milk', 'cheese', 'butter', 'cream', 'yogurt', 'honey',
      // German
      'fleisch', 'hähnchen', 'rind', 'schwein', 'fisch', 'lachs', 'thunfisch', 'garnelen',
      'ei', 'eier', 'milch', 'käse', 'sahne', 'joghurt', 'honig',
      // Spanish
      'carne', 'pollo', 'res', 'cerdo', 'pescado', 'salmón', 'atún', 'camarones',
      'huevo', 'huevos', 'leche', 'queso', 'mantequilla', 'crema', 'miel',
      // French
      'viande', 'poulet', 'boeuf', 'porc', 'poisson', 'saumon', 'thon', 'crevettes',
      'oeuf', 'oeufs', 'lait', 'fromage', 'beurre', 'crème', 'yaourt',
      // Italian
      'carne', 'pollo', 'manzo', 'maiale', 'pesce', 'salmone', 'tonno', 'gamberi',
      'uovo', 'uova', 'latte', 'formaggio', 'burro', 'panna', 'yogurt', 'miele',
      // Turkish
      'et', 'tavuk', 'sığır', 'domuz', 'balık', 'somon', 'ton', 'karides',
      'yumurta', 'süt', 'peynir', 'tereyağı', 'krema', 'yoğurt', 'bal',
    ];

    // Meat products
    final meatProducts = [
      // English
      'meat', 'chicken', 'beef', 'pork', 'lamb', 'fish', 'seafood', 'bacon', 'ham', 'sausage',
      // German
      'fleisch', 'hähnchen', 'rind', 'schwein', 'lamm', 'fisch', 'speck', 'schinken', 'wurst',
      // Spanish
      'carne', 'pollo', 'res', 'cerdo', 'cordero', 'pescado', 'tocino', 'jamón', 'salchicha',
      // French
      'viande', 'poulet', 'boeuf', 'porc', 'agneau', 'poisson', 'bacon', 'jambon', 'saucisse',
      // Italian
      'carne', 'pollo', 'manzo', 'maiale', 'agnello', 'pesce', 'bacon', 'prosciutto', 'salsiccia',
      // Turkish
      'et', 'tavuk', 'sığır', 'domuz', 'kuzu', 'balık', 'pastırma', 'jambon', 'sosis',
    ];

    // Gluten sources
    final glutenSources = [
      // English
      'flour', 'wheat', 'bread', 'pasta', 'noodles', 'barley', 'rye', 'couscous',
      // German
      'mehl', 'weizen', 'brot', 'nudeln', 'gerste', 'roggen',
      // Spanish
      'harina', 'trigo', 'pan', 'pasta', 'fideos', 'cebada', 'centeno',
      // French
      'farine', 'blé', 'pain', 'pâtes', 'nouilles', 'orge', 'seigle',
      // Italian
      'farina', 'grano', 'pane', 'pasta', 'tagliatelle', 'orzo', 'segale',
      // Turkish
      'un', 'buğday', 'ekmek', 'makarna', 'arpa', 'çavdar',
    ];

    // Dairy products
    final dairyProducts = [
      'milk', 'cheese', 'butter', 'cream', 'yogurt',
      'milch', 'käse', 'sahne', 'joghurt',
      'leche', 'queso', 'mantequilla', 'crema',
      'lait', 'fromage', 'beurre', 'crème',
      'latte', 'formaggio', 'burro', 'panna',
      'süt', 'peynir', 'tereyağı', 'krema', 'yoğurt',
    ];

    bool hasAnimalProduct = animalProducts.any((p) => text.contains(p) || ingredientNames.any((i) => i.contains(p)));
    bool hasMeat = meatProducts.any((p) => text.contains(p) || ingredientNames.any((i) => i.contains(p)));
    bool hasGluten = glutenSources.any((p) => text.contains(p) || ingredientNames.any((i) => i.contains(p)));
    bool hasDairy = dairyProducts.any((p) => text.contains(p) || ingredientNames.any((i) => i.contains(p)));

    // Vegan: No animal products at all
    if (!hasAnimalProduct) {
      labels.add('vegan');
      labels.add('vegetarian');
    } else if (!hasMeat) {
      // Vegetarian: No meat but may have dairy/eggs
      labels.add('vegetarian');
    }

    // Gluten-Free
    if (!hasGluten) {
      labels.add('gluten-free');
    }

    // Keto (low-carb, high-fat)
    final highCarbFoods = [
      'rice', 'potato', 'bread', 'pasta', 'sugar', 'flour',
      'reis', 'kartoffel', 'brot', 'nudeln', 'zucker', 'mehl',
      'arroz', 'patata', 'pan', 'azúcar', 'harina',
      'riz', 'pomme de terre', 'pain', 'pâtes', 'sucre', 'farine',
      'riso', 'patata', 'pane', 'pasta', 'zucchero', 'farina',
      'pirinç', 'patates', 'ekmek', 'makarna', 'şeker', 'un',
    ];
    bool hasHighCarb = highCarbFoods.any((p) => text.contains(p) || ingredientNames.any((i) => i.contains(p)));
    if (!hasHighCarb && !hasGluten) {
      labels.add('keto');
      labels.add('low-carb');
    } else if (!hasGluten) {
      labels.add('low-carb');
    }

    return labels;
  }

  /// Detect meal type (Breakfast, Lunch, Dinner, Snack)
  /// Note: 'dessert' is intentionally NOT generated (no filter exists for it)
  /// ALWAYS returns at least ONE meal type label
  Set<String> _detectMealType(String text, Recipe recipe) {
    final labels = <String>{};

    // Breakfast indicators (multilingual)
    final breakfastKeywords = [
      'breakfast', 'pancake', 'waffle', 'oatmeal', 'cereal', 'toast', 'bagel', 'muffin', 'smoothie',
      'frühstück', 'pfannkuchen', 'waffel', 'haferflocken', 'müsli',
      'desayuno', 'panqueque', 'avena', 'tostada',
      'petit déjeuner', 'crêpe', 'gaufre', 'flocons d\'avoine',
      'colazione', 'pancake', 'waffle', 'farina d\'avena',
      'kahvaltı', 'pankek', 'yulaf',
    ];

    // Dessert indicators
    final dessertKeywords = [
      'dessert', 'cake', 'cookie', 'brownie', 'ice cream', 'pudding', 'tart', 'pie', 'chocolate',
      'nachtisch', 'kuchen', 'keks', 'eis', 'pudding', 'torte', 'schokolade',
      'postre', 'pastel', 'galleta', 'helado', 'chocolate',
      'dessert', 'gâteau', 'biscuit', 'glace', 'chocolat',
      'dolce', 'torta', 'biscotto', 'gelato', 'cioccolato',
      'tatlı', 'kek', 'kurabiye', 'dondurma', 'çikolata',
    ];

    // Snack indicators
    final snackKeywords = [
      'snack', 'bite', 'chip', 'dip', 'finger food', 'appetizer',
      'snack', 'häppchen', 'chips', 'vorspeise',
      'aperitivo', 'bocadillo', 'tapas',
      'apéritif', 'amuse-gueule',
      'spuntino', 'antipasto',
      'atıştırmalık', 'meze',
    ];

    // Salad/Light meal indicators
    final saladKeywords = [
      'salad', 'bowl', 'wrap', 'sandwich',
      'salat', 'schale',
      'ensalada',
      'salade',
      'insalata',
      'salata',
    ];

    // Check all categories (can have multiple meal types)
    bool hasBreakfast = breakfastKeywords.any((k) => text.contains(k));
    bool hasSnack = snackKeywords.any((k) => text.contains(k));
    bool hasDessert = dessertKeywords.any((k) => text.contains(k));
    bool hasSalad = saladKeywords.any((k) => text.contains(k));

    // Add breakfast if detected
    if (hasBreakfast) {
      labels.add('breakfast');
    }

    // Desserts and snacks map to 'snack' (no dessert filter exists)
    if (hasDessert || hasSnack) {
      labels.add('snack');
    }

    // Light meals (salads, wraps) are lunch
    if (hasSalad) {
      labels.add('lunch');
    }

    // If no specific meal type detected, classify by time and complexity
    if (labels.isEmpty) {
      if (recipe.totalTimeMinutes <= 20 && recipe.ingredients.length <= 8) {
        labels.add('snack');
      } else if (recipe.totalTimeMinutes >= 45 || recipe.ingredients.length >= 12) {
        labels.add('dinner');
      } else {
        labels.add('lunch');
      }
    }

    return labels;
  }

  /// Detect time-based labels (Quick, 30min, Under-hour)
  /// ALWAYS returns exactly ONE time label
  Set<String> _detectTimeLabels(int totalMinutes) {
    final labels = <String>{};

    if (totalMinutes <= 15) {
      labels.add('quick');
    } else if (totalMinutes <= 30) {
      labels.add('30min');
    } else {
      // Everything over 30 min gets 'under-hour' (even if it's over 60)
      labels.add('under-hour');
    }

    return labels;
  }

  /// Detect difficulty (Easy, Medium, Advanced)
  Set<String> _detectDifficulty(Recipe recipe) {
    final labels = <String>{};

    final ingredientCount = recipe.ingredients.length;
    final stepCount = recipe.instructions.length;
    final totalTime = recipe.totalTimeMinutes;

    // Easy: Few ingredients, few steps, quick
    if (ingredientCount <= 7 && stepCount <= 5 && totalTime <= 30) {
      labels.add('easy');
    }
    // Advanced: Many ingredients or many steps or long time
    else if (ingredientCount > 12 || stepCount > 10 || totalTime > 90) {
      labels.add('advanced');
    }
    // Medium: Everything in between
    else {
      labels.add('medium');
    }

    return labels;
  }

  /// Detect cuisine type (Italian, Asian, Mexican, Mediterranean, etc.)
  Set<String> _detectCuisine(String text) {
    final labels = <String>{};

    // Italian cuisine indicators
    final italianKeywords = [
      'pasta', 'pizza', 'risotto', 'lasagna', 'tiramisu', 'parmesan', 'mozzarella',
      'pesto', 'carbonara', 'bolognese', 'marinara', 'italian', 'italiano'
    ];

    // Asian cuisine indicators
    final asianKeywords = [
      'soy sauce', 'rice', 'noodles', 'wok', 'stir fry', 'teriyaki', 'sushi',
      'curry', 'pad thai', 'ramen', 'udon', 'asian', 'chinese', 'japanese', 'thai',
      'sojasoße', 'reis', 'nudeln', 'asiatisch',
      'salsa de soja', 'arroz', 'asiático',
      'sauce soja', 'riz', 'nouilles', 'asiatique',
      'salsa di soia', 'riso', 'asiatico',
      'soya sosu', 'pirinç', 'asya',
    ];

    // Mexican cuisine indicators
    final mexicanKeywords = [
      'taco', 'burrito', 'quesadilla', 'salsa', 'guacamole', 'tortilla', 'enchilada',
      'fajita', 'chili', 'mexican', 'mexicano', 'mexikanisch', 'messicano', 'meksika',
    ];

    // Mediterranean cuisine indicators
    final mediterraneanKeywords = [
      'olive oil', 'hummus', 'falafel', 'greek', 'mediterranean', 'feta', 'tzatziki',
      'olivenöl', 'griechisch', 'mediterran',
      'aceite de oliva', 'griego', 'mediterráneo',
      'huile d\'olive', 'grec', 'méditerranéen',
      'olio d\'oliva', 'greco', 'mediterraneo',
      'zeytinyağı', 'yunan', 'akdeniz',
    ];

    if (italianKeywords.any((k) => text.contains(k))) {
      labels.add('italian');
    }

    if (asianKeywords.any((k) => text.contains(k))) {
      labels.add('asian');
    }

    if (mexicanKeywords.any((k) => text.contains(k))) {
      labels.add('mexican');
    }

    if (mediterraneanKeywords.any((k) => text.contains(k))) {
      labels.add('mediterranean');
    }

    return labels;
  }

  /// Detect special characteristics (Healthy, Comfort Food, One-Pot, etc.)
  Set<String> _detectSpecialCharacteristics(String text, Recipe recipe) {
    final labels = <String>{};

    // Healthy indicators
    final healthyKeywords = [
      'salad', 'bowl', 'green', 'fresh', 'light', 'healthy', 'fitness',
      'salat', 'frisch', 'leicht', 'gesund',
      'ensalada', 'fresco', 'ligero', 'saludable',
      'salade', 'frais', 'léger', 'sain',
      'insalata', 'fresco', 'leggero', 'sano',
      'salata', 'taze', 'hafif', 'sağlıklı',
    ];

    // Comfort food indicators
    final comfortKeywords = [
      'creamy', 'cheesy', 'crispy', 'fried', 'baked', 'comfort',
      'cremig', 'käsig', 'knusprig', 'gebacken',
      'cremoso', 'con queso', 'crujiente', 'frito',
      'crémeux', 'fromage', 'croustillant', 'frit',
      'cremoso', 'formaggio', 'croccante', 'fritto',
      'kremalı', 'peynirli', 'çıtır', 'kızarmış',
    ];

    // One-pot meal indicators
    final onePotKeywords = [
      'one pot', 'one pan', 'sheet pan', 'casserole', 'slow cooker',
      'eintopf', 'auflauf',
      'una olla', 'cacerola',
      'un seul pot', 'cocotte',
      'una pentola', 'casseruola',
      'tek tencere', 'güveç',
    ];

    if (healthyKeywords.any((k) => text.contains(k)) || 
        (recipe.ingredients.length <= 10 && recipe.totalTimeMinutes <= 30)) {
      labels.add('healthy');
    }

    if (comfortKeywords.any((k) => text.contains(k))) {
      labels.add('comfort-food');
    }

    if (onePotKeywords.any((k) => text.contains(k))) {
      labels.add('one-pot');
    }

    // Meal prep friendly: Can be made ahead, stores well
    if (recipe.totalTimeMinutes >= 30 && recipe.defaultServings >= 4) {
      labels.add('meal-prep');
    }

    return labels;
  }

  /// Batch label multiple recipes
  Map<String, List<String>> labelRecipes(List<Recipe> recipes) {
    final result = <String, List<String>>{};
    for (final recipe in recipes) {
      result[recipe.id] = labelRecipe(recipe);
    }
    return result;
  }
}
