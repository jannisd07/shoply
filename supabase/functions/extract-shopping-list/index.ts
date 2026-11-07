// Supabase Edge Function: extract-shopping-list
//
// Reads a photographed/scanned shopping list from the private `list-imports`
// bucket, runs it through Gemini vision, and returns structured items.
//
// Contract (see app-side ListImportService):
//   POST /functions/v1/extract-shopping-list
//   Auth: caller's Supabase JWT (required; anonymous rejected)
//   Body: { "image_path": "<uid>/<uuid>.jpg", "locale": "de-DE" }
//   200:  { "items": [{name, quantity, unit, confidence}], "unparsed_lines": [] }
//   err:  { "code": "<machine_code>", "message": "<localized>" }
//
// Privacy (DSGVO): the uploaded image is DELETED immediately after
// extraction — success or failure — so nothing is persisted beyond what the
// user chooses to import. See the delete call in `finally`.
//
// Deploy: supabase functions deploy extract-shopping-list
// Secrets: GEMINI_API_KEY (SUPABASE_URL / SERVICE_ROLE_KEY are injected).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { encode as base64Encode } from "https://deno.land/std@0.168.0/encoding/base64.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.7";

const BUCKET = "list-imports";
const GEMINI_MODEL = "gemini-2.0-flash";
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

// Per-user rate limit: max imports per rolling window.
const RATE_LIMIT = 12;
const RATE_WINDOW_MS = 10 * 60 * 1000; // 10 minutes

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Localized user-facing messages. The client also maps `code` → its own
// strings; these are a server-side fallback.
const MESSAGES: Record<string, { de: string; en: string }> = {
  no_items_found: {
    de: "Avo hat darauf keine Artikel gefunden.",
    en: "No items were found in that image.",
  },
  unreadable_image: {
    de: "Das Bild war schwer zu lesen.",
    en: "That image was hard to read.",
  },
  rate_limited: {
    de: "Zu viele Importe hintereinander. Bitte warte kurz.",
    en: "Too many imports in a row. Please wait a moment.",
  },
  provider_error: {
    de: "Beim Lesen deiner Liste ist etwas schiefgelaufen.",
    en: "Something went wrong reading your list.",
  },
  timeout: {
    de: "Das hat zu lange gedauert.",
    en: "That took too long.",
  },
  unauthorized: {
    de: "Nicht angemeldet.",
    en: "Not signed in.",
  },
  bad_request: {
    de: "Ungültige Anfrage.",
    en: "Invalid request.",
  },
};

