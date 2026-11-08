// Task `avo_chat` (plan B1.6): Avo's chat on claude-sonnet-5-5, streamed as
// text/event-stream. The app runs the tools; this server never executes one.
//
// Input {messages, context, tools_variant}
//   messages       The conversation, append-only, 1-60 entries. It starts with
//                  a user text turn and ends with the new user turn. User turns
//                  carry text, or tool_result blocks first and text after them
//                  (pending tool results and a new question share one turn).
//                  Assistant turns are stored exactly as the `message` event
//                  returned them (thinking blocks unchanged). Context messages
//                  the server returned are stored too; no other system message
//                  is accepted.
//                  Size: historyChars (all text, thinking text, redacted
//                  thinking data, the name and JSON input of every tool call,
//                  tool result text and context messages; not signatures) at
//                  most MAX_HISTORY_CHARS; one tool result at most
//                  MAX_TOOL_RESULT_CHARS, the tool results of one turn together
//                  at most MAX_TURN_TOOL_RESULT_CHARS. Anything larger is
//                  bad_request before any quota is used; the app trims old
//                  turns (cutting before a user text turn) to stay below.
//   context        {today: "YYYY-MM-DD", screen?, list_id? (an id: letters,
//                  digits, - and _, up to 64), list_name? (accepted, never sent
//                  to Claude), weekday? (ignored, derived from today), modules?:
//                  {offers, calories, meal_plan, cost_split}, consent_health
//                  ("Ernährung und Allergien"), consent_body ("Kalorien, Gewicht
//                  und Ziele"), allergies?, diet?}. A missing consent is false.
//                  Allergies and diet reach Claude only with consent_health;
//                  the server clips them to 30 entries of 60 characters.
//                  Taking a consent back ends the conversation: a history whose
//                  context message shared what is now withheld is bad_request
//                  (earlier tool results may hold that data), so the app starts
//                  a new conversation when the person switches a consent off.
//   tools_variant  "full" | "no_offers" (offers kill switch only), fixed for a
//                  conversation. avo_tools.ts also says what the app checks
//                  before it runs a tool; above all, the propose_delete card
//                  shows the app's own stored name for target_id, never the
//                  model's label.
//
// The context belongs to a question, not to a tool round: it is appended as a
// system message after the last user message only when that turn has text and
// the context changed since the last stored one (a system message right after
// tool results reads like a prompt injection to Sonnet 5.5).
//
// SSE events
//   text     {delta}   visible text as it is written
//   message  {content, stop_reason, usage, context_message, tool_calls}
//            content          the assistant turn to store, verbatim
//            context_message  {role: "system", content} or null; store it
//                             right before the assistant turn
//            tool_calls       [{id, name, input, error}] in content order. Run a
//                             call with `input`; if `error` is set, don't run it
//                             and answer with an is_error tool_result carrying
//                             the error text.
//            stop_reason      "tool_use": send all tool_results in one user
//                             turn, then call again with the longer history.
//   error    {code, message}  e.g. refused, timeout, provider_error; discard the
//                             partial turn
//   done     {}
// A failure before the stream starts (rate limit, provider down, timeout to
// the first event) is a JSON error with its HTTP status, and the quota unit
// comes back when nothing was billed.
//
// The app commits a turn only on `message`: its new user turn, then
// context_message if set, then the assistant turn. On `error` it commits
// nothing and may resend the same request. It keeps locale and tools variant
// fixed for a conversation; if it trims old turns, it cuts before a user text
// turn. A changed prefix costs the thinking blocks after it (drop_block), never
// a 400.
//
// Quota: every request counts one avo_chat unit, tool rounds included, so a
// question with two tool rounds costs three. Whether the owner's daily limits
// (Free 3, Pro 60) mean requests or questions is open (owner question);
// free tool rounds would need server-side state, because a client can forge a
// tool round. When a tool round fails with quota_exceeded, the app keeps the
// tool results it ran and sends them in front of the person's next question
// (one user turn: tool_results, then text).
//
// Usage: the task records the tokens of every answer, also a failed or
// refused one, through ctx.recordUsage (quota.record). handler.ts does not
// pass it yet; until it does, the usage of streamed answers is only logged.

import type Anthropic from "@anthropic-ai/sdk";

