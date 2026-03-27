-- =====================================================
-- Category Merge Migration
-- Merges "Würzmittel" into "Gewürze" and updates to simplified categories
-- Date: November 5, 2025
-- =====================================================

-- Step 1: Merge "Würzmittel" into "Gewürze"
UPDATE shopping_items
SET category = 'Gewürze'
WHERE category = 'Würzmittel';

-- Step 2: Update old category names to new simplified names
UPDATE shopping_items
SET category = 'Obst & Gemüse'
WHERE category IN ('Obst und Gemüse', 'Obst', 'Gemüse', 'Blumen und Pflanzen');

UPDATE shopping_items
SET category = 'Milchprodukte'
WHERE category IN ('Kühlprodukte', 'Milch', 'Käse', 'Joghurt');

UPDATE shopping_items
SET category = 'Fleisch & Fisch'
WHERE category IN ('Fleisch und Wurst', 'Fleisch', 'Fisch', 'Wurst');

UPDATE shopping_items
SET category = 'Tiefkühl'
WHERE category IN ('Tiefkühlprodukte', 'Gefroren');

UPDATE shopping_items
SET category = 'Grundnahrungsmittel'
WHERE category IN ('Konserven', 'Trockenware', 'Frühstücksprodukte');

UPDATE shopping_items
SET category = 'Snacks'
WHERE category IN ('Süßigkeiten', 'Knabberwaren');

-- Step 3: Set any remaining unmapped categories to "Sonstiges"
UPDATE shopping_items
SET category = 'Sonstiges'
WHERE category NOT IN (
  'Obst & Gemüse',
  'Milchprodukte',
  'Fleisch & Fisch',
  'Backwaren',
  'Getränke',
  'Gewürze',
  'Tiefkühl',
  'Grundnahrungsmittel',
  'Snacks',
  'Sonstiges'
) OR category IS NULL;

-- Step 4: Verify changes
SELECT 
  category, 
  COUNT(*) as item_count 
FROM shopping_items 
GROUP BY category 
ORDER BY item_count DESC;

-- =====================================================
-- Migration Complete
-- =====================================================
--
-- Summary:
-- - Merged "Würzmittel" → "Gewürze"
-- - Updated all categories to new simplified list
-- - Set unmapped categories to "Sonstiges"
-- =====================================================
