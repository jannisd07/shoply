import 'package:flutter/material.dart';

/// Bilingual category data structure
class CategoryData {
  final String id;
  final Map<String, String> names;
  final Color color;
  final IconData icon;
  final Map<String, List<String>> keywords;

  const CategoryData({
    required this.id,
    required this.names,
    required this.color,
    required this.icon,
    required this.keywords,
  });

  String getName(String languageCode) {
    return names[languageCode] ?? names['en']!;
  }

  List<String> getKeywords(String languageCode) {
    return keywords[languageCode] ?? keywords['en'] ?? [];
  }
}

class Categories {
  // Default order matches typical supermarket walking path
  static const List<CategoryData> all = [
    // 1. Fruits & Vegetables - entrance area
    CategoryData(
      id: 'fruits_vegetables',
      names: {'en': 'Fruits & Vegetables', 'de': 'Obst & Gemüse'},
      color: Color(0xFF4CAF50),
      icon: Icons.spa_rounded, // Changed from apple to spa (leaf icon)
      keywords: {
        'en': ['apple', 'banana', 'orange', 'carrot', 'lettuce', 'tomato', 'cucumber', 'potato', 'onion', 'garlic', 'pepper', 'fruit', 'vegetable', 'vegetables', 'broccoli', 'spinach', 'avocado', 'lemon', 'lime', 'grape', 'berry', 'strawberry', 'melon', 'peach', 'pear', 'plum', 'cherry', 'kiwi', 'mango', 'pineapple', 'watermelon', 'cantaloupe', 'honeydew', 'blueberry', 'raspberry', 'blackberry', 'cranberry', 'grapefruit', 'mandarin', 'tangerine', 'clementine', 'apricot', 'nectarine', 'fig', 'date', 'papaya', 'guava', 'passion fruit', 'dragon fruit', 'lychee', 'pomegranate', 'persimmon', 'coconut', 'cabbage', 'cauliflower', 'celery', 'corn', 'eggplant', 'aubergine', 'zucchini', 'courgette', 'squash', 'pumpkin', 'radish', 'turnip', 'parsnip', 'beet', 'beetroot', 'asparagus', 'artichoke', 'leek', 'scallion', 'spring onion', 'shallot', 'chives', 'kale', 'chard', 'collard greens', 'arugula', 'rocket', 'watercress', 'endive', 'radicchio', 'bok choy', 'bean sprouts', 'mushroom', 'bell pepper', 'chili', 'jalapeño', 'habanero', 'serrano', 'poblano', 'sweet potato', 'yam', 'ginger', 'turmeric', 'horseradish', 'fennel', 'rhubarb', 'okra', 'snap peas', 'snow peas', 'green beans', 'wax beans'],
        'de': ['apfel', 'äpfel', 'banane', 'bananen', 'orange', 'orangen', 'birne', 'birnen', 'traube', 'trauben', 'erdbeere', 'erdbeeren', 'tomate', 'tomaten', 'gurke', 'gurken', 'salat', 'karotte', 'karotten', 'möhre', 'möhren', 'kartoffel', 'kartoffeln', 'zwiebel', 'zwiebeln', 'knoblauch', 'paprika', 'obst', 'gemüse', 'brokkoli', 'spinat', 'avocado', 'zitrone', 'zitronen', 'limette', 'limetten', 'weintrauben', 'beere', 'beeren', 'melone', 'melonen', 'pfirsich', 'pfirsiche', 'pflaume', 'pflaumen', 'kirsche', 'kirschen', 'kiwi', 'kiwis', 'mango', 'mangos', 'ananas', 'wassermelone', 'honigmelone', 'heidelbeere', 'himbeere', 'himbeeren', 'brombeere', 'brombeeren', 'preiselbeere', 'grapefruit', 'mandarine', 'mandarinen', 'klementine', 'aprikose', 'aprikosen', 'nektarine', 'feige', 'feigen', 'dattel', 'datteln', 'papaya', 'guave', 'passionsfrucht', 'drachenfrucht', 'litschi', 'granatapfel', 'kaki', 'kokosnuss', 'kohl', 'weißkohl', 'rotkohl', 'blumenkohl', 'sellerie', 'mais', 'aubergine', 'zucchini', 'kürbis', 'radieschen', 'rübe', 'rüben', 'rote beete', 'spargel', 'artischocke', 'lauch', 'porree', 'frühlingszwiebel', 'schalotte', 'schnittlauch', 'grünkohl', 'mangold', 'rucola', 'feldsalat', 'chicorée', 'radicchio', 'pak choi', 'sojasprossen', 'champignon', 'pilze', 'peperoni', 'chili', 'süßkartoffel', 'ingwer', 'kurkuma', 'meerrettich', 'fenchel', 'rhabarber', 'okra', 'zuckerschoten', 'grüne bohnen'],
      },
    ),
    // 2. Bakery & Deli
    CategoryData(
      id: 'bakery',
      names: {'en': 'Bakery & Deli', 'de': 'Bäckerei & Frischetheke'},
      color: Color(0xFFFF9800),
      icon: Icons.bakery_dining_rounded,
      keywords: {
        'en': ['bread', 'roll', 'toast', 'flour', 'sugar', 'salt', 'baguette', 'croissant', 'bagel', 'muffin', 'donut', 'pretzel', 'bun', 'sourdough', 'whole wheat bread', 'white bread', 'rye bread', 'pumpernickel', 'multigrain bread', 'ciabatta', 'focaccia', 'pita', 'naan', 'tortilla', 'wrap', 'flatbread', 'cornbread', 'biscuit', 'scone', 'danish', 'pastry', 'puff pastry', 'phyllo', 'pie crust', 'pizza dough', 'bread dough', 'yeast', 'baking powder', 'baking soda', 'vanilla extract', 'cinnamon', 'nutmeg', 'ginger', 'cloves', 'allspice', 'cardamom', 'cake', 'cupcake', 'brownie', 'cookie', 'biscuit', 'cracker', 'wafer', 'graham cracker', 'breadcrumb', 'panko', 'cake mix', 'brownie mix', 'frosting', 'icing', 'fondant', 'powdered sugar', 'brown sugar', 'granulated sugar', 'confectioners sugar', 'raw sugar', 'turbinado', 'honey', 'maple syrup', 'molasses', 'corn syrup', 'agave', 'stevia', 'artificial sweetener', 'cocoa powder', 'chocolate chips', 'baking chocolate', 'cornstarch', 'corn flour', 'all-purpose flour', 'bread flour', 'cake flour', 'pastry flour', 'self-rising flour', 'gluten-free flour', 'almond flour', 'coconut flour', 'oat flour', 'rice flour', 'wheat flour', 'semolina', 'breadstick', 'grissini', 'english muffin', 'crumpet', 'waffle', 'pancake mix', 'churro', 'eclair', 'cannoli', 'strudel', 'tart', 'quiche', 'empanada'],
        'de': ['brot', 'brötchen', 'toast', 'toastbrot', 'mehl', 'zucker', 'salz', 'baguette', 'croissant', 'bagel', 'muffin', 'donut', 'berliner', 'krapfen', 'brezel', 'laugenbrezel', 'semmel', 'weck', 'schrippe', 'sauerteigbrot', 'vollkornbrot', 'weißbrot', 'roggenbrot', 'pumpernickel', 'mehrkornbrot', 'ciabatta', 'focaccia', 'fladenbrot', 'pitabrot', 'naan', 'tortilla', 'wrap', 'fladen', 'maisbrot', 'biskuit', 'scone', 'plunderteig', 'gebäck', 'blätterteig', 'filoteig', 'teig', 'pizzateig', 'brotteig', 'hefe', 'backpulver', 'natron', 'vanilleextrakt', 'zimt', 'muskat', 'ingwer', 'nelken', 'piment', 'kardamom', 'kuchen', 'törtchen', 'schokokuchen', 'keks', 'plätzchen', 'cracker', 'waffel', 'oblate', 'kekse', 'paniermehl', 'semmelbrösel', 'panko', 'backmischung', 'kuchenmischung', 'glasur', 'zuckerguss', 'fondant', 'puderzucker', 'brauner zucker', 'kristallzucker', 'streuzucker', 'rohrzucker', 'rohzucker', 'honig', 'ahornsirup', 'melasse', 'sirup', 'maissirup', 'agavendicksaft', 'stevia', 'süßstoff', 'kakaopulver', 'schokoladenchips', 'backschokolade', 'speisestärke', 'maisstärke', 'weizenmehl', 'universalmehl', 'brotmehl', 'kuchenmehl', 'dinkelmehl', 'glutenfreies mehl', 'mandelmehl', 'kokosmehl', 'hafermehl', 'reismehl', 'hartweizengrieß', 'grießmehl', 'brotstange', 'grissini', 'hörnchen', 'waffel', 'pfannkuchen', 'pancake', 'churro', 'eclair', 'windbeutel', 'cannoli', 'strudel', 'apfelstrudel', 'torte', 'quiche', 'empanada', 'hefezopf', 'stollen', 'lebkuchen'],
      },
    ),
    // 3. Meat & Deli Counter
    CategoryData(
      id: 'meat_fish',
      names: {'en': 'Meat & Deli Counter', 'de': 'Fleisch & Wurst'},
      color: Color(0xFFE91E63),
      icon: Icons.set_meal_rounded,
      keywords: {
        'en': ['meat', 'chicken', 'beef', 'pork', 'fish', 'salmon', 'tuna', 'sausage', 'turkey', 'duck', 'lamb', 'veal', 'venison', 'rabbit', 'goat', 'bacon', 'ham', 'prosciutto', 'salami', 'pepperoni', 'chorizo', 'bratwurst', 'frankfurter', 'hot dog', 'weiner', 'kielbasa', 'bologna', 'mortadella', 'pastrami', 'corned beef', 'roast beef', 'brisket', 'steak', 't-bone', 'ribeye', 'sirloin', 'tenderloin', 'filet mignon', 'chuck', 'ground beef', 'ground pork', 'ground chicken', 'ground turkey', 'meatball', 'meatloaf', 'patty', 'burger', 'chicken breast', 'chicken thigh', 'chicken wing', 'chicken drumstick', 'whole chicken', 'rotisserie chicken', 'pork chop', 'pork loin', 'pork belly', 'spare ribs', 'baby back ribs', 'rack of lamb', 'lamb chop', 'leg of lamb', 'trout', 'cod', 'haddock', 'halibut', 'tilapia', 'sea bass', 'mackerel', 'sardines', 'anchovies', 'herring', 'swordfish', 'mahi mahi', 'snapper', 'catfish', 'pike', 'perch', 'carp', 'shrimp', 'prawns', 'lobster', 'crab', 'scallops', 'mussels', 'clams', 'oysters', 'squid', 'calamari', 'octopus', 'cuttlefish', 'seafood', 'shellfish', 'smoked salmon', 'smoked fish', 'pickled herring', 'fish fillet', 'fish steak', 'canned tuna', 'canned sardines', 'liver', 'kidney', 'heart', 'tongue', 'offal', 'tripe', 'oxtail'],
        'de': ['fleisch', 'hähnchen', 'huhn', 'rind', 'rindfleisch', 'schwein', 'schweinefleisch', 'fisch', 'lachs', 'thunfisch', 'wurst', 'pute', 'truthahn', 'ente', 'lamm', 'lammfleisch', 'kalb', 'kalbfleisch', 'wild', 'hirsch', 'reh', 'kaninchen', 'ziege', 'speck', 'schinken', 'prosciutto', 'salami', 'peperoni', 'chorizo', 'bratwurst', 'frankfurter', 'würstchen', 'wiener', 'kielbasa', 'mortadella', 'pastrami', 'corned beef', 'braten', 'rinderbraten', 'brust', 'steak', 't-bone', 'rippensteak', 'rumpsteak', 'filet', 'hackfleisch', 'rinderhack', 'schweinehack', 'geflügelhack', 'frikadelle', 'bulette', 'hackbraten', 'patty', 'burger', 'hähnchenbrust', 'hähnchenkeule', 'hähnchenflügel', 'unterschenkel', 'ganzes huhn', 'brathähnchen', 'kotelett', 'schweinekotelett', 'schweinefilet', 'schweinebauch', 'spareribs', 'rippchen', 'lammkeule', 'lammkotelett', 'forelle', 'kabeljau', 'dorsch', 'schellfisch', 'heilbutt', 'tilapia', 'seebarsch', 'wolfsbarsch', 'makrele', 'sardinen', 'sardellen', 'anchovis', 'hering', 'schwertfisch', 'schnapper', 'wels', 'hecht', 'barsch', 'karpfen', 'garnelen', 'shrimps', 'krabben', 'hummer', 'krabbe', 'jakobsmuscheln', 'muscheln', 'miesmuscheln', 'austern', 'tintenfisch', 'calamari', 'krake', 'oktopus', 'meeresfrüchte', 'schalentiere', 'räucherlachs', 'räucherfisch', 'bismarckhering', 'fischfilet', 'fischsteak', 'thunfisch dose', 'sardinen dose', 'leber', 'niere', 'herz', 'zunge', 'innereien', 'kutteln', 'ochsenschwanz'],
      },
    ),
    // 4. Dry Goods (staples + merged spices/condiments)
    CategoryData(
      id: 'staples',
      names: {'en': 'Dry Goods', 'de': 'Trockenwaren'},
      color: Color(0xFF795548),
      icon: Icons.grain_rounded,
      keywords: {
        'en': ['rice', 'pasta', 'noodles', 'cereal', 'beans', 'nuts', 'lentils', 'oats', 'quinoa', 'couscous', 'barley', 'wheat', 'corn', 'white rice', 'brown rice', 'jasmine rice', 'basmati rice', 'arborio rice', 'wild rice', 'rice noodles', 'instant rice', 'rice cakes', 'spaghetti', 'penne', 'rigatoni', 'macaroni', 'fettuccine', 'linguine', 'angel hair', 'lasagna noodles', 'ravioli', 'tortellini', 'gnocchi', 'ramen', 'udon', 'soba', 'egg noodles', 'instant noodles', 'whole wheat pasta', 'gluten-free pasta', 'corn flakes', 'cheerios', 'granola', 'muesli', 'oatmeal', 'cream of wheat', 'grits', 'breakfast cereal', 'puffed rice', 'bran flakes', 'shredded wheat', 'black beans', 'pinto beans', 'kidney beans', 'navy beans', 'lima beans', 'chickpeas', 'garbanzo beans', 'cannellini beans', 'great northern beans', 'refried beans', 'baked beans', 'green lentils', 'red lentils', 'brown lentils', 'split peas', 'yellow lentils', 'almonds', 'walnuts', 'cashews', 'pecans', 'hazelnuts', 'pistachios', 'macadamia', 'brazil nuts', 'pine nuts', 'peanuts', 'mixed nuts', 'trail mix', 'sunflower seeds', 'pumpkin seeds', 'chia seeds', 'flax seeds', 'sesame seeds', 'poppy seeds', 'hemp seeds', 'rolled oats', 'steel cut oats', 'quick oats', 'instant oats', 'oat bran', 'pearl barley', 'bulgur', 'farro', 'spelt', 'millet', 'buckwheat', 'amaranth', 'teff', 'polenta', 'cornmeal', 'grits', 'hominy', 'popcorn', 'popping corn', 'peanut butter', 'almond butter', 'cashew butter', 'sunflower seed butter', 'tahini', 'nutella', 'jam', 'jelly', 'preserves', 'marmalade', 'spice', 'pepper', 'salt', 'oil', 'vinegar', 'sauce', 'black pepper', 'white pepper', 'cayenne', 'paprika', 'chili powder', 'cumin', 'coriander', 'turmeric', 'curry powder', 'garam masala', 'cinnamon', 'nutmeg', 'cloves', 'allspice', 'cardamom', 'star anise', 'fennel seed', 'mustard seed', 'celery seed', 'caraway', 'dill', 'basil', 'oregano', 'thyme', 'rosemary', 'sage', 'marjoram', 'tarragon', 'bay leaf', 'parsley', 'cilantro', 'mint', 'chives', 'garlic powder', 'onion powder', 'ginger powder', 'dry mustard', 'dried herbs', 'italian seasoning', 'herbs de provence', 'cajun seasoning', 'taco seasoning', 'ranch seasoning', 'seasoning salt', 'lemon pepper', 'old bay', 'msg', 'bouillon', 'stock cube', 'olive oil', 'vegetable oil', 'canola oil', 'sunflower oil', 'corn oil', 'peanut oil', 'sesame oil', 'coconut oil', 'avocado oil', 'grape seed oil', 'walnut oil', 'truffle oil', 'cooking spray', 'balsamic vinegar', 'white vinegar', 'apple cider vinegar', 'rice vinegar', 'wine vinegar', 'red wine vinegar', 'white wine vinegar', 'malt vinegar', 'ketchup', 'mustard', 'mayo', 'mayonnaise', 'relish', 'pickle', 'soy sauce', 'teriyaki sauce', 'worcestershire sauce', 'hot sauce', 'tabasco', 'sriracha', 'barbecue sauce', 'bbq sauce', 'steak sauce', 'marinara', 'pasta sauce', 'tomato sauce', 'salsa', 'pesto', 'alfredo sauce', 'gravy', 'tartar sauce', 'cocktail sauce', 'honey mustard', 'ranch dressing', 'caesar dressing', 'italian dressing', 'vinaigrette', 'thousand island'],
        'de': ['reis', 'nudeln', 'pasta', 'müsli', 'bohnen', 'nüsse', 'linsen', 'hafer', 'haferflocken', 'quinoa', 'couscous', 'gerste', 'weizen', 'mais', 'weißer reis', 'naturreis', 'brauner reis', 'jasminreis', 'basmatireis', 'risottoreis', 'arborio', 'wildreis', 'reisnudeln', 'instantreis', 'reiswaffeln', 'spaghetti', 'penne', 'rigatoni', 'makkaroni', 'fettuccine', 'linguine', 'lasagneplatten', 'ravioli', 'tortellini', 'gnocchi', 'ramen', 'udon', 'soba', 'eiernudeln', 'instantnudeln', 'vollkornnudeln', 'glutenfreie nudeln', 'cornflakes', 'granola', 'knuspermüsli', 'haferflocken', 'haferbrei', 'porridge', 'grieß', 'frühstücksflocken', 'puffreis', 'weizenkleie', 'schwarze bohnen', 'pintobohnen', 'kidneybohnen', 'weiße bohnen', 'limabohnen', 'kichererbsen', 'cannellinibohnen', 'bohnenpüree', 'gebackene bohnen', 'grüne linsen', 'rote linsen', 'braune linsen', 'gelbe linsen', 'erbsen', 'schälerbsen', 'mandeln', 'walnüsse', 'cashews', 'pekannüsse', 'haselnüsse', 'pistazien', 'macadamia', 'paranüsse', 'pinienkerne', 'erdnüsse', 'nussmischung', 'studentenfutter', 'sonnenblumenkerne', 'kürbiskerne', 'chiasamen', 'leinsamen', 'sesamsamen', 'mohnsamen', 'hanfsamen', 'haferflocken zart', 'kernige haferflocken', 'schmelzflocken', 'instant haferflocken', 'haferkleie', 'perlgerste', 'bulgur', 'graupen', 'dinkel', 'hirse', 'buchweizen', 'amaranth', 'teff', 'polenta', 'maismehl', 'maisgries', 'popcorn', 'popcornmais', 'erdnussbutter', 'erdnussmus', 'mandelbutter', 'mandelmus', 'cashewmus', 'tahini', 'sesammus', 'nutella', 'nuss-nougat-creme', 'marmelade', 'konfitüre', 'gelee', 'orangenmarmelade', 'gewürz', 'pfeffer', 'salz', 'öl', 'essig', 'soße', 'sauce', 'würze', 'schwarzer pfeffer', 'weißer pfeffer', 'cayenne', 'cayennepfeffer', 'paprika', 'paprikapulver', 'chilipulver', 'kreuzkümmel', 'kumin', 'koriander', 'kurkuma', 'gelbwurz', 'currypulver', 'curry', 'garam masala', 'zimt', 'muskat', 'muskatnuss', 'nelken', 'gewürznelken', 'piment', 'kardamom', 'sternanis', 'fenchelsamen', 'senfsamen', 'selleriesamen', 'kümmel', 'dill', 'basilikum', 'oregano', 'thymian', 'rosmarin', 'salbei', 'majoran', 'estragon', 'lorbeerblatt', 'petersilie', 'koriander', 'minze', 'pfefferminz', 'schnittlauch', 'knoblauchpulver', 'zwiebelpulver', 'ingwerpulver', 'senfpulver', 'getrocknete kräuter', 'kräutermischung', 'italienische kräuter', 'provence kräuter', 'cajun gewürz', 'taco gewürz', 'gewürzsalz', 'zitronenpfeffer', 'meersalz', 'steinsalz', 'jodsalz', 'fleur de sel', 'brühwürfel', 'suppenwürfel', 'bouillon', 'olivenöl', 'pflanzenöl', 'rapsöl', 'sonnenblumenöl', 'maiskeimöl', 'erdnussöl', 'sesamöl', 'kokosöl', 'avocadoöl', 'traubenkernöl', 'walnussöl', 'trüffelöl', 'bratöl', 'balsamico', 'balsamessig', 'weinessig', 'weißweinessig', 'rotweinessig', 'apfelessig', 'reisessig', 'branntweinessig', 'ketchup', 'senf', 'mayo', 'mayonnaise', 'remoulade', 'relish', 'gurken', 'eingelegte gurken', 'sojasoße', 'sojasauce', 'teriyaki', 'worcestersoße', 'worcestersauce', 'scharfe soße', 'tabasco', 'sriracha', 'grillsoße', 'bbq sauce', 'steaksoße', 'marinara', 'pastasoße', 'tomatensoße', 'tomatensauce', 'salsa', 'pesto', 'alfredo', 'bratensauce', 'jus', 'remouladensoße', 'cocktailsoße', 'honigsenf', 'ranch dressing', 'caesar dressing', 'italienisches dressing', 'vinaigrette', 'salatdressing'],
      },
    ),
    // 5. Snacks & Sweets
    CategoryData(
      id: 'snacks',
      names: {'en': 'Snacks & Sweets', 'de': 'Snacks & Süßigkeiten'},
      color: Color(0xFFFF5722),
      icon: Icons.cookie_rounded,
      keywords: {
        'en': ['chips', 'chocolate', 'candy', 'cookie', 'snack', 'potato chips', 'tortilla chips', 'corn chips', 'pita chips', 'bagel chips', 'veggie chips', 'kettle chips', 'ruffles', 'lays', 'pringles', 'doritos', 'cheetos', 'fritos', 'pretzels', 'pretzel sticks', 'popcorn', 'caramel corn', 'cheese popcorn', 'crackers', 'ritz', 'wheat thins', 'triscuits', 'saltines', 'graham crackers', 'rice crackers', 'trail mix', 'mixed nuts', 'roasted nuts', 'salted nuts', 'honey roasted', 'protein bar', 'granola bar', 'energy bar', 'cereal bar', 'fruit bar', 'nut bar', 'chocolate bar', 'candy bar', 'milk chocolate', 'dark chocolate', 'white chocolate', 'chocolate chips', 'chocolate truffles', 'bonbons', 'pralines', 'gummy bears', 'gummy worms', 'gummy candy', 'jelly beans', 'sour patch', 'skittles', 'starburst', 'twizzlers', 'licorice', 'lollipop', 'hard candy', 'peppermint', 'butterscotch', 'toffee', 'caramel', 'fudge', 'nougat', 'marshmallows', 'cotton candy', 'rock candy', 'mints', 'breath mints', 'chewing gum', 'bubble gum', 'sugar-free gum', 'cookies', 'chocolate chip cookies', 'oatmeal cookies', 'sandwich cookies', 'oreos', 'shortbread', 'biscotti', 'wafers', 'vanilla wafers', 'animal crackers', 'fig newtons', 'brownies', 'blondies', 'rice crispy treats', 'fruit snacks', 'fruit leather', 'dried fruit', 'raisins', 'dried cranberries', 'dried apricots', 'dried mango', 'banana chips', 'apple chips', 'veggie straws', 'cheese crackers', 'goldfish', 'cheez-it', 'beef jerky', 'turkey jerky', 'jerky', 'slim jims', 'pork rinds'],
        'de': ['chips', 'kartoffelchips', 'schokolade', 'schoko', 'süßigkeit', 'süßigkeiten', 'keks', 'kekse', 'snack', 'snacks', 'tortilla chips', 'nacho chips', 'nachos', 'pita chips', 'gemüsechips', 'paprikachips', 'salzchips', 'rifflechips', 'stapelchips', 'pringles', 'knabberzeug', 'salzstangen', 'brezel', 'laugenbrezel', 'brezeln', 'knabberbrezeln', 'popcorn', 'karamellpopcorn', 'käsepopcorn', 'cracker', 'salzcracker', 'käsecracker', 'reiswaffeln', 'knäckebrot', 'studentenfutter', 'nussmischung', 'geröstete nüsse', 'gesalzene nüsse', 'honignüsse', 'proteinriegel', 'müsliriegel', 'energieriegel', 'getreideriegel', 'fruchtriegel', 'nussriegel', 'schokoriegel', 'schokoladenriegel', 'tafel schokolade', 'vollmilchschokolade', 'zartbitterschokolade', 'weiße schokolade', 'schokoladenchips', 'pralinen', 'trüffel', 'bonbons', 'gummibärchen', 'gummibären', 'fruchtgummi', 'weingummi', 'lakritze', 'lakritz', 'lutscher', 'lollis', 'lolli', 'dauerlutscher', 'hartbonbons', 'pfefferminz', 'karamell', 'karamellbonbons', 'toffee', 'weichkaramell', 'fudge', 'nougat', 'marshmallows', 'mäusespeck', 'zuckerwatte', 'kandis', 'pfefferminz', 'drops', 'kaugummi', 'kaugummis', 'kaubonbons', 'zuckerfreier kaugummi', 'plätzchen', 'butterkekse', 'schokokekse', 'doppelkekse', 'oreos', 'mürbeteigkekse', 'gebäck', 'waffeln', 'vanillewaffeln', 'tierkekse', 'kekse', 'brownies', 'schokokuchen', 'müslischnitten', 'fruchtschnitten', 'trockenobst', 'getrocknete früchte', 'rosinen', 'getrocknete cranberries', 'getrocknete aprikosen', 'getrocknete mango', 'bananenchips', 'apfelchips', 'gemüsesticks', 'käsestangen', 'knabbergebäck', 'beef jerky', 'trockenfleisch', 'schwarten', 'flips', 'erdnussflips', 'knusperflips'],
      },
    ),
    // 6. Beverages
    CategoryData(
      id: 'beverages',
      names: {'en': 'Beverages', 'de': 'Getränke'},
      color: Color(0xFF00BCD4),
      icon: Icons.local_cafe_rounded,
      keywords: {
        'en': ['water', 'juice', 'soda', 'cola', 'beer', 'wine', 'coffee', 'tea', 'drink', 'beverage', 'sparkling water', 'mineral water', 'still water', 'spring water', 'tonic water', 'club soda', 'seltzer', 'apple juice', 'orange juice', 'grape juice', 'cranberry juice', 'grapefruit juice', 'tomato juice', 'pineapple juice', 'lemon juice', 'lime juice', 'fruit juice', 'vegetable juice', 'smoothie', 'milkshake', 'lemonade', 'iced tea', 'sweet tea', 'green tea', 'black tea', 'herbal tea', 'chamomile tea', 'peppermint tea', 'earl grey', 'english breakfast', 'chai', 'matcha', 'espresso', 'cappuccino', 'latte', 'americano', 'macchiato', 'mocha', 'frappe', 'cold brew', 'iced coffee', 'instant coffee', 'ground coffee', 'coffee beans', 'decaf', 'coca-cola', 'pepsi', 'sprite', 'fanta', '7up', 'root beer', 'ginger ale', 'cream soda', 'dr pepper', 'mountain dew', 'energy drink', 'red bull', 'monster', 'sports drink', 'gatorade', 'powerade', 'coconut water', 'chocolate milk', 'strawberry milk', 'eggnog', 'hot chocolate', 'cocoa', 'champagne', 'prosecco', 'red wine', 'white wine', 'rosé', 'port', 'sherry', 'sake', 'lager', 'ale', 'stout', 'ipa', 'pilsner', 'wheat beer', 'cider', 'hard cider', 'vodka', 'rum', 'whiskey', 'bourbon', 'gin', 'tequila', 'brandy', 'cognac', 'liqueur', 'vermouth', 'cocktail mix'],
        'de': ['wasser', 'saft', 'limo', 'limonade', 'cola', 'bier', 'wein', 'kaffee', 'tee', 'getränk', 'sprudelwasser', 'mineralwasser', 'stilles wasser', 'quellwasser', 'tafelwasser', 'tonic', 'tonic water', 'sodawasser', 'apfelsaft', 'orangensaft', 'traubensaft', 'cranberrysaft', 'grapefruitsaft', 'tomatensaft', 'ananassaft', 'zitronensaft', 'fruchtsaft', 'gemüsesaft', 'smoothie', 'milchshake', 'eistee', 'grüner tee', 'schwarzer tee', 'kräutertee', 'kamillentee', 'pfefferminztee', 'earl grey', 'english breakfast', 'chai', 'matcha', 'espresso', 'cappuccino', 'latte', 'milchkaffee', 'americano', 'macchiato', 'mokka', 'eiskaffee', 'instantkaffee', 'gemahlener kaffee', 'kaffeebohnen', 'entkoffeiniert', 'coca-cola', 'pepsi', 'sprite', 'fanta', '7up', 'ginger ale', 'apfelschorle', 'johannisbeersaft', 'multivitaminsaft', 'energy drink', 'red bull', 'monster', 'sportgetränk', 'iso-drink', 'kokoswasser', 'kakao', 'schokomilch', 'erdbeermilch', 'eierlikör', 'heiße schokolade', 'trinkschokolade', 'champagner', 'sekt', 'prosecco', 'rotwein', 'weißwein', 'rosé', 'portwein', 'sherry', 'sake', 'reiswein', 'pils', 'pilsner', 'weizenbier', 'weißbier', 'helles', 'dunkles', 'radler', 'alsterwasser', 'apfelwein', 'most', 'cidre', 'wodka', 'rum', 'whisky', 'bourbon', 'gin', 'tequila', 'weinbrand', 'cognac', 'likör', 'wermut', 'aperitif', 'digestif', 'cocktail', 'longdrink', 'kurzer', 'schnaps', 'obstler', 'korn', 'klarer', 'grappa'],
      },
    ),
    // 7. Household & Hygiene
    CategoryData(
      id: 'household',
      names: {'en': 'Household & Hygiene', 'de': 'Haushalt & Hygiene'},
      color: Color(0xFF607D8B),
      icon: Icons.cleaning_services_rounded,
      keywords: {
        'en': ['cleaning', 'soap', 'shampoo', 'toothpaste', 'toilet paper', 'paper towels', 'napkins', 'tissues', 'kleenex', 'dish soap', 'dishwasher detergent', 'laundry detergent', 'fabric softener', 'bleach', 'all-purpose cleaner', 'glass cleaner', 'floor cleaner', 'bathroom cleaner', 'toilet bowl cleaner', 'disinfectant', 'wipes', 'cleaning wipes', 'disinfecting wipes', 'sponges', 'scrubbers', 'mop', 'broom', 'dustpan', 'trash bags', 'garbage bags', 'plastic bags', 'aluminum foil', 'plastic wrap', 'cling film', 'parchment paper', 'wax paper', 'freezer bags', 'storage bags', 'ziploc', 'food storage', 'paper plates', 'plastic cups', 'disposable utensils', 'straws', 'coffee filters', 'hand soap', 'bar soap', 'body wash', 'shower gel', 'conditioner', 'hair spray', 'hair gel', 'mousse', 'styling product', 'deodorant', 'antiperspirant', 'perfume', 'cologne', 'aftershave', 'lotion', 'body lotion', 'hand lotion', 'moisturizer', 'face cream', 'sunscreen', 'sunblock', 'lip balm', 'chapstick', 'dental floss', 'mouthwash', 'toothbrush', 'electric toothbrush', 'cotton swabs', 'q-tips', 'cotton balls', 'cotton pads', 'makeup remover', 'facial cleanser', 'face wash', 'razors', 'shaving cream', 'shaving gel', 'feminine products', 'tampons', 'pads', 'panty liners', 'diapers', 'baby wipes', 'baby powder', 'baby lotion', 'baby shampoo', 'baby oil', 'diaper rash cream', 'vitamins', 'supplements', 'multivitamin', 'pain reliever', 'aspirin', 'ibuprofen', 'acetaminophen', 'tylenol', 'advil', 'cold medicine', 'allergy medicine', 'antacid', 'band-aids', 'bandages', 'first aid', 'adhesive tape', 'gauze', 'hydrogen peroxide', 'rubbing alcohol', 'antibacterial ointment', 'thermometer', 'air freshener', 'candles', 'matches', 'lighter', 'batteries', 'light bulbs', 'extension cord', 'duct tape', 'super glue', 'insect repellent', 'bug spray', 'ant traps', 'mouse traps', 'pet food', 'dog food', 'cat food', 'cat litter'],
        'de': ['putzen', 'putzmittel', 'reiniger', 'reinigung', 'seife', 'shampoo', 'zahnpasta', 'zahncreme', 'toilettenpapier', 'klopapier', 'küchenpapier', 'küchenrolle', 'servietten', 'taschentücher', 'tempo', 'spülmittel', 'geschirrspülmittel', 'geschirrspültabs', 'waschmittel', 'waschpulver', 'flüssigwaschmittel', 'weichspüler', 'bleichmittel', 'chlor', 'allzweckreiniger', 'glasreiniger', 'fensterreiniger', 'bodenreiniger', 'badreiniger', 'wc-reiniger', 'toilettenreiniger', 'desinfektionsmittel', 'reinigungstücher', 'feuchttücher', 'schwämme', 'putzschwamm', 'scheuerschwamm', 'topfschwamm', 'bürste', 'putzbürste', 'wischmopp', 'besen', 'kehrblech', 'müllbeutel', 'abfallbeutel', 'mülltüten', 'plastiktüten', 'alufolie', 'frischhaltefolie', 'klarsichtfolie', 'backpapier', 'wachspapier', 'gefrierbeutel', 'gefriertüten', 'vorratsbeutel', 'aufbewahrungsbeutel', 'zip-beutel', 'vorratsdosen', 'pappteller', 'plastikbecher', 'einweggeschirr', 'strohhalme', 'kaffeefilter', 'filtertüten', 'handseife', 'flüssigseife', 'seifenstück', 'duschgel', 'duschbad', 'spülung', 'conditioner', 'haarspray', 'haargel', 'schaumfestiger', 'stylingprodukt', 'deo', 'deodorant', 'antitranspirant', 'parfüm', 'parfum', 'eau de toilette', 'rasierwasser', 'aftershave', 'lotion', 'körperlotion', 'handcreme', 'bodylotion', 'feuchtigkeitscreme', 'gesichtscreme', 'sonnencreme', 'sonnenschutz', 'lippenpflege', 'lippenbalsam', 'zahnseide', 'mundwasser', 'mundspülung', 'zahnbürste', 'elektrische zahnbürste', 'wattestäbchen', 'ohrstäbchen', 'wattepads', 'watteträger', 'abschminktücher', 'gesichtsreinigung', 'rasierer', 'rasierklingen', 'rasierschaum', 'rasiergel', 'damenhygiene', 'tampons', 'binden', 'slipeinlagen', 'windeln', 'babywindeln', 'feuchttücher baby', 'babypuder', 'babyöl', 'babylotion', 'babyshampoo', 'wundschutzcreme', 'vitamine', 'nahrungsergänzung', 'multivitamin', 'schmerzmittel', 'aspirin', 'ibuprofen', 'paracetamol', 'kopfschmerztabletten', 'erkältungsmittel', 'hustensaft', 'allergietabletten', 'magentabletten', 'pflaster', 'verbandsmaterial', 'heftpflaster', 'mullbinden', 'erste hilfe', 'desinfektionsspray', 'wundspray', 'salbe', 'fieberthermometer', 'raumduft', 'lufterfrischer', 'duftkerzen', 'kerzen', 'streichhölzer', 'feuerzeug', 'batterien', 'glühbirnen', 'leuchtmittel', 'verlängerungskabel', 'klebeband', 'panzertape', 'sekundenkleber', 'alleskleber', 'insektenspray', 'mückenspray', 'ameisenfalle', 'mausefalle', 'tierfutter', 'hundefutter', 'katzenfutter', 'katzenstreu'],
      },
    ),
    // 8. Dairy Products
    CategoryData(
      id: 'dairy',
      names: {'en': 'Dairy Products', 'de': 'Milchprodukte'},
      color: Color(0xFF2196F3),
      icon: Icons.water_drop_rounded,
      keywords: {
        'en': ['milk', 'yogurt', 'cheese', 'butter', 'cream', 'egg', 'eggs', 'dairy', 'cheddar', 'mozzarella', 'parmesan', 'feta', 'gouda', 'brie', 'camembert', 'swiss cheese', 'provolone', 'ricotta', 'cottage cheese', 'cream cheese', 'mascarpone', 'blue cheese', 'gorgonzola', 'roquefort', 'stilton', 'goat cheese', 'sheep cheese', 'halloumi', 'paneer', 'quark', 'fromage frais', 'crème fraîche', 'sour cream', 'whipping cream', 'heavy cream', 'light cream', 'half and half', 'buttermilk', 'kefir', 'whole milk', 'skim milk', 'low-fat milk', '2% milk', 'almond milk', 'soy milk', 'oat milk', 'coconut milk', 'lactose-free milk', 'greek yogurt', 'plain yogurt', 'flavored yogurt', 'drinking yogurt', 'skyr', 'frozen yogurt', 'egg white', 'egg yolk', 'free-range eggs', 'organic eggs', 'brown eggs', 'white eggs', 'quail eggs', 'duck eggs', 'whey', 'casein', 'ghee', 'clarified butter', 'salted butter', 'unsalted butter', 'margarine', 'dairy spread', 'condensed milk', 'evaporated milk', 'powdered milk', 'milk powder', 'whey protein', 'cheese curds', 'string cheese', 'cheese slices', 'shredded cheese', 'grated cheese', 'cheese spread', 'processed cheese', 'cheese wheel', 'aged cheese', 'fresh cheese', 'soft cheese', 'hard cheese', 'semi-hard cheese', 'smoked cheese', 'flavored cheese', 'herbed cheese', 'cheese dip', 'cheese sauce', 'dairy dessert', 'pudding', 'custard', 'ice cream'],
        'de': ['milch', 'joghurt', 'käse', 'butter', 'sahne', 'quark', 'ei', 'eier', 'molkerei', 'cheddar', 'mozzarella', 'parmesan', 'feta', 'gouda', 'brie', 'camembert', 'emmentaler', 'schweizer käse', 'provolone', 'ricotta', 'hüttenkäse', 'frischkäse', 'mascarpone', 'blauschimmelkäse', 'gorgonzola', 'roquefort', 'stilton', 'ziegenkäse', 'schafskäse', 'halloumi', 'paneer', 'topfen', 'fromage frais', 'crème fraîche', 'sauerrahm', 'schmand', 'schlagsahne', 'süße sahne', 'kondensmilch', 'buttermilch', 'kefir', 'vollmilch', 'magermilch', 'fettarme milch', 'laktosefreie milch', 'mandelmilch', 'sojamilch', 'hafermilch', 'kokosmilch', 'griechischer joghurt', 'naturjoghurt', 'fruchtjoghurt', 'trinkjoghurt', 'skyr', 'frozen yogurt', 'eiweiß', 'eigelb', 'bio-eier', 'freilandeier', 'braune eier', 'weiße eier', 'wachteleier', 'enteneier', 'molke', 'kasein', 'ghee', 'butterschmalz', 'gesalzene butter', 'ungesalzene butter', 'margarine', 'brotaufstrich', 'kondensmilch', 'dosenmilch', 'milchpulver', 'trockenmilch', 'molkenprotein', 'käsebruch', 'streichkäse', 'käsescheiben', 'geriebener käse', 'käseaufstrich', 'schmelzkäse', 'käselaib', 'gereifter käse', 'frischkäse', 'weichkäse', 'hartkäse', 'schnittkäse', 'geräucherter käse', 'aromatisierter käse', 'kräuterkäse', 'käsedip', 'käsesoße', 'milchdessert', 'pudding', 'vanillesoße', 'eis', 'eiscreme', 'speiseeis'],
      },
    ),
    // 9. Frozen Foods
    CategoryData(
      id: 'frozen',
      names: {'en': 'Frozen Foods', 'de': 'Tiefkühlprodukte'},
      color: Color(0xFF9C27B0),
      icon: Icons.ac_unit_rounded,
      keywords: {
        'en': ['frozen', 'ice cream', 'pizza', 'frozen pizza', 'frozen vegetables', 'frozen fruit', 'frozen berries', 'frozen meals', 'tv dinner', 'frozen dinner', 'frozen chicken', 'frozen fish', 'frozen shrimp', 'frozen seafood', 'frozen meat', 'frozen beef', 'frozen pork', 'frozen burger', 'frozen patty', 'frozen fries', 'french fries', 'frozen potatoes', 'tater tots', 'hash browns', 'frozen corn', 'frozen peas', 'frozen broccoli', 'frozen spinach', 'frozen mixed vegetables', 'frozen cauliflower', 'frozen carrots', 'frozen green beans', 'frozen stir fry', 'frozen waffles', 'frozen pancakes', 'frozen french toast', 'frozen breakfast', 'frozen sausage', 'frozen bacon', 'ice cream bar', 'popsicle', 'ice pop', 'ice cream sandwich', 'frozen yogurt', 'gelato', 'sorbet', 'sherbet', 'frozen dessert', 'frozen pie', 'frozen cake', 'frozen pastry', 'frozen bread', 'frozen dough', 'frozen appetizer', 'frozen snack', 'frozen wings', 'frozen nuggets', 'chicken nuggets', 'fish sticks', 'frozen mozzarella sticks', 'frozen onion rings', 'frozen jalapeño poppers', 'frozen egg rolls', 'frozen dumplings', 'frozen pot stickers', 'frozen spring rolls', 'frozen burrito', 'frozen enchilada', 'frozen lasagna', 'frozen ravioli', 'frozen tortellini', 'frozen gnocchi', 'frozen edamame', 'frozen fruit smoothie', 'frozen concentrate', 'frozen juice', 'frozen lemonade', 'frozen whipped topping', 'cool whip', 'ice cubes', 'frozen mango', 'frozen strawberries', 'frozen blueberries', 'frozen raspberries', 'frozen peaches', 'frozen pineapple', 'frozen acai', 'frozen banana', 'frozen soup', 'frozen stock', 'frozen broth', 'frozen pasta', 'frozen rice', 'frozen quinoa', 'frozen grains', 'frozen breakfast sandwich', 'frozen breakfast burrito', 'frozen croissant', 'frozen bagel', 'frozen garlic bread', 'frozen breadsticks', 'frozen cookie dough', 'frozen brownie', 'frozen cheesecake'],
        'de': ['tiefkühl', 'gefrier', 'gefroren', 'eis', 'eiscreme', 'speiseeis', 'pizza', 'tiefkühlpizza', 'tk-pizza', 'tiefkühlgemüse', 'tk-gemüse', 'gefrorenes gemüse', 'tiefkühlobst', 'gefrorene beeren', 'tiefkühlgerichte', 'fertiggericht', 'tiefkühlessen', 'gefrorenes hähnchen', 'tiefkühlfisch', 'gefrorene garnelen', 'tiefkühlmeeresfrüchte', 'tiefkühlfleisch', 'gefrorenes rindfleisch', 'gefrorenes schweinefleisch', 'tiefkühlburger', 'pommes', 'tiefkühlpommes', 'tk-pommes', 'kartoffelecken', 'kroketten', 'rösti', 'tiefkühlmais', 'tiefkühlerbsen', 'tiefkühlbrokkoli', 'tiefkühlspinat', 'tk-gemüsemischung', 'tiefkühlblumenkohl', 'tiefkühlkarotten', 'tiefkühlbohnen', 'asia-gemüse', 'wok-gemüse', 'tiefkühlwaffeln', 'waffeln', 'eishörnchen', 'eiswaffel', 'eis am stiel', 'stieleis', 'eissandwich', 'frozen yogurt', 'sorbet', 'fruchteis', 'tiefkühldessert', 'tiefkühlkuchen', 'tiefkühltorte', 'tiefkühlgebäck', 'tiefkühlbrot', 'tk-brot', 'tiefkühlteig', 'tk-teig', 'tiefkühlvorspeise', 'tk-snack', 'tiefkühlflügel', 'chicken wings', 'tiefkühlnuggets', 'chicken nuggets', 'fischstäbchen', 'mozzarella sticks', 'zwiebelringe', 'jalapeño poppers', 'frühlingsrollen', 'dumplings', 'maultaschen', 'wan tan', 'burrito', 'enchilada', 'lasagne', 'tiefkühllasagne', 'ravioli', 'tortellini', 'gnocchi', 'edamame', 'smoothie', 'tk-smoothie', 'tiefkühlkonzentrat', 'tk-saft', 'sprühsahne', 'schlagsahne dose', 'eiswürfel', 'tk-mango', 'tk-erdbeeren', 'tk-heidelbeeren', 'tk-himbeeren', 'tk-pfirsiche', 'tk-ananas', 'tk-acai', 'tk-banane', 'tiefkühlsuppe', 'tk-brühe', 'tk-nudeln', 'tk-reis', 'tk-quinoa', 'tk-getreide', 'tk-frühstück', 'frühstückssandwich', 'tk-croissant', 'tk-bagel', 'knoblauchbrot', 'tk-knoblauchbrot', 'brotstangen', 'keksteig', 'brownie', 'käsekuchen'],
      },
    ),
    // 10. Other
    CategoryData(
      id: 'other',
      names: {'en': 'Other', 'de': 'Sonstiges'},
      color: Color(0xFF9E9E9E),
      icon: Icons.inventory_rounded,
      keywords: {'en': [], 'de': []},
    ),
  ];

