// Supabase Edge Function to send FCM push notifications
// Deploy: supabase functions deploy send-push-notification

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const FIREBASE_PROJECT_ID = "shoplyai-1554e"
const FIREBASE_PRIVATE_KEY = Deno.env.get('FIREBASE_PRIVATE_KEY')?.replace(/\\n/g, '\n')
const FIREBASE_CLIENT_EMAIL = Deno.env.get('FIREBASE_CLIENT_EMAIL')

// CORS headers for all responses
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req) => {
  const debugLog: string[] = []
  const log = (msg: string) => {
    console.log(msg)
    debugLog.push(`${new Date().toISOString()} - ${msg}`)
  }

  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    log('🚀 Edge Function invoked')
    
    // Only allow POST
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed', debug: debugLog }), {
        status: 405,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Parse request body
    const body = await req.json()
    const { token, notification, data } = body
    
    log(`📥 Request received - token length: ${token?.length || 0}`)
    log(`📥 Notification: ${JSON.stringify(notification)}`)

    if (!token) {
      log('❌ No FCM token provided')
      return new Response(JSON.stringify({ error: 'FCM token required', debug: debugLog }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Check environment variables - log actual values for debugging
    log(`🔑 FIREBASE_CLIENT_EMAIL: ${FIREBASE_CLIENT_EMAIL}`)
    log(`🔑 FIREBASE_PRIVATE_KEY set: ${!!FIREBASE_PRIVATE_KEY}`)
    log(`🔑 FIREBASE_PRIVATE_KEY length: ${FIREBASE_PRIVATE_KEY?.length || 0}`)
    log(`🔑 Expected project: shoplyai-1554e`)

    // Get OAuth2 access token for Firebase
    log('🔐 Getting Firebase access token...')
    const accessToken = await getFirebaseAccessToken()
    log(`✅ Got access token (length: ${accessToken?.length || 0})`)

    log(`📤 Sending to FCM token: ${token.substring(0, 40)}...`)

    // Send FCM message with proper APNs configuration
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
    log(`📨 FCM Response status: ${fcmResponse.status}`)
    log(`📨 FCM Response: ${JSON.stringify(fcmResult)}`)

    if (!fcmResponse.ok) {
      log(`❌ FCM Error: ${JSON.stringify(fcmResult)}`)
      
      // Check for specific error types
      const errorCode = fcmResult?.error?.details?.[0]?.errorCode || fcmResult?.error?.code
      log(`❌ Error code: ${errorCode}`)
      
      // UNREGISTERED means token is invalid - should be cleaned up
      if (errorCode === 'UNREGISTERED' || errorCode === 'INVALID_ARGUMENT') {
        log('⚠️ Token invalid/unregistered, should be removed from database')
        return new Response(JSON.stringify({ 
          error: 'Token invalid', 
          shouldRemove: true,
          details: fcmResult,
          debug: debugLog
        }), {
          status: 410,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
      }
      
      return new Response(JSON.stringify({ 
        error: 'FCM send failed', 
        details: fcmResult,
        debug: debugLog 
      }), {
        status: fcmResponse.status,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    
    log('✅ Notification sent successfully!')

    return new Response(JSON.stringify({ 
      success: true, 
      result: fcmResult,
      debug: debugLog 
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    debugLog.push(`❌ EXCEPTION: ${error.message}`)
    debugLog.push(`❌ Stack: ${error.stack}`)
    console.error('Edge Function Error:', error)
    return new Response(JSON.stringify({ 
      error: error.message,
      debug: debugLog 
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

// URL-safe Base64 encoding (required for JWT)
function base64UrlEncode(str: string): string {
  return btoa(str)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

// Get Firebase OAuth2 access token using service account
async function getFirebaseAccessToken(): Promise<string> {
  if (!FIREBASE_PRIVATE_KEY || !FIREBASE_CLIENT_EMAIL) {
    throw new Error('Missing Firebase credentials in environment variables')
  }

  const jwtHeader = base64UrlEncode(JSON.stringify({
    alg: 'RS256',
    typ: 'JWT',
  }))

  const now = Math.floor(Date.now() / 1000)
  const jwtPayload = base64UrlEncode(JSON.stringify({
    iss: FIREBASE_CLIENT_EMAIL,
    sub: FIREBASE_CLIENT_EMAIL,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }))

  const unsignedToken = `${jwtHeader}.${jwtPayload}`
  
  console.log('🔐 Generating Firebase access token...')
  
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
  
  console.log('✅ Firebase access token obtained')
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
