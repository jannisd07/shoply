// Assertions of the categorize eval. Output shape (task `categorize` and the
// baseline providers alike): {items: [{category_id, confidence, brand}]}.

function itemsOf(output) {
  let value = output;
  if (typeof value === 'string') {
    try {
      value = JSON.parse(value);
    } catch {
      return null;
    }
  }
  return value && Array.isArray(value.items) ? value.items : null;
}

function squash(text) {
  return String(text ?? '')
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]/gu, '');
}

/** Same brand when one squashed name contains the other ("Beck's" ~ "Becks"). */
function sameBrand(got, expected) {
  const a = squash(got);
  const b = squash(expected);
  return a !== '' && b !== '' && (a.includes(b) || b.includes(a));
}

/**
 * One entry: the category must be the expected id or an accepted alternative
 * (vars.accepted, comma separated). The brand is reported as a named score
 * and never fails the test (the baselines cannot name brands).
 */
export function categoryAccepted(output, context) {
  const vars = context?.vars ?? {};
  const accepted = String(vars.accepted ?? '').split(',').filter(Boolean);
  const items = itemsOf(output);
  if (!items || items.length !== 1) {
    return { pass: false, score: 0, reason: `expected exactly one answer, got ${items ? items.length : 'no items'}` };
  }
  const got = items[0]?.category_id;
  const pass = accepted.includes(got);
  const namedScores = { category: pass ? 1 : 0 };
  if (vars.brand) namedScores.brand = sameBrand(items[0]?.brand, vars.brand) ? 1 : 0;
  return {
    pass,
    score: pass ? 1 : 0,
    reason: pass ? `${got} is accepted` : `got ${got}, expected ${accepted.join(' or ')}`,
    namedScores,
  };
}

/**
 * A batch in production size: one answer per entry in order, and at least
 * config.minAccuracy (default 0.9) of them accepted.
 */
export function batchAccuracy(output, context) {
  const expected = JSON.parse(context?.vars?.items_json ?? '[]');
  const minAccuracy = Number(context?.config?.minAccuracy ?? 0.9);
  const items = itemsOf(output);
  if (!items || items.length !== expected.length) {
    return { pass: false, score: 0, reason: `expected ${expected.length} answers, got ${items ? items.length : 'no items'}` };
  }
  const misses = [];
  expected.forEach((entry, i) => {
    const got = items[i]?.category_id;
    if (!entry.accepted.includes(got)) misses.push(`${entry.name}: ${got} (expected ${entry.accepted.join('/')})`);
  });
  const accuracy = (expected.length - misses.length) / expected.length;
  return {
    pass: accuracy >= minAccuracy,
    score: accuracy,
    reason: `${expected.length - misses.length}/${expected.length} accepted (need ${minAccuracy})` +
      (misses.length ? `. Misses: ${misses.slice(0, 10).join('; ')}${misses.length > 10 ? ' …' : ''}` : ''),
    namedScores: { batch_category: accuracy },
  };
}
