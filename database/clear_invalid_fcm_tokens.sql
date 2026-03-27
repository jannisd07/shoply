-- Clear all FCM tokens that were created with the wrong Firebase project
-- These tokens cause SENDER_ID_MISMATCH errors
-- Run this in Supabase SQL Editor

-- First, let's see what tokens exist
SELECT id, email, display_name, 
       CASE WHEN fcm_token IS NOT NULL THEN 'HAS TOKEN' ELSE 'NO TOKEN' END as token_status,
       LEFT(fcm_token, 30) as token_preview
FROM users 
WHERE fcm_token IS NOT NULL;

-- Clear all FCM tokens - they will be regenerated with the correct sender ID
UPDATE users 
SET fcm_token = NULL, 
    updated_at = NOW()
WHERE fcm_token IS NOT NULL;

-- Verify tokens are cleared
SELECT COUNT(*) as users_with_tokens 
FROM users 
WHERE fcm_token IS NOT NULL;
