#!/usr/bin/env bash
# UserPromptSubmit hook for the two-Mac workflow (CLAUDE.md, "Two people, two Macs"):
# fetches origin/main (max 4 s) and tells Claude when the other Mac has pushed
# commits this checkout does not have yet. Silent when up to date or offline.
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
perl -e 'alarm 4; exec @ARGV' git fetch -q origin main 2>/dev/null
behind=$(git rev-list --count HEAD..origin/main 2>/dev/null)
[ -n "$behind" ] && [ "$behind" -gt 0 ] || exit 0
dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"Sync check: origin/main has %s commit(s) from the other Mac that this checkout lacks (%s uncommitted file(s) here). Before changing code, bring them in as CLAUDE.md (Two people, two Macs) describes, and say so in one line."}}\n' "$behind" "$dirty"
