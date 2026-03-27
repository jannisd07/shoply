-- New Recipe Features Migration
-- Features: Collections, Follow Creators, Recipe Variations, Achievements, Nutrition

-- ============================================
-- FEATURE 2: Recipe Collections (Curated Lists)
-- ============================================
CREATE TABLE IF NOT EXISTS recipe_collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    cover_image_url TEXT,
    icon TEXT DEFAULT '📖',
    color TEXT DEFAULT '#3D8B99',
    is_featured BOOLEAN DEFAULT false,
    is_system BOOLEAN DEFAULT false,  -- System collections can't be deleted
    sort_order INT DEFAULT 0,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS recipe_collection_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    collection_id UUID REFERENCES recipe_collections(id) ON DELETE CASCADE,
    recipe_id UUID REFERENCES recipes(id) ON DELETE CASCADE,
    sort_order INT DEFAULT 0,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(collection_id, recipe_id)
);

-- Insert default system collections
INSERT INTO recipe_collections (name, description, icon, color, is_featured, is_system, sort_order) VALUES
('Quick & Easy', 'Recipes ready in 30 minutes or less', '⚡', '#5AC8FA', true, true, 1),
('Summer BBQ', 'Perfect recipes for outdoor grilling', '🔥', '#FF6B6B', true, true, 2),
('Weeknight Dinners', 'Simple meals for busy evenings', '🌙', '#AF52DE', true, true, 3),
('Healthy Eating', 'Nutritious and delicious recipes', '💚', '#34C759', true, true, 4),
('Comfort Food', 'Warm and cozy favorites', '🍲', '#FF9F0A', true, true, 5),
('Date Night', 'Impress your special someone', '❤️', '#FF2D55', true, true, 6)
ON CONFLICT DO NOTHING;

-- ============================================
-- FEATURE 6: Follow Creators
-- ============================================
CREATE TABLE IF NOT EXISTS creator_follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(follower_id, creator_id),
    CHECK (follower_id != creator_id)
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_creator_follows_follower ON creator_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_creator_follows_creator ON creator_follows(creator_id);

-- ============================================
-- FEATURE 10: Recipe Variations
-- ============================================
CREATE TABLE IF NOT EXISTS recipe_variations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    original_recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    changes JSONB DEFAULT '[]',  -- Array of {field, original, modified, note}
    modified_ingredients JSONB,   -- Full modified ingredients list
    modified_instructions TEXT[], -- Full modified instructions
    upvotes INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS recipe_variation_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    variation_id UUID NOT NULL REFERENCES recipe_variations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    vote INT DEFAULT 1,  -- 1 = upvote, -1 = downvote
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(variation_id, user_id)
);

-- ============================================
-- FEATURE 12: Achievement Badges
-- ============================================
CREATE TABLE IF NOT EXISTS achievement_definitions (
    id TEXT PRIMARY KEY,  -- e.g., 'first_recipe', 'saved_10'
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    icon TEXT NOT NULL,
    color TEXT DEFAULT '#FFD700',
    category TEXT DEFAULT 'general',  -- cooking, saving, social, special
    requirement_type TEXT NOT NULL,   -- recipes_cooked, recipes_saved, recipes_created, followers, etc.
    requirement_value INT NOT NULL,   -- Number needed to unlock
    points INT DEFAULT 10,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    achievement_id TEXT NOT NULL REFERENCES achievement_definitions(id) ON DELETE CASCADE,
    unlocked_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, achievement_id)
);

