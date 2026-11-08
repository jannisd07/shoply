// Request handling of the `ai` function (plan B1.1/B1.2), with every outside
// dependency injected so the contract can be tested without network.
//
// POST {task, v: 1, locale: "de"|"en", input}, Authorization: Bearer <user JWT>
// 200  {result, usage: {input_tokens, output_tokens, cache_read_input_tokens}}
//      or text/event-stream for a streamed task (avo_chat)
// 4xx/5xx {code, message, retry_after_s?} (codes and statuses: _shared/errors.ts)
//
// Order: auth -> body -> version -> task -> input -> ai_enabled -> premium ->
// limit -> Claude client -> quota -> task -> refund (unbilled failure) or
// record. Nothing reaches Claude before the quota is counted, and nothing is
// counted for a request that is invalid or switched off.

import type { ClaudeClient } from "../_shared/claude.ts";
import { toAiError } from "../_shared/claude.ts";
import { preflightResponse } from "../_shared/cors.ts";
import { AiError, type Locale } from "../_shared/errors.ts";
import type { AiFlags } from "../_shared/flags.ts";
import { aiErrorResponse, jsonResponse, parseLocale, readJsonBody } from "../_shared/http.ts";
import { limitFor, type QuotaStore, secondsUntilBerlinMidnight } from "../_shared/quota.ts";
import { requireObject } from "../_shared/validate.ts";
import { findTask, type TaskDefinition, TASKS } from "./tasks/registry.ts";

export const PROTOCOL_VERSION = 1;

export interface HandlerDeps {
  /** The caller's user id; throws AiError (unauthorized / provider_error). */
  authenticate(req: Request): Promise<string>;
  readFlags(): Promise<AiFlags>;
  quota: QuotaStore;
  /** Called once per accepted request, before quota is used. */
  claude(): ClaudeClient;
  tasks?: Readonly<Record<string, TaskDefinition>>;
  now?: () => Date;
}

export function createHandler(deps: HandlerDeps): (req: Request) => Promise<Response> {
  const tasks = deps.tasks ?? TASKS;
  const now = deps.now ?? (() => new Date());

  return async (req) => {
    if (req.method === "OPTIONS") return preflightResponse();
    const started = Date.now();
    let locale: Locale = parseLocale(req.headers.get("accept-language"));
    // Only a name from the registry is ever logged, never what the caller sent.
    let taskName = "unknown";

    try {
      if (req.method !== "POST") throw new AiError("bad_request", "method not allowed");
      const userId = await deps.authenticate(req);

      const body = requireObject(await readJsonBody(req), "body");
      locale = parseLocale(body.locale, locale);
      if (body.v !== PROTOCOL_VERSION) throw new AiError("bad_request", "unsupported protocol version");
      const task = findTask(tasks, body.task);
      taskName = body.task as string;
      const input = task.parse(requireObject(body.input, "input"));

      const flags = await deps.readFlags();
      if (!flags.aiEnabled) throw new AiError("ai_disabled", "kill switch is off");
      const isPro = await deps.quota.isPro(userId);
      const limit = limitFor(flags.limits, isPro ? "pro" : "free", taskName);
      // A missing or zero limit is a configuration state, not a used-up day.
      if (limit <= 0) throw new AiError("ai_disabled", "no limit configured for this task");
      const claude = deps.claude();

      const amount = task.amount(input);
      if (!(await deps.quota.consume(userId, taskName, amount, limit))) {
        throw new AiError("quota_exceeded", "daily limit reached", {
          retryAfterS: secondsUntilBerlinMidnight(now()),
        });
      }

      let output;
      try {
        output = await task.run({ userId, locale, input, claude, isPro });
      } catch (err) {
        const failure = toAiError(err);
        if (failure.refundable) await deps.quota.refund(userId, taskName, amount);
        throw failure;
      }

      if (output instanceof Response) {
        console.log(`🔵 [AI] ${taskName} stream started after ${Date.now() - started} ms`);
        return output;
      }
      await deps.quota.record(userId, taskName, output.usage);
      const { input_tokens, output_tokens, cache_read_input_tokens } = output.usage;
      console.log(
        `✅ [AI] ${taskName} 200 in ${Date.now() - started} ms ` +
          `(units ${amount}, in ${input_tokens}, out ${output_tokens}, cache ${cache_read_input_tokens})`,
      );
      return jsonResponse({ result: output.result, usage: output.usage });
    } catch (err) {
      const failure = toAiError(err);
      const detail = failure.code === "provider_error" || failure.code === "timeout" ? `: ${failure.message}` : "";
      console.warn(`⚠️ [AI] ${taskName} ${failure.status} ${failure.code} after ${Date.now() - started} ms${detail}`);
      return aiErrorResponse(failure, locale);
    }
  };
}
