// Task `list_import` (plan B1.7) and the old `extract-shopping-list` function,
// which runs the same core (_shared/list_import_core.ts) for builds that still
// call it. Fake Claude client and fake storage, no network.

import Anthropic from "@anthropic-ai/sdk";
import { assertEquals, assertRejects, assertStringIncludes, assertThrows } from "@std/assert";

import categoriesFile from "../../_shared/categories.json" with { type: "json" };
import { FALLBACK_BETA } from "../../_shared/claude.ts";
import { AiError } from "../../_shared/errors.ts";
import type { AiFlags } from "../../_shared/flags.ts";
import { encodeBase64, MAX_IMAGE_BASE64_CHARS } from "../../_shared/image_input.ts";
import {
  createLegacyExtractHandler,
  LEGACY_CODES,
  type LegacyStorage,
  LIST_IMPORT_SCHEMA,
  LIST_IMPORT_SYSTEM_PROMPT,
  UNITS,
} from "../../_shared/list_import_core.ts";
import type { QuotaStore } from "../../_shared/quota.ts";
import { FakeClaude, fakeMessage, type ScriptedReply } from "../../_shared/testing/fake_claude.ts";
import { handler, parseInput } from "./list_import.ts";
import type { TaskContext } from "./types.ts";

function bytesOf(head: number[], length = 64): Uint8Array {
  const bytes = new Uint8Array(length);
  bytes.set(head);
  return bytes;
}

