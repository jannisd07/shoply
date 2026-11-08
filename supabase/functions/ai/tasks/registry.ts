// All tasks of the `ai` function. The keys are the `task` values of the
// request and the keys of `app_flags.ai_limits.free/pro`. A task module
// exports parseInput, handler and optionally quotaAmount (see types.ts).

import { AiError } from "../../_shared/errors.ts";
import * as avoChat from "./avo_chat.ts";
import * as categorize from "./categorize.ts";
import * as listImport from "./list_import.ts";
import * as mealPhoto from "./meal_photo.ts";
import * as nutritionEstimate from "./nutrition_estimate.ts";
import * as recommend from "./recommend.ts";
import type { TaskContext, TaskInput, TaskResult } from "./types.ts";

/** A task with its input type erased, as the handler runs it. */
export interface TaskDefinition {
  parse(raw: TaskInput): unknown;
  /** Units counted against the daily limit. */
  amount(input: unknown): number;
  run(ctx: TaskContext<unknown>): Promise<TaskResult | Response>;
}

interface TaskModule<I> {
  parseInput(raw: TaskInput): I;
  quotaAmount?(input: I): number;
  handler(ctx: TaskContext<I>): Promise<TaskResult | Response>;
}

function define<I>(module: TaskModule<I>): TaskDefinition {
  return {
    parse: (raw) => module.parseInput(raw),
    amount: (input) => module.quotaAmount?.(input as I) ?? 1,
    run: (ctx) => module.handler(ctx as TaskContext<I>),
  };
}

export const TASKS: Readonly<Record<string, TaskDefinition>> = Object.freeze({
  categorize: define(categorize),
  recommend: define(recommend),
  nutrition_estimate: define(nutritionEstimate),
  avo_chat: define(avoChat),
  meal_photo: define(mealPhoto),
  list_import: define(listImport),
});

/** Own-property lookup, so "toString" or "__proto__" are unknown tasks too. */
export function findTask(tasks: Readonly<Record<string, TaskDefinition>>, name: unknown): TaskDefinition {
  if (typeof name !== "string" || !Object.hasOwn(tasks, name)) throw new AiError("bad_request", "unknown task");
  return tasks[name];
}
