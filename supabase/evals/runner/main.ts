// CLI of the eval runner, started once per test by the promptfoo providers
// (supabase/evals/providers/runner_provider.mjs). Reads one JSON request from
// stdin (see RunRequest in lib.ts) and writes one line `RESULT_PREFIX + JSON`
// to stdout. Calls Claude with the key in ANTHROPIC_API_KEY, like the edge
// function. From the repo root:
//   echo '{"mode":"task","task":"categorize","locale":"de","input":{"items":[{"name":"Milch"}]}}' | \
//     npx -y deno@2 run --config supabase/functions/ai/deno.json --frozen --no-prompt \
//       --allow-env --allow-net=api.anthropic.com supabase/evals/runner/main.ts

import { createClaudeClient } from "../../functions/_shared/claude.ts";
import { dispatch, RESULT_PREFIX, type RunRequest, type RunResult } from "./lib.ts";

// The handler logs to the console; keep stdout for the result line.
console.log = console.error;
console.info = console.error;
console.warn = console.error;
console.debug = console.error;

async function readRequest(): Promise<RunRequest> {
  const raw = await new Response(Deno.stdin.readable).text();
  return JSON.parse(raw) as RunRequest;
}

let result: RunResult;
try {
  const request = await readRequest();
  if (!Deno.env.get("ANTHROPIC_API_KEY")) {
    result = { ok: false, error: "ANTHROPIC_API_KEY is not set in this shell" };
  } else {
    result = await dispatch(request, { claude: createClaudeClient() });
  }
} catch (err) {
  result = { ok: false, error: err instanceof Error ? err.message : String(err) };
}
await Deno.stdout.write(new TextEncoder().encode(`${RESULT_PREFIX}${JSON.stringify(result)}\n`));
