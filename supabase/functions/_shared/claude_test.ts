import Anthropic from "@anthropic-ai/sdk";
import { assertEquals, assertRejects } from "@std/assert";

import { callStructured, FALLBACK_BETA, HAIKU, SONNET, textOf, toAiError, usageOf } from "./claude.ts";
import { AiError } from "./errors.ts";
import { FakeClaude, fakeMessage } from "./testing/fake_claude.ts";

const SCHEMA = {
  type: "object",
  properties: { answer: { type: "string" } },
  required: ["answer"],
  additionalProperties: false,
};

function headers(entries: Record<string, string> = {}) {
  return new Headers(entries);
}

Deno.test("SDK rate limit maps to rate_limited with the retry hint and a refund", () => {
  const err = toAiError(new Anthropic.RateLimitError(429, {}, "slow down", headers({ "retry-after": "7" })));
  assertEquals(err.code, "rate_limited");
  assertEquals(err.retryAfterS, 7);
  assertEquals(err.refundable, true);
});

Deno.test("SDK 5xx and overload map to provider_error with a refund", () => {
  for (const status of [500, 529]) {
    const err = toAiError(new Anthropic.InternalServerError(status, {}, "boom", headers()));
    assertEquals(err.code, "provider_error");
    assertEquals(err.refundable, true);
  }
});

Deno.test("SDK timeouts and aborts map to timeout without a refund", () => {
  for (const sdkErr of [new Anthropic.APIConnectionTimeoutError(), new Anthropic.APIUserAbortError()]) {
    const err = toAiError(sdkErr);
    assertEquals(err.code, "timeout");
    assertEquals(err.refundable, false);
  }
});

Deno.test("SDK connection errors map to provider_error with a refund", () => {
  const err = toAiError(new Anthropic.APIConnectionError({ message: "offline" }));
  assertEquals(err.code, "provider_error");
  assertEquals(err.refundable, true);
});

Deno.test("SDK 4xx errors (bad key, unknown model, beta off, too large) are not billed: provider_error with a refund", () => {
  const errors = [
    new Anthropic.BadRequestError(400, {}, "bad", headers()),
    new Anthropic.AuthenticationError(401, {}, "bad key", headers()),
    new Anthropic.PermissionDeniedError(403, {}, "forbidden", headers()),
    new Anthropic.NotFoundError(404, {}, "no model", headers()),
    Anthropic.APIError.generate(413, {}, "too large", headers()),
  ];
  for (const sdkErr of errors) {
    const err = toAiError(sdkErr);
    assertEquals(err.code, "provider_error", String(sdkErr.status));
    assertEquals(err.refundable, true, String(sdkErr.status));
  }
});

Deno.test("AiError passes through and unknown errors become provider_error", () => {
  const own = new AiError("no_food_detected");
  assertEquals(toAiError(own), own);
  assertEquals(toAiError(new TypeError("bug")).code, "provider_error");
});

Deno.test("usageOf counts cache writes as input and defaults missing fields to zero", () => {
  assertEquals(
    usageOf({ input_tokens: 10, output_tokens: 4, cache_creation_input_tokens: 600, cache_read_input_tokens: null }),
    { input_tokens: 610, output_tokens: 4, cache_read_input_tokens: 0 },
  );
});

Deno.test("Haiku structured call: thinking off, effort low, JSON schema, cached system, no sampling params", async () => {
  const claude = new FakeClaude(fakeMessage({ json: { answer: "ok" } }));
  const out = await callStructured<{ answer: string }>(HAIKU, "SYSTEM", "question", SCHEMA, {
    client: claude,
    maxTokens: 300,
    timeoutMs: 5_000,
  });
  assertEquals(out.data, { answer: "ok" });
  assertEquals(claude.calls.length, 1);
  const call = claude.calls[0];
  assertEquals(call.api, "messages");
  assertEquals(call.body.model, "claude-haiku-5-5");
  assertEquals(call.body.max_tokens, 300);
  assertEquals(call.body.thinking, { type: "disabled" });
  assertEquals(call.body.output_config, { effort: "low", format: { type: "json_schema", schema: SCHEMA } });
  assertEquals(call.body.system, [{ type: "text", text: "SYSTEM", cache_control: { type: "ephemeral" } }]);
  assertEquals(call.body.messages, [{ role: "user", content: "question" }]);
  for (const forbidden of ["temperature", "top_p", "top_k", "fallbacks", "tool_choice"]) {
    assertEquals(forbidden in call.body, false, forbidden);
  }
  assertEquals(call.options?.timeout, 5_000);
});

