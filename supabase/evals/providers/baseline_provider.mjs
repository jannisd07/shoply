// promptfoo provider for today's offline categorization (the comparison
// baseline of supabase/evals/categorize). It reads the answers that
// test/evals_export_test.dart computed with the app's own Dart code and
// answers in the shape of the categorize task, so the same assertions grade
// both. Costs nothing and calls nothing.
import { readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(HERE, '../../..');
const DEFAULT_FILE = path.join(REPO_ROOT, 'supabase/evals/.results/baseline.json');
const EXPORT_HINT =
  'AVO_EVALS_BASELINE_OUT=supabase/evals/.results/baseline.json flutter test test/evals_export_test.dart';

const cache = new Map();

function load(file) {
  if (!cache.has(file)) cache.set(file, JSON.parse(readFileSync(file, 'utf8')).answers);
  return cache.get(file);
}

export default class BaselineProvider {
  constructor(options = {}) {
    this.providerId = options.id ?? 'baseline';
    this.config = options.config ?? {};
  }

  id() {
    return this.providerId;
  }

  async callApi(_prompt, context = {}) {
    const vars = context.vars ?? {};
    const variant = this.config.variant;
    if (variant !== 'keywords' && variant !== 'local') return { error: 'config.variant must be keywords or local' };
    const file = this.config.file ? path.resolve(REPO_ROOT, this.config.file) : DEFAULT_FILE;
    let answers;
    try {
      answers = load(file);
    } catch {
      return { error: `no baseline at ${path.relative(REPO_ROOT, file)}; export it first: ${EXPORT_HINT}` };
    }
    const names =
      typeof vars.items_json === 'string' && vars.items_json.trim() !== ''
        ? JSON.parse(vars.items_json).map((item) => (typeof item === 'string' ? item : item.name))
        : [vars.name];
    const items = [];
    for (const name of names) {
      const id = answers?.[name]?.[variant];
      if (typeof id !== 'string') return { error: `no baseline answer for "${name}"; re-export: ${EXPORT_HINT}` };
      items.push({ category_id: id, confidence: null, brand: null });
    }
    return { output: { items }, latencyMs: 0, cost: 0 };
  }
}
