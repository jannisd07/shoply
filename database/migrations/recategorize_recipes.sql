-- ============================================================
-- recategorize_recipes.sql
-- ============================================================
-- Fixes ALL recipe labels to use the correct category IDs that
-- match recipe_categories.dart and recipe_filter.dart.
--
-- Valid category IDs:
--   italian, asian, mexican, mediterranean,
--   vegetarian, vegan, snack, breakfast,
--   healthy, comfort-food, seafood, soup
--
-- Strategy (two passes):
--   1. Map wrong/old labels to correct category IDs
--   2. Keyword scan on recipe name + ingredient names
--   3. Vegetarian/vegan detection from ingredients
--   4. Fallback: any recipe still missing a valid category → comfort-food
--
-- Safe to re-run: only adds labels, never removes them.
--
-- Time label thresholds (matches recipe_labeling_service.dart):
--   quick:      total ≤ 35 min
--   30min:      36–45 min
--   under-hour: > 45 min
--
-- Difficulty thresholds (ingredient + step count; time is unreliable for imports):
--   easy:     ingredients ≤ 6 AND steps ≤ 5
--   medium:   everything in between
--   advanced: ingredients > 12 OR steps > 10 OR total > 90 min
-- ============================================================


-- ============================================================
-- PASS 1 — Map existing wrong labels to correct category IDs
-- ============================================================

-- indian / chinese / japanese / korean / vietnamese / thai / curry → asian
UPDATE recipes
SET labels = array_append(labels, 'asian')
WHERE (
  'indian'     = ANY(labels) OR
  'chinese'    = ANY(labels) OR
  'japanese'   = ANY(labels) OR
  'korean'     = ANY(labels) OR
  'vietnamese' = ANY(labels) OR
  'thai'       = ANY(labels) OR
  'curry'      = ANY(labels)
)
AND NOT 'asian' = ANY(labels);

-- dessert / cake / baking / pie / muffin / cookies → snack
UPDATE recipes
SET labels = array_append(labels, 'snack')
WHERE (
  'dessert' = ANY(labels) OR
  'cake'    = ANY(labels) OR
  'baking'  = ANY(labels) OR
  'pie'     = ANY(labels) OR
  'muffin'  = ANY(labels) OR
  'cookies' = ANY(labels)
)
AND NOT 'snack' = ANY(labels);

-- drinks / sandwich / appetizer → snack
UPDATE recipes
SET labels = array_append(labels, 'snack')
WHERE (
  'drinks'    = ANY(labels) OR
  'sandwich'  = ANY(labels) OR
  'appetizer' = ANY(labels)
)
AND NOT 'snack' = ANY(labels);

-- salad → healthy
UPDATE recipes
SET labels = array_append(labels, 'healthy')
WHERE 'salad' = ANY(labels)
AND NOT 'healthy' = ANY(labels);

-- stew → soup
UPDATE recipes
SET labels = array_append(labels, 'soup')
WHERE 'stew' = ANY(labels)
AND NOT 'soup' = ANY(labels);

-- stew → comfort-food
UPDATE recipes
SET labels = array_append(labels, 'comfort-food')
WHERE 'stew' = ANY(labels)
AND NOT 'comfort-food' = ANY(labels);

-- middle-eastern / greek / turkish / spanish → mediterranean
UPDATE recipes
SET labels = array_append(labels, 'mediterranean')
WHERE (
  'middle-eastern' = ANY(labels) OR
  'greek'          = ANY(labels) OR
  'turkish'        = ANY(labels) OR
  'spanish'        = ANY(labels)
)
AND NOT 'mediterranean' = ANY(labels);

-- lamb → mediterranean
UPDATE recipes
SET labels = array_append(labels, 'mediterranean')
WHERE 'lamb' = ANY(labels)
AND NOT 'mediterranean' = ANY(labels);

-- fish → seafood
UPDATE recipes
SET labels = array_append(labels, 'seafood')
WHERE 'fish' = ANY(labels)
AND NOT 'seafood' = ANY(labels);

-- frühstück / eggs → breakfast
UPDATE recipes
SET labels = array_append(labels, 'breakfast')
WHERE (
  'frühstück' = ANY(labels) OR
  'eggs'      = ANY(labels)
)
AND NOT 'breakfast' = ANY(labels);

