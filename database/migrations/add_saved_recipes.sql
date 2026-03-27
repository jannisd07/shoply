-- Migration: Add saved_recipes table for bookmarking recipes
-- Created: 2025-01-XX
-- Description: Allows users to save/bookmark recipes for quick access

-- Create saved_recipes table
CREATE TABLE IF NOT EXISTS saved_recipes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    recipe_id TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure unique user-recipe pairs
    UNIQUE(user_id, recipe_id)
);

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_saved_recipes_user_id ON saved_recipes(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_recipes_recipe_id ON saved_recipes(recipe_id);
CREATE INDEX IF NOT EXISTS idx_saved_recipes_created_at ON saved_recipes(created_at DESC);

-- Enable Row Level Security
ALTER TABLE saved_recipes ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own saved recipes
CREATE POLICY "Users can view own saved recipes"
    ON saved_recipes
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Users can insert their own saved recipes
CREATE POLICY "Users can save recipes"
    ON saved_recipes
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own saved recipes
CREATE POLICY "Users can unsave recipes"
    ON saved_recipes
    FOR DELETE
    USING (auth.uid() = user_id);

-- Policy: Users can update their own saved recipes (needed for upsert)
CREATE POLICY "Users can update own saved recipes"
    ON saved_recipes
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Grant permissions
GRANT ALL ON saved_recipes TO authenticated;
GRANT SELECT ON saved_recipes TO anon;
