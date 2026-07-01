<!-- gitnexus:start -->
# GitNexus — Code Intelligence (optional)

This project has a GitNexus index (`.gitnexus/`). **Only follow this section if `gitnexus_*` MCP tools are actually available in your session** — if they are not connected, skip GitNexus entirely and use Grep/Read for impact analysis instead (find all callers of a symbol before changing its signature).

When the tools ARE available:

- Before changing a symbol's signature or deleting it: `gitnexus_impact({target: "symbolName", direction: "upstream"})` — update all d=1 (WILL BREAK) callers.
- To explore unfamiliar code: `gitnexus_query({query: "concept"})`; for one symbol's callers/callees: `gitnexus_context({name: "symbolName"})`.
- For renames: `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})`, review, then `dry_run: false`.
- After committing, the index goes stale — refresh with `npx gitnexus analyze` (a PostToolUse hook may handle this automatically).

Detailed skill files live in `.claude/skills/gitnexus/` (exploring, impact-analysis, debugging, refactoring, guide, cli).
<!-- gitnexus:end -->