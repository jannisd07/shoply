import { assertEquals, assertRejects } from "@std/assert";

import { AiError } from "./errors.ts";
import { createFlagsReader, parseAiFlags } from "./flags.ts";

const LIMITS = {
  free: { avo_chat: 3, categorize: 200 },
  pro: { avo_chat: 60, categorize: 500 },
};

Deno.test("parseAiFlags reads the kill switch and the limits", () => {
  const flags = parseAiFlags([
    { key: "ai_enabled", enabled: false, value: null },
    { key: "ai_limits", enabled: true, value: LIMITS },
  ]);
  assertEquals(flags.aiEnabled, false);
  assertEquals(flags.limits, LIMITS);
});

Deno.test("parseAiFlags keeps AI on when the kill switch row is missing", () => {
  assertEquals(parseAiFlags([]).aiEnabled, true);
});

Deno.test("parseAiFlags drops limits that are not plain numbers", () => {
  const flags = parseAiFlags([
    { key: "ai_limits", enabled: true, value: { free: { a: "3", b: 2 }, pro: "nope" } },
  ]);
  assertEquals(flags.limits, { free: { b: 2 }, pro: {} });
});

Deno.test("flags reader caches within the TTL and refreshes after it", async () => {
  let fetches = 0;
  let clock = 1_000;
  const read = createFlagsReader(() => {
    fetches++;
    return Promise.resolve([{ key: "ai_enabled", enabled: fetches === 1, value: null }]);
  }, { ttlMs: 60_000, now: () => clock });

  assertEquals((await read()).aiEnabled, true);
  clock += 59_000;
  assertEquals((await read()).aiEnabled, true);
  assertEquals(fetches, 1);
  clock += 2_000;
  assertEquals((await read()).aiEnabled, false);
  assertEquals(fetches, 2);
});

Deno.test("flags reader keeps the last good value when a refresh fails", async () => {
  let fail = false;
  let clock = 0;
  const read = createFlagsReader(() => {
    if (fail) return Promise.reject(new Error("db down"));
    return Promise.resolve([{ key: "ai_enabled", enabled: false, value: null }]);
  }, { ttlMs: 10, now: () => clock });

  assertEquals((await read()).aiEnabled, false);
  fail = true;
  clock += 100;
  assertEquals((await read()).aiEnabled, false);
});

Deno.test("flags reader without any value fails closed with provider_error", async () => {
  const read = createFlagsReader(() => Promise.reject(new Error("db down")));
  const err = await assertRejects(() => read(), AiError);
  assertEquals(err.code, "provider_error");
});
