-- Migration: add order_index column to shopping_items
-- This column stores the user-defined sort position of an item within a list.
-- Items without a value fall back to created_at ordering in the app.

ALTER TABLE shopping_items
  ADD COLUMN IF NOT EXISTS order_index INTEGER DEFAULT NULL;

-- Backfill: assign initial order_index values based on created_at so that
-- existing items already have a meaningful order after the migration.
-- We use a window function partitioned by list_id so each list gets
-- independent 0-based indices.
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY list_id
      ORDER BY COALESCE(order_index, 999999), created_at
    ) - 1 AS new_index
  FROM shopping_items
)
UPDATE shopping_items
SET order_index = ranked.new_index
FROM ranked
WHERE shopping_items.id = ranked.id
  AND shopping_items.order_index IS NULL;
