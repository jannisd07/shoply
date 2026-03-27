-- Reset trial status for all users
-- Use this to test the trial flow again

-- Remove trial status from all users
UPDATE users
SET 
  trial_ends_at = NULL,
  subscription_status = 'inactive',
  subscription_tier = 'free',
  subscription_expires_at = NULL
WHERE trial_ends_at IS NOT NULL 
   OR subscription_status IN ('trial', 'active');

-- Optional: Also clear subscription transactions (if you want a complete reset)
-- TRUNCATE TABLE subscription_transactions;

-- Verify the reset
SELECT 
  id,
  email,
  subscription_status,
  subscription_tier,
  trial_ends_at,
  subscription_expires_at
FROM users
LIMIT 10;
