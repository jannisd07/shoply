# Avo-Redesign: Wegweiser

1. **Design:** Verbindlich ist das D2-Glas-Artifact „Shoply Redesign – 5 Richtungen“, Seite „D2 · Glas“: https://claude.ai/artifact/FKDP5yDZnBeGzfn6HH19dU
   - Die Screens `X-…` sind die Erweiterungen vom 07.11.: Einkaufsmodus, Avo, Sprachmodus, Wochenplan, Essen eintragen, Profil mit Modulen, Preise & Angebote, Onboarding, Paywall.
   - Was wofür gilt: [`design-quelle.md`](design-quelle.md).
2. **Parallel bauen:**
   - Mac 1 (Owner): [`prompt-teil-A.md`](prompt-teil-A.md) in eine neue Claude-Code-Session (Opus 5.5).
   - Mac 2 (Jannis): [`prompt-teil-B.md`](prompt-teil-B.md) in eine neue Claude-Code-Session (Opus 5.5).
3. **Abstimmen** läuft über [`status-A.md`](status-A.md) und [`status-B.md`](status-B.md). Die Sessions legen sie selbst an.

## Dateien

| Datei | Inhalt |
|---|---|
| [`design-quelle.md`](design-quelle.md) | Design-Quelle D2: Werte, Tab-Bar, wo die Module sitzen, Liste aller Artboards |
| [`konzept/`](konzept/) | Funktionen, Abläufe, Zustände, Barrierefreiheit pro Bereich (10 bis 20). Optische Angaben darin sind überholt. |
| [`konzept/inventar/`](konzept/inventar/) | Ist-Zustand der App pro Bereich (mit Datei:Zeile) |
| [`arbeitsteilung.md`](arbeitsteilung.md) | Wer macht was, Dateibesitz, Verträge zwischen A und B, Meilensteine, Git-Protokoll |
| [`owner.sh`](owner.sh), [`check-ownership.sh`](check-ownership.sh) | Zeigt, wem eine Datei gehört; prüft vor jedem Commit |
| [`prompt-teil-A.md`](prompt-teil-A.md), [`prompt-teil-B.md`](prompt-teil-B.md) | Die beiden Arbeitsaufträge |
| [`avo-verbesserungsliste.md`](avo-verbesserungsliste.md) | Die 16 Verbesserungspunkte (eingeflossen) |
| [`chatgpt-redesign-prompt.md`](chatgpt-redesign-prompt.md) | Alt; nur noch als Funktionsliste der App (Abschnitt 3) |

Bei Widersprüchen gilt Jannis' Plan: [`../Shoply-Ideen-und-Plan.md`](../Shoply-Ideen-und-Plan.md).
