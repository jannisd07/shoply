#!/usr/bin/env bash
# Vor jedem Commit: prüft, ob die gestagten Dateien zu deinem Teil gehören.
# Nutzung: bash docs/redesign/check-ownership.sh A   (oder B)
# Exit 1, wenn eine Datei dem anderen Teil gehört oder unklar ist.
set -u
me="${1:-}"
if [ "$me" != "A" ] && [ "$me" != "B" ]; then
  echo "Nutzung: $0 A|B" >&2
  exit 2
fi
here="$(cd "$(dirname "$0")" && pwd)"
bad=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  o="$(bash "$here/owner.sh" "$f" | cut -f1)"
  case "$o" in
    "$me"|NEU-BEIDE) ;;
    GETEILT) echo "Hinweis: $f ist geteilt. Nur kleine Änderung, eigener Commit, sofort pushen." ;;
    TEST) echo "Hinweis: $f ist ein Test. Nur Tests für eigene Dateien." ;;
    UNKLAR) echo "STOPP: $f ist keinem Teil zugeordnet. Erst in docs/redesign/status-$me.md abstimmen."; bad=1 ;;
    *) echo "STOPP: $f gehört Teil $o, nicht Teil $me. Änderungswunsch in docs/redesign/status-$me.md eintragen."; bad=1 ;;
  esac
done < <(git diff --cached --name-only --diff-filter=ACMRD)
exit $bad
