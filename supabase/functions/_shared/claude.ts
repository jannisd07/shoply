// The only way from Avo to Claude (plan B1.1). The key comes from the
// ANTHROPIC_API_KEY secret and never leaves the server.
//
// Model rules (owner, 07.11.2026):
// - Haiku 5.5 (categories, recommendations, nutrition): thinking disabled,
//   effort "low", answer via output_config.format (JSON schema), no
//   `fallbacks` (Haiku has no server-side fallback).
// - Sonnet 5.5 (Avo chat, photos): adaptive thinking, effort "low" for chat and
//   "medium" for photos, `fallbacks: "default"` with the fallback beta.
// - Never temperature/top_p/top_k, never prefill, never forced tool_choice.
// - Read blocks by `type`; check stop_reason "refusal" before content.

import Anthropic from "@anthropic-ai/sdk";

import { AiError } from "./errors.ts";

export const HAIKU = "claude-haiku-5-5";
export const SONNET = "claude-sonnet-5-5";
export type ClaudeModel = typeof HAIKU | typeof SONNET;

/** Beta header for `fallbacks: "default"` (Sonnet only). */
export const FALLBACK_BETA = "server-side-fallback-2026-07-01";
/** Beta header for `thinking.block_binding` (Avo chat). */
export const THINKING_BINDING_BETA = "thinking-binding-controls-2026-08-01";

export type Effort = "low" | "medium";

/** Token usage as the client sees it. `input_tokens` includes cache writes. */
export interface AiUsage {
  input_tokens: number;
  output_tokens: number;
  cache_read_input_tokens: number;
}

/** Request body of `client.beta.messages.stream` (the SDK does not re-export its name). */
export type BetaStreamParams = Parameters<Anthropic["beta"]["messages"]["stream"]>[0];

/** The streaming surface Avo needs from the SDK's BetaMessageStream. */
export interface ClaudeBetaStream extends AsyncIterable<Anthropic.Beta.BetaRawMessageStreamEvent> {
  finalMessage(): Promise<Anthropic.Beta.BetaMessage>;
  abort(): void;
}

/**
 * The part of the Anthropic client the tasks use. `new Anthropic()` fits it
 * as is; tests pass a fake (see testing/fake_claude.ts).
 */
export interface ClaudeClient {
  messages: {
    create(
      body: Anthropic.MessageCreateParamsNonStreaming,
      options?: Anthropic.RequestOptions,
    ): PromiseLike<Anthropic.Message>;
  };
  beta: {
    messages: {
      create(
        body: Anthropic.Beta.MessageCreateParamsNonStreaming,
        options?: Anthropic.RequestOptions,
      ): PromiseLike<Anthropic.Beta.BetaMessage>;
      stream(
        body: BetaStreamParams,
        options?: Anthropic.RequestOptions,
      ): ClaudeBetaStream;
    };
  };
}

export function createClaudeClient(): ClaudeClient {
  // Without the secret the SDK constructor throws a plain error, which the log
  // used to show only as "unexpected error" (S6 finding P1, 09.11.2026).
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) throw new AiError("provider_error", "ANTHROPIC_API_KEY secret is not set");
  return new Anthropic({ apiKey, maxRetries: 1 });
}

/**
 * Error chain from the SDK's typed errors, most specific first. `refundable`
 * marks failures the provider did not bill, so the caller gives the quota
 * back: every HTTP error status (Anthropic bills no 4xx or 5xx) and a lost
 * connection. Timeouts and aborts may have been billed and stay counted.
 */
export function toAiError(err: unknown): AiError {
  if (err instanceof AiError) return err;
  if (err instanceof Anthropic.APIUserAbortError) return new AiError("timeout", "request aborted");
  if (err instanceof Anthropic.APIConnectionTimeoutError) return new AiError("timeout", "provider timeout");
  if (err instanceof Anthropic.APIConnectionError) {
    return new AiError("provider_error", "provider unreachable", { refundable: true });
  }
  if (err instanceof Anthropic.RateLimitError) {
    return new AiError("rate_limited", "provider rate limit", {
      refundable: true,
      retryAfterS: retryAfterSeconds(err.headers),
    });
  }
  if (err instanceof Anthropic.APIError) {
    const status = err.status;
    if (typeof status === "number") {
      return new AiError("provider_error", `provider status ${status}`, { refundable: true });
    }
    return new AiError("provider_error", "provider error without status");
  }
  if (err instanceof DOMException && (err.name === "TimeoutError" || err.name === "AbortError")) {
    return new AiError("timeout", err.name);
  }
  return new AiError("provider_error", "unexpected error");
}

