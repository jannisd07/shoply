-- =====================================================
-- Premium Subscription System Migration
-- Adds subscription tracking to users table
-- Date: November 5, 2025
-- =====================================================

-- Step 1: Add subscription columns to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium_monthly', 'premium_yearly')),
ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT 'inactive' CHECK (subscription_status IN ('inactive', 'trial', 'active', 'expired', 'cancelled')),
ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS trial_ends_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS subscription_started_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS last_payment_date TIMESTAMP WITH TIME ZONE;

-- Step 2: Create subscription_transactions table for audit trail
CREATE TABLE IF NOT EXISTS subscription_transactions (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  transaction_id TEXT NOT NULL UNIQUE, -- Store receipt ID
  product_id TEXT NOT NULL, -- shoply_premium_monthly or shoply_premium_yearly
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  purchase_date TIMESTAMP WITH TIME ZONE NOT NULL,
  expiry_date TIMESTAMP WITH TIME ZONE NOT NULL,
  is_trial BOOLEAN DEFAULT FALSE,
  transaction_receipt TEXT, -- Store original receipt for validation
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 3: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_subscription_status ON users(subscription_status);
CREATE INDEX IF NOT EXISTS idx_users_subscription_expires ON users(subscription_expires_at);
CREATE INDEX IF NOT EXISTS idx_subscription_transactions_user ON subscription_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscription_transactions_transaction ON subscription_transactions(transaction_id);

-- Step 4: Enable Row Level Security
ALTER TABLE subscription_transactions ENABLE ROW LEVEL SECURITY;

-- Step 5: RLS Policies for subscription_transactions
DROP POLICY IF EXISTS "Users can view their own transactions" ON subscription_transactions;
CREATE POLICY "Users can view their own transactions"
  ON subscription_transactions FOR SELECT
  USING (auth.uid() = user_id);

-- Note: Only backend/admin can insert transactions (not users directly)
-- This prevents fraud

-- Step 6: Create helper function to check if user has active premium
CREATE OR REPLACE FUNCTION is_premium_user(user_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
  user_status TEXT;
  expiry_date TIMESTAMP WITH TIME ZONE;
BEGIN
  SELECT subscription_status, subscription_expires_at
  INTO user_status, expiry_date
  FROM users
  WHERE id = user_uuid;
  
  -- User has active subscription or trial that hasn't expired
  RETURN (user_status IN ('trial', 'active') AND (expiry_date IS NULL OR expiry_date > NOW()));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 7: Create function to activate trial
CREATE OR REPLACE FUNCTION activate_trial(user_uuid UUID)
RETURNS void AS $$
BEGIN
  UPDATE users
  SET 
    subscription_status = 'trial',
    trial_ends_at = NOW() + INTERVAL '14 days',
    subscription_expires_at = NOW() + INTERVAL '14 days',
    subscription_started_at = NOW()
  WHERE id = user_uuid
    AND subscription_status = 'inactive'
    AND trial_ends_at IS NULL; -- Can only activate trial once
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Create function to activate subscription
CREATE OR REPLACE FUNCTION activate_subscription(
  user_uuid UUID,
  tier TEXT,
  transaction_id_param TEXT,
  platform_param TEXT,
  expiry_date_param TIMESTAMP WITH TIME ZONE
)
RETURNS void AS $$
BEGIN
  -- Update user subscription status
  UPDATE users
  SET 
    subscription_tier = tier,
    subscription_status = 'active',
    subscription_expires_at = expiry_date_param,
    subscription_started_at = COALESCE(subscription_started_at, NOW()),
    last_payment_date = NOW()
  WHERE id = user_uuid;
  
  -- Insert transaction record
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
    FALSE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 9: Create function to check and expire subscriptions (run daily via cron)
CREATE OR REPLACE FUNCTION expire_subscriptions()
RETURNS void AS $$
BEGIN
  UPDATE users
  SET subscription_status = 'expired'
  WHERE subscription_status IN ('trial', 'active')
    AND subscription_expires_at < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- Migration Complete
-- =====================================================
-- 
-- What was added:
-- 1. Subscription columns to users table
-- 2. subscription_transactions table for audit trail
-- 3. Helper functions for subscription management
-- 4. RLS policies for security
-- 5. Indexes for performance
--
-- Next steps:
-- 1. Configure App Store Connect products
-- 2. Configure Google Play Console products
-- 3. Implement Flutter in_app_purchase integration
-- 4. Set up cron job to run expire_subscriptions() daily
-- 
-- Product IDs to create in stores:
-- - iOS: shoply_premium_monthly, shoply_premium_yearly
-- - Android: shoply_premium_monthly, shoply_premium_yearly
-- =====================================================
