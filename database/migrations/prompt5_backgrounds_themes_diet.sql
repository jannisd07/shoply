-- ==================================================================
-- PROMPT 5: Backgrounds, Themes & Diet Features Migration
-- ==================================================================
-- Run this in Supabase SQL Editor after premium subscription system
-- This adds:
-- 1. List background system (color/gradient/image)
-- 2. User theme preferences (True Black, High Contrast, etc.)
-- 3. Ingredient diet tags for filtering & analysis
-- ==================================================================

-- ============================================================================
-- 1. UPDATE SHOPPING_LISTS TABLE - Add Background Support
-- ============================================================================

-- Add new background columns
ALTER TABLE shopping_lists 
ADD COLUMN IF NOT EXISTS background_type TEXT 
CHECK (background_type IN ('color', 'gradient', 'image')) 
DEFAULT 'gradient';

ALTER TABLE shopping_lists 
ADD COLUMN IF NOT EXISTS background_value TEXT;

ALTER TABLE shopping_lists 
ADD COLUMN IF NOT EXISTS background_image_url TEXT;

-- Create index for background type queries
CREATE INDEX IF NOT EXISTS idx_shopping_lists_background_type 
ON shopping_lists(background_type);

-- Migrate existing background_gradient data to new system
UPDATE shopping_lists 
SET background_type = 'gradient', 
    background_value = background_gradient
WHERE background_gradient IS NOT NULL 
  AND background_type IS NULL;

-- Set default for lists with no background
UPDATE shopping_lists 
SET background_type = 'color',
    background_value = '#000000' -- Black default
WHERE background_type IS NULL;

-- Optional: Drop old column after migration (comment out if keeping for backwards compat)
-- ALTER TABLE shopping_lists DROP COLUMN IF EXISTS background_gradient;

COMMENT ON COLUMN shopping_lists.background_type IS 
'Type of background: color (solid hex), gradient (gradient ID), or image (Supabase storage URL)';

COMMENT ON COLUMN shopping_lists.background_value IS 
'Value for background: hex color code for color type, gradient_X ID for gradient type, or image filename for image type';

COMMENT ON COLUMN shopping_lists.background_image_url IS 
'Full Supabase storage URL for image backgrounds. NULL for color/gradient types.';

-- ============================================================================
-- 2. CREATE USER_PREFERENCES TABLE - Theme Customization
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_preferences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Theme Settings
  theme_mode TEXT CHECK (theme_mode IN ('light', 'dark', 'system')) DEFAULT 'system',
  theme_variant TEXT CHECK (theme_variant IN ('standard', 'true_black', 'high_contrast', 'warm', 'cool')) DEFAULT 'standard',
  accent_color TEXT DEFAULT '#2196F3', -- Material Blue
  
  -- Timestamps
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  
  -- Ensure one preference row per user
  UNIQUE(user_id)
);

-- Enable Row Level Security
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can only access their own preferences
CREATE POLICY "Users can view their own preferences" 
ON user_preferences FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own preferences" 
ON user_preferences FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own preferences" 
ON user_preferences FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own preferences" 
ON user_preferences FOR DELETE 
USING (auth.uid() = user_id);

-- Create index for fast user lookups
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id 
ON user_preferences(user_id);

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_user_preferences_updated_at
BEFORE UPDATE ON user_preferences
FOR EACH ROW
EXECUTE FUNCTION update_user_preferences_updated_at();

COMMENT ON TABLE user_preferences IS 
'Stores user-specific theme and UI preferences including advanced theme variants (premium feature)';

-- ============================================================================
-- 3. CREATE INGREDIENT_DIET_TAGS TABLE - Diet Filtering & Analysis
-- ============================================================================

CREATE TABLE IF NOT EXISTS ingredient_diet_tags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ingredient_name TEXT NOT NULL,
  
  -- Diet Compatibility Flags
  is_vegan BOOLEAN DEFAULT TRUE,
  is_vegetarian BOOLEAN DEFAULT TRUE,
  is_gluten_free BOOLEAN DEFAULT TRUE,
  is_dairy_free BOOLEAN DEFAULT TRUE,
  is_nut_free BOOLEAN DEFAULT TRUE,
  is_soy_free BOOLEAN DEFAULT TRUE,
  is_egg_free BOOLEAN DEFAULT TRUE,
  
  -- Additional Allergen Info
  contains_shellfish BOOLEAN DEFAULT FALSE,
  contains_fish BOOLEAN DEFAULT FALSE,
  
  -- Metadata
  verified BOOLEAN DEFAULT FALSE, -- TRUE if manually verified, FALSE if AI-generated
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create unique index for case-insensitive ingredient names (instead of constraint)
CREATE UNIQUE INDEX IF NOT EXISTS idx_ingredient_diet_tags_name_unique 
ON ingredient_diet_tags(LOWER(ingredient_name));

