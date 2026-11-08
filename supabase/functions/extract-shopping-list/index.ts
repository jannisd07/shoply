// Supabase Edge Function `extract-shopping-list`: kept for app builds from
// before the `ai` function. It reads the photographed list from the private
// `list-imports` bucket and runs the same core as the `ai` task `list_import`
// (Claude, _shared/list_import_core.ts), with the same daily quota and kill
// switch. New builds call `ai` with task `list_import` instead.
//
// Contract of the old builds (ListImportService), unchanged:
//   POST /functions/v1/extract-shopping-list, Authorization: Bearer <user JWT>
//   Body: {"image_path": "<uid>/<uuid>.jpg", "locale": "de-DE"}
//   200:  {"items": [{name, quantity, unit, confidence}], "unparsed_lines": []}
//   err:  {"code": "<machine_code>", "message": "<localized>"}
//         codes: no_items_found, unreadable_image, rate_limited, provider_error,
//         timeout, unauthorized, bad_request
//
// Privacy (DSGVO): the upload is deleted after every request that passed the
// path check, success or failure. Neither the photo nor the path is logged.
//
// Secrets: ANTHROPIC_API_KEY (set by the owner). SUPABASE_URL,
// SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are injected by Supabase.
// Needs the migrations 20261108000000_b_app_flags.sql and
// 20261108000100_b_ai_usage.sql (quota RPCs) before it is deployed.
// Deploy (owner only, after an explicit yes): supabase functions deploy extract-shopping-list

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import { getUserId } from "../_shared/auth.ts";
import { createClaudeClient } from "../_shared/claude.ts";
import { createFlagsReader, supabaseFlagRows } from "../_shared/flags.ts";
import { createLegacyExtractHandler, LEGACY_BUCKET } from "../_shared/list_import_core.ts";
import { createSupabaseQuotaStore } from "../_shared/quota.ts";

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

Deno.serve(createLegacyExtractHandler({
  authenticate: (req) => getUserId(req),
  readFlags: createFlagsReader(() => supabaseFlagRows(admin())()),
  quota: createSupabaseQuotaStore({ rpc: (fn, args) => admin().rpc(fn, args) }),
  claude: once(createClaudeClient),
  storage: {
    async download(path) {
      const { data, error } = await admin().storage.from(LEGACY_BUCKET).download(path);
      if (error || !data) return null;
      return new Uint8Array(await data.arrayBuffer());
    },
    async remove(path) {
      try {
        const { error } = await admin().storage.from(LEGACY_BUCKET).remove([path]);
        if (!error) return;
      } catch {
        // Reported below.
      }
      console.warn("⚠️ [LIST_IMPORT] could not delete an upload");
    },
  },
}));
