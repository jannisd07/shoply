// promptfoo test generator for the categorize eval: one test per dataset entry
// and the same entries again in batches of the size the app sends
// (AiCategorizationService.categorizeBatch: at most 60 names per call).
// Vars are strings only: promptfoo expands array vars into separate tests.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const BATCH_SIZE = 60;
/** The app gives up on Claude after 8 s and keeps its local category (plan, timeouts). */
export const APP_TIMEOUT_MS = 8000;
/** Share of a batch that must be right (owner gate: at least today's level, see README). */
export const BATCH_MIN_ACCURACY = 0.9;

function acceptedOf(item) {
  return [item.expected, ...(item.accept ?? [])];
}

export default async function generateTests() {
  const items = JSON.parse(readFileSync(path.join(HERE, 'dataset.json'), 'utf8')).items;
  const tests = items.map((item) => {
    const accepted = acceptedOf(item);
    return {
      description: `${item.name} → ${accepted.join(' | ')} [${item.tags.join(',')}] (${item.lang})`,
      vars: { name: item.name, lang: item.lang, accepted: accepted.join(','), brand: item.brand ?? '' },
      metadata: { kind: 'item', category: item.expected, lang: item.lang, tags: item.tags },
      assert: [
        { type: 'javascript', value: 'file://assertions.mjs:categoryAccepted', metric: 'category' },
        { type: 'latency', threshold: APP_TIMEOUT_MS },
      ],
    };
  });

  // Round robin over the dataset, which is sorted by category, so every batch mixes them.
  const count = Math.ceil(items.length / BATCH_SIZE);
  const batches = Array.from({ length: count }, () => []);
  items.forEach((item, i) => batches[i % count].push({ name: item.name, accepted: acceptedOf(item) }));
  batches.forEach((batch, i) => {
    tests.push({
      description: `batch ${i + 1}/${count}: ${batch.length} entries in one call`,
      vars: { items_json: JSON.stringify(batch), lang: 'de' },
      metadata: { kind: 'batch', size: batch.length },
      assert: [
        {
          type: 'javascript',
          value: 'file://assertions.mjs:batchAccuracy',
          config: { minAccuracy: BATCH_MIN_ACCURACY },
          metric: 'batch_category',
        },
        { type: 'latency', threshold: APP_TIMEOUT_MS },
      ],
    });
  });
  return tests;
}
