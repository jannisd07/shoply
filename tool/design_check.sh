#!/usr/bin/env bash
# D2 design rules (konzept/20-qualitaet.md §7.8) for screens and widgets.
#
#   bash tool/design_check.sh          # all files in lib/presentation, lib/core/widgets
#   bash tool/design_check.sh A        # only files Teil A owns (docs/redesign/owner.sh)
#   bash tool/design_check.sh B        # only files Teil B owns
#
# Exits 1 when a rule is broken. Exempt: the token files (lib/core/design),
# the components in lib/presentation/widgets/design, providers and state,
# legacy shims, files waiting for their own package (below), D2 one-offs
# and brand colours marked "// D2" or "// brand data", and lines ending in
# "// design-check: ok <reason>". Durations count only as `duration:` of an
# animation (timers, debounces and undo windows are behaviour, not motion).
# CupertinoIcons are reported as a note: AvoIcons has no glyph for them yet.
set -euo pipefail
cd "$(dirname "$0")/.."

part="${1:-}"
roots=(lib/presentation lib/core/widgets)
# subscription_screen: Paywall, rebuilt in A9. nudge_card: only B's dead
# home cards import it (a12-stand.md), deleted with them. list_info_colors:
# the list colour palette (iOS system colours in four variants), a token file.
exempt='^lib/presentation/screens/lists/widgets/list_info_colors\.dart$|^lib/presentation/screens/subscription/subscription_screen\.dart$|^lib/presentation/screens/home/widgets/nudge_card\.dart$|^lib/presentation/widgets/design/|^lib/presentation/(state|providers)/|^lib/core/widgets/design_system\.dart$|^lib/core/widgets/paper/'

# Extended regex (BSD grep has no -P). Colors.transparent is allowed.
rules=(
  'Farbe|Color\(0x|(^|[^A-Za-z])Colors\.[a-z]'
  'Schriftgroesse|fontSize:|letterSpacing:'
  'Dauer|duration: (const )?Duration\((milliseconds|seconds):'
  'Icon|(^|[^A-Za-z])Icons\.|LucideIcons\.'
  'Haptik|HapticFeedback\.'
  'Sheet/Slider|showModalBottomSheet|showCupertinoModalPopup|DraggableScrollableSheet|(^|[^A-Za-z])Slider\(|CupertinoSlider'
)

files=()
while IFS= read -r f; do
  [[ "$f" =~ $exempt ]] && continue
  if [[ -n "$part" ]]; then
    owner="$(bash docs/redesign/owner.sh "$f" | cut -f1)"
    [[ "$owner" == "$part" ]] || continue
  fi
  files+=("$f")
done < <(find "${roots[@]}" -name '*.dart' | sort)

fail=0
for rule in "${rules[@]}"; do
  name="${rule%%|*}"
  pattern="${rule#*|}"
  hits="$(grep -nE "$pattern" "${files[@]}" /dev/null \
    | grep -v '// design-check: ok' \
    | grep -v 'Colors\.transparent' \
    | grep -vE '// (D2|brand data)' \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*//' || true)"
  if [[ -n "$hits" ]]; then
    fail=1
    count="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
    echo "❌ $name ($count)"
    printf '%s\n' "$hits" | sed 's/^/   /'
  fi
done

notes="$(grep -nE 'CupertinoIcons\.' "${files[@]}" /dev/null | grep -v '// design-check: ok' || true)"
if [[ -n "$notes" ]]; then
  echo "ℹ️  CupertinoIcons statt AvoIcons ($(printf '%s\n' "$notes" | wc -l | tr -d ' ') Stellen, kein Fehler):"
  printf '%s\n' "$notes" | cut -d: -f1 | sort | uniq -c | sed 's/^/   /'
fi

if [[ $fail -eq 0 ]]; then
  echo "✅ design_check ${part:-alle}: ${#files[@]} Dateien, keine Funde"
fi
exit $fail
