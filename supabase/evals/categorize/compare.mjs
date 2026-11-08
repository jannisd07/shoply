// Comparison gate for the categorize eval (plan B1.9: Claude at least as good
// as today's local categorization). Reads a promptfoo result file and
// recomputes per provider: accuracy on the single-entry tests, per tag, the
// misses and the errors. Exit 1 when the candidate has errors, skipped
// entries, or lower accuracy than any baseline.
//   node supabase/evals/categorize/compare.mjs supabase/evals/.results/categorize.json [--candidate avo-categorize]
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));

function rowsOf(data) {
  const rows = data?.results?.results ?? data?.results ?? [];
  return Array.isArray(rows) ? rows : [];
}

function labelOf(row) {
  return row?.provider?.label ?? row?.provider?.id ?? 'unknown';
}

function firstCategory(output) {
  let value = output;
  if (typeof value === 'string') {
    try {
      value = JSON.parse(value);
    } catch {
      return undefined;
    }
  }
  return value?.items?.length === 1 ? value.items[0]?.category_id : undefined;
}

function share(hits, total) {
  return total === 0 ? 0 : hits / total;
}

export function compare(data, { candidate = 'avo-categorize', expectedItems } = {}) {
  const providers = {};
  for (const row of rowsOf(data)) {
    if (row?.testCase?.metadata?.kind !== 'item') continue;
    const label = labelOf(row);
    const p = (providers[label] ??= { total: 0, hits: 0, errors: 0, misses: [], tags: {} });
    p.total++;
    const vars = row.testCase.vars ?? {};
    const accepted = String(vars.accepted ?? '').split(',').filter(Boolean);
    const error = row.error ?? row.response?.error;
    const got = error ? undefined : firstCategory(row.response?.output);
    const hit = got !== undefined && accepted.includes(got);
    if (error) p.errors++;
    if (hit) p.hits++;
    else if (!error) p.misses.push({ name: vars.name, got, accepted });
    for (const tag of row.testCase.metadata.tags ?? []) {
      const t = (p.tags[tag] ??= { total: 0, hits: 0 });
      t.total++;
      if (hit) t.hits++;
    }
  }
  for (const p of Object.values(providers)) {
    p.accuracy = share(p.hits, p.total);
    for (const t of Object.values(p.tags)) t.accuracy = share(t.hits, t.total);
  }

  const mine = providers[candidate];
  const betterThanCandidate = mine
    ? Object.entries(providers)
        .filter(([label, p]) => label !== candidate && p.accuracy > mine.accuracy)
        .map(([label]) => label)
    : [];
  const complete = mine !== undefined && (expectedItems === undefined || mine.total === expectedItems);
  const ok = complete && mine.errors === 0 && betterThanCandidate.length === 0;
  return { ok, candidate, complete, providers, betterThanCandidate };
}

function percent(value) {
  return `${(value * 100).toFixed(1)} %`;
}

function printReport(report) {
  const labels = Object.keys(report.providers).sort();
  console.log('Provider                    entries  right   accuracy  errors');
  for (const label of labels) {
    const p = report.providers[label];
    console.log(`${label.padEnd(28)}${String(p.total).padStart(7)}${String(p.hits).padStart(7)}${percent(p.accuracy).padStart(11)}${String(p.errors).padStart(8)}`);
  }
  const tags = [...new Set(labels.flatMap((label) => Object.keys(report.providers[label].tags)))].sort();
  console.log(`\nAccuracy per tag: ${labels.join(' | ')}`);
  for (const tag of tags) {
    const cells = labels.map((label) => {
      const t = report.providers[label].tags[tag];
      return t ? `${percent(t.accuracy)} (${t.hits}/${t.total})` : '-';
    });
    console.log(`${tag.padEnd(14)}${cells.join(' | ')}`);
  }
  const mine = report.providers[report.candidate];
  if (mine?.misses.length) {
    console.log(`\nMisses of ${report.candidate}:`);
    for (const miss of mine.misses) console.log(`  ${miss.name}: ${miss.got} (expected ${miss.accepted.join(' or ')})`);
  }
  console.log(
    report.ok
      ? `\n✅ ${report.candidate} is at least as accurate as every baseline, without errors.`
      : `\n❌ gate failed: ${!report.complete ? 'entries missing; ' : ''}${mine?.errors ? `${mine.errors} errors; ` : ''}${report.betterThanCandidate.length ? `better: ${report.betterThanCandidate.join(', ')}` : ''}`,
  );
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const file = process.argv[2];
  if (!file) {
    console.error('usage: node supabase/evals/categorize/compare.mjs <promptfoo-output.json> [--candidate <label>]');
    process.exit(2);
  }
  const at = process.argv.indexOf('--candidate');
  const candidate = at > -1 ? process.argv[at + 1] : undefined;
  const expectedItems = JSON.parse(readFileSync(path.join(HERE, 'dataset.json'), 'utf8')).items.length;
  const report = compare(JSON.parse(readFileSync(file, 'utf8')), { candidate, expectedItems });
  printReport(report);
  process.exit(report.ok ? 0 : 1);
}
