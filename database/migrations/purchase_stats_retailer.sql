-- Where the user habitually buys each item.
--
-- Background: shopping_history_items already carries a per-item
-- `price_retailer`, but nothing ever aggregated it, so "wo kaufe ich Bananen
-- normalerweise?" was unanswerable. The offer flyer on the home screen needs
-- exactly that answer ("Bananen sind bei REWE im Angebot, und da kaufst du
-- sie sowieso"), as does a store-aware repurchase reminder.
--
-- retailer_counts holds a tally per retailer, e.g. {"REWE": 7, "Lidl": 2},
-- rather than only the winner. Keeping the distribution means the preference
-- can shift over time without losing history, and it exposes how lopsided the
-- preference actually is — buying something at REWE 7 of 9 times is a real
-- pattern, 2 of 3 is not yet.
--
-- Both columns are nullable and default to empty: rows written before this
-- migration stay valid, and the app treats a missing retailer as "unknown"
-- rather than as an error.

ALTER TABLE public.item_purchase_stats
  ADD COLUMN IF NOT EXISTS preferred_retailer text,
  ADD COLUMN IF NOT EXISTS retailer_counts    jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.item_purchase_stats.preferred_retailer IS
  'Retailer this item is bought at most often; NULL while unknown.';
COMMENT ON COLUMN public.item_purchase_stats.retailer_counts IS
  'Tally of purchases per retailer, e.g. {"REWE": 7, "Lidl": 2}.';

-- Backfill from the purchase history that already exists. Only history rows
-- that actually recorded a retailer contribute; today that is none, but this
-- makes the migration correct for anyone who already has such rows and lets
-- it be re-run safely later.
WITH tallies AS (
  SELECT
    sh.user_id,
    lower(trim(shi.name))                    AS item_name,
    shi.price_retailer                       AS retailer,
    count(*)                                 AS n
  FROM public.shopping_history_items shi
  JOIN public.shopping_history sh ON sh.id = shi.history_id
  WHERE shi.price_retailer IS NOT NULL
    AND btrim(shi.price_retailer) <> ''
  GROUP BY sh.user_id, lower(trim(shi.name)), shi.price_retailer
),
aggregated AS (
  SELECT
    user_id,
    item_name,
    jsonb_object_agg(retailer, n)                             AS counts,
    (array_agg(retailer ORDER BY n DESC, retailer ASC))[1]    AS top_retailer
  FROM tallies
  GROUP BY user_id, item_name
)
UPDATE public.item_purchase_stats s
SET retailer_counts    = a.counts,
    preferred_retailer = a.top_retailer
FROM aggregated a
WHERE s.user_id = a.user_id
  AND s.item_name = a.item_name;
