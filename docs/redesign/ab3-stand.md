# AB3 Offene Wünsche von B – Ergebnis (09.11.2026)

S5c ging nicht: B7 und B6b sind nicht auf `main` (nur `origin/feature/b7-plan`, ein Grundlagen-Commit). Owner zu A10
(Maskottchen F-17-11): „noch offen“. `status-B.md` hat seit S5b keine neuen Anfragen. Der Owner hat entschieden, die
offenen Wünsche aus `s5b-stand.md` „Von Teil B“ 3 als Paket AB3 umzusetzen.

## Ergebnis

- **`AvoTextStyle.numberXL`** (neu, `avo_typography.dart`): 34/41 Bold, immer tabellarische Ziffern, wächst wie der
  große Titel und bleibt ab AX3 bei 51 pt. `AmountField` groß nutzt den Stil statt einer eigenen Deckelung.
- **A-V4 „alle oder keine“:** `AvoBarChart` misst die Werte in der halbfetten Schrift der gewählten Spalte. Passt ein
  Wert nicht in seine Spalte (lange Beträge, 320 pt, größere Schrift), entfallen alle; die Zeile über den Balken
  bleibt frei, damit das Diagramm nicht springt, und VoiceOver liest weiter jeden Wert. Die Auswahl einer anderen
  Spalte schaltet die Werte nie um. Achsen-Kürzel schrumpfen wie bisher.
- **A-V17 `RowActions`** (neu, `widgets/design/row_actions.dart`): ein Baustein für Wischaktionen
  (`trailingActions`, `leadingActions`, wie `SwipeActions`), Kontextmenü per Langdruck (`menuItems`, optional
  `menuPreview` und `menuSemanticLabel`) und dieselben Aktionen für VoiceOver. Eine aufgewischte Zeile nimmt keinen
  Langdruck. Zeilen mit eigenem Semantik-Knoten setzen `exposeSemantics: false` und nehmen
  `RowActions.semanticActionsOf(...)`. Galerie: „RowActions (wischen und lange drücken)“.
- **A-V15 entschieden:** Der Rückgängig- und Status-Hinweis zählt nicht zu den drei Glasflächen (höchstens 4 s, nie
  zwei gleichzeitig), ebenso ein offenes Menü. Steht in Konzept 00 §8.5.
- **A-V21 entschieden:** „Verlauf“ und „Offene Beträge“ behalten den großen Titel in jeder Tiefe, weil sie eigene
  Ziele sind (Listen-Übersicht, Home, Mitteilung, Avo). Detail- und Unterseiten bleiben beim Inline-Titel. Steht in
  Konzept 00 §12 (Navigationsleiste, Varianten).
- **Schon vorher erledigt, jetzt belegt:**
  - A-V5: getönte Kapsel hell 96 % Deckkraft, weiße Schrift 4,99:1 (`glassTintFill`, `be2971f`, mit A-T2).
  - A-V18: `AvatarSize.small` (20), `size28`, `size40` mit Initiale oder Foto.
  - A-V20: `FullScreenEditor(dirty:)` sperrt das Zurück-Wischen und fragt „Änderungen verwerfen?“; `bottom:` läuft
    über der Tastatur mit (Tests „pushed editor with changes: swipe back is off“, „the keyboard shrinks the content
    and lifts the action“). B nutzt beides schon in V1, V6 und V7.

Geprüft: `dart analyze lib test` 0 Fehler, 0 Warnungen; `bash tool/design_check.sh A` ohne Funde; Tests siehe
Commit-Nachricht.

## Braucht den Owner

- A10: Maskottchen F-17-11 (3D-Figur behalten oder neu flach). Ohne Entscheidung kein A10.
- Platte: 14 GB frei. Unter 15 GB keine Worktrees, unter 10 GB keine Builds.
- Eine neue A-Sitzung lohnt sich erst, wenn B7 oder B6b auf `main` ist, B neue Wünsche einträgt oder A10 entschieden
  ist. Vorher endet sie ohne Code.

## Von Teil B

1. `history/widgets/month_review.dart`: die eigene Deckelung („D2 numberXL cap“) durch
   `context.text(AvoTextStyle.numberXL)` ersetzen; ebenso jede andere große Zahl (V5 Betrag im Kopf).
2. `AvoBarChart`: „alle oder keine“ macht das Diagramm jetzt selbst. Eigene Prüfungen dafür können weg; der Punkt
   „320 pt: Wertebeschriftung alle oder keine“ der Checkliste ist damit erfüllt.
3. Optional: `trip_row.dart`, `open_balances_screen.dart`, `trip_detail_screen.dart` und `split_editor_screen.dart`
   bauen `SwipeActions` plus `onLongPress: showAvoMenu` selbst zusammen. `RowActions(trailingActions:, menuItems:,
   exposeSemantics: false)` ersetzt beides; die VoiceOver-Aktionen kommen aus `RowActions.semanticActionsOf`.
4. A-V22 bleibt bei B: `write_queue.dart` gehört laut `owner.sh` Teil B (Aufgaben mit „frühestens ab“, Bereich
   `history`). Braucht B dafür etwas aus A's Dateien, bitte als neue Anfrage.
5. W11 M10 („im Konto gemerkt“): A liest es als „pro Konto auf diesem Gerät“, wie Tipps (`TipService`) und der
   Pro-Hinweis (`ProHintCounter`), nicht synchronisiert. Ein weggewischter Hinweis darf auf einem zweiten Gerät noch
   einmal erscheinen.

## Offen bei A

- Gegenprüfung von B7 (Wochenplan) und B6b (Kalorien-Woche, Gewicht, Challenges), sobald sie auf `main` sind (S5c).
- Im Simulator ansehen: erhöhter Kontrast im Diagramm (`chartBar` #8A8A8E neben `chartHighlight` #248A3D), Galerie,
  gestrichelter Kreis, `ReorderableInsetSection`.
- Reste aus [`abschlussbericht-A.md`](abschlussbericht-A.md) „Offen bei A“ (`ListCard` ab AX1 ohne Cover, Präsenz im
  Einkaufsmodus, Ziehen aus der Menü-Vorschau).

## Bewusst abgewichen

- A-V4: Die freie Zeile über den Balken bleibt stehen, wenn die Werte entfallen. So ändert das Diagramm seine Höhe
  nicht, wenn ein Betrag eine Stelle länger wird.
- A-V17: `ItemRow` behält seine eigene Verdrahtung (Zonen für Abhaken und Öffnen); `RowActions` ist für alle anderen
  Zeilen.
