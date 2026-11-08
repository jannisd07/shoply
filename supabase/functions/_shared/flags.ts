// Remote flags for the `ai` function, read from `public.app_flags`
// (migration 20261108000000_b_app_flags.sql): the kill switch `ai_enabled`
// (column `enabled`) and the daily limits `ai_limits` (column `value`).

import type { SupabaseClient } from "@supabase/supabase-js";

import { AiError } from "./errors.ts";
import type { AiLimits } from "./quota.ts";

export const AI_FLAG_KEYS = ["ai_enabled", "ai_limits"] as const;

export interface FlagRow {
  key: string;
  enabled: boolean | null;
  value: unknown;
}

export interface AiFlags {
  /** False only when the row says so; a missing row keeps AI on. */
  aiEnabled: boolean;
  limits: AiLimits;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function numbersOf(value: unknown): Record<string, number> {
  const out: Record<string, number> = {};
  if (!isRecord(value)) return out;
  for (const [key, entry] of Object.entries(value)) {
    if (typeof entry === "number" && Number.isFinite(entry)) out[key] = entry;
  }
  return out;
}

export function parseAiFlags(rows: readonly FlagRow[]): AiFlags {
  const byKey = new Map(rows.map((row) => [row.key, row]));
  const limits = byKey.get("ai_limits")?.value;
  return {
    aiEnabled: byKey.get("ai_enabled")?.enabled !== false,
    limits: {
      free: numbersOf(isRecord(limits) ? limits.free : undefined),
      pro: numbersOf(isRecord(limits) ? limits.pro : undefined),
    },
  };
}

export interface FlagsReaderOptions {
  ttlMs?: number;
  now?: () => number;
}

/**
 * Cached reader (default 60 s per warm instance). A failed refresh keeps the
 * last good value; without one it fails closed with provider_error.
 */
export function createFlagsReader(
  fetchRows: () => Promise<FlagRow[]>,
  options: FlagsReaderOptions = {},
): () => Promise<AiFlags> {
  const ttlMs = options.ttlMs ?? 60_000;
  const now = options.now ?? Date.now;
  let cached: { flags: AiFlags; at: number } | undefined;

  return async () => {
    if (cached && now() - cached.at < ttlMs) return cached.flags;
    try {
      const flags = parseAiFlags(await fetchRows());
      cached = { flags, at: now() };
      return flags;
    } catch {
      if (cached) {
        console.warn("⚠️ [AI] app_flags refresh failed, keeping the last value");
        return cached.flags;
      }
      throw new AiError("provider_error", "app_flags unreadable");
    }
  };
}

export function supabaseFlagRows(db: SupabaseClient): () => Promise<FlagRow[]> {
  return async () => {
    const { data, error } = await db.from("app_flags").select("key, enabled, value").in("key", [...AI_FLAG_KEYS]);
    if (error) throw new Error("app_flags read failed");
    return (data ?? []) as FlagRow[];
  };
}
