// promptfoo provider for the Avo evals (supabase/evals/README.md).
//
// Every call starts the Deno runner (supabase/evals/runner/main.ts), which
// runs the real code of the `ai` edge function: its prompts, schemas, tools
// and request settings. Nothing is copied here. Modes (config.mode):
//   categorize  vars.name or vars.items_json -> task `categorize`
//   avo         vars.message + vars.world    -> task `avo_chat` with the tool loop
//   grade       promptfoo's rubric prompt    -> grader for llm-rubric
//
// The key comes from ANTHROPIC_API_KEY in the shell that runs promptfoo; this
// file never reads, logs or stores it.
import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = path.resolve(HERE, '../../..');
const RUNNER = path.join(REPO_ROOT, 'supabase/evals/runner/main.ts');
const DENO_CONFIG = path.join(REPO_ROOT, 'supabase/functions/ai/deno.json');
const DEFAULT_WORLDS = path.join(REPO_ROOT, 'supabase/evals/avo_injection/worlds');
const RESULT_PREFIX = '@@AVO_EVAL_RESULT@@ ';

const DEFAULT_TIMEOUT_MS = { categorize: 60_000, avo: 600_000, grade: 180_000 };

/**
 * The Deno command. AVO_EVALS_DENO=/path/to/deno skips npx (faster per test);
 * the network is limited to the Anthropic API host (plus ANTHROPIC_BASE_URL).
 */
export function denoInvocation(env = process.env) {
  const deno = env.AVO_EVALS_DENO ? [env.AVO_EVALS_DENO] : ['npx', '-y', 'deno@2'];
  const hosts = ['api.anthropic.com'];
  if (env.ANTHROPIC_BASE_URL) {
    try {
      const { host } = new URL(env.ANTHROPIC_BASE_URL);
      if (host && !hosts.includes(host)) hosts.push(host);
    } catch {
      // An invalid base URL fails inside the SDK with a clear message.
    }
  }
  return [
    ...deno,
    'run',
    '--config',
    DENO_CONFIG,
    '--frozen',
    '--no-prompt',
    '--allow-env',
    `--allow-net=${hosts.join(',')}`,
    RUNNER,
  ];
}

function tail(text, max = 600) {
  const trimmed = text.trim();
  return trimmed.length > max ? `…${trimmed.slice(-max)}` : trimmed;
}

