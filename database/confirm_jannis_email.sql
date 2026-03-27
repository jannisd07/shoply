-- Manually confirm email for jannis account
-- Run this in Supabase SQL Editor to bypass email confirmation

-- Find and confirm janniscyrus7@gmail.com
UPDATE auth.users
SET 
  email_confirmed_at = NOW()
WHERE email = 'janniscyrus7@gmail.com';

-- Verify the update
SELECT 
  id,
  email,
  created_at,
  email_confirmed_at,
  confirmed_at,
  last_sign_in_at
FROM auth.users
WHERE email = 'janniscyrus7@gmail.com';