-- pasta / pizza → italian
UPDATE recipes
SET labels = array_append(labels, 'italian')
WHERE (
  'pasta' = ANY(labels) OR
  'pizza' = ANY(labels)
)
AND NOT 'italian' = ANY(labels);

-- rice → asian (most rice dishes in this dataset are Asian)
UPDATE recipes
SET labels = array_append(labels, 'asian')
WHERE 'rice' = ANY(labels)
AND NOT 'asian' = ANY(labels);

-- german / beef / pork / american / british / french / sauce → comfort-food
UPDATE recipes
SET labels = array_append(labels, 'comfort-food')
WHERE (
  'german'   = ANY(labels) OR
  'beef'     = ANY(labels) OR
  'pork'     = ANY(labels) OR
  'american' = ANY(labels) OR
  'british'  = ANY(labels) OR
  'french'   = ANY(labels) OR
  'sauce'    = ANY(labels)
)
AND NOT 'comfort-food' = ANY(labels);

-- african → comfort-food (majority are hearty stews/soups)
UPDATE recipes
SET labels = array_append(labels, 'comfort-food')
WHERE 'african' = ANY(labels)
AND NOT 'comfort-food' = ANY(labels);

-- bread → snack (catches breads not already handled by name scan below)
UPDATE recipes
SET labels = array_append(labels, 'snack')
WHERE 'bread' = ANY(labels)
AND NOT 'snack' = ANY(labels)
AND NOT 'breakfast' = ANY(labels);


-- ============================================================
-- PASS 2 — Keyword scan on recipe name
-- (catches anything the label mapping missed)
-- ============================================================

-- ITALIAN
UPDATE recipes
SET labels = array_append(labels, 'italian')
WHERE lower(name) SIMILAR TO
  '%(pasta|pizza|risotto|lasagna|lasagne|spaghetti|carbonara|bolognese|'
  'pesto|tiramisu|gnocchi|ravioli|bruschetta|parmigiana|fettuccine|'
  'linguine|tagliatelle|osso buco|arancini|calzone|focaccia|minestrone|'
  'penne|rigatoni|cannelloni|saltimbocca|caprese|involtini)%'
AND NOT 'italian' = ANY(labels);

-- ASIAN
UPDATE recipes
SET labels = array_append(labels, 'asian')
WHERE lower(name) SIMILAR TO
  '%(sushi|ramen|pho|pad thai|dim sum|dumpling|gyoza|kimchi|bibimbap|'
  'laksa|biryani|tikka|masala|korma|tandoori|dahl|dal|naan|samosa|'
  'teriyaki|tempura|yakitori|miso|udon|soba|baozi|mapo|kung pao|'
  'chow mein|lo mein|fried rice|spring roll|satay|rendang|nasi|'
  'basmati|paneer|chana|saag|vindaloo|palak|aloo|dosa|idli|'
  'stir.fry|stir fry|wonton|bao|bún|bok choy|tom yum|tom kha|'
  'green curry|red curry|yellow curry|massaman|peanut sauce|'
  'soy.*glaze|hoisin|oyster sauce|fish sauce|lemongrass|galangal)%'
AND NOT 'asian' = ANY(labels);

-- MEXICAN
UPDATE recipes
SET labels = array_append(labels, 'mexican')
WHERE lower(name) SIMILAR TO
  '%(taco|burrito|enchilada|quesadilla|guacamole|nachos|fajita|'
  'chimichanga|chile verde|chile rojo|pozole|tamale|tamales|'
  'mole|salsa verde|pico de gallo|elote|carnitas|ceviche|'
  'chili|tex.mex|mexican)%'
AND NOT 'mexican' = ANY(labels);

-- MEDITERRANEAN
UPDATE recipes
SET labels = array_append(labels, 'mediterranean')
WHERE lower(name) SIMILAR TO
  '%(hummus|falafel|tzatziki|shawarma|kebab|pita|couscous|tabouleh|'
  'shakshuka|moussaka|baklava|baba ganoush|baba ghanoush|dolma|dolmades|'
  'fattoush|tabbouleh|kibbeh|kofta|halloumi|spanakopita|tiropita|'
  'greek|paella|gazpacho|ratatouille|bouillabaisse|tagine|'
  'harissa|za.atar|ras el hanout|preserved lemon|tahini)%'
AND NOT 'mediterranean' = ANY(labels);

