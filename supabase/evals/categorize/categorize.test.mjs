// Calibration of the categorize assertions, the test generator and the
// comparison gate (offline): node --test 'supabase/evals/**/*.test.mjs'
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';

import { load } from '../../../.claude/skills/promptfoo-provider-setup/scripts/vendor/js-yaml.mjs';
import { batchAccuracy, categoryAccepted } from './assertions.mjs';
import { compare } from './compare.mjs';
import generateTests, { BATCH_SIZE } from './tests.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const dataset = JSON.parse(readFileSync(path.join(HERE, 'dataset.json'), 'utf8')).items;
const answer = (category_id, brand = null) => ({ items: [{ category_id, confidence: 'high', brand }] });

test('categoryAccepted passes the expected id and an accepted alternative', () => {
  const vars = { accepted: 'staples,meat_fish', brand: '' };
  assert.equal(categoryAccepted(answer('staples'), { vars }).pass, true);
  assert.equal(categoryAccepted(answer('meat_fish'), { vars }).pass, true);
  assert.equal(categoryAccepted(JSON.stringify(answer('staples')), { vars }).pass, true);
});

test('categoryAccepted fails a wrong id, a missing answer and extra answers', () => {
  const vars = { accepted: 'dairy', brand: '' };
  const wrong = categoryAccepted(answer('frozen'), { vars });
  assert.equal(wrong.pass, false);
  assert.match(wrong.reason, /frozen/);
  assert.equal(categoryAccepted({ items: [] }, { vars }).pass, false);
  assert.equal(categoryAccepted('not json', { vars }).pass, false);
  assert.equal(categoryAccepted({ items: [answer('dairy').items[0], answer('dairy').items[0]] }, { vars }).pass, false);
});

test('brand is a named score only, it never fails the category', () => {
  const vars = { accepted: 'snacks', brand: 'Milka' };
  const right = categoryAccepted(answer('snacks', 'Milka'), { vars });
  assert.equal(right.pass, true);
  assert.deepEqual(right.namedScores, { category: 1, brand: 1 });
  const loose = categoryAccepted(answer('snacks', "milka "), { vars: { accepted: 'snacks', brand: "Beck's" } });
  assert.equal(loose.namedScores.brand, 0);
  assert.equal(categoryAccepted(answer('beverages', 'Becks'), { vars: { accepted: 'beverages', brand: "Beck's" } }).namedScores.brand, 1);
  const none = categoryAccepted(answer('snacks', null), { vars });
  assert.equal(none.pass, true);
  assert.equal(none.namedScores.brand, 0);
  assert.deepEqual(categoryAccepted(answer('dairy'), { vars: { accepted: 'dairy', brand: '' } }).namedScores, { category: 1 });
});

test('batchAccuracy passes at the threshold and fails below it or on a count mismatch', () => {
  const items = [
    { name: 'Milch', accepted: ['dairy'] },
    { name: 'Brot', accepted: ['bakery'] },
    { name: 'Thunfisch in der Dose', accepted: ['staples', 'meat_fish'] },
    { name: 'Chips', accepted: ['snacks'] },
  ];
  const vars = { items_json: JSON.stringify(items) };
  const output = (ids) => ({ items: ids.map((category_id) => ({ category_id, confidence: 'high', brand: null })) });
  assert.equal(batchAccuracy(output(['dairy', 'bakery', 'meat_fish', 'snacks']), { vars, config: { minAccuracy: 1 } }).pass, true);
  const threeOfFour = batchAccuracy(output(['dairy', 'bakery', 'meat_fish', 'other']), { vars, config: { minAccuracy: 0.75 } });
  assert.equal(threeOfFour.pass, true);
  assert.equal(threeOfFour.score, 0.75);
  const below = batchAccuracy(output(['dairy', 'other', 'meat_fish', 'other']), { vars, config: { minAccuracy: 0.75 } });
  assert.equal(below.pass, false);
  assert.match(below.reason, /Brot/);
  assert.equal(batchAccuracy(output(['dairy']), { vars, config: { minAccuracy: 0 } }).pass, false);
});

