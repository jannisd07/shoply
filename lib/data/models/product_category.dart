enum ProductCategory {
  fruitsVegetables('Obst und Gemüse'),
  meatFish('Fleisch und Wurst'),
  bakery('Backwaren'),
  flowersPlants('Blumen und Pflanzen'),
  dairy('Kühlprodukte'),
  frozen('Tiefkühlprodukte'),
  staples('Grundnahrungsmittel'),
  canned('Konserven'),
  spices('Gewürze'),
  condiments('Würzmittel'),
  breakfast('Frühstücksprodukte'),
  sweets('Süßigkeiten'),
  snacks('Snacks'),
  beverages('Getränke'),
  household('Haushaltswaren'),
  cleaning('Reinigungsmittel'),
  paper('Papierwaren'),
  drugstore('Drogerie'),
  bodycare('Körperpflege'),
  cosmetics('Kosmetik'),
  hygiene('Hygieneartikel'),
  householdDrugstore('Haushalt & Drogerie'),
  baby('Babyartikel'),
  petSupplies('Tierbedarf'),
  nonFood('Non-Food'),
  appliances('Haushaltsgeräte'),
  stationery('Schreibwaren'),
  textiles('Textilien'),
  toys('Spielzeug'),
  seasonal('Saisonartikel'),
  checkout('Kassenbereich');

  final String displayName;
  const ProductCategory(this.displayName);
  
  /// Get category index for ML model
  int get categoryIndex => ProductCategory.values.indexOf(this);

  /// Get category for a product name
  static ProductCategory categorize(String productName) {
    final name = productName.toLowerCase().trim();

    // Fleisch und Wurst
    if (_matchesAny(name, [
      'fleisch', 'hähnchen', 'huhn', 'rind', 'schwein', 'lamm', 'pute', 'ente',
      'wurst', 'schinken', 'salami', 'bacon', 'speck', 'hack', 'hackfleisch',
      'steak', 'schnitzel', 'fisch', 'lachs', 'thunfisch', 'forelle', 'kabeljau',
      'garnele', 'shrimp', 'muschel', 'tofu', 'tempeh', 'seitan', 'veggie',
      'vegetarisch', 'vegan', 'fleischersatz', 'braten', 'brust', 'filet',
      'leber', 'wienerschnitzel', 'fleischwurst', 'mortadella', 'schwarzwälder',
      'bregenwurst', 'leberwurst', 'blutwurst', 'mett', 'gehacktes',
    ])) {
      return ProductCategory.meatFish;
    }

    // Blumen und Pflanzen
    if (_matchesAny(name, [
      'blume', 'blumen', 'pflanze', 'pflanzen', 'rose', 'tulpe', 'orchidee',
      'kaktus', 'topfpflanze', 'schnittblumen', 'strauß', 'blumenstrauß',
      'zimmerpflanze', 'gartenpflanze', 'samen', 'blumenerde', 'dünger',
    ])) {
      return ProductCategory.flowersPlants;
    }

    // Kühlprodukte
    if (_matchesAny(name, [
      'milch', 'joghurt', 'quark', 'sahne', 'butter', 'margarine', 'käse',
      'frischkäse', 'mozzarella', 'gouda', 'emmentaler', 'parmesan', 'feta',
      'ei', 'eier', 'pudding', 'dessert', 'aufstrich', 'hummus', 'frischmilch',
    ])) {
      return ProductCategory.dairy;
    }

    // Tiefkühlprodukte
    if (_matchesAny(name, [
      'tiefkühl', 'gefrier', 'frozen', 'tk', 'eis', 'eiscreme', 'pizza',
      'pommes', 'fischstäbchen', 'gemüsemix', 'tiefgefroren',
    ])) {
      return ProductCategory.frozen;
    }

    // Backwaren
    if (_matchesAny(name, [
      'brot', 'brötchen', 'toast', 'baguette', 'croissant', 'kuchen', 'torte',
      'gebäck', 'brezel', 'laugenbrezel', 'muffin', 'donut', 'berliner',
      'hörnchen', 'teilchen', 'plunder', 'strudel', 'zwieback',
    ])) {
      return ProductCategory.bakery;
    }

    // Grundnahrungsmittel
    if (_matchesAny(name, [
      'mehl', 'zucker', 'salz', 'reis', 'nudel', 'pasta', 'spaghetti',
      'penne', 'fusilli', 'getreide', 'quinoa', 'couscous', 'bulgur',
      'hirse', 'grieß', 'stärke', 'backpulver', 'hefe', 'natron',
    ])) {
      return ProductCategory.staples;
    }

    // Konserven & Trockenware
    if (_matchesAny(name, [
      'dose', 'konserve', 'bohnen', 'kichererbsen', 'linsen', 'erbsen',
      'mais', 'tomatenmark', 'passata', 'tomatensauce', 'pesto', 'marmelade',
      'honig', 'nuss', 'nüsse', 'mandel', 'cashew', 'erdnuss', 'rosine',
      'trockenobst', 'datteln', 'feige',
    ])) {
      return ProductCategory.canned;
    }

    // Gewürze
    if (_matchesAny(name, [
      'gewürz', 'pfeffer', 'paprika', 'curry', 'kurkuma', 'zimt', 'muskat',
      'oregano', 'thymian', 'rosmarin', 'koriander', 'kreuzkümmel', 'chili',
      'cayenne', 'vanille', 'kardamom', 'ingwer', 'nelke', 'lorbeer',
      'safran', 'anis', 'fenchel', 'kümmel', 'majoran', 'salbei',
    ])) {
      return ProductCategory.spices;
    }

    // Würzmittel
    if (_matchesAny(name, [
      'essig', 'öl', 'olivenöl', 'sonnenblumenöl', 'rapsöl', 'senf',
      'ketchup', 'mayonnaise', 'soße', 'sauce', 'brühe', 'bouillon',
      'maggi', 'würze', 'dressing', 'marinade', 'sojasauce', 'tabasco',
      'worcester', 'balsamico', 'teriyaki', 'sriracha',
    ])) {
      return ProductCategory.condiments;
    }

    // Frühstücksprodukte
    if (_matchesAny(name, [
      'müsli', 'haferflocken', 'cornflakes', 'frühstück', 'cerealien',
      'marmelade', 'honig', 'nutella', 'aufstrich', 'konfitüre', 'gelee',
      'müsliriegel', 'granola', 'porridge', 'frühstücksflocken',
    ])) {
      return ProductCategory.breakfast;
    }

    // Süßigkeiten
    if (_matchesAny(name, [
      'schokolade', 'schoko', 'bonbon', 'gummibärchen', 'keks', 'cookie',
      'riegel', 'nachtisch', 'süß', 'candy', 'lutscher', 'praline',
      'trüffel', 'karamell', 'toffee', 'fudge', 'marshmallow', 'lakritze',
      'weingummi', 'fruchtgummi', 'kaugummi', 'drops',
    ])) {
      return ProductCategory.sweets;
    }

    // Snacks
    if (_matchesAny(name, [
      'chips', 'snack', 'knabber', 'salzstange', 'cracker', 'popcorn',
      'flips', 'erdnüsse', 'nüsse', 'studentenfutter', 'trail mix',
      'brezel', 'nachos', 'tortilla', 'reiswaffel', 'maiswaffel',
    ])) {
      return ProductCategory.snacks;
    }

    // Getränke
    if (_matchesAny(name, [
      'wasser', 'saft', 'limo', 'cola', 'fanta', 'sprite', 'bier', 'wein',
      'sekt', 'champagner', 'kaffee', 'tee', 'kakao', 'milch', 'smoothie',
      'energy', 'drink', 'getränk', 'mineralwasser', 'sprudel',
    ])) {
      return ProductCategory.beverages;
    }

    // Haushaltswaren
    if (_matchesAny(name, [
      'haushalt', 'geschirr', 'besteck', 'teller', 'tasse', 'glas',
      'schüssel', 'topf', 'pfanne', 'messer', 'gabel', 'löffel',
      'küchenutensil', 'schneide', 'reibe', 'sieb', 'schale', 'dose',
      'box', 'behälter', 'aufbewahrung', 'frischhalte', 'alufolie',
    ])) {
      return ProductCategory.household;
    }

    // Reinigungsmittel
    if (_matchesAny(name, [
      'putzen', 'reiniger', 'spülmittel', 'waschmittel', 'weichspüler',
      'allzweckreiniger', 'glasreiniger', 'badreiniger', 'wc-reiniger',
      'entkalker', 'scheuermilch', 'bleiche', 'fleckentferner',
      'schwamm', 'bürste', 'lappen', 'mikrofaser', 'staubwedel',
    ])) {
      return ProductCategory.cleaning;
    }

    // Papierwaren
    if (_matchesAny(name, [
      'toilettenpapier', 'klopapier', 'küchenpapier', 'serviette',
      'taschentuch', 'tempo', 'zewa', 'papier', 'küchenrolle',
      'feuchttuch', 'kosmetiktuch', 'pappteller', 'pappbecher',
    ])) {
      return ProductCategory.paper;
    }

    // Drogerie
    if (_matchesAny(name, [
      'drogerie', 'pflaster', 'verband', 'schmerzmittel', 'aspirin',
      'ibuprofen', 'paracetamol', 'hustensaft', 'nasenspray',
      'vitamine', 'nahrungsergänzung', 'magnesium', 'vitamin',
      'erkältung', 'medikament', 'salbe', 'creme',
    ])) {
      return ProductCategory.drugstore;
    }

    // Körperpflege
    if (_matchesAny(name, [
      'seife', 'shampoo', 'duschgel', 'badezusatz', 'schaumbad',
      'bodylotion', 'körperlotion', 'handcreme', 'fußcreme',
      'peeling', 'körperpflege', 'pflege', 'waschgel', 'reinigung',
    ])) {
      return ProductCategory.bodycare;
    }

    // Kosmetik
    if (_matchesAny(name, [
      'kosmetik', 'makeup', 'make-up', 'schminke', 'lippenstift',
      'mascara', 'wimperntusche', 'lidschatten', 'rouge', 'puder',
      'foundation', 'concealer', 'nagellack', 'parfüm', 'parfum',
      'eau de toilette', 'duftwasser', 'gesichtscreme', 'tagescreme',
    ])) {
      return ProductCategory.cosmetics;
    }

    // Hygieneartikel
    if (_matchesAny(name, [
      'zahnpasta', 'zahnbürste', 'zahnseide', 'mundspülung',
      'mundwasser', 'deo', 'deodorant', 'rasier', 'rasierer',
      'rasierschaum', 'rasiergel', 'aftershave', 'damenhygiene',
      'binde', 'tampon', 'slipeinlage', 'hygiene', 'intimpflege',
    ])) {
      return ProductCategory.hygiene;
    }

    // Haushalt & Drogerie (kombinierte Kategorie)
    if (_matchesAny(name, [
      'reiniger', 'putzmittel', 'spülmittel', 'waschmittel', 'weichspüler',
      'allzweckreiniger', 'glasreiniger', 'badreiniger', 'wc-reiniger',
      'entkalker', 'scheuermilch', 'bleiche', 'fleckentferner',
      'schwamm', 'bürste', 'lappen', 'mikrofaser', 'staubwedel',
      'toilettenpapier', 'klopapier', 'küchenpapier', 'serviette',
      'taschentuch', 'tempo', 'zewa', 'papier', 'küchenrolle',
      'feuchttuch', 'kosmetiktuch', 'pappteller', 'pappbecher',
      'seife', 'shampoo', 'duschgel', 'badezusatz', 'schaumbad',
      'bodylotion', 'körperlotion', 'handcreme', 'fußcreme',
      'zahnpasta', 'zahnbürste', 'deo', 'deodorant',
      'drogerie', 'pflaster', 'verband', 'vitamine',
    ])) {
      return ProductCategory.householdDrugstore;
    }

    // Babyartikel
    if (_matchesAny(name, [
      'baby', 'windel', 'pampers', 'feuchttücher', 'babytücher',
      'babynahrung', 'babybrei', 'babymilch', 'fläschchen',
      'schnuller', 'nuckel', 'beißring', 'babypflege', 'wundcreme',
      'babyshampoo', 'babybad', 'babypuder',
    ])) {
      return ProductCategory.baby;
    }

    // Tierbedarf
    if (_matchesAny(name, [
      'hund', 'katze', 'tier', 'futter', 'hundefutter', 'katzenfutter',
      'leckerli', 'streu', 'katzenstreu', 'napf', 'leine', 'spielzeug',
      'vogel', 'fisch', 'aquarium',
    ])) {
      return ProductCategory.petSupplies;
    }

    // Non-Food
    if (_matchesAny(name, [
      'non-food', 'nonfood', 'batterie', 'glühbirne', 'kerze',
      'feuerzeug', 'streichholz', 'zeitschrift', 'zeitung', 'buch',
      'karte', 'geschenk', 'deko', 'dekoration',
    ])) {
      return ProductCategory.nonFood;
    }

    // Haushaltsgeräte
    if (_matchesAny(name, [
      'mixer', 'toaster', 'wasserkocher', 'kaffeemaschine',
      'staubsauger', 'bügeleisen', 'föhn', 'haartrockner',
      'elektro', 'gerät', 'küchengerät', 'haushaltsgerät',
    ])) {
      return ProductCategory.appliances;
    }

    // Schreibwaren
    if (_matchesAny(name, [
      'stift', 'kugelschreiber', 'bleistift', 'füller', 'marker',
      'textmarker', 'radiergummi', 'spitzer', 'lineal', 'schere',
      'kleber', 'klebestift', 'tesafilm', 'heft', 'block', 'notiz',
      'ordner', 'mappe', 'schreibwaren', 'büro',
    ])) {
      return ProductCategory.stationery;
    }

    // Textilien
    if (_matchesAny(name, [
      'handtuch', 'geschirrtuch', 'waschlappen', 'bettwäsche',
      'bettlaken', 'kissenbezug', 'decke', 'kissen', 'textil',
      'stoff', 'tuch', 'serviette', 'tischdecke',
    ])) {
      return ProductCategory.textiles;
    }

    // Spielzeug
    if (_matchesAny(name, [
      'spielzeug', 'spiel', 'puzzle', 'puppe', 'teddy', 'kuscheltier',
      'lego', 'baustein', 'ball', 'auto', 'spielauto', 'actionfigur',
      'brettspiel', 'kartenspiel', 'malbuch', 'buntstift',
    ])) {
      return ProductCategory.toys;
    }

    // Saisonartikel
    if (_matchesAny(name, [
      'weihnachten', 'ostern', 'halloween', 'silvester', 'advent',
      'nikolaus', 'lebkuchen', 'spekulatius', 'christstollen',
      'osterei', 'schokoladenhase', 'adventskalender', 'lametta',
      'christbaumkugel', 'lichterkette', 'saison', 'saisonal',
    ])) {
      return ProductCategory.seasonal;
    }

    // Kassenbereich
    if (_matchesAny(name, [
      'kaugummi', 'kasse', 'kassenbereich', 'zeitschrift',
      'lotterie', 'rubbellos', 'zigarette', 'tabak', 'feuerzeug',
      'pfandbon', 'gutschein', 'geschenkkarte', 'tüte', 'tragetasche',
    ])) {
      return ProductCategory.checkout;
    }

    return ProductCategory.staples;
  }

  static bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }
}
