// CORS headers shared by the edge functions (same values as the existing
// functions: the app calls with its Supabase JWT, no cookies).

export const CORS_HEADERS: Readonly<Record<string, string>> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function preflightResponse(): Response {
  return new Response("ok", { headers: CORS_HEADERS });
}