const JPEG = bytesOf([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46]);
const PNG = bytesOf([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const HEIC = bytesOf([0, 0, 0, 0x18, ...[..."ftypheic"].map((c) => c.charCodeAt(0))]);
const JPEG_B64 = encodeBase64(JPEG);

function ctx(claude: FakeClaude, raw: Record<string, unknown>, locale: "de" | "en" = "de") {
  const input = parseInput(raw);
  return { userId: "u1", locale, input, claude, isPro: false } satisfies TaskContext<typeof input>;
}

const PHOTO = { image_b64: JPEG_B64, media_type: "image/jpeg" };

interface ModelItem {
  name: string;
  quantity: number | null;
  unit: string | null;
  category_id: string;
  confidence: "high" | "medium" | "low";
}

function item(name: string, values: Partial<ModelItem> = {}): ModelItem {
  return { name, quantity: null, unit: null, category_id: "other", confidence: "high", ...values };
}

function listReply(items: ModelItem[], extra: Record<string, unknown> = {}) {
  return fakeMessage({
    json: { legible: true, items, unparsed_lines: [], ...extra },
    usage: { input_tokens: 1500, output_tokens: 300, cache_read_input_tokens: 700 },
  });
}

const NOTE = listReply([
  item("Kartoffeln", { quantity: 1, unit: "kg", category_id: "fruits_vegetables" }),
  item("Sahne", { quantity: 2, category_id: "dairy" }),
  item("Penne", { unit: "pack", category_id: "staples", confidence: "medium" }),
  item("Schmand", { category_id: "dairy", confidence: "low" }),
], { unparsed_lines: ["für Sonntag", "Oma anrufen"] });

/** Every object in the schema must close its properties (structured outputs rule). */
function assertClosedObjects(schema: unknown, path = "schema"): void {
  if (Array.isArray(schema)) {
    schema.forEach((entry, i) => assertClosedObjects(entry, `${path}[${i}]`));
    return;
  }
  if (typeof schema !== "object" || schema === null) return;
  const node = schema as Record<string, unknown>;
  if (node.type === "object") {
    assertEquals(node.additionalProperties, false, `${path}: additionalProperties`);
    const properties = Object.keys(node.properties as Record<string, unknown>).sort();
    assertEquals([...(node.required as string[])].sort(), properties, `${path}: every property is required`);
  }
  for (const [key, value] of Object.entries(node)) assertClosedObjects(value, `${path}.${key}`);
}

// --- Task list_import -------------------------------------------------------

Deno.test("parseInput takes the photo and reads its type from the bytes", () => {
  assertEquals(parseInput(PHOTO), { image: { data: JPEG_B64, mediaType: "image/jpeg" } });
  assertEquals(parseInput({ image_b64: encodeBase64(PNG), media_type: "image/jpeg" }).image.mediaType, "image/png");
});

Deno.test("parseInput answers bad_request for a missing, malformed or oversized photo", () => {
  const head = encodeBase64(JPEG.subarray(0, 63));
  const oversized = head + "A".repeat(MAX_IMAGE_BASE64_CHARS - head.length + 4);
  const bad: Record<string, unknown>[] = [
    {},
    { image_b64: JPEG_B64 },
    { image_b64: "%%%%", media_type: "image/jpeg" },
    { image_b64: oversized, media_type: "image/jpeg" },
  ];
  for (const raw of bad) {
    const err = assertThrows(() => parseInput(raw), AiError);
    assertEquals(err.code, "bad_request");
    assertEquals(err.message.includes(head), false, "the photo never appears in an error");
  }
});

Deno.test("parseInput answers unreadable_image for a photo Claude cannot read (HEIC)", () => {
  const err = assertThrows(() => parseInput({ image_b64: encodeBase64(HEIC), media_type: "image/jpeg" }), AiError);
  assertEquals(err.code, "unreadable_image");
});

Deno.test("list_import calls Sonnet with adaptive thinking, effort medium and the server-side fallback", async () => {
  const claude = new FakeClaude(NOTE);
  await handler(ctx(claude, PHOTO));
  assertEquals(claude.calls.length, 1, "one call per note");
  const { api, body, options } = claude.calls[0];
  assertEquals(api, "beta");
  assertEquals(body.model, "claude-sonnet-5-5");
  assertEquals(body.thinking, { type: "adaptive" });
  assertEquals(body.output_config, {
    effort: "medium",
    format: { type: "json_schema", schema: LIST_IMPORT_SCHEMA },
  });
  assertEquals(body.fallbacks, "default");
  assertEquals(body.betas, [FALLBACK_BETA]);
  assertEquals(body.system, [{ type: "text", text: LIST_IMPORT_SYSTEM_PROMPT, cache_control: { type: "ephemeral" } }]);
  for (const forbidden of ["temperature", "top_p", "top_k", "tool_choice", "tools"]) {
    assertEquals(forbidden in body, false, forbidden);
  }
  assertEquals(options?.timeout, 27_000);
  assertEquals(options?.maxRetries, 0);
});

Deno.test("list_import sends the photo first, then the app language as text; the system prompt stays fixed", async () => {
  const systems: unknown[] = [];
  for (const [locale, language] of [["de", "German"], ["en", "English"]] as const) {
    const claude = new FakeClaude(NOTE);
    await handler(ctx(claude, PHOTO, locale));
    const { body } = claude.calls[0];
    systems.push(body.system);
    const messages = body.messages as Array<{ role: string; content: Array<Record<string, unknown>> }>;
    assertEquals(messages.length, 1);
    assertEquals(messages[0].role, "user");
    assertEquals(messages[0].content.length, 2);
    const [image, text] = messages[0].content;
    assertEquals(image, { type: "image", source: { type: "base64", media_type: "image/jpeg", data: JPEG_B64 } });
    assertEquals(text.type, "text");
    assertStringIncludes(text.text as string, language);
  }
  assertEquals(systems[0], systems[1]);
});

Deno.test("the list schema closes every object and uses the app's category ids and units", () => {
  assertClosedObjects(LIST_IMPORT_SCHEMA);
  const itemSchema = (LIST_IMPORT_SCHEMA.properties.items as { items: { properties: Record<string, unknown> } })
    .items.properties;
  assertEquals(Object.keys(itemSchema).sort(), ["category_id", "confidence", "name", "quantity", "unit"]);
  assertEquals(
    (itemSchema.category_id as { enum: string[] }).enum,
    categoriesFile.categories.map((category) => category.id),
  );
  assertEquals([...UNITS], ["g", "kg", "ml", "l", "pack", "bottle", "can", "box", "bunch"]);
  assertEquals(itemSchema.unit, { anyOf: [{ type: "string", enum: [...UNITS] }, { type: "null" }] });
  for (const id of categoriesFile.categories.map((category) => category.id)) {
    assertStringIncludes(LIST_IMPORT_SYSTEM_PROMPT, `- ${id}:`);
  }
});

Deno.test("list_import returns the items with category ids, a confidence score and the unread lines", async () => {
  const claude = new FakeClaude(NOTE);
  const out = await handler(ctx(claude, PHOTO));
  assertEquals(out.result, {
    items: [
      { name: "Kartoffeln", quantity: 1, unit: "kg", category_id: "fruits_vegetables", confidence: 0.95 },
      { name: "Sahne", quantity: 2, unit: null, category_id: "dairy", confidence: 0.95 },
      { name: "Penne", quantity: null, unit: "pack", category_id: "staples", confidence: 0.7 },
      { name: "Schmand", quantity: null, unit: null, category_id: "dairy", confidence: 0.4 },
    ],
    unparsed_lines: ["für Sonntag", "Oma anrufen"],
  });
  assertEquals(out.usage, { input_tokens: 1500, output_tokens: 300, cache_read_input_tokens: 700 });
});

Deno.test("list_import cleans names, quantities, units and categories the schema cannot rule out", async () => {
  const claude = new FakeClaude(listReply([
    item("  Milch  ", { quantity: 0 }),
    item("   "),
    { name: 5 } as unknown as ModelItem,
    item("Eier", { quantity: 12.5, unit: "dozen" }),
    item("Wasser", { quantity: 10_000, category_id: "drinks" }),
    item("Mehl", { quantity: -1, unit: "kg", confidence: "sure" as "high" }),
    item("x".repeat(300)),
  ], { unparsed_lines: ["  ", " Oma anrufen ", 7, "y".repeat(300)] }));
  const out = await handler(ctx(claude, PHOTO));
  const result = out.result as { items: Array<Omit<ModelItem, "confidence"> & { confidence: number }> };
  const unparsed = (out.result as { unparsed_lines: string[] }).unparsed_lines;
  assertEquals(result.items.map((i) => i.name), ["Milch", "Eier", "Wasser", "Mehl", "x".repeat(120)]);
  assertEquals(result.items.map((i) => i.quantity), [null, 12.5, null, null, null]);
  assertEquals(result.items.map((i) => i.unit), [null, null, null, "kg", null]);
  assertEquals(result.items[2].category_id, "other");
  assertEquals(result.items[3].confidence, 0.4, "an unknown confidence asks the person to check");
  assertEquals(unparsed, ["Oma anrufen", "y".repeat(200)]);
});

Deno.test("list_import keeps at most 100 items and 30 unread lines", async () => {
  const claude = new FakeClaude(listReply(
    Array.from({ length: 130 }, (_, i) => item(`Artikel ${i}`)),
    { unparsed_lines: Array.from({ length: 40 }, (_, i) => `Zeile ${i}`) },
  ));
  const out = await handler(ctx(claude, PHOTO));
  const result = out.result as { items: unknown[]; unparsed_lines: string[] };
  assertEquals(result.items.length, 100);
  assertEquals(result.unparsed_lines.length, 30);
});

Deno.test("list_import answers unreadable_image when the photo cannot be read", async () => {
  const claude = new FakeClaude(listReply([], { legible: false }));
  assertEquals((await assertRejects(() => handler(ctx(claude, PHOTO)), AiError)).code, "unreadable_image");
});

Deno.test("list_import answers no_items_found for a readable photo without products", async () => {
  for (const reply of [listReply([]), listReply([item(" ")], { unparsed_lines: ["Oma anrufen"] })]) {
    const claude = new FakeClaude(reply);
    const err = await assertRejects(() => handler(ctx(claude, PHOTO)), AiError);
    assertEquals(err.code, "no_items_found");
    assertEquals(err.refundable, false, "the call was billed");
  }
});

Deno.test("list_import maps refusals, cut-off answers and broken JSON", async () => {
  const cases: Array<[ScriptedReply, string]> = [
    [fakeMessage({ stop_reason: "refusal" }), "refused"],
    [fakeMessage({ stop_reason: "max_tokens", json: { legible: true } }), "provider_error"],
    [fakeMessage({ text: "not json" }), "provider_error"],
    [fakeMessage({ json: { legible: true, items: "many", unparsed_lines: [] } }), "provider_error"],
    [fakeMessage({ json: { items: [item("Brot")], unparsed_lines: [] } }), "provider_error"],
    [fakeMessage({ json: [item("Brot")] }), "provider_error"],
  ];
  for (const [reply, code] of cases) {
    const claude = new FakeClaude(reply);
    assertEquals((await assertRejects(() => handler(ctx(claude, PHOTO)), AiError)).code, code, code);
  }
});

Deno.test("list_import reads only text blocks, after a thinking block", async () => {
  const claude = new FakeClaude(fakeMessage({
    content: [
      { type: "thinking", thinking: "", signature: "sig" },
      { type: "text", text: JSON.stringify({ legible: true, items: [item("Brot")], unparsed_lines: [] }) },
    ],
  }));
  const out = await handler(ctx(claude, PHOTO));
  assertEquals((out.result as { items: ModelItem[] }).items.map((i) => i.name), ["Brot"]);
});

// --- Old function extract-shopping-list -------------------------------------

const UID = "4b3c2a10-0000-4000-8000-000000000001";
/** The only shape old builds send: `<uid>/<uuid v4>.jpg` (ListImportService). */
const PATH = `${UID}/9f0e2d4c-5b6a-4f78-9a0b-1c2d3e4f5a6b.jpg`;
const LIMITS = { free: { list_import: 1 }, pro: { list_import: 10 } };

interface LegacyOptions {
  replies?: ScriptedReply[];
  files?: Record<string, Uint8Array>;
  aiEnabled?: boolean;
  allow?: boolean;
  pro?: boolean;
  limits?: AiFlags["limits"];
}

function legacy(opts: LegacyOptions = {}) {
  const claude = new FakeClaude(...(opts.replies ?? [NOTE]));
  const files = new Map(Object.entries(opts.files ?? { [PATH]: JPEG }));
  const removed: string[] = [];
  const downloads: string[] = [];
  const consumed: Array<{ task: string; amount: number; limit: number }> = [];
  const refunds: Array<{ task: string; amount: number }> = [];
  const records: string[] = [];
  const storage: LegacyStorage = {
    download: (path) => {
      downloads.push(path);
      return Promise.resolve(files.get(path) ?? null);
    },
    remove: (path) => {
      removed.push(path);
      return Promise.resolve();
    },
  };
  const quota: QuotaStore = {
    isPro: () => Promise.resolve(opts.pro ?? false),
    consume: (_user, task, amount, limit) => {
      consumed.push({ task, amount, limit });
      return Promise.resolve(opts.allow ?? true);
    },
    refund: (_user, task, amount) => {
      refunds.push({ task, amount });
      return Promise.resolve();
    },
    record: (_user, task) => {
      records.push(task);
      return Promise.resolve();
    },
  };
  const handle = createLegacyExtractHandler({
    authenticate: (req) => {
      if (req.headers.get("Authorization") === "Bearer good-jwt") return Promise.resolve(UID);
      return Promise.reject(new AiError("unauthorized", "invalid token"));
    },
    readFlags: () => Promise.resolve({ aiEnabled: opts.aiEnabled ?? true, limits: opts.limits ?? LIMITS }),
    quota,
    claude: () => claude,
    storage,
  });
  return { handle, claude, removed, downloads, consumed, refunds, records };
}

function legacyPost(body: unknown, authorization: string | null = "Bearer good-jwt", method = "POST"): Request {
  const headers = new Headers({ "content-type": "application/json" });
  if (authorization !== null) headers.set("Authorization", authorization);
  return new Request("http://localhost/functions/v1/extract-shopping-list", {
    method,
    headers,
    body: method === "GET" ? undefined : typeof body === "string" ? body : JSON.stringify(body),
  });
}

async function legacyError(res: Response) {
  assertEquals(res.headers.get("content-type"), "application/json");
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
  const body = await res.json() as Record<string, unknown>;
  assertEquals(Object.keys(body).sort(), ["code", "message"], "old error shape");
  assertEquals((LEGACY_CODES as readonly string[]).includes(body.code as string), true, String(body.code));
  return body as { code: string; message: string };
}

Deno.test("old function: 200 keeps the old keys, old units and the unread lines, and deletes the upload", async () => {
  const h = legacy();
  const res = await h.handle(legacyPost({ image_path: PATH, locale: "de-DE" }));
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("access-control-allow-origin"), "*");
  const body = await res.json();
  assertEquals(Object.keys(body).sort(), ["items", "unparsed_lines"]);
  assertEquals(body, {
    items: [
      { name: "Kartoffeln", quantity: 1, unit: "kg", confidence: 0.95 },
      { name: "Sahne", quantity: 2, unit: null, confidence: 0.95 },
      { name: "Penne", quantity: null, unit: "Pck", confidence: 0.7 },
      { name: "Schmand", quantity: null, unit: null, confidence: 0.4 },
    ],
    unparsed_lines: ["für Sonntag", "Oma anrufen"],
  });
  assertEquals(h.downloads, [PATH]);
  assertEquals(h.removed, [PATH]);
  assertEquals(h.consumed, [{ task: "list_import", amount: 1, limit: 1 }]);
  assertEquals(h.records, ["list_import"]);
  assertEquals(h.refunds, []);
});

Deno.test("old function: units map back to the old German spelling", async () => {
  const units = ["g", "kg", "ml", "l", "pack", "bottle", "can", "box", "bunch", null];
  const h = legacy({ replies: [listReply(units.map((unit, i) => item(`Artikel ${i}`, { unit })))] });
  const body = await (await h.handle(legacyPost({ image_path: PATH }))).json();
  assertEquals(
    body.items.map((i: { unit: string | null }) => i.unit),
    ["g", "kg", "ml", "l", "Pck", "Flasche", "Dose", "Schachtel", "Bund", null],
  );
});

Deno.test("old function: runs the same Claude request as the list_import task", async () => {
  const h = legacy();
  await h.handle(legacyPost({ image_path: PATH, locale: "en-US" }));
  const task = new FakeClaude(NOTE);
  await handler(ctx(task, PHOTO, "en"));
  const { body } = h.claude.calls[0];
  assertEquals(body.system, task.calls[0].body.system);
  assertEquals(body.output_config, task.calls[0].body.output_config);
  assertEquals(body.messages, task.calls[0].body.messages);
  assertEquals(body.model, "claude-sonnet-5-5");
  assertEquals(h.claude.calls[0].options?.timeout, 45_000, "old builds wait up to 60 s");
});

Deno.test("old function: 401 without a valid JWT, nothing downloaded or deleted", async () => {
  for (const auth of [null, "Bearer expired"]) {
    const h = legacy();
    const res = await h.handle(legacyPost({ image_path: PATH }, auth));
    assertEquals(res.status, 401);
    const body = await legacyError(res);
    assertEquals(body, { code: "unauthorized", message: "Nicht angemeldet." });
    assertEquals(h.downloads, []);
    assertEquals(h.removed, []);
    assertEquals(h.consumed, []);
  }
});

Deno.test("old function: 403 for a path outside the caller's folder, which is never deleted", async () => {
  const otherUid = "00000000-0000-4000-8000-0000000000ff";
  const other = `${otherUid}/9f0e2d4c-5b6a-4f78-9a0b-1c2d3e4f5a6b.jpg`;
  // fetch's URL parser turns %2e%2e, .%2E and backslashes into "..", so these
  // would reach another person's folder if only a literal ".." were refused.
  const paths = [
    other,
    `${UID}/../${other}`,
    `x${UID}/a.jpg`,
    `${UID}/%2e%2e/${other}`,
    `${UID}/.%2E/${other}`,
    `${UID}\\..\\${other}`,
    `${UID}/sub/9f0e2d4c-5b6a-4f78-9a0b-1c2d3e4f5a6b.jpg`,
    `${UID}/9f0e2d4c-5b6a-4f78-9a0b-1c2d3e4f5a6b.jpg?x=1`,
    `${UID}/9f0e2d4c-5b6a-4f78-9a0b-1c2d3e4f5a6b.jpg#x`,
    `${UID}/9f0e.jpg`,
    `${UID}/`,
  ];
  for (const path of paths) {
    const h = legacy({ files: { [path]: JPEG } });
    const res = await h.handle(legacyPost({ image_path: path, locale: "en-US" }));
    assertEquals(res.status, 403, path);
    assertEquals((await legacyError(res)).code, "unauthorized");
    assertEquals(h.downloads, []);
    assertEquals(h.removed, []);
    assertEquals(h.consumed, []);
  }
});

Deno.test("old function: 400 bad_request for a missing image_path or no JSON, 405 for GET", async () => {
  for (const body of [{}, { image_path: 5 }, "{nope", "[]"]) {
    const h = legacy();
    const res = await h.handle(legacyPost(body));
    assertEquals(res.status, 400, JSON.stringify(body));
    assertEquals(await legacyError(res), { code: "bad_request", message: "Ungültige Anfrage." });
    assertEquals(h.removed, []);
  }
  const res = await legacy().handle(legacyPost(null, "Bearer good-jwt", "GET"));
  assertEquals(res.status, 405);
  assertEquals((await legacyError(res)).code, "bad_request");
});

Deno.test("old function: OPTIONS answers the CORS preflight", async () => {
  const res = await legacy().handle(new Request("http://localhost/", { method: "OPTIONS" }));
  assertEquals(res.status, 200);
  assertEquals(res.headers.get("access-control-allow-methods"), "POST, OPTIONS");
});

Deno.test("old function: the daily list_import quota applies, shown as rate_limited", async () => {
  const h = legacy({ allow: false, pro: true });
  const res = await h.handle(legacyPost({ image_path: PATH, locale: "en-US" }));
  assertEquals(res.status, 429);
  assertEquals(await legacyError(res), {
    code: "rate_limited",
    message: "Too many imports in a row. Please wait a moment.",
  });
  assertEquals(h.consumed, [{ task: "list_import", amount: 1, limit: 10 }]);
  assertEquals(h.claude.calls, []);
  assertEquals(h.removed, [PATH], "the upload is deleted on every outcome");
});

Deno.test("old function: kill switch or a missing limit answer provider_error without quota or Claude", async () => {
  for (const opts of [{ aiEnabled: false }, { limits: { free: {}, pro: {} } }]) {
    const h = legacy(opts);
    const res = await h.handle(legacyPost({ image_path: PATH }));
    assertEquals(res.status, 502);
    assertEquals((await legacyError(res)).code, "provider_error");
    assertEquals(h.consumed, []);
    assertEquals(h.claude.calls, []);
    assertEquals(h.removed, [PATH]);
  }
});

Deno.test("old function: a missing upload or an unreadable file type is unreadable_image and refunded", async () => {
  const uploads: Array<Record<string, Uint8Array>> = [{}, { [PATH]: HEIC }];
  for (const files of uploads) {
    const h = legacy({ files });
    const res = await h.handle(legacyPost({ image_path: PATH }));
    assertEquals(res.status, 400);
    assertEquals(await legacyError(res), { code: "unreadable_image", message: "Das Bild war schwer zu lesen." });
    assertEquals(h.claude.calls, []);
    assertEquals(h.refunds, [{ task: "list_import", amount: 1 }]);
    assertEquals(h.removed, [PATH]);
  }
});

Deno.test("old function: model answers map to the old codes and statuses", async () => {
  const cases: Array<[ScriptedReply, number, string, boolean]> = [
    [listReply([]), 422, "no_items_found", false],
    [listReply([], { legible: false }), 400, "unreadable_image", false],
    [fakeMessage({ stop_reason: "refusal" }), 400, "unreadable_image", false],
    [new Anthropic.InternalServerError(500, {}, "boom", new Headers()), 502, "provider_error", true],
    [new Anthropic.RateLimitError(429, {}, "slow", new Headers()), 429, "rate_limited", true],
    [new Anthropic.APIConnectionTimeoutError(), 504, "timeout", false],
  ];
  for (const [reply, status, code, refunded] of cases) {
    const h = legacy({ replies: [reply] });
    const res = await h.handle(legacyPost({ image_path: PATH }));
    assertEquals(res.status, status, code);
    assertEquals((await legacyError(res)).code, code);
    assertEquals(h.refunds.length, refunded ? 1 : 0, `${code} refund`);
    assertEquals(h.removed, [PATH]);
  }
});

Deno.test("old function: messages follow the old locale rule (de* German, anything else English)", async () => {
  const cases = [
    ["de-AT", "Avo hat darauf keine Artikel gefunden."],
    ["en-GB", "No items were found in that image."],
    ["fr-FR", "No items were found in that image."],
  ];
  for (const [locale, message] of cases) {
    const h = legacy({ replies: [listReply([])] });
    const res = await h.handle(legacyPost({ image_path: PATH, locale }));
    assertEquals((await legacyError(res)).message, message, locale);
  }
});

Deno.test("old function: logs carry neither the photo nor the storage path", async () => {
  const lines: string[] = [];
  const original = { log: console.log, warn: console.warn, error: console.error };
  console.log = console.warn = console.error = (...args: unknown[]) => {
    lines.push(args.map(String).join(" "));
  };
  try {
    await legacy().handle(legacyPost({ image_path: PATH }));
    await legacy({ replies: [listReply([])] }).handle(legacyPost({ image_path: PATH }));
  } finally {
    Object.assign(console, original);
  }
  assertEquals(lines.length > 0, true);
  for (const line of lines) {
    assertEquals(line.includes(UID), false, line);
    assertEquals(line.includes(JPEG_B64.slice(0, 12)), false, line);
  }
});