function retryAfterSeconds(headers: Headers | undefined): number | undefined {
  const raw = headers?.get("retry-after");
  if (!raw) return undefined;
  const seconds = Number(raw);
  if (!Number.isFinite(seconds)) return undefined;
  return Math.min(3600, Math.max(1, Math.ceil(seconds)));
}

export interface UsageLike {
  input_tokens: number;
  output_tokens: number;
  cache_creation_input_tokens?: number | null;
  cache_read_input_tokens?: number | null;
}

export function usageOf(usage: UsageLike): AiUsage {
  return {
    input_tokens: usage.input_tokens + (usage.cache_creation_input_tokens ?? 0),
    output_tokens: usage.output_tokens,
    cache_read_input_tokens: usage.cache_read_input_tokens ?? 0,
  };
}

function isTextBlock(block: { type: string }): block is { type: "text"; text: string } {
  return block.type === "text" && typeof (block as { text?: unknown }).text === "string";
}

/** Joins all `text` blocks; thinking, fallback and other blocks are skipped. */
export function textOf(content: ReadonlyArray<{ type: string }>): string {
  let text = "";
  for (const block of content) {
    if (isTextBlock(block)) text += block.text;
  }
  return text;
}

export type JsonSchema = Record<string, unknown>;

export interface StructuredOptions {
  client: ClaudeClient;
  maxTokens: number;
  /** Hard limit for the whole call; there is no SDK retry inside it. */
  timeoutMs: number;
  /** Sonnet only (default "medium"); Haiku always runs at "low". */
  effort?: Effort;
  /** Aborts the call when the app hangs up. */
  signal?: AbortSignal;
}

export interface StructuredResult<T> {
  data: T;
  usage: AiUsage;
}

/**
 * One request with a fixed, cached system prompt and a JSON-schema answer.
 * Throws AiError: refused, provider_error, rate_limited or timeout.
 */
export async function callStructured<T>(
  model: ClaudeModel,
  system: string,
  userContent: string | Anthropic.ContentBlockParam[],
  schema: JsonSchema,
  opts: StructuredOptions,
): Promise<StructuredResult<T>> {
  const systemBlocks: Anthropic.TextBlockParam[] = [
    { type: "text", text: system, cache_control: { type: "ephemeral" } },
  ];
  const format = { type: "json_schema" as const, schema };
  const requestOptions: Anthropic.RequestOptions = {
    timeout: opts.timeoutMs,
    maxRetries: 0,
    signal: opts.signal,
  };

  let message: { stop_reason: string | null; content: ReadonlyArray<{ type: string }>; usage: UsageLike };
  try {
    if (model === HAIKU) {
      message = await opts.client.messages.create({
        model,
        max_tokens: opts.maxTokens,
        system: systemBlocks,
        messages: [{ role: "user", content: userContent }],
        thinking: { type: "disabled" },
        output_config: { effort: "low", format },
      }, requestOptions);
    } else {
      message = await opts.client.beta.messages.create({
        model,
        max_tokens: opts.maxTokens,
        system: systemBlocks,
        messages: [{ role: "user", content: userContent as Anthropic.Beta.BetaContentBlockParam[] | string }],
        thinking: { type: "adaptive" },
        output_config: { effort: opts.effort ?? "medium", format },
        fallbacks: "default",
        betas: [FALLBACK_BETA],
      }, requestOptions);
    }
  } catch (err) {
    throw toAiError(err);
  }

  if (message.stop_reason === "refusal") throw new AiError("refused", "model refused");
  if (message.stop_reason !== "end_turn" && message.stop_reason !== "stop_sequence") {
    throw new AiError("provider_error", `structured answer stopped with ${message.stop_reason}`);
  }
  let data: T;
  try {
    data = JSON.parse(textOf(message.content)) as T;
  } catch {
    throw new AiError("provider_error", "structured answer is not JSON");
  }
  return { data, usage: usageOf(message.usage) };
}
