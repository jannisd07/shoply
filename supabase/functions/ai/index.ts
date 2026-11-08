// Supabase Edge Function `ai`: the app's only way to Claude (plan B1).
// Protocol, error codes and the order of checks: handler.ts. Tasks:
// tasks/registry.ts. Daily quota: migration 20261108000100_b_ai_usage.sql.
//
// Secrets: ANTHROPIC_API_KEY (set by the owner). SUPABASE_URL,
// SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are injected by Supabase.
// The service role is used only for app_flags and the quota RPCs.
//
// Deploy (owner only, after an explicit yes): supabase functions deploy ai
// Local checks, from supabase/functions (the import map lives in ai/deno.json):
//   npx -y deno@2 check --config ai/deno.json ai/*.ts ai/tasks/*.ts _shared/*.ts
//   npx -y deno@2 test --config ai/deno.json --allow-env --allow-net=none ai _shared

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import { getUserId } from "../_shared/auth.ts";
import { createClaudeClient } from "../_shared/claude.ts";
import { createFlagsReader, supabaseFlagRows } from "../_shared/flags.ts";
import { createSupabaseQuotaStore } from "../_shared/quota.ts";
import { createHandler } from "./handler.ts";

/** Builds on first use, so a missing secret becomes a provider_error, not a crash at boot. */
function once<T>(make: () => T): () => T {
  let made: { value: T } | undefined;
  return () => (made ??= { value: make() }).value;
}

const admin = once((): SupabaseClient =>
  createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "", {
    auth: { persistSession: false, autoRefreshToken: false },
  })
);

Deno.serve(createHandler({
  authenticate: (req) => getUserId(req),
  readFlags: createFlagsReader(() => supabaseFlagRows(admin())()),
  quota: createSupabaseQuotaStore({ rpc: (fn, args) => admin().rpc(fn, args) }),
  claude: once(createClaudeClient),
}));