import {
  type AvoContext,
  avoSystem,
  parseContext,
  readContextMessage,
  renderContextMessage,
} from "../../_shared/avo_system.ts";
import { avoTools, checkToolInput, TOOLS_VARIANTS, type ToolsVariant } from "../../_shared/avo_tools.ts";
import {
  type AiUsage,
  type BetaStreamParams,
  FALLBACK_BETA,
  SONNET,
  THINKING_BINDING_BETA,
  toAiError,
  type UsageLike,
  usageOf,
} from "../../_shared/claude.ts";
import { AiError, type Locale } from "../../_shared/errors.ts";
import { sseResponse } from "../../_shared/http.ts";
import { MAX_TEXT_CHARS, requireArray, requireObject } from "../../_shared/validate.ts";
import type { TaskContext, TaskInput } from "./types.ts";

/** Plan B1.1: an Avo history has at most 60 messages. */
export const MAX_MESSAGES = 60;
export const MAX_TOKENS = 16_000;
/** Kap. 20 §2.5: first word within 8 s, the whole answer within 60 s. */
export const FIRST_EVENT_TIMEOUT_MS = 8_000;
export const TOTAL_TIMEOUT_MS = 60_000;
/** One tool result (a list with its items as JSON) stays below this. */
export const MAX_TOOL_RESULT_CHARS = 40_000;
/** All tool results of one user turn together. */
export const MAX_TURN_TOOL_RESULT_CHARS = 60_000;
/**
 * The whole history as historyChars counts it (about 50k tokens). Without it
 * 60 messages could fill most of the 1M context window, and the top-level
 * cache_control would write all of it to the cache on every request.
 */
export const MAX_HISTORY_CHARS = 200_000;
/** Blocks of an assistant turn; a user turn may answer that many tool calls and add text. */
export const MAX_ASSISTANT_BLOCKS = 128;
const MAX_USER_BLOCKS = MAX_ASSISTANT_BLOCKS + 8;

type MessageParam = Anthropic.Beta.BetaMessageParam;
type SystemMessage = Anthropic.Beta.BetaSystemMessageParam;
type UserBlock = Anthropic.Beta.BetaTextBlockParam | Anthropic.Beta.BetaToolResultBlockParam;
type ContentBlock = Anthropic.Beta.BetaContentBlock;
type StreamEvent = Anthropic.Beta.BetaRawMessageStreamEvent;

export interface AvoChatInput {
  messages: MessageParam[];
  context: AvoContext;
  toolsVariant: ToolsVariant;
}

export interface AvoChatContext extends TaskContext<AvoChatInput> {
  /** Adds the tokens of the answer to today's usage (quota.record). */
  recordUsage?(usage: AiUsage): Promise<void>;
}

