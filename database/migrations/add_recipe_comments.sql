-- Recipe Comments System Migration
-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/rtwzzerhgieyxsijemsd/editor

-- Create recipe_comments table
CREATE TABLE IF NOT EXISTS recipe_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  comment TEXT NOT NULL CHECK (length(comment) > 0 AND length(comment) <= 500),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_recipe_comments_recipe_id ON recipe_comments(recipe_id);
CREATE INDEX IF NOT EXISTS idx_recipe_comments_user_id ON recipe_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_recipe_comments_created_at ON recipe_comments(created_at DESC);

-- Enable Row Level Security
ALTER TABLE recipe_comments ENABLE ROW LEVEL SECURITY;

-- Policy: Anyone can read comments
CREATE POLICY "Anyone can read recipe comments"
ON recipe_comments FOR SELECT
USING (true);

-- Policy: Authenticated users can create comments
CREATE POLICY "Authenticated users can create comments"
ON recipe_comments FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own comments
CREATE POLICY "Users can update their own comments"
ON recipe_comments FOR UPDATE
USING (auth.uid() = user_id);

-- Policy: Users can delete their own comments
CREATE POLICY "Users can delete their own comments"
ON recipe_comments FOR DELETE
USING (auth.uid() = user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_recipe_comment_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER recipe_comment_updated_at
BEFORE UPDATE ON recipe_comments
FOR EACH ROW
EXECUTE FUNCTION update_recipe_comment_updated_at();

-- Verify the table was created
SELECT 
  'recipe_comments table created with ' || COUNT(*) || ' comments' as status
FROM recipe_comments;
