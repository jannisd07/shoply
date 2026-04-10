-- Add source_url to recipes table for imported/attributed content.
-- Recipes with a non-null source_url were imported from a third-party source
-- (e.g. Wikibooks Cookbook, CC BY-SA) and will render a "Source" link at the
-- bottom of the detail screen in place of the author credit.

ALTER TABLE recipes ADD COLUMN IF NOT EXISTS source_url TEXT DEFAULT NULL;

-- Marks where the recipe came from. Current known values:
--   NULL         — user-authored recipe (default)
--   'wikibooks'  — imported from en.wikibooks.org/wiki/Cookbook (CC BY-SA)
ALTER TABLE recipes ADD COLUMN IF NOT EXISTS source_name TEXT DEFAULT NULL;

CREATE INDEX IF NOT EXISTS idx_recipes_source_name
  ON recipes (source_name)
  WHERE source_name IS NOT NULL;
