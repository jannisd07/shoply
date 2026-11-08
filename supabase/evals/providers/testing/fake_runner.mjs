// Stand-in for the Deno runner in provider tests: no Deno, no network.
// Writes the received request to FAKE_RUNNER_REQUEST_OUT (when set), prints
// FAKE_RUNNER_STDOUT verbatim when set, else the prefixed FAKE_RUNNER_RESULT.
import { writeFileSync } from 'node:fs';

const chunks = [];
for await (const chunk of process.stdin) chunks.push(chunk);
const request = Buffer.concat(chunks).toString('utf8');
if (process.env.FAKE_RUNNER_REQUEST_OUT) writeFileSync(process.env.FAKE_RUNNER_REQUEST_OUT, request);
process.stderr.write('🔵 [AI] fake runner log line\n');
if (process.env.FAKE_RUNNER_STDOUT !== undefined) {
  process.stdout.write(process.env.FAKE_RUNNER_STDOUT);
} else {
  process.stdout.write('some log on stdout\n');
  process.stdout.write(`@@AVO_EVAL_RESULT@@ ${process.env.FAKE_RUNNER_RESULT ?? '{"ok":false,"error":"no result"}'}\n`);
}
