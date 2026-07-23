-- ==================================================================
-- Add app_priorities to users
-- ==================================================================
-- Feature 7 (Personalized onboarding & navbar) — a brief-required
-- capability that had no implementation anywhere: "Ask what kind of
-- user they are / what they want from the app." Stores the persona
-- chips a user picks during onboarding (or edits later from Profile),
-- e.g. ["save_money", "share_lists"]. Read by the home screen to
-- reorder the existing proactive nudge cards (split/restock/calorie/
-- price) so the ones matching what the user said they care about show
-- first — no card is hidden or gated, this only affects order.
-- ==================================================================

ALTER TABLE users
ADD COLUMN IF NOT EXISTS app_priorities JSONB NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN users.app_priorities IS
  'Onboarding "what brings you to Shoply" answers, e.g. ["save_money","share_lists"]. Drives home-screen nudge-card ordering only — never gates a feature.';
