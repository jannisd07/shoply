// Contract tests for POST /functions/v1/ai (plan B1.1-B1.3): status codes,
// error bodies and the order auth -> body -> version -> task -> input ->
// ai_enabled -> premium -> limit -> quota -> Claude -> refund/record.
// Everything outside the handler is injected; no network.

import Anthropic from "@anthropic-ai/sdk";
import { assertEquals } from "@std/assert";

import { type AuthClientFactory, getUserId } from "../_shared/auth.ts";
import type { AiUsage } from "../_shared/claude.ts";
import type { AiFlags } from "../_shared/flags.ts";
import { type AiLimits, type QuotaStore, secondsUntilBerlinMidnight } from "../_shared/quota.ts";
import { FakeClaude, fakeMessage, type ScriptedReply } from "../_shared/testing/fake_claude.ts";
import { createHandler } from "./handler.ts";

const NOW = new Date("2026-11-07T21:30:00Z");
const LIMITS: AiLimits = {
  free: { categorize: 200, recommend: 5, nutrition_estimate: 10, avo_chat: 3 },
  pro: { categorize: 500, recommend: 30, nutrition_estimate: 50, avo_chat: 60 },
};

interface HarnessOptions {
  claudeMissing?: boolean;
  aiEnabled?: boolean;
  limits?: AiLimits;
  pro?: boolean;
  allow?: boolean;
  replies?: ScriptedReply[];
  flagsFail?: boolean;
}

function harness(opts: HarnessOptions = {}) {
  const consumed: Array<{ userId: string; task: string; amount: number; limit: number }> = [];
  const refunds: Array<{ task: string; amount: number }> = [];
  const records: Array<{ task: string; usage: AiUsage }> = [];
  const authLookups: string[] = [];
  const claude = new FakeClaude(...(opts.replies ?? [categorizeReply(1)]));

  const authFactory: AuthClientFactory = (_url, _key, options) => {
    authLookups.push(options.global.headers.Authorization);
    const ok = options.global.headers.Authorization === "Bearer good-jwt";
    return {
      auth: {
        getUser: () =>
          Promise.resolve(
            ok
              ? { data: { user: { id: "user-1" } }, error: null }
              : { data: { user: null }, error: { name: "AuthApiError", status: 401 } },
          ),
      },
    };
  };
  const quota: QuotaStore = {
    isPro: () => Promise.resolve(opts.pro ?? false),
    consume: (userId, task, amount, limit) => {
      consumed.push({ userId, task, amount, limit });
      return Promise.resolve(opts.allow ?? true);
    },
    refund: (_userId, task, amount) => {
      refunds.push({ task, amount });
      return Promise.resolve();
    },
    record: (_userId, task, usage) => {
      records.push({ task, usage });
      return Promise.resolve();
    },
  };
  const flags: AiFlags = { aiEnabled: opts.aiEnabled ?? true, limits: opts.limits ?? LIMITS };

  const handle = createHandler({
    authenticate: (req) => getUserId(req, { url: "http://supabase.test", anonKey: "anon", createClient: authFactory }),
    readFlags: () => opts.flagsFail ? Promise.reject(new Error("db down")) : Promise.resolve(flags),
    quota,
    claude: () => {
      if (opts.claudeMissing) throw new Error("The ANTHROPIC_API_KEY environment variable is missing");
      return claude;
    },
    now: () => NOW,
  });
  return { handle, claude, consumed, refunds, records, authLookups };
}

function categorizeReply(count: number) {
  return fakeMessage({
    json: {
      items: Array.from({ length: count }, (_, i) => ({
        index: i + 1,
        category_id: "dairy",
        confidence: "high",
        brand: null,
      })),
    },
    usage: { input_tokens: 40, output_tokens: 12, cache_creation_input_tokens: 0, cache_read_input_tokens: 900 },
  });
}

