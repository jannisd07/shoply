import { assertEquals, assertRejects } from "@std/assert";

import { AiError } from "./errors.ts";
import { aiErrorResponse, jsonResponse, parseLocale, readJsonBody, sseResponse } from "./http.ts";

function post(body: BodyInit, headers: Record<string, string> = {}) {
  return new Request("http://localhost/ai", { method: "POST", body, headers });
}

Deno.test("readJsonBody parses a JSON object", async () => {
  assertEquals(await readJsonBody(post('{"task":"x"}')), { task: "x" });
});

Deno.test("readJsonBody rejects invalid JSON as bad_request", async () => {
  const err = await assertRejects(() => readJsonBody(post("{nope")), AiError);
  assertEquals(err.code, "bad_request");
});

Deno.test("readJsonBody rejects a declared body over the limit without reading it", async () => {
  const err = await assertRejects(
    () => readJsonBody(post("{}", { "content-length": String(7 * 1024 * 1024) }), 6 * 1024 * 1024),
    AiError,
  );
  assertEquals(err.code, "bad_request");
});

Deno.test("readJsonBody stops reading a streamed body once it passes the limit", async () => {
  const chunk = new TextEncoder().encode("a".repeat(1024));
  let sent = 0;
  const stream = new ReadableStream<Uint8Array>({
    pull(controller) {
      sent++;
      controller.enqueue(chunk);
      if (sent > 100) controller.close();
    },
  });
  const err = await assertRejects(() => readJsonBody(post(stream), 4 * 1024), AiError);
  assertEquals(err.code, "bad_request");
  assertEquals(sent < 10, true);
});

Deno.test("parseLocale accepts de/en and regional variants, else falls back", () => {
  assertEquals(parseLocale("en"), "en");
  assertEquals(parseLocale("en-GB"), "en");
  assertEquals(parseLocale("de-DE,de;q=0.9"), "de");
  assertEquals(parseLocale("fr", "en"), "en");
  assertEquals(parseLocale(undefined), "de");
});

Deno.test("jsonResponse sends JSON with CORS headers", async () => {
  const res = jsonResponse({ ok: true }, 200);
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("content-type"), "application/json");
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
  assertEquals(await res.json(), { ok: true });
});

Deno.test("aiErrorResponse sets status, body and Retry-After", async () => {
  const res = aiErrorResponse(new AiError("quota_exceeded", "x", { retryAfterS: 90 }), "en");
  assertEquals(res.status, 429);
  assertEquals(res.headers.get("retry-after"), "90");
  const body = await res.json();
  assertEquals(body.code, "quota_exceeded");
  assertEquals(body.retry_after_s, 90);
});

async function readAll(res: Response): Promise<string> {
  return await res.text();
}

Deno.test("sseResponse streams named events and always ends with done", async () => {
  const res = sseResponse(async (send) => {
    send("text", { delta: "Hal" });
    await Promise.resolve();
    send("text", { delta: "lo" });
  }, "de");
  assertEquals(res.headers.get("content-type"), "text/event-stream");
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
  assertEquals(
    await readAll(res),
    'event: text\ndata: {"delta":"Hal"}\n\n' +
      'event: text\ndata: {"delta":"lo"}\n\n' +
      "event: done\ndata: {}\n\n",
  );
});

Deno.test("sseResponse turns a failure into an error event before done", async () => {
  const res = sseResponse(() => {
    throw new AiError("timeout", "slow");
  }, "en");
  const text = await readAll(res);
  const [errorEvent, doneEvent] = text.trim().split("\n\n");
  assertEquals(errorEvent.split("\n")[0], "event: error");
  const data = JSON.parse(errorEvent.split("\n")[1].slice("data: ".length));
  assertEquals(data.code, "timeout");
  assertEquals(typeof data.message, "string");
  assertEquals(doneEvent, "event: done\ndata: {}");
});

Deno.test("sseResponse aborts the run's signal when the app hangs up", async () => {
  let seen: AbortSignal | undefined;
  let release!: () => void;
  const finished = new Promise<void>((resolve) => (release = resolve));
  const res = sseResponse(async (send, signal) => {
    seen = signal;
    send("text", { delta: "a" });
    await new Promise<void>((resolve) => signal.addEventListener("abort", () => resolve(), { once: true }));
    send("text", { delta: "after hang-up" });
    release();
  }, "de");
  const reader = res.body!.getReader();
  await reader.read();
  assertEquals(seen?.aborted, false);
  await reader.cancel();
  await finished;
  assertEquals(seen?.aborted, true);
});

Deno.test("sseResponse survives a run that fails after the app hung up", async () => {
  let release!: () => void;
  const finished = new Promise<void>((resolve) => (release = resolve));
  const res = sseResponse(async (_send, signal) => {
    await new Promise<void>((resolve) => signal.addEventListener("abort", () => resolve(), { once: true }));
    queueMicrotask(release);
    throw new AiError("timeout", "upstream aborted");
  }, "en");
  await res.body!.cancel();
  await finished;
  await new Promise((resolve) => setTimeout(resolve, 0));
});
