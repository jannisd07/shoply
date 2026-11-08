// Daily AI quota per person and task (plan B1.2). The counting itself is the
// atomic RPC `ai_consume_quota_b`, with `ai_refund_quota_b` and
// `ai_record_usage_b` beside it (migration 20261108000100_b_ai_usage.sql);
// only the service role may execute them. A day is a calendar day in
// Europe/Berlin.

import type { AiUsage } from "./claude.ts";
import { AiError } from "./errors.ts";

export type Tier = "free" | "pro";

/** `app_flags.ai_limits.value`: calls (categorize: items) per task and day. */
export interface AiLimits {
  free: Record<string, number>;
  pro: Record<string, number>;
}

/**
 * Missing, negative or non-numeric limits count as 0. The handler answers 0
 * with ai_disabled (a configuration state), never with quota_exceeded.
 */
export function limitFor(limits: AiLimits, tier: Tier, task: string): number {
  const table = limits[tier];
  if (!Object.hasOwn(table, task)) return 0;
  const value = table[task];
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) return 0;
  return Math.floor(value);
}

const BERLIN_PARTS = new Intl.DateTimeFormat("en-US", {
  timeZone: "Europe/Berlin",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
  hourCycle: "h23",
});

function berlinWallClock(date: Date) {
  const parts: Record<string, number> = {};
  for (const part of BERLIN_PARTS.formatToParts(date)) {
    if (part.type !== "literal") parts[part.type] = Number(part.value);
  }
  return parts as { year: number; month: number; day: number; hour: number; minute: number; second: number };
}

/** Berlin's offset from UTC at `date`, in ms (+1 h in winter, +2 h in summer). */
function berlinOffsetMs(date: Date): number {
  const p = berlinWallClock(date);
  const wallAsUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second);
  return wallAsUtc - Math.floor(date.getTime() / 1000) * 1000;
}

/** Seconds until the quota resets (next midnight in Berlin), at least 1. */
export function secondsUntilBerlinMidnight(now: Date): number {
  const today = berlinWallClock(now);
  const nextMidnightWall = Date.UTC(today.year, today.month - 1, today.day + 1);
  let instant = nextMidnightWall - berlinOffsetMs(now);
  // Second pass picks up a DST switch between now and midnight.
  instant = nextMidnightWall - berlinOffsetMs(new Date(instant));
  return Math.max(1, Math.ceil((instant - now.getTime()) / 1000));
}

export interface QuotaStore {
  isPro(userId: string): Promise<boolean>;
  /** True when `amount` more fits under `limit` today; counts it atomically. */
  consume(userId: string, task: string, amount: number, limit: number): Promise<boolean>;
  /** Gives back calls nobody billed. Best effort: never throws. */
  refund(userId: string, task: string, amount: number): Promise<void>;
  /** Adds the token counts of a finished call. Best effort: never throws. */
  record(userId: string, task: string, usage: AiUsage): Promise<void>;
}

/** The one method of the service-role Supabase client the store needs. */
export interface RpcClient {
  rpc(fn: string, args: Record<string, unknown>): PromiseLike<{ data: unknown; error: { message: string } | null }>;
}

/** Runs an RPC; a failure (error result or rejection) comes back as `ok: false`. */
async function callRpc(
  db: RpcClient,
  fn: string,
  args: Record<string, unknown>,
): Promise<{ ok: true; data: unknown } | { ok: false }> {
  try {
    const { data, error } = await db.rpc(fn, args);
    return error ? { ok: false } : { ok: true, data };
  } catch {
    return { ok: false };
  }
}

/**
 * Quota store on the service-role client. Consume fails closed (no answer
 * from the database, no AI call); premium falls back to the free limits;
 * refund and record only log, so a billed answer still reaches the person and
 * the real error code of a failed call is not replaced. Logs carry no ids.
 */
export function createSupabaseQuotaStore(db: RpcClient): QuotaStore {
  return {
    async isPro(userId) {
      const res = await callRpc(db, "is_premium_user", { user_uuid: userId });
      if (!res.ok) {
        console.warn("⚠️ [AI] premium status unreadable, using free limits");
        return false;
      }
      return res.data === true;
    },
    async consume(userId, task, amount, limit) {
      const res = await callRpc(db, "ai_consume_quota_b", {
        p_user: userId,
        p_task: task,
        p_amount: amount,
        p_limit: limit,
      });
      if (!res.ok) throw new AiError("provider_error", "quota rpc failed");
      return res.data === true;
    },
    async refund(userId, task, amount) {
      const res = await callRpc(db, "ai_refund_quota_b", { p_user: userId, p_task: task, p_amount: amount });
      if (!res.ok) console.warn(`⚠️ [AI] quota refund failed (${task}, ${amount})`);
    },
    async record(userId, task, usage) {
      const res = await callRpc(db, "ai_record_usage_b", {
        p_user: userId,
        p_task: task,
        p_in: usage.input_tokens,
        p_out: usage.output_tokens,
        p_cache: usage.cache_read_input_tokens,
      });
      if (!res.ok) console.warn(`⚠️ [AI] usage record failed (${task})`);
    },
  };
}
