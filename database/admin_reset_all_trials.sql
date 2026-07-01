-- ============================================
-- COPY AND RUN IN SUPABASE SQL EDITOR
-- ============================================
-- URL: https://supabase.com/dashboard/project/rtwzzerhgieyxsijemsd/editor
-- ============================================

-- 1. Reset trial status for ALL users
UPDATE users
SET 
  trial_ends_at = NULL,
  subscription_status = 'inactive',
  subscription_tier = 'free',
  subscription_expires_at = NULL
WHERE trial_ends_at IS NOT NULL 
   OR subscription_status IN ('trial', 'active');

-- 2. Verify the reset
SELECT 
  id,
  email,
  subscription_status,
  subscription_tier,
  trial_ends_at,
  subscription_expires_at
FROM users
ORDER BY created_at DESC
LIMIT 10;