function post(body: unknown, authorization: string | null = "Bearer good-jwt"): Request {
  const headers = new Headers({ "content-type": "application/json" });
  if (authorization !== null) headers.set("Authorization", authorization);
  return new Request("http://localhost/functions/v1/ai", {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

function envelope(task: string, input: unknown, extra: Record<string, unknown> = {}) {
  return { task, v: 1, locale: "en", input, ...extra };
}

const MILK = envelope("categorize", { items: [{ name: "Milch" }] });

async function errorOf(res: Response) {
  assertEquals(res.headers.get("content-type"), "application/json");
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
  return await res.json() as { code: string; message: string; retry_after_s?: number };
}

Deno.test("401 unauthorized without a JWT: no auth lookup, no quota, no Claude", async () => {
  const h = harness();
  const res = await h.handle(post(MILK, null));
  assertEquals(res.status, 401);
  const body = await errorOf(res);
  assertEquals(body.code, "unauthorized");
  assertEquals(typeof body.message, "string");
  assertEquals(h.authLookups, []);
  assertEquals(h.consumed, []);
  assertEquals(h.claude.calls, []);
});

Deno.test("401 unauthorized for a rejected JWT, before the body is read", async () => {
  const h = harness();
  const res = await h.handle(post("{not json", "Bearer expired"));
  assertEquals(res.status, 401);
  assertEquals((await errorOf(res)).code, "unauthorized");
  assertEquals(h.consumed, []);
});

Deno.test("400 bad_request for an unknown task, also for inherited object keys", async () => {
  for (const task of ["nope", "toString", "__proto__", "constructor"]) {
    const h = harness();
    const res = await h.handle(post(envelope(task, {})));
    assertEquals(res.status, 400, task);
    assertEquals((await errorOf(res)).code, "bad_request");
    assertEquals(h.consumed, []);
    assertEquals(h.claude.calls, []);
  }
});

Deno.test("400 bad_request for a wrong protocol version, a missing task or no JSON", async () => {
  const bodies: unknown[] = [
    envelope("categorize", { items: [{ name: "Milch" }] }, { v: 2 }),
    { v: 1, locale: "de", input: {} },
    { task: 5, v: 1, input: {} },
    "{nope",
    "[]",
    envelope("categorize", "not an object"),
  ];
  for (const body of bodies) {
    const h = harness();
    const res = await h.handle(post(body));
    assertEquals(res.status, 400, JSON.stringify(body));
    assertEquals((await errorOf(res)).code, "bad_request");
    assertEquals(h.consumed, []);
  }
});

Deno.test("400 bad_request for invalid task input, before any quota is used", async () => {
  for (const input of [{ items: [] }, { items: Array.from({ length: 61 }, () => ({ name: "x" })) }, {}]) {
    const h = harness();
    const res = await h.handle(post(envelope("categorize", input)));
    assertEquals(res.status, 400);
    assertEquals(h.consumed, []);
    assertEquals(h.claude.calls, []);
  }
});

Deno.test("503 ai_disabled when the kill switch is off: no quota, no Claude", async () => {
  const h = harness({ aiEnabled: false });
  const res = await h.handle(post(MILK));
  assertEquals(res.status, 503);
  assertEquals((await errorOf(res)).code, "ai_disabled");
  assertEquals(h.consumed, []);
  assertEquals(h.claude.calls, []);
});

Deno.test("503 ai_disabled when the task has no limit for the tier, not a false 'resets tomorrow'", async () => {
  const h = harness({ limits: { free: {}, pro: { categorize: 500 } } });
  const res = await h.handle(post(MILK));
  assertEquals(res.status, 503);
  const body = await errorOf(res);
  assertEquals(body.code, "ai_disabled");
  assertEquals("retry_after_s" in body, false);
  assertEquals(h.consumed, []);
});

Deno.test("429 quota_exceeded with retry_after_s until Berlin midnight, Claude not called", async () => {
  const h = harness({ allow: false });
  const res = await h.handle(post(MILK));
  assertEquals(res.status, 429);
  const body = await errorOf(res);
  assertEquals(body.code, "quota_exceeded");
  assertEquals(body.retry_after_s, secondsUntilBerlinMidnight(NOW));
  assertEquals(body.retry_after_s, 5400);
  assertEquals(res.headers.get("retry-after"), "5400");
  assertEquals(h.consumed.length, 1);
  assertEquals(h.claude.calls, []);
});

Deno.test("422 refused when Claude declines: the quota stays used, nothing recorded", async () => {
  const h = harness({ replies: [fakeMessage({ stop_reason: "refusal" })] });
  const res = await h.handle(post(MILK));
  assertEquals(res.status, 422);
  assertEquals((await errorOf(res)).code, "refused");
  assertEquals(h.claude.calls.length, 1);
  assertEquals(h.refunds, []);
  assertEquals(h.records, []);
});

Deno.test("200 categorize: result and usage, quota counted per item with the free limit", async () => {
  const h = harness({ replies: [categorizeReply(3)] });
  const res = await h.handle(
    post(envelope("categorize", { items: [{ name: "Milch" }, { name: "Quark" }, { name: "Butter" }] })),
  );
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
  const body = await res.json();
  assertEquals(body.result.items.length, 3);
  assertEquals(body.result.items[0], { category_id: "dairy", confidence: "high", brand: null });
  assertEquals(body.usage, { input_tokens: 40, output_tokens: 12, cache_read_input_tokens: 900 });
  assertEquals(h.consumed, [{ userId: "user-1", task: "categorize", amount: 3, limit: 200 }]);
  assertEquals(h.records, [{ task: "categorize", usage: body.usage }]);
});

Deno.test("Pro users get the pro limit", async () => {
  const h = harness({ pro: true });
  await h.handle(post(MILK));
  assertEquals(h.consumed[0].limit, 500);
});

Deno.test("a provider error the provider did not bill gives the quota back", async () => {
  const rateLimit = new Anthropic.RateLimitError(429, {}, "slow", new Headers({ "retry-after": "20" }));
  const h = harness({ replies: [rateLimit] });
  const res = await h.handle(post(envelope("categorize", { items: [{ name: "a" }, { name: "b" }] })));
  assertEquals(res.status, 429);
  const body = await errorOf(res);
  assertEquals(body.code, "rate_limited");
  assertEquals(body.retry_after_s, 20);
  assertEquals(h.refunds, [{ task: "categorize", amount: 2 }]);
  assertEquals(h.records, []);
});

Deno.test("a 4xx from Anthropic (bad key) is a 502 and refunded", async () => {
  const h = harness({ replies: [new Anthropic.AuthenticationError(401, {}, "bad key", new Headers())] });
  const res = await h.handle(post(MILK));
  assertEquals(res.status, 502);
  assertEquals((await errorOf(res)).code, "provider_error");
  assertEquals(h.refunds.length, 1);
});

Deno.test("a stub task answers bad_request and gives its quota unit back", async () => {
  const h = harness();
  const res = await h.handle(post(envelope("avo_chat", { messages: [] })));
  assertEquals(res.status, 400);
  assertEquals((await errorOf(res)).code, "bad_request");
  assertEquals(h.consumed.map((c) => c.task), ["avo_chat"]);
  assertEquals(h.refunds, [{ task: "avo_chat", amount: 1 }]);
});

Deno.test("unreadable flags fail closed with provider_error", async () => {
  const h = harness({ flagsFail: true });
  const res = await h.handle(post(MILK));
  assertEquals(res.status, 502);
  assertEquals((await errorOf(res)).code, "provider_error");
  assertEquals(h.consumed, []);
});

Deno.test("error messages follow the request locale", async () => {
  const h = harness({ aiEnabled: false });
  const de = await (await h.handle(post(envelope("categorize", { items: [{ name: "a" }] }, { locale: "de" })))).json();
  const en = await (await h.handle(post(envelope("categorize", { items: [{ name: "a" }] }, { locale: "en" })))).json();
  assertEquals(de.message === en.message, false);
});

Deno.test("OPTIONS answers the CORS preflight without auth", async () => {
  const h = harness();
  const res = await h.handle(new Request("http://localhost/functions/v1/ai", { method: "OPTIONS" }));
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("access-control-allow-methods"), "POST, OPTIONS");
  await res.body?.cancel();
  assertEquals(h.authLookups, []);
});

Deno.test("logs carry counts only: no item names, no user id", async () => {
  const lines: string[] = [];
  const original = { log: console.log, warn: console.warn, error: console.error };
  const keep = (...args: unknown[]) => lines.push(args.map(String).join(" "));
  Object.assign(console, { log: keep, warn: keep, error: keep });
  try {
    const ok = harness({ replies: [categorizeReply(1)] });
    await ok.handle(post(envelope("categorize", { items: [{ name: "Geheimrezept-Zutat" }] })));
    const refused = harness({ replies: [fakeMessage({ stop_reason: "refusal" })] });
    await refused.handle(post(envelope("categorize", { items: [{ name: "Geheimrezept-Zutat" }] })));
  } finally {
    Object.assign(console, original);
  }
  assertEquals(lines.length >= 2, true);
  for (const line of lines) {
    assertEquals(line.includes("Geheimrezept"), false, line);
    assertEquals(line.includes("user-1"), false, line);
  }
});

Deno.test("a missing ANTHROPIC_API_KEY is a provider_error before any quota is used", async () => {
  const h = harness({ claudeMissing: true });
  const res = await h.handle(post(MILK));
  assertEquals(res.status, 502);
  assertEquals((await errorOf(res)).code, "provider_error");
  assertEquals(h.consumed, []);
});

Deno.test("a body over 6 MB is a bad_request before any quota is used", async () => {
  const h = harness();
  const req = new Request("http://localhost/functions/v1/ai", {
    method: "POST",
    headers: { Authorization: "Bearer good-jwt", "content-length": String(6 * 1024 * 1024 + 1) },
    body: JSON.stringify(MILK),
  });
  const res = await h.handle(req);
  assertEquals(res.status, 400);
  assertEquals((await errorOf(res)).code, "bad_request");
  assertEquals(h.consumed, []);
});
