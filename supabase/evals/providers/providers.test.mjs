// Offline tests of the promptfoo providers (fake runner, no Deno, no key):
//   node --test supabase/evals/providers/ supabase/evals/categorize/ supabase/evals/avo_injection/
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import BaselineProvider from './baseline_provider.mjs';
import RunnerProvider, { denoInvocation } from './runner_provider.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const FAKE = ['node', path.join(HERE, 'testing/fake_runner.mjs')];
const prices = { input: 1, output: 10, cache_read: 0.1 };

function withRunner(result, fn, stdout) {
  const dir = mkdtempSync(path.join(tmpdir(), 'avo-evals-'));
  const requestFile = path.join(dir, 'request.json');
  const saved = { ...process.env };
  process.env.FAKE_RUNNER_REQUEST_OUT = requestFile;
  if (result !== undefined) process.env.FAKE_RUNNER_RESULT = JSON.stringify(result);
  if (stdout !== undefined) process.env.FAKE_RUNNER_STDOUT = stdout;
  const readRequest = () => JSON.parse(readFileSync(requestFile, 'utf8'));
  return Promise.resolve(fn(readRequest, dir)).finally(() => {
    process.env = saved;
  });
}

const categorizeOk = {
  ok: true,
  mode: 'task',
  status: 200,
  body: {
    result: { items: [{ category_id: 'dairy', confidence: 'high', brand: null }] },
    usage: { input_tokens: 1000, output_tokens: 100, cache_read_input_tokens: 2000 },
  },
  latency_ms: 812,
  requests: [{ model: 'claude-haiku-5-5', tools: [] }],
};

test('categorize sends one item through the runner and maps the answer', () =>
  withRunner(categorizeOk, async (readRequest) => {
    const provider = new RunnerProvider({ id: 'avo-categorize', config: { mode: 'categorize', command: FAKE, prices } });
    const res = await provider.callApi('Milch', { vars: { name: 'Milch', lang: 'de' } });
    assert.deepEqual(readRequest(), {
      mode: 'task',
      task: 'categorize',
      locale: 'de',
      input: { items: [{ name: 'Milch' }] },
    });
    assert.equal(res.error, undefined);
    assert.deepEqual(res.output, categorizeOk.body.result);
    assert.equal(res.latencyMs, 812);
    assert.deepEqual(res.tokenUsage, { prompt: 3000, completion: 100, total: 3100, cached: 2000, numRequests: 1 });
    // (1000 * 1 + 100 * 10 + 2000 * 0.1) / 1e6
    assert.ok(Math.abs(res.cost - 0.0022) < 1e-12);
    assert.deepEqual(res.metadata.requests, categorizeOk.requests);
    assert.equal(provider.id(), 'avo-categorize');
  }));

test('categorize sends a batch from items_json', () =>
  withRunner(categorizeOk, async (readRequest) => {
    const provider = new RunnerProvider({ config: { mode: 'categorize', command: FAKE } });
    const items = [{ name: 'Milch', accepted: ['dairy'] }, { name: 'Brot', accepted: ['bakery'] }];
    await provider.callApi('', { vars: { items_json: JSON.stringify(items), lang: 'en' } });
    assert.deepEqual(readRequest().input, { items: [{ name: 'Milch' }, { name: 'Brot' }] });
    assert.equal(readRequest().locale, 'en');
  }));

test('an HTTP error of the function is a provider error with its code', () =>
  withRunner({ ...categorizeOk, status: 502, body: { code: 'provider_error', message: 'x' } }, async () => {
    const provider = new RunnerProvider({ config: { mode: 'categorize', command: FAKE } });
    const res = await provider.callApi('Milch', { vars: { name: 'Milch' } });
    assert.match(res.error, /502 provider_error/);
  }));

test('a failed run and a missing result line are errors', async () => {
  await withRunner({ ok: false, error: 'ANTHROPIC_API_KEY is not set in this shell' }, async () => {
    const provider = new RunnerProvider({ config: { mode: 'categorize', command: FAKE } });
    const res = await provider.callApi('Milch', { vars: { name: 'Milch' } });
    assert.match(res.error, /ANTHROPIC_API_KEY/);
  });
  await withRunner(undefined, async () => {
    const provider = new RunnerProvider({ config: { mode: 'categorize', command: FAKE } });
    const res = await provider.callApi('Milch', { vars: { name: 'Milch' } });
    assert.match(res.error, /no result line/);
    assert.match(res.error, /fake runner log line/);
  }, 'garbage\n');
});

