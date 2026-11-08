// Test double for the Claude client. Used only by *_test.ts files; the edge
// function never imports it. No network: every call is answered from a script.

import type Anthropic from "@anthropic-ai/sdk";

import type { ClaudeBetaStream, ClaudeClient } from "../claude.ts";

export interface RecordedCall {
  api: "messages" | "beta";
  body: Record<string, unknown>;
  options?: Anthropic.RequestOptions;
}

export type ScriptedReply =
  | Anthropic.Message
  | Error
  | ((body: Record<string, unknown>) => Anthropic.Message | Error);

/** Answers each call with the next scripted reply; the last reply repeats. */
export class FakeClaude implements ClaudeClient {
  readonly calls: RecordedCall[] = [];
  readonly #replies: ScriptedReply[];

  constructor(...replies: ScriptedReply[]) {
    this.#replies = replies;
  }

  readonly messages = {
    create: (body: Anthropic.MessageCreateParamsNonStreaming, options?: Anthropic.RequestOptions) =>
      this.#answer("messages", body as unknown as Record<string, unknown>, options),
  };

  readonly beta = {
    messages: {
      create: (
        body: Anthropic.Beta.MessageCreateParamsNonStreaming,
        options?: Anthropic.RequestOptions,
      ) =>
        this.#answer("beta", body as unknown as Record<string, unknown>, options) as unknown as Promise<
          Anthropic.Beta.BetaMessage
        >,
      stream: (): ClaudeBetaStream => {
        throw new Error("FakeClaude: streaming is not scripted");
      },
    },
  };

  #answer(
    api: RecordedCall["api"],
    body: Record<string, unknown>,
    options?: Anthropic.RequestOptions,
  ): Promise<Anthropic.Message> {
    this.calls.push({ api, body, options });
    const index = Math.min(this.calls.length - 1, this.#replies.length - 1);
    const scripted = this.#replies[index];
    if (scripted === undefined) return Promise.reject(new Error("FakeClaude: no reply scripted"));
    const reply = typeof scripted === "function" ? scripted(body) : scripted;
    return reply instanceof Error ? Promise.reject(reply) : Promise.resolve(reply);
  }
}

export interface FakeMessageOptions {
  /** Serialized into a single text block. */
  json?: unknown;
  text?: string;
  /** Raw blocks; wins over json/text. */
  content?: Array<Record<string, unknown>>;
  stop_reason?: Anthropic.StopReason;
  usage?: Partial<Anthropic.Usage>;
}

export function fakeMessage(opts: FakeMessageOptions = {}): Anthropic.Message {
  const text = opts.text ?? (opts.json === undefined ? "" : JSON.stringify(opts.json));
  const content = opts.content ?? [{ type: "text", text, citations: null }];
  return {
    id: "msg_fake",
    type: "message",
    role: "assistant",
    model: "claude-haiku-5-5",
    container: null,
    diagnostics: null,
    stop_details: null,
    stop_reason: opts.stop_reason ?? "end_turn",
    stop_sequence: null,
    content,
    usage: {
      cache_creation: null,
      cache_creation_input_tokens: 0,
      cache_read_input_tokens: 0,
      inference_geo: null,
      input_tokens: 10,
      output_tokens: 5,
      output_tokens_details: null,
      server_tool_use: null,
      service_tier: "standard",
      speed: null,
      ...opts.usage,
    },
  } as unknown as Anthropic.Message;
}
