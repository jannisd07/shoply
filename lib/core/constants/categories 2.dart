import 'package:flutter/material.dart';

class Categories {
  // Simplified and merged categories
  // Note: "Würzmittel" merged into "Gewürze"
  static const List<String> all = [
    'Obst & Gemüse',
    'Milchprodukte',
    'Fleisch & Fisch',
    'Backwaren',
    'Getränke',
    'Gewürze', // Merged: was "Gewürze" and "Würzmittel"
    'Tiefkühl',
    'Grundnahrungsmittel',
    'Snacks',
    'Haushalt & Drogerie',
    'Sonstiges',
  ];

  // Category colors mapping
  static const Map<String, Color> colors = {
    'Obst & Gemüse': Color(0xFF4CAF50), // Green
    'Milchprodukte': Color(0xFF2196F3), // Blue
    'Fleisch & Fisch': Color(0xFFE91E63), // Pink/Red
    'Backwaren': Color(0xFFFF9800), // Orange
    'Getränke': Color(0xFF00BCD4), // Cyan
    'Gewürze': Color(0xFFD32F2F), // Red
    'Tiefkühl': Color(0xFF9C27B0), // Purple
    'Grundnahrungsmittel': Color(0xFF795548), // Brown
    'Snacks': Color(0xFFFF5722), // Deep Orange
    'Haushalt & Drogerie': Color(0xFF607D8B), // Blue Grey
    'Sonstiges': Color(0xFF9E9E9E), // Grey
  };

  // Category icons mapping
  static const Map<String, IconData> icons = {
    'Obst & Gemüse': Icons.apple_rounded,
    'Milchprodukte': Icons.water_drop_rounded,
    'Fleisch & Fisch': Icons.set_meal_rounded,
    'Backwaren': Icons.bakery_dining_rounded,
    'Getränke': Icons.local_cafe_rounded,
    'Gewürze': Icons.restaurant_rounded,
    'Tiefkühl': Icons.ac_unit_rounded,
    'Grundnahrungsmittel': Icons.grain_rounded,
    'Snacks': Icons.cookie_rounded,
    'Haushalt & Drogerie': Icons.cleaning_services_rounded,
    'Sonstiges': Icons.inventory_rounded,
  };