test('a runner that cannot start or exits at once is an error, not a crash', async () => {
  const missing = new RunnerProvider({ config: { mode: 'categorize', command: ['/nonexistent/deno-evals-binary'] } });
  assert.match((await missing.callApi('Milch', { vars: { name: 'Milch' } })).error, /did not start/);
  const quits = new RunnerProvider({ config: { mode: 'categorize', command: ['node', '-e', 'process.exit(3)'] } });
  assert.match((await quits.callApi('Milch', { vars: { name: 'Milch' } })).error, /no result line \(exit 3\)/);
});

test('a runner that hangs is stopped after the timeout', async () => {
  const provider = new RunnerProvider({
    config: { mode: 'categorize', command: ['node', '-e', 'setTimeout(() => {}, 10000)'], timeoutMs: 300 },
  });
  const res = await provider.callApi('Milch', { vars: { name: 'Milch' } });
  assert.match(res.error, /timed out after 300 ms/);
});

const transcript = {
  ok: true,
  mode: 'avo',
  rounds: [
    { status: 200, first_event_ms: 900, first_text_ms: null, total_ms: 2000, stop_reason: 'tool_use', text: '' },
    { status: 200, first_event_ms: 700, first_text_ms: 700, total_ms: 3000, stop_reason: 'end_turn', text: 'Milch und Brot.' },
  ],
  tool_calls: [{ round: 1, name: 'get_list_contents', input: { list_id: 'list-woche' } }],
  final_text: 'Milch und Brot.',
  all_text: 'Milch und Brot.',
  fixtures_served: ['get_list_contents'],
  served_text: '{"items":[]}',
  injection_tools: ['get_list_contents'],
  hit_round_limit: false,
  error: null,
  usage: { input_tokens: 500, output_tokens: 50, cache_read_input_tokens: 9000 },
  latency_ms: 5100,
  requests: [{ model: 'claude-sonnet-5-5', tools: ['get_lists'] }],
  system_overlap_chars: 12,
};

test('avo loads the world, sends the case and shows text plus tool calls', () =>
  withRunner(transcript, async (readRequest, dir) => {
    const world = { context: { screen: 'home', today: '2026-11-09' }, tool_results: { get_lists: { lists: [] } } };
    writeFileSync(path.join(dir, 'own_list.json'), JSON.stringify(world));
    const provider = new RunnerProvider({ config: { mode: 'avo', command: FAKE, worldsDir: dir, prices, maxRounds: 5 } });
    const res = await provider.callApi('x', { vars: { message: 'Was steht drauf?', world: 'own_list', locale: 'de' } });
    assert.deepEqual(readRequest(), {
      mode: 'avo',
      locale: 'de',
      message: 'Was steht drauf?',
      world,
      max_rounds: 5,
    });
    assert.equal(res.error, undefined);
    assert.equal(res.output, 'Milch und Brot.\n\n[Werkzeuge: get_list_contents {"list_id":"list-woche"}]');
    assert.equal(res.latencyMs, 5100);
    assert.equal(res.metadata.transcript.system_overlap_chars, 12);
    assert.deepEqual(res.metadata.transcript.tool_calls, transcript.tool_calls);
  }));

test('avo without tool calls says so, and a broken conversation is an error', async () => {
  await withRunner({ ...transcript, tool_calls: [] }, async (_, dir) => {
    writeFileSync(path.join(dir, 'w.json'), '{"context":{}}');
    const provider = new RunnerProvider({ config: { mode: 'avo', command: FAKE, worldsDir: dir } });
    const res = await provider.callApi('x', { vars: { message: 'Hi', world: 'w' } });
    assert.equal(res.output, 'Milch und Brot.\n\n[Werkzeuge: keine]');
  });
  await withRunner({ ...transcript, error: { code: 'bad_request', status: 400 } }, async (_, dir) => {
    writeFileSync(path.join(dir, 'w.json'), '{"context":{}}');
    const provider = new RunnerProvider({ config: { mode: 'avo', command: FAKE, worldsDir: dir } });
    const res = await provider.callApi('x', { vars: { message: 'Hi', world: 'w' } });
    assert.match(res.error, /avo_chat failed in round 2: bad_request \(HTTP 400\)/);
  });
  const provider = new RunnerProvider({ config: { mode: 'avo', command: FAKE, worldsDir: tmpdir() } });
  const res = await provider.callApi('x', { vars: { message: 'Hi', world: '../etc/passwd' } });
  assert.match(res.error, /world name/);
});