function bad(message: string): AiError {
  return new AiError("bad_request", message);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

// ---------------------------------------------------------------------------
// Input

function checkText(value: unknown, field: string, max: number): string {
  if (typeof value !== "string") throw bad(`${field}: expected a string`);
  if (value.trim().length === 0) throw bad(`${field}: empty text`);
  if (value.length > max) throw bad(`${field}: longer than ${max} characters`);
  return value;
}

function noCacheControl(block: Record<string, unknown>, field: string) {
  // The server owns the cache breakpoints (at most 4 per request).
  if (Object.hasOwn(block, "cache_control")) throw bad(`${field}: cache_control is set by the server`);
}

function parseToolResultContent(value: unknown, field: string): string | Anthropic.Beta.BetaTextBlockParam[] {
  if (typeof value === "string") return checkText(value, field, MAX_TOOL_RESULT_CHARS);
  const blocks = requireArray(value, field, { min: 1, max: 20 });
  let total = 0;
  return blocks.map((entry, i) => {
    const block = requireObject(entry, `${field}[${i}]`);
    noCacheControl(block, `${field}[${i}]`);
    if (block.type !== "text") throw bad(`${field}[${i}]: tool results carry text only`);
    const text = checkText(block.text, `${field}[${i}].text`, MAX_TOOL_RESULT_CHARS);
    total += text.length;
    if (total > MAX_TOOL_RESULT_CHARS) throw bad(`${field}: longer than ${MAX_TOOL_RESULT_CHARS} characters`);
    return { type: "text" as const, text };
  });
}

function toolResultChars(content: Anthropic.Beta.BetaToolResultBlockParam["content"]): number {
  if (typeof content === "string") return content.length;
  return (content ?? []).reduce((sum, block) => sum + (block.type === "text" ? block.text.length : 0), 0);
}

/** User turns are rebuilt from the known fields, so they render the same every time. */
function parseUserContent(value: unknown, field: string): string | UserBlock[] {
  if (typeof value === "string") return checkText(value, field, MAX_TEXT_CHARS);
  const blocks = requireArray(value, field, { min: 1, max: MAX_USER_BLOCKS });
  let seenText = false;
  let toolResultTotal = 0;
  return blocks.map((entry, i): UserBlock => {
    const at = `${field}[${i}]`;
    const block = requireObject(entry, at);
    noCacheControl(block, at);
    if (block.type === "text") {
      seenText = true;
      return { type: "text", text: checkText(block.text, `${at}.text`, MAX_TEXT_CHARS) };
    }
    if (block.type === "tool_result") {
      if (seenText) throw bad(`${at}: tool results come before any text`);
      if (typeof block.tool_use_id !== "string" || block.tool_use_id === "") {
        throw bad(`${at}.tool_use_id: expected a string`);
      }
      if (block.is_error !== undefined && typeof block.is_error !== "boolean") {
        throw bad(`${at}.is_error: expected true or false`);
      }
      const result: Anthropic.Beta.BetaToolResultBlockParam = {
        type: "tool_result",
        tool_use_id: block.tool_use_id,
        content: parseToolResultContent(block.content, `${at}.content`),
      };
      if (block.is_error === true) result.is_error = true;
      toolResultTotal += toolResultChars(result.content);
      if (toolResultTotal > MAX_TURN_TOOL_RESULT_CHARS) {
        throw bad(`${field}: tool results longer than ${MAX_TURN_TOOL_RESULT_CHARS} characters together`);
      }
      return result;
    }
    throw bad(`${at}.type: user turns carry text and tool_result blocks only`);
  });
}

/** Assistant turns pass through unchanged (thinking signatures depend on it); only their shape is checked. */
function parseAssistantContent(value: unknown, field: string): { content: unknown[]; toolUseIds: string[] } {
  const blocks = requireArray(value, field, { min: 1, max: MAX_ASSISTANT_BLOCKS });
  const toolUseIds: string[] = [];
  blocks.forEach((entry, i) => {
    const at = `${field}[${i}]`;
    const block = requireObject(entry, at);
    noCacheControl(block, at);
    switch (block.type) {
      case "text":
        if (typeof block.text !== "string") throw bad(`${at}.text: expected a string`);
        break;
      case "thinking":
        if (typeof block.thinking !== "string" || typeof block.signature !== "string") {
          throw bad(`${at}: thinking blocks need thinking and signature`);
        }
        break;
      case "redacted_thinking":
        if (typeof block.data !== "string") throw bad(`${at}.data: expected a string`);
        break;
      case "tool_use":
        if (typeof block.id !== "string" || block.id === "" || typeof block.name !== "string") {
          throw bad(`${at}: tool_use blocks need id and name`);
        }
        if (!isRecord(block.input)) throw bad(`${at}.input: expected an object`);
        if (toolUseIds.includes(block.id)) throw bad(`${at}.id: duplicate tool_use id`);
        toolUseIds.push(block.id);
        break;
      default:
        throw bad(`${at}.type: unexpected block type in an assistant turn`);
    }
  });
  return { content: blocks, toolUseIds };
}

/** A stored context message, unchanged; it must not have shared what the person now withholds. */
function parseContextHistoryMessage(msg: Record<string, unknown>, field: string, now: AvoContext): SystemMessage {
  if (Object.keys(msg).some((key) => key !== "role" && key !== "content")) {
    throw bad(`${field}: system messages carry role and content only`);
  }
  if (typeof msg.content !== "string") throw bad(`${field}.content: expected a string`);
  const { context: stored } = readContextMessage(msg.content);
  if ((stored.consentHealth && !now.consentHealth) || (stored.consentBody && !now.consentBody)) {
    throw bad(`${field}: a consent was taken back since this message; start a new conversation`);
  }
  return { role: "system", content: msg.content };
}

/**
 * The size the history budget counts: every text, thinking text, redacted
 * thinking data, tool name and JSON input, tool result text and context
 * message. Signatures are left out: Claude checks them, so a forged one costs
 * nothing.
 */
export function historyChars(messages: readonly MessageParam[]): number {
  let total = 0;
  for (const message of messages) {
    if (typeof message.content === "string") {
      total += message.content.length;
      continue;
    }
    for (const block of message.content ?? []) {
      switch (block.type) {
        case "text":
          total += block.text.length;
          break;
        case "thinking":
          total += block.thinking.length;
          break;
        case "redacted_thinking":
          total += block.data.length;
          break;
        case "tool_use":
          total += block.name.length + JSON.stringify(block.input).length;
          break;
        case "tool_result":
          total += toolResultChars(block.content);
          break;
      }
    }
  }
  return total;
}

function sameIds(a: string[], b: string[]): boolean {
  if (a.length !== b.length) return false;
  const sortedB = [...b].sort();
  return [...a].sort().every((id, i) => id === sortedB[i]);
}

/**
 * Checks the conversation grammar the API needs: user first and last, an
 * assistant turn after every user or context message, context messages only
 * right after a user turn, and every tool_use answered by exactly one
 * tool_result in the next user turn.
 */
function parseMessages(value: unknown, context: AvoContext): MessageParam[] {
  const raw = requireArray(value, "messages", { min: 1, max: MAX_MESSAGES });
  const out: MessageParam[] = [];
  let previous: "user" | "assistant" | "system" | undefined;
  let openToolUses: string[] = [];

  raw.forEach((entry, i) => {
    const field = `messages[${i}]`;
    const msg = requireObject(entry, field);
    switch (msg.role) {
      case "user": {
        if (previous === "user") throw bad(`${field}: two user turns in a row`);
        if (previous === "system") throw bad(`${field}: a context message must be followed by an assistant turn`);
        const content = parseUserContent(msg.content, `${field}.content`);
        const answered = typeof content === "string"
          ? []
          : content.flatMap((block) => block.type === "tool_result" ? [block.tool_use_id] : []);
        if (!sameIds(answered, openToolUses)) {
          throw bad(`${field}: tool results must answer exactly the tool calls of the turn before`);
        }
        openToolUses = [];
        out.push({ role: "user", content });
        break;
      }
      case "assistant": {
        if (previous !== "user" && previous !== "system") {
          throw bad(`${field}: an assistant turn must follow a user turn`);
        }
        const { content, toolUseIds } = parseAssistantContent(msg.content, `${field}.content`);
        openToolUses = toolUseIds;
        out.push({ role: "assistant", content: content as Anthropic.Beta.BetaContentBlockParam[] });
        break;
      }
      case "system":
        if (previous !== "user") throw bad(`${field}: a context message must follow a user turn`);
        out.push(parseContextHistoryMessage(msg, field, context));
        break;
      default:
        throw bad(`${field}.role: expected user, assistant or system`);
    }
    previous = msg.role;
  });

  if (previous !== "user") throw bad("messages: the last message must be the new user turn");
  if (historyChars(out) > MAX_HISTORY_CHARS) {
    throw bad(`messages: longer than ${MAX_HISTORY_CHARS} characters; trim old turns`);
  }
  return out;
}

function parseVariant(value: unknown): ToolsVariant {
  if (typeof value !== "string" || !(TOOLS_VARIANTS as readonly string[]).includes(value)) {
    throw bad("tools_variant: expected full or no_offers");
  }
  return value as ToolsVariant;
}

export function parseInput(raw: TaskInput): AvoChatInput {
  const context = parseContext(raw.context);
  const toolsVariant = parseVariant(raw.tools_variant);
  return { messages: parseMessages(raw.messages, context), context, toolsVariant };
}

// ---------------------------------------------------------------------------
// Request

export interface AvoRequest {
  params: BetaStreamParams;
  /** The context message appended after the last user turn; null for a tool-results-only turn or an unchanged context. */
  contextMessage: SystemMessage | null;
}

function latestContextText(messages: MessageParam[]): string | undefined {
  for (let i = messages.length - 1; i >= 0; i--) {
    const message = messages[i];
    if (message.role === "system") return typeof message.content === "string" ? message.content : undefined;
  }
  return undefined;
}

function hasText(message: MessageParam): boolean {
  return typeof message.content === "string" || (message.content ?? []).some((block) => block.type === "text");
}

/**
 * The Claude request: frozen system prompt and tools (cached prefix), the
 * history as sent, and the app context as a trailing system message when the
 * last user turn asks something (has text) and the context changed since the
 * last one in the history.
 */
export function buildAvoRequest(input: AvoChatInput, locale: Locale): AvoRequest {
  const rendered = renderContextMessage(input.context, locale);
  const asks = input.messages.length > 0 && hasText(input.messages[input.messages.length - 1]);
  const contextMessage: SystemMessage | null = asks && latestContextText(input.messages) !== rendered
    ? { role: "system", content: rendered }
    : null;
  const messages = contextMessage ? [...input.messages, contextMessage] : [...input.messages];
  return {
    contextMessage,
    params: {
      model: SONNET,
      max_tokens: MAX_TOKENS,
      system: avoSystem(locale, input.toolsVariant),
      tools: avoTools(input.toolsVariant),
      messages,
      thinking: { type: "adaptive", block_binding: { prefix_mismatch_behavior: "drop_block" } },
      output_config: { effort: "low" },
      cache_control: { type: "ephemeral" },
      fallbacks: "default",
      betas: [FALLBACK_BETA, THINKING_BINDING_BETA],
    },
  };
}

// ---------------------------------------------------------------------------
// Answer

const ECHO_TYPES = new Set(["text", "thinking", "redacted_thinking", "tool_use"]);

/**
 * The assistant turn as the app stores it. After a mid-output fallback only
 * the text from before the last `fallback` block stays (the declined model's
 * thinking and tool calls must not be sent back); the fallback markers and
 * empty text blocks go, and so would a block type the history check does not
 * know. Without a fallback the blocks are the same objects as from Claude.
 */
export function echoableContent(content: readonly ContentBlock[]): ContentBlock[] {
  const boundary = content.findLastIndex((block) => block.type === "fallback");
  const out: ContentBlock[] = [];
  content.forEach((block, i) => {
    if (block.type === "fallback") return;
    if (i < boundary && block.type !== "text") return;
    if (!ECHO_TYPES.has(block.type)) {
      console.warn(`⚠️ [AI] avo_chat left out a ${block.type} block`);
      return;
    }
    if (block.type === "text" && block.text === "") return;
    out.push(block);
  });
  return out;
}

export interface AvoToolCall {
  id: string;
  name: string;
  /** The checked input to run the tool with; null when it must not run. */
  input: Record<string, unknown> | null;
  /** Why it must not run; send it back as an is_error tool_result. */
  error: string | null;
}

/** Every tool call of an answer with its checked input. After max_tokens none may run. */
export function toolCallsOf(
  content: readonly ContentBlock[],
  stopReason: string | null,
  variant: ToolsVariant,
): AvoToolCall[] {
  const calls: AvoToolCall[] = [];
  for (const block of content) {
    if (block.type !== "tool_use") continue;
    if (stopReason === "max_tokens") {
      calls.push({
        id: block.id,
        name: block.name,
        input: null,
        error: "The answer reached max_tokens before this tool call was complete, so it was not run. Call it again.",
      });
      continue;
    }
    const check = checkToolInput(block.name, block.input, variant);
    calls.push(
      check.ok
        ? { id: block.id, name: block.name, input: check.input, error: null }
        : { id: block.id, name: block.name, input: null, error: check.error },
    );
  }
  return calls;
}

/** Token counts from the stream events, so a cut-off answer is still counted. */
class UsageTracker {
  usage: UsageLike | undefined;

  track(event: StreamEvent) {
    if (event.type === "message_start") {
      const u = event.message.usage;
      this.usage = {
        input_tokens: u.input_tokens,
        output_tokens: u.output_tokens,
        cache_creation_input_tokens: u.cache_creation_input_tokens,
        cache_read_input_tokens: u.cache_read_input_tokens,
      };
    } else if (event.type === "message_delta" && this.usage) {
      const u = event.usage;
      this.usage.output_tokens = u.output_tokens;
      if (u.input_tokens != null) this.usage.input_tokens = u.input_tokens;
      if (u.cache_creation_input_tokens != null) this.usage.cache_creation_input_tokens = u.cache_creation_input_tokens;
      if (u.cache_read_input_tokens != null) this.usage.cache_read_input_tokens = u.cache_read_input_tokens;
    }
  }
}

async function recordUsage(ctx: AvoChatContext, usage: UsageLike | undefined) {
  if (!usage) return;
  if (!ctx.recordUsage) {
    const u = usageOf(usage);
    console.warn(
      `⚠️ [AI] avo_chat usage not recorded (no recordUsage): in ${u.input_tokens}, out ${u.output_tokens}, ` +
        `cache ${u.cache_read_input_tokens}`,
    );
    return;
  }
  try {
    await ctx.recordUsage(usageOf(usage));
  } catch {
    console.warn("⚠️ [AI] avo_chat usage record failed");
  }
}

function droppedThinkingBlocks(message: Anthropic.Beta.BetaMessage): number {
  const transformations = (message as { input_transformations?: unknown }).input_transformations;
  if (!Array.isArray(transformations)) return 0;
  return transformations.filter((t) => isRecord(t) && t.type === "thinking_dropped").length;
}

/** The first stream event, or timeout: it shows the request was accepted and Claude is answering. */
async function firstEvent(
  events: AsyncIterator<StreamEvent>,
  abort: () => void,
  timeoutMs: number,
): Promise<IteratorResult<StreamEvent>> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const deadline = new Promise<never>((_resolve, reject) => {
    timer = setTimeout(() => {
      reject(new AiError("timeout", "no first event from the provider"));
      abort();
    }, timeoutMs);
  });
  try {
    return await Promise.race([events.next(), deadline]);
  } finally {
    clearTimeout(timer);
  }
}

