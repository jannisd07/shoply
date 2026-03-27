-- Bilingual Support Migration
-- Adds language detection and category IDs to support English/German bilingual app
-- Created: 2025-11-09
-- Status: READY TO EXECUTE

-- ============================================================
-- 1. Add language tracking to shopping items
-- ============================================================
ALTER TABLE shopping_items 
  ADD COLUMN IF NOT EXISTS language VARCHAR(2) DEFAULT 'de',
  ADD COLUMN IF NOT EXISTS category_id VARCHAR(50);

-- ============================================================
-- 2. Migrate existing German category names to language-agnostic IDs
-- ============================================================
UPDATE shopping_items
SET category_id = CASE 
  WHEN category = 'Obst & Gemüse' THEN 'fruits_vegetables'
  WHEN category = 'Milchprodukte' THEN 'dairy'
  WHEN category = 'Fleisch & Fisch' THEN 'meat_fish'
  WHEN category = 'Backwaren' THEN 'bakery'
  WHEN category = 'Getränke' THEN 'beverages'
  WHEN category = 'Gewürze' THEN 'spices'
  WHEN category = 'Tiefkühl' THEN 'frozen'
  WHEN category = 'Grundnahrungsmittel' THEN 'staples'
  WHEN category = 'Snacks' THEN 'snacks'
  WHEN category = 'Haushalt & Drogerie' THEN 'household'
  WHEN category = 'Sonstiges' THEN 'other'
  WHEN category = 'Other' THEN 'other'
  ELSE 'other'
END
WHERE category_id IS NULL;

-- ============================================================
-- 3. Make category_id the primary category field
-- ============================================================
-- Note: Keeping old 'category' column for backward compatibility
-- Will be dropped in future migration after full app update

-- ============================================================
-- 4. Add language support to recipes
-- ============================================================
ALTER TABLE recipes
  ADD COLUMN IF NOT EXISTS language VARCHAR(2) DEFAULT 'de',
  ADD COLUMN IF NOT EXISTS translations JSONB;

-- ============================================================
-- 5. Add indexes for performance
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_recipes_language ON recipes(language);
CREATE INDEX IF NOT EXISTS idx_shopping_items_category_id ON shopping_items(category_id);
CREATE INDEX IF NOT EXISTS idx_shopping_items_language ON shopping_items(language);

-- ============================================================
-- 6. Verify migration
-- ============================================================
-- Run these queries after migration to verify:
-- SELECT DISTINCT category_id, COUNT(*) FROM shopping_items GROUP BY category_id;
-- SELECT DISTINCT language, COUNT(*) FROM shopping_items GROUP BY language;
-- SELECT DISTINCT language, COUNT(*) FROM recipes GROUP BY language;

-- ============================================================
-- ROLLBACK (if needed)
-- ============================================================
-- ALTER TABLE shopping_items DROP COLUMN IF EXISTS language;
-- ALTER TABLE shopping_items DROP COLUMN IF EXISTS category_id;
-- ALTER TABLE recipes DROP COLUMN IF EXISTS language;
-- ALTER TABLE recipes DROP COLUMN IF EXISTS translations;
-- DROP INDEX IF EXISTS idx_recipes_language;
-- DROP INDEX IF EXISTS idx_shopping_items_category_id;
-- DROP INDEX IF EXISTS idx_shopping_items_language;
-- DROP INDEX IF EXISTS idx_list_items_language;
