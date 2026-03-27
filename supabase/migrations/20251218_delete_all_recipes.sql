-- Delete all recipes and related data
-- This migration removes all existing recipes so users can create fresh ones

-- Delete related data first (foreign key constraints)
-- Using IF EXISTS pattern with DO blocks for tables that may not exist
DELETE FROM recipe_ratings WHERE true;

DO $$ BEGIN
  DELETE FROM recipe_comments WHERE true;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DELETE FROM saved_recipes WHERE true;

DO $$ BEGIN
  DELETE FROM collection_recipes WHERE true;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- Delete all recipes
DELETE FROM recipes WHERE true;