  // Category keywords for auto-detection
  static const Map<String, List<String>> keywords = {
    'Obst & Gemüse': [
      'apfel', 'äpfel', 'banane', 'orange', 'birne', 'traube', 'erdbeere', 'himbeere',
      'blaubeere', 'kirsche', 'pfirsich', 'pflaume', 'melone', 'ananas', 'mango',
      'kiwi', 'zitrone', 'limette', 'avocado', 'tomate', 'gurke', 'salat', 'kopfsalat',
      'karotte', 'möhre', 'kartoffel', 'zwiebel', 'knoblauch', 'paprika', 'zucchini',
      'aubergine', 'brokkoli', 'blumenkohl', 'kohl', 'spinat', 'pilz', 'champignon',
      'lauch', 'sellerie', 'radieschen', 'rettich', 'kürbis', 'mais', 'erbse',
      'bohne', 'obst', 'gemüse', 'kräuter', 'petersilie', 'basilikum', 'rucola',
      'apple', 'banana', 'orange', 'grape', 'strawberry', 'watermelon', 'lemon',
      'lime', 'tomato', 'cucumber', 'lettuce', 'carrot', 'potato', 'onion', 'garlic',
    ],
    'Fleisch, Fisch & Ersatzprodukte': [
      'fleisch', 'hähnchen', 'huhn', 'rind', 'schwein', 'lamm', 'pute', 'ente',
      'wurst', 'schinken', 'salami', 'bacon', 'speck', 'hack', 'hackfleisch',
      'steak', 'schnitzel', 'fisch', 'lachs', 'thunfisch', 'forelle', 'kabeljau',
      'garnele', 'shrimp', 'muschel', 'tofu', 'tempeh', 'seitan', 'veggie',
      'vegetarisch', 'vegan', 'fleischersatz', 'chicken', 'beef', 'pork', 'fish',
      'salmon', 'tuna', 'meat', 'sausage',
    ],
    'Kühlprodukte': [
      'milch', 'joghurt', 'quark', 'sahne', 'butter', 'margarine', 'käse',
      'frischkäse', 'mozzarella', 'gouda', 'emmentaler', 'parmesan', 'feta',
      'ei', 'eier', 'pudding', 'dessert', 'aufstrich', 'hummus', 'frischmilch',
      'milk', 'cheese', 'yogurt', 'cream', 'eggs',
    ],
    'Tiefkühlprodukte': [
      'tiefkühl', 'gefrier', 'frozen', 'tk', 'eis', 'eiscreme', 'pizza',
      'pommes', 'fischstäbchen', 'gemüsemix', 'tiefgefroren', 'ice cream',
    ],
    'Backwaren & Getreide': [
      'brot', 'brötchen', 'toast', 'baguette', 'croissant', 'kuchen', 'torte',
      'mehl', 'zucker', 'salz', 'backpulver', 'hefe', 'reis', 'nudel', 'pasta',
      'spaghetti', 'penne', 'fusilli', 'müsli', 'haferflocken', 'cornflakes',
      'getreide', 'quinoa', 'couscous', 'bulgur', 'bread', 'flour', 'rice',
      'noodles', 'cereal',
    ],
    'Konserven & Trockenware': [
      'dose', 'konserve', 'bohnen', 'kichererbsen', 'linsen', 'erbsen',
      'mais', 'tomatenmark', 'passata', 'tomatensauce', 'pesto', 'marmelade',
      'honig', 'nuss', 'nüsse', 'mandel', 'cashew', 'erdnuss', 'rosine',
      'trockenobst', 'datteln', 'feige', 'canned', 'beans', 'nuts',
    ],
    'Gewürze & Würzmittel': [
      'gewürz', 'pfeffer', 'paprika', 'curry', 'kurkuma', 'zimt', 'muskat',
      'oregano', 'thymian', 'rosmarin', 'koriander', 'kreuzkümmel', 'chili',
      'cayenne', 'vanille', 'essig', 'öl', 'olivenöl', 'sonnenblumenöl',
      'rapsöl', 'senf', 'ketchup', 'mayonnaise', 'soße', 'sauce', 'brühe',
      'bouillon', 'maggi', 'würze', 'spices', 'pepper', 'oil', 'vinegar',
    ],
    'Snacks & Süßwaren': [
      'chips', 'schokolade', 'schoko', 'bonbon', 'gummibärchen', 'keks',
      'cookie', 'riegel', 'snack', 'knabber', 'salzstange', 'cracker',
      'popcorn', 'nachtisch', 'süß', 'candy', 'lutscher', 'chocolate',
      'cookies', 'sweets',
    ],
    'Getränke': [
      'wasser', 'saft', 'limo', 'cola', 'fanta', 'sprite', 'bier', 'wein',
      'sekt', 'champagner', 'kaffee', 'tee', 'kakao', 'smoothie',
      'energy', 'drink', 'getränk', 'mineralwasser', 'sprudel', 'water',
      'juice', 'coffee', 'tea', 'beer', 'wine',
    ],
    'Haushalt & Hygiene': [
      'putzen', 'reiniger', 'spülmittel', 'waschmittel', 'weichspüler',
      'toilettenpapier', 'klopapier', 'küchenpapier', 'serviette', 'müllbeutel',
      'schwamm', 'bürste', 'seife', 'shampoo', 'duschgel', 'zahnpasta',
      'zahnbürste', 'deo', 'creme', 'lotion', 'rasier', 'windel', 'taschentuch',
      'hygiene', 'haushalt', 'detergent', 'soap', 'toilet paper', 'shampoo',
      'toothpaste',
    ],
    'Tierbedarf': [
      'hund', 'katze', 'tier', 'futter', 'hundefutter', 'katzenfutter',
      'leckerli', 'streu', 'katzenstreu', 'napf', 'leine', 'spielzeug',
      'vogel', 'fisch', 'aquarium', 'pet', 'dog', 'cat', 'food',
    ],
  };

  // Diet preferences
  static const List<String> dietPreferences = [
    'None / No restrictions',
    'Vegetarian',
    'Vegan',
    'Gluten-free',
    'Lactose-free',
    'Low-carb / Keto',
    'Halal',
    'Kosher',
    'Nut allergy',
    'Other allergies',
  ];

  // Diet-incompatible foods
  static const Map<String, List<String>> dietRestrictions = {
    'Vegan': [
      'meat', 'fish', 'chicken', 'beef', 'pork', 'lamb', 'turkey',
      'milk', 'cheese', 'yogurt', 'butter', 'cream', 'eggs', 'honey',
      'fleisch', 'fisch', 'milch', 'käse', 'eier',
    ],
    'Vegetarian': [
      'meat', 'fish', 'chicken', 'beef', 'pork', 'lamb', 'turkey',
      'gelatin', 'fleisch', 'fisch',
    ],
    'Gluten-free': [
      'bread', 'pasta', 'wheat', 'barley', 'rye', 'flour', 'cereal',
      'brot', 'nudeln', 'weizen', 'mehl',
    ],
    'Lactose-free': [
      'milk', 'cheese', 'yogurt', 'butter', 'cream', 'ice cream',
      'milch', 'käse', 'joghurt', 'sahne', 'eis',
    ],
  };

  // Units
  static const List<String> units = [
    'pcs',
    'kg',
    'g',
    'l',
    'ml',
    'dozen',
    'pack',
    'bottle',
    'can',
    'box',
  ];
}
