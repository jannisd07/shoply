-- =====================================================
-- Recipe Rating System Migration
-- Converts from likes to 5-star rating system
-- Date: November 4, 2025
-- =====================================================

-- Step 1: Drop old recipe_likes table
DROP TABLE IF EXISTS recipe_likes CASCADE;

-- Step 2: Create new recipe_ratings table
CREATE TABLE IF NOT EXISTS recipe_ratings (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(recipe_id, user_id)
);

-- Step 3: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_recipe_ratings_recipe_id ON recipe_ratings(recipe_id);
CREATE INDEX IF NOT EXISTS idx_recipe_ratings_user_id ON recipe_ratings(user_id);

-- Step 4: Reset all recipe data (as requested - clean slate)
-- This removes all user-created recipes and ratings
DELETE FROM recipe_ratings;
DELETE FROM recipes WHERE author_id IS NOT NULL;

-- Step 5: Enable Row Level Security
ALTER TABLE recipe_ratings ENABLE ROW LEVEL SECURITY;

-- Step 6: Create RLS Policies

-- Allow everyone to view all ratings
DROP POLICY IF EXISTS "Users can view all ratings" ON recipe_ratings;
CREATE POLICY "Users can view all ratings"
  ON recipe_ratings FOR SELECT
  USING (true);

-- Allow users to insert their own ratings
DROP POLICY IF EXISTS "Users can insert their own ratings" ON recipe_ratings;
CREATE POLICY "Users can insert their own ratings"
  ON recipe_ratings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Allow users to update their own ratings
DROP POLICY IF EXISTS "Users can update their own ratings" ON recipe_ratings;
CREATE POLICY "Users can update their own ratings"
  ON recipe_ratings FOR UPDATE
  USING (auth.uid() = user_id);

-- Allow users to delete their own ratings
DROP POLICY IF EXISTS "Users can delete their own ratings" ON recipe_ratings;
CREATE POLICY "Users can delete their own ratings"
  ON recipe_ratings FOR DELETE
  USING (auth.uid() = user_id);

-- Step 7: Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_recipe_rating_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 8: Create trigger for updated_at
DROP TRIGGER IF EXISTS recipe_ratings_updated_at ON recipe_ratings;
CREATE TRIGGER recipe_ratings_updated_at
  BEFORE UPDATE ON recipe_ratings
  FOR EACH ROW
  EXECUTE FUNCTION update_recipe_rating_updated_at();

-- =====================================================
-- Migration Complete
-- =====================================================
-- 
-- What changed:
-- 1. recipe_likes table → recipe_ratings table
-- 2. Binary like → 1-5 star rating
-- 3. All recipe data reset (clean slate)
-- 4. Proper indexes and RLS policies
--
-- Next steps:
-- 1. Update Flutter app to use new rating system
-- 2. Test rating submission and retrieval
-- 3. Verify average rating calculation
-- =====================================================