function errorResponse(code: string, status: number, locale: string) {
  const lang = locale.startsWith("de") ? "de" : "en";
  const message = (MESSAGES[code] ?? MESSAGES.provider_error)[lang];
  return new Response(JSON.stringify({ code, message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const UNITS = ["stk", "g", "kg", "ml", "l", "pck", "dose", "dosen", "bund", "pkg"];

function normalizeUnit(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const u = raw.trim().toLowerCase().replace(".", "");
  if (u.length === 0) return null;
  const map: Record<string, string> = {
    stück: "Stk",
    stk: "Stk",
    packung: "Pck",
    pck: "Pck",
    pkg: "Pck",
    dose: "Dose",
    dosen: "Dose",
    liter: "l",
    gramm: "g",
    kilogramm: "kg",
    kilo: "kg",
    milliliter: "ml",
  };
  if (map[u]) return map[u];
  if (UNITS.includes(u)) return u === "dosen" ? "Dose" : u;
  return raw.trim().slice(0, 12);
}

function buildPrompt(locale: string): string {
  return `You extract grocery shopping-list items from a photo of a handwritten or printed list (locale: ${locale}).

Return STRICT JSON ONLY — no prose, no markdown fences. Shape:
{"items":[{"name":string,"quantity":number|null,"unit":string|null,"confidence":number}],"unparsed_lines":[string]}

Rules:
- One object per distinct product line.
- "name": the product, normalized to a clean German grocery term (singular where natural, correct capitalization). Never invent items not visibly present.
- "quantity": numeric amount if written, else null. "unit": one of Stk, g, kg, ml, l, Pck, Dose — normalized — else null.
- "confidence": 0..1, how sure you are you read the line correctly (lower for messy handwriting).
- DROP non-product lines: prices, totals, store names, dates, headings, phone numbers. Put anything you saw but couldn't parse as a product into "unparsed_lines".
- If the image is unreadable or has no products, return {"items":[],"unparsed_lines":[]} — do NOT guess.`;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  let locale = "de-DE";
  let imagePath: string | null = null;

  if (req.method !== "POST") {
    return errorResponse("bad_request", 405, locale);
  }

  // 1. Verify the caller's JWT — reject anonymous.
  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace("Bearer ", "").trim();
  if (!jwt) return errorResponse("unauthorized", 401, locale);

  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  const userId = userData?.user?.id;
  if (userErr || !userId) return errorResponse("unauthorized", 401, locale);

  // Service-role client for storage read/delete + rate-limit bookkeeping.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  try {
    const body = await req.json().catch(() => null);
    if (!body || typeof body.image_path !== "string") {
      return errorResponse("bad_request", 400, locale);
    }
    locale = typeof body.locale === "string" ? body.locale : locale;
    imagePath = body.image_path;

    // 2. Path must live under the caller's own folder — no arbitrary reads.
    if (!imagePath.startsWith(`${userId}/`) || imagePath.includes("..")) {
      return errorResponse("unauthorized", 403, locale);
    }

    // 3. Per-user rate limit.
    const limited = await isRateLimited(admin, userId);
    if (limited) return errorResponse("rate_limited", 429, locale);

    // 4. Download the image (private bucket, service role).
    const { data: file, error: dlErr } = await admin.storage
      .from(BUCKET)
      .download(imagePath);
    if (dlErr || !file) return errorResponse("unreadable_image", 400, locale);

    const bytes = new Uint8Array(await file.arrayBuffer());
    const base64 = base64Encode(bytes);

    // 5. Call Gemini vision with a timeout.
    const items = await callGemini(base64, file.type || "image/jpeg", locale);
    if (items === "timeout") return errorResponse("timeout", 504, locale);
    if (items === "provider_error") {
      return errorResponse("provider_error", 502, locale);
    }

    if (items.items.length === 0) {
      return errorResponse("no_items_found", 422, locale);
    }

    return new Response(JSON.stringify(items), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (_e) {
    return errorResponse("provider_error", 502, locale);
  } finally {
    // 6. DSGVO: delete the upload no matter what.
    if (imagePath) {
      await admin.storage.from(BUCKET).remove([imagePath]).catch(() => {});
    }
  }
});

interface ExtractResult {
  items: Array<{
    name: string;
    quantity: number | null;
    unit: string | null;
    confidence: number;
  }>;
  unparsed_lines: string[];
}

async function callGemini(
  base64: string,
  mimeType: string,
  locale: string,
): Promise<ExtractResult | "timeout" | "provider_error"> {
  if (!GEMINI_API_KEY) return "provider_error";
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 45_000);
  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: controller.signal,
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: buildPrompt(locale) },
              { inline_data: { mime_type: mimeType, data: base64 } },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.1,
          responseMimeType: "application/json",
        },
      }),
    });
    if (!res.ok) return "provider_error";
    const json = await res.json();
    const text: string | undefined =
      json?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!text) return "provider_error";
    return parseModelJson(text);
  } catch (e) {
    if ((e as Error).name === "AbortError") return "timeout";
    return "provider_error";
  } finally {
    clearTimeout(timer);
  }
}

function parseModelJson(text: string): ExtractResult {
  // Strip accidental fences, then parse defensively.
  const cleaned = text.replace(/```json/gi, "").replace(/```/g, "").trim();
  let raw: unknown;
  try {
    raw = JSON.parse(cleaned);
  } catch {
    return { items: [], unparsed_lines: [] };
  }
  const obj = raw as Record<string, unknown>;
  const rawItems = Array.isArray(obj.items) ? obj.items : [];
  const items = rawItems
    .map((it) => {
      const o = it as Record<string, unknown>;
      const name = typeof o.name === "string" ? o.name.trim() : "";
      if (!name) return null;
      const quantity =
        typeof o.quantity === "number" && isFinite(o.quantity)
          ? o.quantity
          : null;
      const confidence =
        typeof o.confidence === "number" && isFinite(o.confidence)
          ? Math.max(0, Math.min(1, o.confidence))
          : 0.8;
      return { name, quantity, unit: normalizeUnit(o.unit), confidence };
    })
    .filter((x): x is NonNullable<typeof x> => x !== null);
  const unparsed = Array.isArray(obj.unparsed_lines)
    ? obj.unparsed_lines.filter((l): l is string => typeof l === "string")
    : [];
  return { items, unparsed_lines: unparsed };
}

// Best-effort rate limit backed by a small table (see migration). If the
// table is missing, we fail OPEN (never block a real import over bookkeeping).
async function isRateLimited(
  admin: ReturnType<typeof createClient>,
  userId: string,
): Promise<boolean> {
  try {
    const since = new Date(Date.now() - RATE_WINDOW_MS).toISOString();
    const { count, error } = await admin
      .from("list_import_events")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .gte("created_at", since);
    if (error) return false;
    if ((count ?? 0) >= RATE_LIMIT) return true;
    await admin.from("list_import_events").insert({ user_id: userId });
    return false;
  } catch {
    return false;
  }
}
