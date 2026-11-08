import { assertEquals, assertRejects } from "@std/assert";

import { AiError } from "./errors.ts";
import { createSupabaseQuotaStore, limitFor, secondsUntilBerlinMidnight } from "./quota.ts";

Deno.test("seconds until Berlin midnight in winter time (UTC+1)", () => {
  // 23:00 in Berlin.
  assertEquals(secondsUntilBerlinMidnight(new Date("2026-11-07T22:00:00Z")), 3600);
});

Deno.test("seconds until Berlin midnight in summer time (UTC+2)", () => {
  // 14:00 in Berlin.
  assertEquals(secondsUntilBerlinMidnight(new Date("2026-07-01T12:00:00Z")), 36000);
});

Deno.test("seconds until Berlin midnight on the 25-hour day when summer time ends", () => {
  // 00:30 CEST on 25.10.2026; the clocks go back at 03:00, the next midnight is 23:00 UTC.
  assertEquals(secondsUntilBerlinMidnight(new Date("2026-10-24T22:30:00Z")), 88200);
});

Deno.test("seconds until Berlin midnight never reports zero", () => {
  assertEquals(secondsUntilBerlinMidnight(new Date("2026-11-07T22:59:59.700Z")), 1);
});

Deno.test("limitFor reads the plan's limit and treats missing or broken values as zero", () => {
  const limits = {
    free: { categorize: 200, recommend: 5.9, broken: -3 },
    pro: { categorize: 500 },
  };
  assertEquals(limitFor(limits, "free", "categorize"), 200);
  assertEquals(limitFor(limits, "pro", "categorize"), 500);
  assertEquals(limitFor(limits, "free", "recommend"), 5);
  assertEquals(limitFor(limits, "free", "broken"), 0);
  assertEquals(limitFor(limits, "pro", "recommend"), 0);
  assertEquals(limitFor(limits, "free", "toString"), 0);
});

type RpcCall = { fn: string; args: Record<string, unknown> };

function fakeRpc(results: Record<string, { data: unknown; error: { message: string } | null }>) {
  const calls: RpcCall[] = [];
  return {
    calls,
    client: {
      rpc(fn: string, args: Record<string, unknown>) {
        calls.push({ fn, args });
        return Promise.resolve(results[fn] ?? { data: null, error: null });
      },
    },
  };
}

Deno.test("quota store calls the atomic consume RPC with amount and limit", async () => {
  const { calls, client } = fakeRpc({ ai_consume_quota_b: { data: true, error: null } });
  const store = createSupabaseQuotaStore(client);
  assertEquals(await store.consume("u1", "categorize", 12, 200), true);
  assertEquals(calls, [{
    fn: "ai_consume_quota_b",
    args: { p_user: "u1", p_task: "categorize", p_amount: 12, p_limit: 200 },
  }]);
});

Deno.test("quota store reports a denied consume as false", async () => {
  const { client } = fakeRpc({ ai_consume_quota_b: { data: false, error: null } });
  assertEquals(await createSupabaseQuotaStore(client).consume("u1", "avo_chat", 1, 3), false);
});

Deno.test("quota store treats an unreadable premium status as free", async () => {
  const { client } = fakeRpc({ is_premium_user: { data: null, error: { message: "down" } } });
  assertEquals(await createSupabaseQuotaStore(client).isPro("u1"), false);
});

Deno.test("quota store reads the premium status with the user's id", async () => {
  const { calls, client } = fakeRpc({ is_premium_user: { data: true, error: null } });
  assertEquals(await createSupabaseQuotaStore(client).isPro("u1"), true);
  assertEquals(calls[0], { fn: "is_premium_user", args: { user_uuid: "u1" } });
});

Deno.test("quota store records token usage including cache writes as input", async () => {
  const { calls, client } = fakeRpc({});
  await createSupabaseQuotaStore(client).record("u1", "recommend", {
    input_tokens: 120,
    output_tokens: 30,
    cache_read_input_tokens: 900,
  });
  assertEquals(calls[0], {
    fn: "ai_record_usage_b",
    args: { p_user: "u1", p_task: "recommend", p_in: 120, p_out: 30, p_cache: 900 },
  });
});

Deno.test("quota store refunds through its own RPC", async () => {
  const { calls, client } = fakeRpc({});
  await createSupabaseQuotaStore(client).refund("u1", "meal_photo", 1);
  assertEquals(calls[0], {
    fn: "ai_refund_quota_b",
    args: { p_user: "u1", p_task: "meal_photo", p_amount: 1 },
  });
});

async function captureConsole<T>(fn: () => Promise<T>): Promise<{ value: T; lines: string[] }> {
  const lines: string[] = [];
  const original = { log: console.log, warn: console.warn, error: console.error };
  const keep = (...args: unknown[]) => lines.push(args.map(String).join(" "));
  console.log = keep;
  console.warn = keep;
  console.error = keep;
  try {
    return { value: await fn(), lines };
  } finally {
    Object.assign(console, original);
  }
}

Deno.test("quota store never throws when recording usage fails, and logs no user data", async () => {
  const failing = { rpc: () => Promise.resolve({ data: null, error: { message: "db down for u-secret" } }) };
  const rejecting = { rpc: () => Promise.reject(new TypeError("network u-secret")) };
  for (const client of [failing, rejecting]) {
    const store = createSupabaseQuotaStore(client);
    const { lines } = await captureConsole(() =>
      store.record("u-secret", "recommend", { input_tokens: 1, output_tokens: 1, cache_read_input_tokens: 0 })
    );
    assertEquals(lines.length, 1);
    assertEquals(lines[0].includes("u-secret"), false);
  }
});

Deno.test("quota store never throws when a refund fails", async () => {
  const failing = { rpc: () => Promise.resolve({ data: null, error: { message: "db down" } }) };
  const rejecting = { rpc: () => Promise.reject(new TypeError("network")) };
  for (const client of [failing, rejecting]) {
    const { lines } = await captureConsole(() => createSupabaseQuotaStore(client).refund("u1", "avo_chat", 1));
    assertEquals(lines.length, 1);
  }
});

Deno.test("quota store fails closed when the consume RPC fails", async () => {
  const failing = { rpc: () => Promise.resolve({ data: null, error: { message: "db down" } }) };
  const err = await assertRejects(() => createSupabaseQuotaStore(failing).consume("u1", "avo_chat", 1, 3), AiError);
  assertEquals(err.code, "provider_error");
  const rejecting = { rpc: () => Promise.reject(new TypeError("network")) };
  const err2 = await assertRejects(() => createSupabaseQuotaStore(rejecting).consume("u1", "avo_chat", 1, 3), AiError);
  assertEquals(err2.code, "provider_error");
});

Deno.test("quota store treats a rejected premium lookup as free", async () => {
  const rejecting = { rpc: () => Promise.reject(new TypeError("network")) };
  const { value } = await captureConsole(() => createSupabaseQuotaStore(rejecting).isPro("u1"));
  assertEquals(value, false);
});