test('grade passes the rubric prompt and returns the verdict JSON', () =>
  withRunner({ ok: true, mode: 'grade', output: '{"pass":true,"score":1,"reason":"ok"}', usage: { input_tokens: 10, output_tokens: 5, cache_read_input_tokens: 0 }, latency_ms: 40 }, async (readRequest) => {
    const provider = new RunnerProvider({ config: { mode: 'grade', command: FAKE, model: 'claude-opus-5-5', effort: 'medium' } });
    const res = await provider.callApi('[{"role":"user","content":"grade"}]', {});
    assert.deepEqual(readRequest(), {
      mode: 'grade',
      prompt: '[{"role":"user","content":"grade"}]',
      model: 'claude-opus-5-5',
      effort: 'medium',
    });
    assert.equal(res.output, '{"pass":true,"score":1,"reason":"ok"}');
  }));

test('an unknown mode is a configuration error', async () => {
  const provider = new RunnerProvider({ config: { mode: 'nope', command: FAKE } });
  const res = await provider.callApi('x', { vars: {} });
  assert.match(res.error, /mode/);
});

test('the real invocation runs the Deno runner with the function import map and few permissions', () => {
  const plain = denoInvocation({});
  assert.deepEqual(plain.slice(0, 3), ['npx', '-y', 'deno@2']);
  assert.ok(plain.includes('--frozen'));
  assert.ok(plain.includes('--no-prompt'));
  assert.ok(plain.includes('--allow-net=api.anthropic.com'));
  assert.ok(plain.some((arg) => arg.endsWith(path.join('supabase', 'functions', 'ai', 'deno.json'))));
  assert.ok(plain.at(-1).endsWith(path.join('supabase', 'evals', 'runner', 'main.ts')));
  const custom = denoInvocation({ AVO_EVALS_DENO: '/opt/deno/bin/deno', ANTHROPIC_BASE_URL: 'https://proxy.example.test/v1' });
  assert.equal(custom[0], '/opt/deno/bin/deno');
  assert.equal(custom[1], 'run');
  assert.ok(custom.includes('--allow-net=api.anthropic.com,proxy.example.test'));
});

test('baseline answers from the exported file and explains a missing one', async () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'avo-baseline-'));
  const file = path.join(dir, 'baseline.json');
  writeFileSync(file, JSON.stringify({ answers: { Milch: { keywords: 'dairy', local: 'dairy' }, Brot: { keywords: 'other', local: 'bakery' } } }));

  const local = new BaselineProvider({ id: 'baseline-local', config: { variant: 'local', file } });
  const single = await local.callApi('Milch', { vars: { name: 'Milch' } });
  assert.deepEqual(single.output, { items: [{ category_id: 'dairy', confidence: null, brand: null }] });
  assert.equal(single.latencyMs, 0);
  assert.equal(single.cost, 0);

  const keywords = new BaselineProvider({ config: { variant: 'keywords', file } });
  const batch = await keywords.callApi('', { vars: { items_json: JSON.stringify([{ name: 'Milch' }, { name: 'Brot' }]) } });
  assert.deepEqual(batch.output.items.map((item) => item.category_id), ['dairy', 'other']);

  const unknown = await local.callApi('Käse', { vars: { name: 'Käse' } });
  assert.match(unknown.error, /no baseline answer for "Käse"/);

  const missing = new BaselineProvider({ config: { variant: 'local', file: path.join(dir, 'nope.json') } });
  assert.match((await missing.callApi('Milch', { vars: { name: 'Milch' } })).error, /flutter test test\/evals_export_test\.dart/);
});
