#!/usr/bin/env python3
"""
Apple Sign In client-secret JWT generator for Supabase.

Supabase's Apple OAuth provider needs a client secret JWT signed with a
"Sign in with Apple" key (.p8). Apple caps its lifetime at 180 days, so it
has to be regenerated and pasted into Supabase Dashboard -> Authentication ->
Providers -> Apple -> "Secret Key (for OAuth)" before it expires.

Usage:
    pip install pyjwt cryptography
    python3 tools/generate_apple_jwt.py --key-path ~/Downloads/AuthKey_XXXXXXXXXX.p8 \
        --key-id XXXXXXXXXX [--team-id CTBGYBDPP4] [--client-id com.dominik.shoply]
"""

import argparse
import sys
import time

import jwt

MAX_LIFETIME_SECONDS = 86400 * 180  # 180 days, the maximum Apple allows


def generate_client_secret(key_path: str, key_id: str, team_id: str, client_id: str) -> str:
    with open(key_path, "r") as f:
        private_key = f.read()

    now = int(time.time())
    payload = {
        "iss": team_id,
        "iat": now,
        "exp": now + MAX_LIFETIME_SECONDS,
        "aud": "https://appleid.apple.com",
        "sub": client_id,
    }
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": key_id})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--key-path", required=True, help="Path to the AuthKey_<KEY_ID>.p8 file")
    parser.add_argument("--key-id", required=True, help="Sign in with Apple key ID (10 characters)")
    parser.add_argument("--team-id", default="CTBGYBDPP4", help="Apple Developer team ID")
    parser.add_argument("--client-id", default="com.dominik.shoply", help="Services ID / bundle ID")
    args = parser.parse_args()

    try:
        secret = generate_client_secret(args.key_path, args.key_id, args.team_id, args.client_id)
    except FileNotFoundError:
        print(f"Error: private key file not found: {args.key_path}", file=sys.stderr)
        return 1
    except Exception as e:  # noqa: BLE001 - surface any signing error to the user
        print(f"Error generating JWT: {e}", file=sys.stderr)
        return 1

    print(secret)
    print("\nPaste this into Supabase -> Authentication -> Providers -> Apple. "
          "It expires in 180 days.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