Deno.test("Sonnet structured call: beta client, adaptive thinking, server-side fallback", async () => {
  const claude = new FakeClaude(fakeMessage({ json: { answer: "ok" } }));
  await callStructured(SONNET, "SYSTEM", [{ type: "text", text: "photo" }], SCHEMA, {
    client: claude,
    maxTokens: 4_000,
    timeoutMs: 30_000,
    effort: "medium",
  });
  const call = claude.calls[0];
  assertEquals(call.api, "beta");
  assertEquals(call.body.model, "claude-sonnet-5-5");
  assertEquals(call.body.thinking, { type: "adaptive" });
  assertEquals(call.body.fallbacks, "default");
  assertEquals(call.body.betas, [FALLBACK_BETA]);
  assertEquals(call.body.output_config, { effort: "medium", format: { type: "json_schema", schema: SCHEMA } });
  assertEquals(call.body.system, [{ type: "text", text: "SYSTEM", cache_control: { type: "ephemeral" } }]);
  for (const forbidden of ["temperature", "top_p", "top_k", "tool_choice"]) {
    assertEquals(forbidden in call.body, false, forbidden);
  }
});

Deno.test("Sonnet structured call checks refusal before reading content", async () => {
  const claude = new FakeClaude(fakeMessage({ json: { answer: "ok" }, stop_reason: "refusal" }));
  const err = await assertRejects(
    () => callStructured(SONNET, "S", "q", SCHEMA, { client: claude, maxTokens: 100, timeoutMs: 1_000 }),
    AiError,
  );
  assertEquals(err.code, "refused");
  assertEquals(err.refundable, false);
});

Deno.test("textOf joins text blocks only and ignores malformed blocks", () => {
  const blocks: Array<{ type: string; text?: unknown }> = [
    { type: "thinking" },
    { type: "text", text: "a" },
    { type: "text" },
    { type: "text", text: 7 },
    { type: "redacted_thinking" },
    { type: "text", text: "b" },
  ];
  assertEquals(textOf(blocks), "ab");
});

Deno.test("structured call checks refusal before reading content", async () => {
  const claude = new FakeClaude(fakeMessage({ json: { answer: "ok" }, stop_reason: "refusal" }));
  const err = await assertRejects(
    () => callStructured(HAIKU, "S", "q", SCHEMA, { client: claude, maxTokens: 100, timeoutMs: 1_000 }),
    AiError,
  );
  assertEquals(err.code, "refused");
  assertEquals(err.refundable, false);
});

Deno.test("structured call reads text blocks by type, skipping thinking blocks", async () => {
  const claude = new FakeClaude(fakeMessage({
    content: [
      { type: "thinking", thinking: "", signature: "sig" },
      { type: "text", text: '{"answer":', citations: null },
      { type: "text", text: '"split"}', citations: null },
    ],
  }));
  const out = await callStructured<{ answer: string }>(HAIKU, "S", "q", SCHEMA, {
    client: claude,
    maxTokens: 100,
    timeoutMs: 1_000,
  });
  assertEquals(out.data.answer, "split");
});

Deno.test("structured call treats a truncated answer as provider_error", async () => {
  const claude = new FakeClaude(fakeMessage({ text: '{"answer": "cut', stop_reason: "max_tokens" }));
  const err = await assertRejects(
    () => callStructured(HAIKU, "S", "q", SCHEMA, { client: claude, maxTokens: 10, timeoutMs: 1_000 }),
    AiError,
  );
  assertEquals(err.code, "provider_error");
});

Deno.test("structured call maps SDK errors through the error chain", async () => {
  const claude = new FakeClaude(new Anthropic.RateLimitError(429, {}, "slow", headers()));
  const err = await assertRejects(
    () => callStructured(HAIKU, "S", "q", SCHEMA, { client: claude, maxTokens: 10, timeoutMs: 1_000 }),
    AiError,
  );
  assertEquals(err.code, "rate_limited");
});

Deno.test("structured call returns usage from the response", async () => {
  const claude = new FakeClaude(fakeMessage({
    json: { answer: "ok" },
    usage: { input_tokens: 20, output_tokens: 7, cache_creation_input_tokens: 0, cache_read_input_tokens: 800 },
  }));
  const out = await callStructured(HAIKU, "S", "q", SCHEMA, { client: claude, maxTokens: 10, timeoutMs: 1_000 });
  assertEquals(out.usage, { input_tokens: 20, output_tokens: 7, cache_read_input_tokens: 800 });
});
