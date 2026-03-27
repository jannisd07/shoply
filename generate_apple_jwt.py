#!/usr/bin/env python3
"""
Apple Sign In JWT Generator for Supabase
This script generates the JWT token needed for Supabase Apple OAuth configuration.
"""

import jwt
import time
from datetime import datetime, timedelta

# ============================================
# CONFIGURATION - FILL IN YOUR VALUES HERE
# ============================================

# Your Apple Team ID (10 characters, e.g., "CTBGYBDPP4")
TEAM_ID = "CTBGYBDPP4"

# Your Sign in with Apple Key ID (10 characters)
KEY_ID = "W2T9K5D2RA"

# Your Client ID (Services ID, e.g., "com.dominik.shoply")
CLIENT_ID = "com.dominik.shoply"

# Path to your .p8 private key file
PRIVATE_KEY_PATH = "/Users/dominikk/Downloads/AuthKey_W2T9K5D2RA.p8"

# ============================================
# DO NOT MODIFY BELOW THIS LINE
# ============================================

def generate_client_secret():
    """Generate the client secret JWT for Apple Sign In"""
    
    # Read the private key
    try:
        with open(PRIVATE_KEY_PATH, 'r') as f:
            private_key = f.read()
    except FileNotFoundError:
        print(f"❌ Error: Could not find private key file at: {PRIVATE_KEY_PATH}")
        print("Please make sure the .p8 file is in the same directory as this script.")
        return None
    
    # JWT headers
    headers = {
        'kid': KEY_ID,
        'alg': 'ES256'
    }
    
    # JWT payload
    now = int(time.time())
    expiration = now + (86400 * 180)  # 180 days (maximum allowed)
    
    payload = {
        'iss': TEAM_ID,
        'iat': now,
        'exp': expiration,
        'aud': 'https://appleid.apple.com',
        'sub': CLIENT_ID
    }
    
    # Generate the JWT
    try:
        client_secret = jwt.encode(
            payload,
            private_key,
            algorithm='ES256',
            headers=headers
        )
        return client_secret
    except Exception as e:
        print(f"❌ Error generating JWT: {e}")
        return None

def main():
    print("=" * 60)
    print("Apple Sign In JWT Generator for Supabase")
    print("=" * 60)
    print()
    
    # Validate configuration
    if TEAM_ID == "YOUR_TEAM_ID_HERE":
        print("❌ Error: Please set your TEAM_ID in the script")
        return
    
    if KEY_ID == "YOUR_KEY_ID_HERE":
        print("❌ Error: Please set your KEY_ID in the script")
        return
    
    print(f"Team ID: {TEAM_ID}")
    print(f"Key ID: {KEY_ID}")
    print(f"Client ID: {CLIENT_ID}")
    print(f"Private Key: {PRIVATE_KEY_PATH}")
    print()
    
    # Generate the JWT
    print("Generating JWT...")
    client_secret = generate_client_secret()
    
    if client_secret:
        print()
        print("✅ SUCCESS! Your JWT Client Secret:")
        print("=" * 60)
        print(client_secret)
        print("=" * 60)
        print()
        print("📋 Next Steps:")
        print("1. Copy the JWT token above")
        print("2. Go to Supabase Dashboard → Authentication → Providers → Apple")
        print("3. Paste it into the 'Secret Key (for OAuth)' field")
        print("4. Save the configuration")
        print()
        print("⚠️  Note: This JWT expires in 180 days. You'll need to regenerate it then.")
    else:
        print()
        print("❌ Failed to generate JWT. Please check the error messages above.")

if __name__ == "__main__":
    main()
