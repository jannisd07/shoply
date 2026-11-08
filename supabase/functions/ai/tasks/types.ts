// Shapes shared by every task of the `ai` function (contract for the task
// agents, plan B1.1). A task module exports:
//   parseInput(raw)    validates `input` before any quota is used (bad_request)
//   quotaAmount(input) optional, units counted against the daily limit (default 1)
//   handler(ctx)       the work; TaskResult, or a text/event-stream Response
//                      from sseResponse for a streamed task (avo_chat)

import type { AiUsage, ClaudeClient } from "../../_shared/claude.ts";
import type { Locale } from "../../_shared/errors.ts";

/** The request's `input` object, before a task has validated it. */
export type TaskInput = Record<string, unknown>;

export interface TaskContext<I = TaskInput> {
  userId: string;
  locale: Locale;
  input: I;
  claude: ClaudeClient;
  isPro: boolean;
}

export interface TaskResult {
  result: object;
  usage: AiUsage;
}

export type TaskHandler<I = TaskInput> = (ctx: TaskContext<I>) => Promise<TaskResult | Response>;
