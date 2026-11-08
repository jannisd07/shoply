import { assertEquals } from "@std/assert";

import { AI_ERROR_STATUS, AiError, errorBody, userMessage } from "./errors.ts";

Deno.test("every error code maps to the HTTP status of the client contract", () => {
  assertEquals(AI_ERROR_STATUS, {
    unauthorized: 401,
    bad_request: 400,
    quota_exceeded: 429,
    rate_limited: 429,
    ai_disabled: 503,
    refused: 422,
    no_items_found: 422,
    unreadable_image: 422,
    no_food_detected: 422,
    provider_error: 502,
    timeout: 504,
  });
});

Deno.test("AiError exposes code, status, retry hint and refund flag", () => {
  const err = new AiError("quota_exceeded", "limit", { retryAfterS: 120 });
  assertEquals(err.code, "quota_exceeded");
  assertEquals(err.status, 429);
  assertEquals(err.retryAfterS, 120);
  assertEquals(err.refundable, false);
  assertEquals(new AiError("rate_limited", "x", { refundable: true }).refundable, true);
});

Deno.test("error body is localized and never leaks the internal message", () => {
  const err = new AiError("bad_request", "items[3].name too long: secret text");
  const de = errorBody(err, "de");
  const en = errorBody(err, "en");
  assertEquals(de.code, "bad_request");
  assertEquals(de.message, userMessage("bad_request", "de"));
  assertEquals(en.message, userMessage("bad_request", "en"));
  assertEquals(de.message.includes("secret"), false);
  assertEquals("retry_after_s" in de, false);
});

Deno.test("error body carries retry_after_s when set", () => {
  const body = errorBody(new AiError("quota_exceeded", "x", { retryAfterS: 42 }), "en");
  assertEquals(body.retry_after_s, 42);
});

Deno.test("German and English messages exist for every code", () => {
  for (const code of Object.keys(AI_ERROR_STATUS) as Array<keyof typeof AI_ERROR_STATUS>) {
    assertEquals(userMessage(code, "de").length > 0, true, code);
    assertEquals(userMessage(code, "en").length > 0, true, code);
    assertEquals(userMessage(code, "de") === userMessage(code, "en"), false, code);
  }
});