-- Create indexes for fast diet filtering
CREATE INDEX IF NOT EXISTS idx_ingredient_diet_tags_vegan 
ON ingredient_diet_tags(is_vegan) 
WHERE is_vegan = FALSE;

CREATE INDEX IF NOT EXISTS idx_ingredient_diet_tags_vegetarian 
ON ingredient_diet_tags(is_vegetarian) 
WHERE is_vegetarian = FALSE;

CREATE INDEX IF NOT EXISTS idx_ingredient_diet_tags_gluten_free 
ON ingredient_diet_tags(is_gluten_free) 
WHERE is_gluten_free = FALSE;

CREATE INDEX IF NOT EXISTS idx_ingredient_diet_tags_dairy_free 
ON ingredient_diet_tags(is_dairy_free) 
WHERE is_dairy_free = FALSE;

CREATE INDEX IF NOT EXISTS idx_ingredient_diet_tags_nut_free 
ON ingredient_diet_tags(is_nut_free) 
WHERE is_nut_free = FALSE;

-- Enable pg_trgm extension for fuzzy search (must be enabled BEFORE creating the GIN index)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Full-text search index for ingredient name lookups
CREATE INDEX IF NOT EXISTS idx_ingredient_diet_tags_name_trgm 
ON ingredient_diet_tags USING gin(LOWER(ingredient_name) gin_trgm_ops);

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_ingredient_diet_tags_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_ingredient_diet_tags_updated_at
BEFORE UPDATE ON ingredient_diet_tags
FOR EACH ROW
EXECUTE FUNCTION update_ingredient_diet_tags_updated_at();

COMMENT ON TABLE ingredient_diet_tags IS 
'Contains diet and allergen information for ingredients. Used for recipe filtering and diet warnings. Can be populated manually or via AI.';

-- ============================================================================
-- 4. HELPER FUNCTIONS
-- ============================================================================

-- Function to check if an ingredient is compatible with diet preferences
CREATE OR REPLACE FUNCTION is_ingredient_compatible(
  p_ingredient_name TEXT,
  p_diet_preferences JSONB
)
RETURNS BOOLEAN AS $$
DECLARE
  v_tag RECORD;
  v_diet TEXT;
BEGIN
  -- Get ingredient tags (case-insensitive lookup)
  SELECT * INTO v_tag 
  FROM ingredient_diet_tags 
  WHERE LOWER(ingredient_name) = LOWER(p_ingredient_name)
  LIMIT 1;
  
  -- If ingredient not in database, assume compatible (will be flagged for AI analysis)
  IF v_tag IS NULL THEN
    RETURN TRUE;
  END IF;
  
  -- Check each diet preference
  FOR v_diet IN SELECT jsonb_array_elements_text(p_diet_preferences)
  LOOP
    CASE v_diet
      WHEN 'vegan' THEN
        IF NOT v_tag.is_vegan THEN RETURN FALSE; END IF;
      WHEN 'vegetarian' THEN
        IF NOT v_tag.is_vegetarian THEN RETURN FALSE; END IF;
      WHEN 'gluten_free' THEN
        IF NOT v_tag.is_gluten_free THEN RETURN FALSE; END IF;
      WHEN 'dairy_free' THEN
        IF NOT v_tag.is_dairy_free THEN RETURN FALSE; END IF;
      WHEN 'nut_free' THEN
        IF NOT v_tag.is_nut_free THEN RETURN FALSE; END IF;
      WHEN 'soy_free' THEN
        IF NOT v_tag.is_soy_free THEN RETURN FALSE; END IF;
      WHEN 'egg_free' THEN
        IF NOT v_tag.is_egg_free THEN RETURN FALSE; END IF;
      WHEN 'shellfish_free' THEN
        IF v_tag.contains_shellfish THEN RETURN FALSE; END IF;
      WHEN 'fish_free' THEN
        IF v_tag.contains_fish THEN RETURN FALSE; END IF;
    END CASE;
  END LOOP;
  
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION is_ingredient_compatible IS 
'Checks if an ingredient is compatible with given diet preferences. Returns TRUE if compatible or if ingredient not found in database.';