-- SEAFOOD
UPDATE recipes
SET labels = array_append(labels, 'seafood')
WHERE lower(name) SIMILAR TO
  '%(salmon|tuna|shrimp|lobster|crab|cod|halibut|trout|sardine|'
  'anchovy|mussel|clam|oyster|scallop|squid|calamari|octopus|prawn|'
  'tilapia|bass|snapper|mahi|catfish|herring|mackerel|eel|'
  'fish cake|fish pie|fishcake|seafood|crayfish|langoustine)%'
AND NOT 'seafood' = ANY(labels);

-- SOUP
UPDATE recipes
SET labels = array_append(labels, 'soup')
WHERE lower(name) SIMILAR TO
  '%(soup|suppe|chowder|bisque|broth|bouillon|consomme|gazpacho|'
  'minestrone|potage|veloute|vichyssoise|goulash)%'
AND NOT 'soup' = ANY(labels);

-- BREAKFAST
UPDATE recipes
SET labels = array_append(labels, 'breakfast')
WHERE lower(name) SIMILAR TO
  '%(pancake|pfannkuchen|waffle|waffel|omelette|omelet|french toast|'
  'granola|porridge|muesli|müsli|smoothie bowl|acai bowl|'
  'scrambled egg|poached egg|fried egg|egg benedict|eggs benedict|'
  'breakfast|brunch|crepe|crêpe|beignet)%'
AND NOT 'breakfast' = ANY(labels);

-- SNACK / DESSERT
UPDATE recipes
SET labels = array_append(labels, 'snack')
WHERE lower(name) SIMILAR TO
  '%(cake|kuchen|torte|cookie|keks|brownie|muffin|cupcake|cheesecake|'
  'pudding|mousse|tart|soufflé|souffle|flan|creme brulee|crème brûlée|'
  'panna cotta|eclair|macaron|profiterole|biscuit|shortbread|scone|'
  'donut|doughnut|croissant|danish|strudel|galette|clafoutis|'
  'lemon curd|jam|compote|sorbet|gelato|ice cream|parfait|'
  'truffle|praline|fudge|caramel|nougat|meringue|pavlova|'
  'banana bread|zucchini bread|pumpkin bread|carrot cake)%'
AND NOT 'snack' = ANY(labels);

-- HEALTHY
UPDATE recipes
SET labels = array_append(labels, 'healthy')
WHERE lower(name) SIMILAR TO
  '%(salad|salat|smoothie|quinoa|bowl|acai|buddha|grain bowl|'
  'green juice|detox|superfood|kale|spinach.*salad|avocado toast|'
  'energy ball|power bowl|overnight oat|chia|spirulina)%'
AND NOT 'healthy' = ANY(labels);

-- COMFORT FOOD
UPDATE recipes
SET labels = array_append(labels, 'comfort-food')
WHERE lower(name) SIMILAR TO
  '%(mac.*cheese|macaroni.*cheese|grilled cheese|casserole|gratin|'
  'schnitzel|käsespätzle|pot roast|pot pie|shepherd.s pie|'
  'meatloaf|mashed potato|gravy|biscuits.*gravy|chicken pot pie|'
  'beef stew|lamb stew|irish stew|goulash|stroganoff|beef bourguignon|'
  'coq au vin|cassoulet|pulled pork|ribs|brisket|roast|'
  'dumplings.*gravy|bread pudding|rice pudding|sticky toffee)%'
AND NOT 'comfort-food' = ANY(labels);


-- ============================================================
-- PASS 3 — Vegetarian / vegan detection from ingredient names
-- (only for recipes not already tagged)
-- ============================================================

-- Mark as NON-vegetarian first (has clear meat/fish ingredients)
-- We'll use this to skip those in the veg detection below.
-- (No need to add a 'meat' label — we just check with a subquery.)

-- Vegan: no animal products at all in ingredient names
UPDATE recipes
SET labels = array_append(labels, 'vegan')
WHERE NOT 'vegan' = ANY(labels)
AND NOT EXISTS (
  SELECT 1
  FROM jsonb_array_elements(COALESCE(ingredients, '[]'::jsonb)) AS ing
  WHERE lower(ing->>'name') SIMILAR TO
    '%(chicken|beef|pork|lamb|turkey|duck|veal|venison|rabbit|'
    'bacon|ham|sausage|salami|pepperoni|prosciutto|pancetta|chorizo|'
    'fish|salmon|tuna|shrimp|prawn|lobster|crab|mussel|clam|oyster|'
    'scallop|squid|calamari|anchovy|sardine|herring|cod|halibut|'
    'milk|cream|butter|cheese|yogurt|egg|honey|lard|gelatin|'
    'whey|casein|ghee|mayo|mayonnaise)%'
);