test('the generator makes one test per entry plus batches of the production size', async () => {
  const tests = await generateTests();
  const items = tests.filter((t) => t.metadata.kind === 'item');
  const batches = tests.filter((t) => t.metadata.kind === 'batch');
  assert.equal(items.length, dataset.length);
  assert.equal(BATCH_SIZE, 60);
  assert.equal(batches.length, Math.ceil(dataset.length / BATCH_SIZE));
  const batched = batches.flatMap((t) => JSON.parse(t.vars.items_json).map((i) => i.name));
  assert.deepEqual([...batched].sort(), dataset.map((i) => i.name).sort());
  for (const t of tests) {
    for (const value of Object.values(t.vars)) assert.equal(typeof value, 'string', 'promptfoo expands array vars');
  }
  const tuna = items.find((t) => t.vars.name === 'Thunfisch in der Dose');
  assert.equal(tuna.vars.accepted, 'staples,meat_fish');
  assert.ok(tuna.assert.some((a) => a.type === 'latency' && a.threshold === 8000));
  assert.ok(tuna.metadata.tags.includes('ambiguous'));
  assert.deepEqual(await generateTests(), tests, 'deterministic');
});

test('the config runs the real task and both baselines, labelled as compare.mjs expects', () => {
  const config = load(readFileSync(path.join(HERE, 'promptfooconfig.yaml'), 'utf8'));
  const labels = config.providers.map((p) => p.label);
  assert.deepEqual(labels, ['avo-categorize', 'baseline-keywords', 'baseline-local']);
  assert.equal(config.providers[0].config.mode, 'categorize');
  assert.deepEqual(config.providers.slice(1).map((p) => p.config.variant), ['keywords', 'local']);
  assert.equal(config.tests, 'file://tests.mjs');
});

function fakeResult(label, name, accepted, got, extra = {}) {
  return {
    provider: { id: `file://x/${label}`, label },
    testCase: { vars: { name, accepted: accepted.join(',') }, metadata: { kind: 'item', tags: extra.tags ?? ['plain'] } },
    response: got === undefined ? { error: 'boom' } : { output: answer(got) },
    error: got === undefined ? 'boom' : undefined,
  };
}

test('compare reports accuracy per provider and tag and gates on the baselines', () => {
  const rows = [
    fakeResult('claude-haiku', 'Milch', ['dairy'], 'dairy'),
    fakeResult('claude-haiku', 'Gurkn', ['fruits_vegetables'], 'fruits_vegetables', { tags: ['typo'] }),
    fakeResult('baseline-local', 'Milch', ['dairy'], 'dairy'),
    fakeResult('baseline-local', 'Gurkn', ['fruits_vegetables'], 'other', { tags: ['typo'] }),
  ];
  const report = compare({ results: { results: rows } }, { candidate: 'claude-haiku', expectedItems: 2 });
  assert.equal(report.ok, true);
  assert.equal(report.providers['claude-haiku'].accuracy, 1);
  assert.equal(report.providers['baseline-local'].accuracy, 0.5);
  assert.equal(report.providers['baseline-local'].tags.typo.accuracy, 0);
  assert.deepEqual(report.betterThanCandidate, []);

  const worse = compare(
    { results: { results: [fakeResult('claude-haiku', 'Milch', ['dairy'], 'frozen'), fakeResult('baseline-local', 'Milch', ['dairy'], 'dairy')] } },
    { candidate: 'claude-haiku', expectedItems: 1 },
  );
  assert.equal(worse.ok, false);
  assert.deepEqual(worse.betterThanCandidate, ['baseline-local']);
  assert.deepEqual(worse.providers['claude-haiku'].misses, [{ name: 'Milch', got: 'frozen', accepted: ['dairy'] }]);

  const errored = compare({ results: { results: [fakeResult('claude-haiku', 'Milch', ['dairy'], undefined)] } }, { candidate: 'claude-haiku', expectedItems: 1 });
  assert.equal(errored.ok, false);
  assert.equal(errored.providers['claude-haiku'].errors, 1);

  const partial = compare({ results: { results: [fakeResult('claude-haiku', 'Milch', ['dairy'], 'dairy')] } }, { candidate: 'claude-haiku', expectedItems: 3 });
  assert.equal(partial.ok, false, 'a run that skipped entries does not pass the gate');
});
