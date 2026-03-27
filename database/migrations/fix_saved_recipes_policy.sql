-- Quick fix: Add missing UPDATE policy for saved_recipes upsert
-- Run this if you already ran add_saved_recipes.sql

-- Drop if exists, then create (PostgreSQL doesn't support IF NOT EXISTS for policies)
DROP POLICY IF EXISTS "Users can update own saved recipes" ON saved_recipes;

CREATE POLICY "Users can update own saved recipes"
    ON saved_recipes
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