-- Vegetarian: no meat/fish but may have dairy/eggs
UPDATE recipes
SET labels = array_append(labels, 'vegetarian')
WHERE NOT 'vegetarian' = ANY(labels)
AND NOT 'vegan' = ANY(labels)  -- vegan implies vegetarian, avoid duplicate
AND NOT EXISTS (
  SELECT 1
  FROM jsonb_array_elements(COALESCE(ingredients, '[]'::jsonb)) AS ing
  WHERE lower(ing->>'name') SIMILAR TO
    '%(chicken|beef|pork|lamb|turkey|duck|veal|venison|rabbit|'
    'bacon|ham|sausage|salami|pepperoni|prosciutto|pancetta|chorizo|'
    'fish|salmon|tuna|shrimp|prawn|lobster|crab|mussel|clam|oyster|'
    'scallop|squid|calamari|anchovy|sardine|herring|cod|halibut)%'
);


-- ============================================================
-- PASS 4 — Fallback: assign comfort-food to any recipe that
-- still has no valid category label
-- ============================================================

UPDATE recipes
SET labels = array_append(labels, 'comfort-food')
WHERE NOT (
  'italian'      = ANY(labels) OR
  'asian'        = ANY(labels) OR
  'mexican'      = ANY(labels) OR
  'mediterranean'= ANY(labels) OR
  'vegetarian'   = ANY(labels) OR
  'vegan'        = ANY(labels) OR
  'snack'        = ANY(labels) OR
  'breakfast'    = ANY(labels) OR
  'healthy'      = ANY(labels) OR
  'comfort-food' = ANY(labels) OR
  'seafood'      = ANY(labels) OR
  'soup'         = ANY(labels)
);


-- ============================================================
-- VERIFY — Count recipes per valid category
-- ============================================================

SELECT cat, count
FROM (
  SELECT 'italian'       AS cat, COUNT(*) AS count FROM recipes WHERE 'italian'       = ANY(labels) UNION ALL
  SELECT 'asian',               COUNT(*)            FROM recipes WHERE 'asian'         = ANY(labels) UNION ALL
  SELECT 'mexican',             COUNT(*)            FROM recipes WHERE 'mexican'       = ANY(labels) UNION ALL
  SELECT 'mediterranean',       COUNT(*)            FROM recipes WHERE 'mediterranean' = ANY(labels) UNION ALL
  SELECT 'vegetarian',          COUNT(*)            FROM recipes WHERE 'vegetarian'    = ANY(labels) UNION ALL
  SELECT 'vegan',               COUNT(*)            FROM recipes WHERE 'vegan'         = ANY(labels) UNION ALL
  SELECT 'snack',               COUNT(*)            FROM recipes WHERE 'snack'         = ANY(labels) UNION ALL
  SELECT 'breakfast',           COUNT(*)            FROM recipes WHERE 'breakfast'     = ANY(labels) UNION ALL
  SELECT 'healthy',             COUNT(*)            FROM recipes WHERE 'healthy'       = ANY(labels) UNION ALL
  SELECT 'comfort-food',        COUNT(*)            FROM recipes WHERE 'comfort-food'  = ANY(labels) UNION ALL
  SELECT 'seafood',             COUNT(*)            FROM recipes WHERE 'seafood'       = ANY(labels) UNION ALL
  SELECT 'soup',                COUNT(*)            FROM recipes WHERE 'soup'          = ANY(labels) UNION ALL
  SELECT '-- TOTAL (any valid)', COUNT(*)           FROM recipes WHERE (
    'italian' = ANY(labels) OR 'asian' = ANY(labels) OR 'mexican' = ANY(labels) OR
    'mediterranean' = ANY(labels) OR 'vegetarian' = ANY(labels) OR 'vegan' = ANY(labels) OR
    'snack' = ANY(labels) OR 'breakfast' = ANY(labels) OR 'healthy' = ANY(labels) OR
    'comfort-food' = ANY(labels) OR 'seafood' = ANY(labels) OR 'soup' = ANY(labels)
  )
) AS results
ORDER BY count DESC;