/** Runs one request; resolves to the runner's result object or {ok:false, error}. */
export function runRunner(request, { command, timeoutMs }) {
  return new Promise((resolve) => {
    const [cmd, ...args] = command;
    const child = spawn(cmd, args, { cwd: REPO_ROOT, env: process.env, stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    let settled = false;
    const finish = (value) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve(value);
    };
    const timer = setTimeout(() => {
      child.kill('SIGKILL');
      finish({ ok: false, error: `runner timed out after ${timeoutMs} ms` });
    }, timeoutMs);
    child.stdout.setEncoding('utf8').on('data', (chunk) => (stdout += chunk));
    child.stderr.setEncoding('utf8').on('data', (chunk) => (stderr += chunk));
    child.on('error', (err) => finish({ ok: false, error: `runner did not start (${cmd}): ${err.message}` }));
    // A runner that exits early closes stdin; the result line (or its absence) tells what happened.
    child.stdin.on('error', () => {});
    child.on('close', (code) => {
      const line = stdout.split('\n').reverse().find((l) => l.startsWith(RESULT_PREFIX));
      if (!line) {
        finish({ ok: false, error: `runner gave no result line (exit ${code}). stderr: ${tail(stderr)}` });
        return;
      }
      try {
        finish(JSON.parse(line.slice(RESULT_PREFIX.length)));
      } catch {
        finish({ ok: false, error: 'runner result line is not JSON' });
      }
    });
    child.stdin.end(JSON.stringify(request));
  });
}

function tokenUsageOf(usage) {
  const input = usage?.input_tokens ?? 0;
  const output = usage?.output_tokens ?? 0;
  const cached = usage?.cache_read_input_tokens ?? 0;
  return { prompt: input + cached, completion: output, total: input + cached + output, cached, numRequests: 1 };
}

/** USD from $/MTok prices; `input_tokens` already includes cache writes (billed at 1.25x, counted as 1x). */
function costOf(usage, prices) {
  if (!prices || !usage) return undefined;
  return (
    ((usage.input_tokens ?? 0) * (prices.input ?? 0) +
      (usage.output_tokens ?? 0) * (prices.output ?? 0) +
      (usage.cache_read_input_tokens ?? 0) * (prices.cache_read ?? 0)) /
    1e6
  );
}

function namesOf(vars) {
  if (typeof vars.items_json === 'string' && vars.items_json.trim() !== '') {
    const items = JSON.parse(vars.items_json);
    return items.map((item) => (typeof item === 'string' ? item : item.name));
  }
  if (typeof vars.name === 'string') return [vars.name];
  throw new Error('categorize needs vars.name or vars.items_json');
}

function loadWorld(worldsDir, name) {
  if (typeof name !== 'string' || !/^[a-z0-9_]+$/.test(name)) {
    throw new Error(`world name must be [a-z0-9_]+, got ${JSON.stringify(name)}`);
  }
  return JSON.parse(readFileSync(path.join(worldsDir, `${name}.json`), 'utf8'));
}

/** What the person would read, plus a line with Avo's tool calls (for the grader and the promptfoo view). */
export function transcriptView(transcript) {
  const calls = transcript.tool_calls ?? [];
  const tools = calls.length === 0 ? 'keine' : calls.map((c) => `${c.name} ${JSON.stringify(c.input ?? {})}`).join('; ');
  return `${transcript.all_text ?? ''}\n\n[Werkzeuge: ${tools}]`;
}

export default class AvoRunnerProvider {
  constructor(options = {}) {
    this.providerId = options.id ?? 'avo-runner';
    this.config = options.config ?? {};
  }

  id() {
    return this.providerId;
  }

  async callApi(prompt, context = {}) {
    const vars = context.vars ?? {};
    const mode = this.config.mode;
    const command = this.config.command ?? denoInvocation();
    const timeoutMs = this.config.timeoutMs ?? DEFAULT_TIMEOUT_MS[mode] ?? 120_000;
    let request;
    try {
      if (mode === 'categorize') {
        request = {
          mode: 'task',
          task: 'categorize',
          locale: vars.lang ?? 'de',
          input: { items: namesOf(vars).map((name) => ({ name })) },
        };
      } else if (mode === 'avo') {
        request = {
          mode: 'avo',
          locale: vars.locale ?? 'de',
          message: vars.message,
          world: loadWorld(this.config.worldsDir ?? DEFAULT_WORLDS, vars.world),
        };
        if (this.config.maxRounds) request.max_rounds = this.config.maxRounds;
      } else if (mode === 'grade') {
        request = { mode: 'grade', prompt, model: this.config.model, effort: this.config.effort };
      } else {
        return { error: `config.mode must be categorize, avo or grade, got ${JSON.stringify(mode)}` };
      }
    } catch (err) {
      return { error: err.message };
    }

    const result = await runRunner(request, { command, timeoutMs });
    if (!result.ok) return { error: result.error };

    if (mode === 'categorize') {
      if (result.status !== 200) {
        return { error: `ai function answered ${result.status} ${result.body?.code ?? ''}`.trim(), latencyMs: result.latency_ms };
      }
      return {
        output: result.body.result,
        latencyMs: result.latency_ms,
        tokenUsage: tokenUsageOf(result.body.usage),
        cost: costOf(result.body.usage, this.config.prices),
        metadata: { requests: result.requests },
      };
    }

    if (mode === 'avo') {
      const { ok: _ok, mode: _mode, ...transcript } = result;
      if (transcript.error) {
        return {
          error: `avo_chat failed in round ${transcript.rounds.length}: ${transcript.error.code} (HTTP ${transcript.error.status})`,
          metadata: { transcript },
        };
      }
      return {
        output: transcriptView(transcript),
        latencyMs: transcript.latency_ms,
        tokenUsage: tokenUsageOf(transcript.usage),
        cost: costOf(transcript.usage, this.config.prices),
        metadata: { transcript },
      };
    }

    return {
      output: result.output,
      latencyMs: result.latency_ms,
      tokenUsage: tokenUsageOf(result.usage),
      cost: costOf(result.usage, this.config.prices),
    };
  }
}
