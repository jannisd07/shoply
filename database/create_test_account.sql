-- Create a new test account that's already confirmed
-- Run this in Supabase SQL Editor

-- Create test user with confirmed email
-- Password will be: Test123456!

-- First, let's create the user via Supabase auth
-- You'll need to do this in two steps:

-- Step 1: Create the user (run this first)
-- Go to Authentication > Users in Supabase Dashboard
-- Click "Add User" and use:
-- Email: test@shoplyapp.com
-- Password: Test123456!
-- Auto Confirm User: YES (check this box!)

-- OR use this SQL if you have the service role key:
-- This creates a user with a hashed password for "Test123456!"

INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  invited_at,
  confirmation_token,
  confirmation_sent_at,
  recovery_token,
  recovery_sent_at,
  email_change_token_new,
  email_change,
  email_change_sent_at,
  last_sign_in_at,
  raw_app_meta_data,
  raw_user_meta_data,
  is_super_admin,
  created_at,
  updated_at,
  phone,
  phone_confirmed_at,
  phone_change,
  phone_change_token,
  phone_change_sent_at,
  email_change_token_current,
  email_change_confirm_status,
  banned_until,
  reauthentication_token,
  reauthentication_sent_at,
  is_sso_user,
  deleted_at
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'test@shoplyapp.com',
  '$2a$10$rKvBw7ZLkJKQZ5Z5Z5Z5ZeF5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5Z5ZO',  -- This is a placeholder, won't work
  NOW(),
  NOW(),
  '',
  NOW(),
  '',
  NULL,
  '',
  '',
  NULL,
  NULL,
  '{"provider":"email","providers":["email"]}',
  '{"display_name":"Test User"}',
  FALSE,
  NOW(),
  NOW(),
  NULL,
  NULL,
  '',
  '',
  NULL,
  '',
  0,
  NULL,
  '',
  NULL,
  FALSE,
  NULL
) ON CONFLICT (email) DO NOTHING;

-- Step 2: Create user profile in public.users table
INSERT INTO public.users (
  id,
  email,
  display_name,
  created_at,
  updated_at
)
SELECT 
  id,
  email,
  'Test User',
  NOW(),
  NOW()
FROM auth.users
WHERE email = 'test@shoplyapp.com'
ON CONFLICT (id) DO NOTHING;

-- Verify the account was created
SELECT 
  id,
  email,
  email_confirmed_at,
  created_at
FROM auth.users
WHERE email = 'test@shoplyapp.com';
