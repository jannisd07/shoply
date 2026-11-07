-- 20251218_delete_all_recipes (neutralized)
--
-- This was a one-off data wipe (DELETE FROM recipes / recipe_ratings /
-- recipe_comments / saved_recipes / collection_recipes) that ran once in
-- December 2025. It stays in the migration chain only so the CLI's
-- migration history keeps matching the remote project; its body is now a
-- no-op so `supabase db reset` or a push to a fresh project no longer
-- deletes every recipe. The original statements are in git history.

select 1;
