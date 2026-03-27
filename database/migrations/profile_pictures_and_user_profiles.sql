-- =====================================================
-- Profile Pictures & User Profiles Migration
-- Adds profile picture support and author avatars on recipes
-- Date: November 4, 2025
-- =====================================================

-- Step 1: Add author_avatar_url to recipes table
ALTER TABLE recipes 
ADD COLUMN IF NOT EXISTS author_avatar_url TEXT;
xco
-- Step 2: Create profile-pictures storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-pictures', 'profile-pictures', true)
ON CONFLICT (id) DO NOTHING;

-- Step 3: Set up RLS policies for profile-pictures bucket

-- Allow users to upload their own profile picture
DROP POLICY IF EXISTS "Users can upload their own profile picture" ON storage.objects;
CREATE POLICY "Users can upload their own profile picture"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'profile-pictures' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Profile pictures are publicly accessible
DROP POLICY IF EXISTS "Profile pictures are publicly accessible" ON storage.objects;
CREATE POLICY "Profile pictures are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'profile-pictures');

-- Users can update their own profile picture
DROP POLICY IF EXISTS "Users can update their own profile picture" ON storage.objects;
CREATE POLICY "Users can update their own profile picture"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'profile-pictures' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Users can delete their own profile picture
DROP POLICY IF EXISTS "Users can delete their own profile picture" ON storage.objects;
CREATE POLICY "Users can delete their own profile picture"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'profile-pictures' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Step 4: Create index for faster author queries
CREATE INDEX IF NOT EXISTS idx_recipes_author_id ON recipes(author_id);

-- =====================================================
-- Migration Complete
-- =====================================================
-- 
-- What changed:
-- 1. Added author_avatar_url column to recipes
-- 2. Created profile-pictures storage bucket
-- 3. Set up RLS policies for secure uploads
-- 4. Added index for author queries
--
-- Next steps:
-- 1. Update Recipe model in Flutter
-- 2. Implement profile picture upload UI
-- 3. Create user profile screen
-- 4. Update recipe cards to show author avatar
-- =====================================================
