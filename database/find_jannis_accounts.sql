-- Find all accounts with "jannis" in email or display name
-- Run this in Supabase SQL Editor

-- Check auth.users table for email
SELECT 
  id,
  email,
  created_at,
  last_sign_in_at,
  email_confirmed_at
FROM auth.users
WHERE email ILIKE '%jannis%'
ORDER BY created_at DESC;

-- Check users table for display name
SELECT 
  u.id,
  u.email,
  users.display_name,
  users.created_at
FROM auth.users u
LEFT JOIN public.users users ON users.id = u.id
WHERE u.email ILIKE '%jannis%' 
   OR users.display_name ILIKE '%jannis%'
ORDER BY u.created_at DESC;