CREATE TABLE IF NOT EXISTS user_stats (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    recipes_cooked INT DEFAULT 0,
    recipes_saved INT DEFAULT 0,
    recipes_created INT DEFAULT 0,
    recipes_rated INT DEFAULT 0,
    followers_count INT DEFAULT 0,
    following_count INT DEFAULT 0,
    total_points INT DEFAULT 0,
    streak_days INT DEFAULT 0,
    last_activity_date DATE,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert default achievements
INSERT INTO achievement_definitions (id, name, description, icon, category, requirement_type, requirement_value, points, sort_order) VALUES
-- Cooking achievements
('first_cook', 'First Steps', 'Mark your first recipe as cooked', '👨‍🍳', 'cooking', 'recipes_cooked', 1, 10, 1),
('cook_10', 'Home Chef', 'Cook 10 recipes', '🍳', 'cooking', 'recipes_cooked', 10, 25, 2),
('cook_50', 'Kitchen Master', 'Cook 50 recipes', '👩‍🍳', 'cooking', 'recipes_cooked', 50, 50, 3),
('cook_100', 'Culinary Expert', 'Cook 100 recipes', '🏆', 'cooking', 'recipes_cooked', 100, 100, 4),
-- Saving achievements
('first_save', 'Bookmark Beginner', 'Save your first recipe', '🔖', 'saving', 'recipes_saved', 1, 10, 5),
('save_10', 'Recipe Collector', 'Save 10 recipes', '📚', 'saving', 'recipes_saved', 10, 25, 6),
('save_50', 'Recipe Hoarder', 'Save 50 recipes', '📖', 'saving', 'recipes_saved', 50, 50, 7),
-- Creating achievements
('first_create', 'Recipe Author', 'Create your first recipe', '✍️', 'creating', 'recipes_created', 1, 20, 8),
('create_5', 'Recipe Writer', 'Create 5 recipes', '📝', 'creating', 'recipes_created', 5, 50, 9),
('create_20', 'Prolific Chef', 'Create 20 recipes', '🌟', 'creating', 'recipes_created', 20, 100, 10),
-- Social achievements
('first_follower', 'Rising Star', 'Get your first follower', '⭐', 'social', 'followers_count', 1, 15, 11),
('followers_10', 'Popular Chef', 'Get 10 followers', '🔥', 'social', 'followers_count', 10, 50, 12),
('followers_100', 'Celebrity Chef', 'Get 100 followers', '👑', 'social', 'followers_count', 100, 200, 13),
-- Rating achievements
('first_rate', 'Critic', 'Rate your first recipe', '⭐', 'rating', 'recipes_rated', 1, 10, 14),
('rate_20', 'Food Critic', 'Rate 20 recipes', '🎯', 'rating', 'recipes_rated', 20, 30, 15)
ON CONFLICT (id) DO NOTHING;

-- ============================================
-- FEATURE 13: Recipe of the Day
-- ============================================
CREATE TABLE IF NOT EXISTS recipe_of_the_day (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id UUID NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    featured_date DATE NOT NULL UNIQUE,
    featured_reason TEXT,
    notification_sent BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast date lookups
CREATE INDEX IF NOT EXISTS idx_rotd_date ON recipe_of_the_day(featured_date);

-- ============================================
-- FEATURE 15: Nutrition Info (Add to recipes)
-- ============================================
ALTER TABLE recipes ADD COLUMN IF NOT EXISTS nutrition JSONB DEFAULT NULL;
-- Format: {"calories": 450, "protein": 25, "carbs": 50, "fat": 15, "fiber": 5, "sugar": 8, "sodium": 600}

ALTER TABLE recipes ADD COLUMN IF NOT EXISTS nutrition_per_serving BOOLEAN DEFAULT true;

-- ============================================
-- FEATURE 16: Unit Preferences (Add to user_preferences)
-- ============================================
-- Note: user_preferences table should already exist from prompt5 migration
-- Add unit conversion preferences
ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS unit_system TEXT DEFAULT 'metric';
-- Values: 'metric', 'imperial'

ALTER TABLE user_preferences ADD COLUMN IF NOT EXISTS temperature_unit TEXT DEFAULT 'celsius';
-- Values: 'celsius', 'fahrenheit'

-- ============================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================
ALTER TABLE recipe_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_collection_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE creator_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_variations ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_variation_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_of_the_day ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Collections are viewable by everyone" ON recipe_collections FOR SELECT USING (true);
CREATE POLICY "Users can create collections" ON recipe_collections FOR INSERT WITH CHECK (auth.uid() = created_by OR is_system = false);

CREATE POLICY "Collection items viewable by everyone" ON recipe_collection_items FOR SELECT USING (true);

CREATE POLICY "Follows viewable by everyone" ON creator_follows FOR SELECT USING (true);
CREATE POLICY "Users can manage own follows" ON creator_follows FOR ALL USING (auth.uid() = follower_id);

CREATE POLICY "Variations viewable by everyone" ON recipe_variations FOR SELECT USING (true);
CREATE POLICY "Users can create variations" ON recipe_variations FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own variations" ON recipe_variations FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Votes viewable by everyone" ON recipe_variation_votes FOR SELECT USING (true);
CREATE POLICY "Users can manage own votes" ON recipe_variation_votes FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Achievements viewable by everyone" ON user_achievements FOR SELECT USING (true);
CREATE POLICY "System can grant achievements" ON user_achievements FOR INSERT WITH CHECK (true);

CREATE POLICY "Stats viewable by everyone" ON user_stats FOR SELECT USING (true);
CREATE POLICY "Users can view own stats" ON user_stats FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "ROTD viewable by everyone" ON recipe_of_the_day FOR SELECT USING (true);
