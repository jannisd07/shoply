// HTTP helpers for the `ai` function: body limit, JSON and error responses,
// and the SSE stream used by streamed tasks (avo_chat).

import { toAiError } from "./claude.ts";
import { CORS_HEADERS } from "./cors.ts";
import { AiError, errorBody, type Locale } from "./errors.ts";

/** Plan B1.1: request bodies up to 6 MB (a 5 MB base64 photo plus JSON). */
export const MAX_BODY_BYTES = 6 * 1024 * 1024;

export function jsonResponse(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json", ...headers },
  });
}

export function aiErrorResponse(err: AiError, locale: Locale): Response {
  const headers: Record<string, string> = {};
  if (err.retryAfterS !== undefined) headers["Retry-After"] = String(err.retryAfterS);
  return jsonResponse(errorBody(err, locale), err.status, headers);
}

/** Reads at most `maxBytes` and parses JSON; anything else is bad_request. */
export async function readJsonBody(req: Request, maxBytes = MAX_BODY_BYTES): Promise<unknown> {
  const declared = Number(req.headers.get("content-length") ?? "");
  if (Number.isFinite(declared) && declared > maxBytes) throw new AiError("bad_request", "body too large");
  if (!req.body) throw new AiError("bad_request", "empty body");

  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      throw new AiError("bad_request", "body too large");
    }
    chunks.push(value);
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    throw new AiError("bad_request", "body is not JSON");
  }
}

/** "de"/"en" from a body field or an Accept-Language header. */
export function parseLocale(value: unknown, fallback: Locale = "de"): Locale {
  if (typeof value !== "string") return fallback;
  const tag = value.trim().toLowerCase();
  if (tag.startsWith("en")) return "en";
  if (tag.startsWith("de")) return "de";
  return fallback;
}

/** Events of a streamed task; `done` is sent by sseResponse itself. */
export type SseEvent = "text" | "message" | "error";
export type SseSend = (event: SseEvent, data: unknown) => void;

/**
 * Streams `event: <name>\ndata: <json>\n\n` frames. A thrown error becomes an
 * `error` event `{code, message}`; the stream always ends with `done`.
 *
 * `signal` aborts when the app hangs up: forward it to the upstream Claude
 * stream (`stream.abort()`) so it stops generating and billing. Writes after
 * the hang-up are dropped.
 */
export function sseResponse(
  run: (send: SseSend, signal: AbortSignal) => Promise<void> | void,
  locale: Locale,
): Response {
  const encoder = new TextEncoder();
  const hangUp = new AbortController();
  let open = true;
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      const write = (event: string, data: unknown) => {
        if (!open) return;
        try {
          controller.enqueue(encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`));
        } catch {
          open = false;
        }
      };
      (async () => {
        try {
          await run(write, hangUp.signal);
        } catch (err) {
          write("error", errorBody(toAiError(err), locale));
        }
        write("done", {});
        if (open) {
          open = false;
          controller.close();
        }
      })().catch(() => {
        console.error("❌ [AI] stream writer failed");
      });
    },
    cancel() {
      open = false;
      hangUp.abort();
    },
  });
  return new Response(stream, {
    headers: { ...CORS_HEADERS, "Content-Type": "text/event-stream", "Cache-Control": "no-cache" },
  });
}
