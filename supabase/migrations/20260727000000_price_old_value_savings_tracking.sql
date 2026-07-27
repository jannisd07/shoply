-- Feature 8: "you've saved €X thanks to offers" — persists the offer's
-- regular/pre-discount price at the moment an item is added or updated with
-- a live offer price, so savings can be computed later from shopping_items
-- and, once a trip completes, from shopping_history_items. Nullable and
-- purely additive — never populated for manually-priced or unpriced items.
ALTER TABLE public.shopping_items
  ADD COLUMN IF NOT EXISTS price_old_value numeric;

ALTER TABLE public.shopping_history_items
  ADD COLUMN IF NOT EXISTS price_old_value numeric;