  static CategoryData getById(String id) {
    return all.firstWhere((cat) => cat.id == id, orElse: () => all.last);
  }

  static List<String> getNamesInLanguage(String languageCode) {
    return all.map((cat) => cat.getName(languageCode)).toList();
  }

  static List<String> get allIds => all.map((cat) => cat.id).toList();

  static String? getIdByName(String name, String languageCode) {
    try {
      // Normalize the input name (trim, lowercase, remove punctuation)
      final normalizedInput = name.trim().toLowerCase().replaceAll(RegExp(r'[.,!?;:]'), '');
      
      // Try exact match first
      for (final cat in all) {
        final catName = cat.getName(languageCode);
        if (catName == name) {
          return cat.id;
        }
      }
      
      // Try normalized match
      for (final cat in all) {
        final catName = cat.getName(languageCode).toLowerCase().replaceAll(RegExp(r'[.,!?;:]'), '');
        if (catName == normalizedInput) {
          return cat.id;
        }
      }
      
      // Try partial match (input contains category name or vice versa)
      for (final cat in all) {
        final catName = cat.getName(languageCode).toLowerCase();
        if (normalizedInput.contains(catName) || catName.contains(normalizedInput)) {
          return cat.id;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  static Color getColor(String categoryId) {
    return getById(categoryId).color;
  }

  static IconData getIcon(String categoryId) {
    return getById(categoryId).icon;
  }

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