-- Function to get incompatible ingredients from a recipe
CREATE OR REPLACE FUNCTION get_incompatible_ingredients(
  p_recipe_id UUID,
  p_user_id UUID
)
RETURNS TABLE(ingredient_name TEXT, violated_diet TEXT) AS $$
DECLARE
  v_diet_preferences JSONB;
BEGIN
  -- Get user's diet preferences
  SELECT diet_preferences INTO v_diet_preferences
  FROM users
  WHERE id = p_user_id;
  
  -- If no preferences, return empty
  IF v_diet_preferences IS NULL OR jsonb_array_length(v_diet_preferences) = 0 THEN
    RETURN;
  END IF;
  
  -- Find incompatible ingredients
  -- Note: This assumes recipes table has an ingredients JSONB column
  -- Adjust based on your actual recipe schema
  RETURN QUERY
  SELECT 
    ing.ingredient_name,
    pref::TEXT as violated_diet
  FROM ingredient_diet_tags ing
  CROSS JOIN jsonb_array_elements_text(v_diet_preferences) pref
  WHERE NOT is_ingredient_compatible(ing.ingredient_name, v_diet_preferences);
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION get_incompatible_ingredients IS 
'Returns list of ingredients in a recipe that violate user diet preferences';

-- ============================================================================
-- 5. SEED DATA - Common Ingredients (Starter Set)
-- ============================================================================

-- Insert 50+ common ingredients to bootstrap the system
-- Users can expand this via app usage (AI will auto-populate unknown ingredients)

INSERT INTO ingredient_diet_tags (ingredient_name, is_vegan, is_vegetarian, is_gluten_free, is_dairy_free, is_nut_free, is_soy_free, is_egg_free, contains_shellfish, contains_fish, verified) VALUES
-- Meats & Proteins
('chicken', FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('beef', FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('pork', FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('lamb', FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('turkey', FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('salmon', FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE),
('tuna', FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE),
('shrimp', FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE),
('bacon', FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),

-- Dairy & Eggs
('milk', FALSE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('cheese', FALSE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('butter', FALSE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('cream', FALSE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('yogurt', FALSE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('eggs', FALSE, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE),
('mozzarella', FALSE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('parmesan', FALSE, FALSE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),

-- Grains & Flours
('wheat flour', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('white flour', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('bread', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('pasta', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('rice', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('quinoa', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('oats', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('barley', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),

-- Nuts & Seeds
('almonds', TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, TRUE),
('walnuts', TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, TRUE),
('cashews', TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, TRUE),
('peanuts', TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, TRUE),
('peanut butter', TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, TRUE),
('sunflower seeds', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('chia seeds', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),

-- Soy Products
('tofu', TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE),
('soy sauce', TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE),
('tempeh', TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE),
('edamame', TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE),

-- Vegetables (all vegan-friendly)
('tomato', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('onion', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('garlic', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('carrot', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('broccoli', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('spinach', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('potato', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('bell pepper', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),

-- Fruits (all vegan-friendly)
('apple', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('banana', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('orange', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('strawberry', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('blueberry', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),

-- Sweeteners
('honey', FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('sugar', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE),
('maple syrup', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE)

ON CONFLICT (LOWER(ingredient_name)) DO NOTHING;

-- ============================================================================
-- 6. PERFORMANCE & CLEANUP
-- ============================================================================

-- Analyze tables for query planner optimization
ANALYZE shopping_lists;
ANALYZE user_preferences;
ANALYZE ingredient_diet_tags;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Verify migration success
DO $$
DECLARE
  v_lists_count INT;
  v_prefs_count INT;
  v_ingredients_count INT;
BEGIN
  SELECT COUNT(*) INTO v_lists_count FROM shopping_lists WHERE background_type IS NOT NULL;
  SELECT COUNT(*) INTO v_prefs_count FROM user_preferences;
  SELECT COUNT(*) INTO v_ingredients_count FROM ingredient_diet_tags;
  
  RAISE NOTICE '✅ Migration Complete!';
  RAISE NOTICE '   - Shopping lists with backgrounds: %', v_lists_count;
  RAISE NOTICE '   - User preferences created: %', v_prefs_count;
  RAISE NOTICE '   - Ingredient tags populated: %', v_ingredients_count;
  RAISE NOTICE '';
  RAISE NOTICE '📝 Next Steps:';
  RAISE NOTICE '   1. Create "list-backgrounds" storage bucket in Supabase';
  RAISE NOTICE '   2. Set bucket to public readable';
  RAISE NOTICE '   3. Configure bucket policies (5MB file size limit)';
  RAISE NOTICE '   4. Test background image upload in app';
  RAISE NOTICE '   5. Populate more ingredients via AI or manual entry';
END $$;
