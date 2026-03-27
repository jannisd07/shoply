-- Migration: Smart Trial Detection in activate_subscription
-- This migration updates the activate_subscription function to automatically
-- detect if this is a first-time purchase and activate trial instead

-- Drop and recreate activate_subscription with trial detection
CREATE OR REPLACE FUNCTION activate_subscription(
  user_uuid UUID,
  tier TEXT,
  transaction_id_param TEXT,
  platform_param TEXT,
  expiry_date_param TIMESTAMP WITH TIME ZONE
)
RETURNS void AS $$
DECLARE
  user_trial_date TIMESTAMP WITH TIME ZONE;
  is_trial_eligible BOOLEAN;
BEGIN
  -- Check if user has ever used trial
  SELECT trial_ends_at INTO user_trial_date
  FROM users
  WHERE id = user_uuid;
  
  -- User is eligible for trial if they've never had one
  is_trial_eligible := (user_trial_date IS NULL);
  
  IF is_trial_eligible THEN
    -- ACTIVATE AS TRIAL (14 days free, then subscription)
    UPDATE users
    SET 
      subscription_tier = tier,
      subscription_status = 'trial',
      subscription_expires_at = NOW() + INTERVAL '14 days',
      trial_ends_at = NOW() + INTERVAL '14 days',
      subscription_started_at = COALESCE(subscription_started_at, NOW()),
      last_payment_date = NOW()
    WHERE id = user_uuid;
    
    -- Insert transaction record (marked as trial)
    INSERT INTO subscription_transactions (
      user_id,
      transaction_id,
      product_id,
      platform,
      purchase_date,
      expiry_date,
      is_trial
    ) VALUES (
      user_uuid,
      transaction_id_param,
      tier,
      platform_param,
      NOW(),
      NOW() + INTERVAL '14 days',
      TRUE  -- This is a trial
    );
  ELSE
    -- ACTIVATE AS PAID SUBSCRIPTION (trial already used)
    UPDATE users
    SET 
      subscription_tier = tier,
      subscription_status = 'active',
      subscription_expires_at = expiry_date_param,
      subscription_started_at = COALESCE(subscription_started_at, NOW()),
      last_payment_date = NOW()
    WHERE id = user_uuid;
    
    -- Insert transaction record (not a trial)
    INSERT INTO subscription_transactions (
      user_id,
      transaction_id,
      product_id,
      platform,
      purchase_date,
      expiry_date,
      is_trial
    ) VALUES (
      user_uuid,
      transaction_id_param,
      tier,
      platform_param,
      NOW(),
      expiry_date_param,
      FALSE  -- This is a paid subscription
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
