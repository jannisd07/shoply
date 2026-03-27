-- Recipe Features Migration
-- Collections, Follows, Challenges, Nutrition

-- =============================================
-- RECIPE COLLECTIONS (Curated Lists)
-- =============================================
CREATE TABLE IF NOT EXISTS recipe_collections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    name_de TEXT, -- German translation
    description TEXT,
    description_de TEXT,
    image_url TEXT,
    icon TEXT DEFAULT '📚', -- Emoji icon
    is_featured BOOLEAN DEFAULT false,
    display_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS collection_recipes (
    collection_id UUID REFERENCES recipe_collections(id) ON DELETE CASCADE,
    recipe_id TEXT NOT NULL, -- Can be sample recipe ID or UUID
    display_order INT DEFAULT 0,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (collection_id, recipe_id)
);

-- Enable RLS
ALTER TABLE recipe_collections ENABLE ROW LEVEL SECURITY;
ALTER TABLE collection_recipes ENABLE ROW LEVEL SECURITY;

-- Policies - collections are public read
CREATE POLICY "Collections are publicly readable" ON recipe_collections
    FOR SELECT USING (true);

CREATE POLICY "Collection recipes are publicly readable" ON collection_recipes
    FOR SELECT USING (true);

-- Insert default collections
INSERT INTO recipe_collections (name, name_de, description, description_de, icon, is_featured, display_order) VALUES
('Quick Weeknight Dinners', 'Schnelle Feierabendküche', 'Ready in 30 minutes or less', 'Fertig in 30 Minuten oder weniger', '⚡', true, 1),
('Summer BBQ', 'Sommer Grillparty', 'Perfect recipes for outdoor cooking', 'Perfekte Rezepte fürs Grillen', '🔥', true, 2),
('Healthy Meal Prep', 'Gesunde Meal Prep', 'Prep once, eat all week', 'Einmal vorbereiten, die ganze Woche essen', '🥗', true, 3),
('Comfort Food Classics', 'Comfort Food Klassiker', 'Hearty dishes that warm the soul', 'Herzhafte Gerichte die die Seele wärmen', '🍲', true, 4),
('Budget-Friendly', 'Günstig & Lecker', 'Delicious meals that won''t break the bank', 'Leckere Gerichte die den Geldbeutel schonen', '💰', false, 5),
('Date Night', 'Romantisches Dinner', 'Impressive dishes for special occasions', 'Beeindruckende Gerichte für besondere Anlässe', '❤️', false, 6),
('Kid-Approved', 'Kinderfreundlich', 'Recipes the whole family will love', 'Rezepte die der ganzen Familie schmecken', '👨‍👩‍👧‍👦', false, 7),
('One-Pot Wonders', 'Ein-Topf-Gerichte', 'Minimal cleanup, maximum flavor', 'Minimaler Aufwand, maximaler Geschmack', '🍳', false, 8)
ON CONFLICT DO NOTHING;

-- =============================================
-- CREATOR FOLLOWS
-- =============================================
CREATE TABLE IF NOT EXISTS creator_follows (
    follower_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    creator_id UUID NOT NULL, -- Can also be TEXT for flexibility
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (follower_id, creator_id)
);

CREATE INDEX IF NOT EXISTS idx_creator_follows_creator ON creator_follows(creator_id);
CREATE INDEX IF NOT EXISTS idx_creator_follows_follower ON creator_follows(follower_id);

-- Enable RLS
ALTER TABLE creator_follows ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their follows" ON creator_follows
    FOR SELECT USING (auth.uid() = follower_id);

CREATE POLICY "Users can follow creators" ON creator_follows
    FOR INSERT WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can unfollow" ON creator_follows
    FOR DELETE USING (auth.uid() = follower_id);

-- =============================================
-- WEEKLY CHALLENGES
-- =============================================
CREATE TABLE IF NOT EXISTS weekly_challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    title_de TEXT,
    description TEXT NOT NULL,
    description_de TEXT,
    image_url TEXT,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    prize_description TEXT,
    prize_description_de TEXT,
    hashtag TEXT, -- e.g. #ShoplySummerChallenge
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS challenge_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenge_id UUID REFERENCES weekly_challenges(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    recipe_id TEXT NOT NULL,
    photo_url TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(challenge_id, user_id) -- One entry per user per challenge
);

-- Enable RLS
ALTER TABLE weekly_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenge_entries ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Challenges are publicly readable" ON weekly_challenges
    FOR SELECT USING (true);

CREATE POLICY "Entries are publicly readable" ON challenge_entries
    FOR SELECT USING (true);

CREATE POLICY "Users can submit entries" ON challenge_entries
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own entries" ON challenge_entries
    FOR UPDATE USING (auth.uid() = user_id);

-- Insert sample challenge
INSERT INTO weekly_challenges (title, title_de, description, description_de, start_date, end_date, hashtag) VALUES
('5 Ingredient Challenge', '5-Zutaten-Challenge', 'Create a delicious meal using only 5 ingredients!', 'Kreiere ein leckeres Gericht mit nur 5 Zutaten!', CURRENT_DATE, CURRENT_DATE + INTERVAL '7 days', '#Shoply5Ingredients')
ON CONFLICT DO NOTHING;

-- =============================================
-- RECIPE OF THE DAY
-- =============================================
CREATE TABLE IF NOT EXISTS recipe_of_the_day (
    date DATE PRIMARY KEY,
    recipe_id TEXT NOT NULL,
    featured_reason TEXT,
    featured_reason_de TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE recipe_of_the_day ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Recipe of day is publicly readable" ON recipe_of_the_day
    FOR SELECT USING (true);

-- =============================================
-- NUTRITION INFO (extends recipes)
-- =============================================
CREATE TABLE IF NOT EXISTS recipe_nutrition (
    recipe_id TEXT PRIMARY KEY,
    calories INT, -- per serving
    protein_g DECIMAL(6,1),
    carbs_g DECIMAL(6,1),
    fat_g DECIMAL(6,1),
    fiber_g DECIMAL(6,1),
    sugar_g DECIMAL(6,1),
    sodium_mg INT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE recipe_nutrition ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Nutrition info is publicly readable" ON recipe_nutrition
    FOR SELECT USING (true);

-- Insert sample nutrition data for sample recipes
INSERT INTO recipe_nutrition (recipe_id, calories, protein_g, carbs_g, fat_g, fiber_g, sugar_g, sodium_mg) VALUES
('recipe_001', 520, 28, 45, 24, 3, 5, 680),
('recipe_002', 380, 12, 62, 8, 4, 8, 420),
('recipe_003', 290, 8, 35, 12, 6, 4, 380),
('recipe_004', 680, 35, 52, 32, 2, 6, 890),
('recipe_005', 420, 22, 38, 18, 5, 3, 520)
ON CONFLICT DO NOTHING;

-- =============================================
-- USER PREFERENCES (for unit conversion)
-- =============================================
-- This extends the existing users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS unit_system TEXT DEFAULT 'metric'; -- 'metric' or 'imperial'
ALTER TABLE users ADD COLUMN IF NOT EXISTS temperature_unit TEXT DEFAULT 'celsius'; -- 'celsius' or 'fahrenheit'
