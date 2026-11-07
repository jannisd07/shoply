// Supabase Edge Function to send FCM push notifications
// Deploy: supabase functions deploy send-push-notification
//
// Contract:
//   POST /functions/v1/send-push-notification
//   Auth: caller's Supabase user JWT (required; the bare anon key is rejected)
//   Body: { "token": "<recipient FCM token>", "notification": {title, body}, "data": {...} }
//
// Authorization: the recipient token must belong to the caller or to a user
// who shares at least one list with the caller (owner or list_members row).
//
// Secrets: FIREBASE_PRIVATE_KEY, FIREBASE_CLIENT_EMAIL, optional
// FIREBASE_PROJECT_ID (defaults to shoply-92f28). SUPABASE_URL,
// SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are injected.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.39.7"

const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID') ?? 'shoply-92f28'
const FIREBASE_PRIVATE_KEY = Deno.env.get('FIREBASE_PRIVATE_KEY')?.replace(/\\n/g, '\n')
const FIREBASE_CLIENT_EMAIL = Deno.env.get('FIREBASE_CLIENT_EMAIL')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

// CORS headers for all responses
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405)
  }

  try {
    // 1. Verify the caller's user JWT (the anon key alone has no user).
    const authHeader = req.headers.get('Authorization') ?? ''
    const jwt = authHeader.replace('Bearer ', '').trim()
    if (!jwt) return jsonResponse({ error: 'Unauthorized' }, 401)

    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    })
    const { data: userData, error: userErr } = await userClient.auth.getUser()
    const callerId = userData?.user?.id
    if (userErr || !callerId) return jsonResponse({ error: 'Unauthorized' }, 401)

    // 2. Parse request body
    const body = await req.json().catch(() => null)
    const token = typeof body?.token === 'string' ? body.token : ''
    const notification = body?.notification
    const data = body?.data

    if (!token) {
      return jsonResponse({ error: 'FCM token required' }, 400)
    }

    // 3. The recipient must be the caller or share a list with the caller.
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)
    const allowed = await canNotify(admin, callerId, token)
    if (!allowed) {
      console.log(`⚠️ Caller ${callerId} may not notify this token`)
      return jsonResponse({ error: 'Recipient not allowed' }, 403)
    }

    // 4. Send via FCM HTTP v1
    const accessToken = await getFirebaseAccessToken()
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          message: {
            token: token,
            notification: notification || {},
            data: data || {},
            // iOS specific - required for reliable delivery
            apns: {
              headers: {
                'apns-priority': '10',  // High priority
                'apns-push-type': 'alert',  // Required for iOS 13+
              },
              payload: {
                aps: {
                  alert: notification || {},
                  sound: 'default',
                  badge: 1,
                  'content-available': 1,  // Wake app for background processing
                  'mutable-content': 1,    // Allow notification modification
                },
              },
            },
            // Android specific
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                default_vibrate_timings: true,
                default_light_settings: true,
              },
            },
          },
        }),
      }
    )

    const fcmResult = await fcmResponse.json()

    if (!fcmResponse.ok) {
      const errorCode = fcmResult?.error?.details?.[0]?.errorCode || fcmResult?.error?.code
      console.log(`❌ FCM error ${fcmResponse.status} (${errorCode}): ${JSON.stringify(fcmResult)}`)

      // UNREGISTERED means token is invalid - should be cleaned up
      if (errorCode === 'UNREGISTERED' || errorCode === 'INVALID_ARGUMENT') {
        return jsonResponse({ error: 'Token invalid', shouldRemove: true }, 410)
      }

      return jsonResponse({ error: 'FCM send failed', code: errorCode ?? null }, fcmResponse.status)
    }

    console.log('✅ Notification sent')
    return jsonResponse({ success: true }, 200)
  } catch (error) {
    console.error('❌ Edge Function Error:', error)
    return jsonResponse({ error: 'Internal error' }, 500)
  }
})

// True when `token` belongs to the caller or to a user who shares a list
// with the caller (as owner or list member).
async function canNotify(admin: SupabaseClient, callerId: string, token: string): Promise<boolean> {
  const { data: recipients, error } = await admin
    .from('users')
    .select('id')
    .eq('fcm_token', token)
  if (error || !recipients || recipients.length === 0) return false

  const recipientIds = recipients.map((r: { id: string }) => r.id)
  if (recipientIds.includes(callerId)) return true

  const callerLists = await listIdsFor(admin, [callerId])
  if (callerLists.size === 0) return false
  const recipientLists = await listIdsFor(admin, recipientIds)
  for (const id of recipientLists) {
    if (callerLists.has(id)) return true
  }
  return false
}

async function listIdsFor(admin: SupabaseClient, userIds: string[]): Promise<Set<string>> {
  const [members, owned] = await Promise.all([
    admin.from('list_members').select('list_id').in('user_id', userIds),
    admin.from('shopping_lists').select('id').in('owner_id', userIds),
  ])
  const ids = new Set<string>()
  for (const row of members.data ?? []) ids.add(row.list_id)
  for (const row of owned.data ?? []) ids.add(row.id)
  return ids
}

// URL-safe Base64 encoding (required for JWT)
function base64UrlEncode(str: string): string {
  return btoa(str)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

// Access tokens are valid for 1 h; edge isolates are reused between calls,
// so cache the token in module scope and refresh it 60 s before expiry.
let cachedAccessToken: { token: string; exp: number } | null = null

// Get Firebase OAuth2 access token using service account
async function getFirebaseAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedAccessToken && cachedAccessToken.exp - 60 > now) {
    return cachedAccessToken.token
  }

  if (!FIREBASE_PRIVATE_KEY || !FIREBASE_CLIENT_EMAIL) {
    throw new Error('Missing Firebase credentials in environment variables')
  }

  const jwtHeader = base64UrlEncode(JSON.stringify({
    alg: 'RS256',
    typ: 'JWT',
  }))

  const jwtPayload = base64UrlEncode(JSON.stringify({
    iss: FIREBASE_CLIENT_EMAIL,
    sub: FIREBASE_CLIENT_EMAIL,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }))

  const unsignedToken = `${jwtHeader}.${jwtPayload}`

  // Sign JWT with private key
  const encoder = new TextEncoder()
  const data = encoder.encode(unsignedToken)

  // Import private key
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(FIREBASE_PRIVATE_KEY!),
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  )

  // Sign the token
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    data
  )

  const signatureBase64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')

  const jwt = `${unsignedToken}.${signatureBase64}`

  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })

  const tokenData = await tokenResponse.json()

  if (!tokenResponse.ok || !tokenData.access_token) {
    console.error('❌ Failed to get Firebase access token:', JSON.stringify(tokenData))
    throw new Error(`OAuth token exchange failed: ${tokenData.error_description || tokenData.error || 'Unknown error'}`)
  }

  const expiresIn = typeof tokenData.expires_in === 'number' ? tokenData.expires_in : 3600
  cachedAccessToken = { token: tokenData.access_token, exp: now + expiresIn }
  return tokenData.access_token
}

// Convert PEM to ArrayBuffer
function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')

  const binaryString = atob(b64)
  const bytes = new Uint8Array(binaryString.length)
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i)
  }
  return bytes.buffer
}
