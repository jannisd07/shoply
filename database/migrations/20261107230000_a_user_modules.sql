-- Teil A, A1 (07.11.2026): module choices per account (Konzept 00, Kap. 15).
-- Read and written by lib/core/modules/app_modules.dart (DefaultModuleStore).
-- Shape: {"offers": true, "meal_plan": true, "calories": false, "avo": true, "cost_split": false}
-- An empty object means "never chosen"; the app then keeps the device choice.
-- Existing RLS on user_preferences (own row only) covers the new column.
-- Applied 2026-11-07 to project rtwzzerhgieyxsijemsd (ShoplyAI) with the
-- owner's approval (Teil A session).

ALTER TABLE public.user_preferences
  ADD COLUMN IF NOT EXISTS modules JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.user_preferences.modules IS
  'Avo module switches by id (offers, meal_plan, calories, avo, cost_split).';