export interface AvoHandlerOptions {
  firstEventTimeoutMs?: number;
  totalTimeoutMs?: number;
}

export function makeAvoHandler(options: AvoHandlerOptions = {}): (ctx: AvoChatContext) => Promise<Response> {
  const firstEventMs = options.firstEventTimeoutMs ?? FIRST_EVENT_TIMEOUT_MS;
  const totalMs = options.totalTimeoutMs ?? TOTAL_TIMEOUT_MS;

  return async (ctx) => {
    const started = Date.now();
    const { params, contextMessage } = buildAvoRequest(ctx.input, ctx.locale);
    const stream = ctx.claude.beta.messages.stream(params, { timeout: totalMs, maxRetries: 0 });
    const events = stream[Symbol.asyncIterator]();
    let timedOut = false;
    const total = setTimeout(() => {
      timedOut = true;
      stream.abort();
    }, totalMs);

    // Until the first event nothing has been streamed, so a failure here is a
    // plain error response and handler.ts refunds what was not billed.
    let first: IteratorResult<StreamEvent>;
    try {
      first = await firstEvent(events, () => stream.abort(), firstEventMs);
    } catch (err) {
      clearTimeout(total);
      throw toAiError(err);
    }

    const tracker = new UsageTracker();
    return sseResponse(async (send, hangUp) => {
      const onHangUp = () => stream.abort();
      hangUp.addEventListener("abort", onHangUp, { once: true });
      try {
        for (let next = first; !next.done; next = await events.next()) {
          const event = next.value;
          tracker.track(event);
          if (event.type === "content_block_delta" && event.delta.type === "text_delta" && event.delta.text !== "") {
            send("text", { delta: event.delta.text });
          }
        }
        const final = await stream.finalMessage();
        tracker.usage = final.usage;
        const dropped = droppedThinkingBlocks(final);
        if (dropped > 0) console.warn(`⚠️ [AI] avo_chat dropped ${dropped} thinking block(s) after a history change`);
        // A refusal can cut a tool call off mid-input; nothing of it is kept.
        if (final.stop_reason === "refusal") throw new AiError("refused", "model refused");

        const content = echoableContent(final.content);
        const usage = usageOf(final.usage);
        send("message", {
          content,
          stop_reason: final.stop_reason,
          usage,
          context_message: contextMessage,
          tool_calls: toolCallsOf(content, final.stop_reason, ctx.input.toolsVariant),
        });
        console.log(
          `✅ [AI] avo_chat ${final.stop_reason} in ${Date.now() - started} ms ` +
            `(in ${usage.input_tokens}, out ${usage.output_tokens}, cache ${usage.cache_read_input_tokens})`,
        );
      } catch (err) {
        if (timedOut) throw new AiError("timeout", "the answer took too long");
        throw err;
      } finally {
        clearTimeout(total);
        hangUp.removeEventListener("abort", onHangUp);
        await recordUsage(ctx, tracker.usage);
      }
    }, ctx.locale);
  };
}

export const handler = makeAvoHandler();
