# S5b Nachzug von B – Ergebnis (09.11.2026)

B8 (Einkauf abschließen, Verlauf, Kosten teilen) kam während dieser Sitzung auf `main` (`3fbaf58`, `2269045`). A-V9
hat B mit A's OK im selben Commit wie B8 erledigt. B6b und B7 sind noch nicht auf `main` (nur
`origin/feature/b7-plan`). Owner zu A10 (Maskottchen F-17-11): „noch offen“. Auftrag: [`s5b-auftrag.md`](s5b-auftrag.md).

## Ergebnis

Die Wünsche aus `status-B.md` Nr. 19 und 20 (Einzelheiten in `b-screens/verlauf-kosten.md`, Tabelle „A-V…“):

- **A-V3 `AmountField`** (neu, `widgets/design/amount_field.dart`): kompakt (in Zeilen, rechtsbündig, mit `label`
  als ganze Zeile, ab xxxLarge gestapelt) und groß (`largeTitle`, höchstens 51 pt). Parst mit B's `parseAmountCents`
  (`trip_split_math.dart`), `onChanged(int? cents)`, `onInputChanged(AmountInput)` unterscheidet leer und ungültig,
  `errorText` mit `exclamationmark.circle` als Live-Region. Dazu `formatAmount` und `formatAmountNumber`.
- **A-V4 `AvoBarChart`:** `selectedIndex` und `onSelected` (Tippen und Ziehen, Auswahl-Haptik je Spalte, leere
  Spalten nicht wählbar, ab AX1 Tipp auf die Zeile, VoiceOver einstellbar), `AvoBarEntry.secondaryLabel` („bisher“).
  Tokens `chartBar`, `chartHighlight`, `monthCardGradientStart` und `monthCardGradient` (135°, nach `surface`) in allen
  vier Farbvarianten; das Diagramm nutzt sie als Standard.
- **A-V6:** `ValueRow(subtitle:)`. Die Zeile mit Wert und Pull-down gab es schon: `MenuValueRow` (`picker_row.dart`),
  jetzt auch über `settings_rows.dart` exportiert.
- **A-V7 `showSuccessMoment`:** ab AX3 ohne Figur (AX1–AX2 weiter 72 pt), Unterzeile bricht um ohne Kürzen, mit
  VoiceOver bleibt der Moment 10 s stehen.
- **A-V24 `AvoToast.show(onDismissed:)`:** genau einmal, wenn der Hinweis weg ist (Ablauf auch nach VoiceOver-Pause,
  Wischen, Aktion, Ziel, ersetzt durch einen neuen, Host abgebaut).
- **`AppFilterChip(trailing:)`:** Widget 6 pt hinter dem Label, von VoiceOver nicht gelesen.
- **A-V16:** alle genannten Glyphen gab es schon in `AvoIcons`.
- **A-V9 Rest:** freie Schlüssel gelöscht (`complete_btn`, `complete_shopping_question`,
  `complete_shopping_checked_message`, `shopping_complete_push_*`, `no_checked_items*`, `list_shop_saved_*`).
  `someone` bleibt (Mitglieder, Änderungen). Bei 0 abgehakten Artikeln ruft A `openCheckoutFlow` schon nie auf: der
  Knopf im Einkaufsmodus ist gedimmt, der Menüpunkt erscheint erst ab einem abgehakten Artikel.
- **A-V11:** `NavigationService` öffnet bei `shopping_complete`, `expense_split` und `split_reminder` mit
  `history_id` den Einkauf (`/history/<id>`); ältere Mitteilungen ohne `history_id` öffnen weiter die Liste.
- **A-V12:** Listen-Übersicht, Gruppe „Verlauf“ am Ende: „Einkäufe“ mit „November · 6“ (ohne Einkauf ohne Wert) →
  `historyLocation()`, „Offene Beträge“ mit der offenen Summe → `splitsLocation()`, nur wenn
  `openBalancesSummaryProvider` etwas liefert. Monatsname über B's `monthName` (keine intl-Daten nötig).
- **A-V13:** Home zeigt `HomeSplitHint` direkt unter der Avo-Karte (`HomeSection.splitHint`, 12 pt Abstand) und zählt
  ihn bei der Grenze für Hinweis-Zeilen des Pro-Hinweises mit.
- **A-V14 geprüft (Test in `app_routes_test.dart`):** `/history/:tripId` liegt im Listen-Tab unter dem Verlauf. Ein
  `context.push('/history/<id>')` aus Home oder dem Avo-Tab zeigt das Detail im Listen-Tab, **legt aber den Verlauf
  nicht darunter**: Zurück führt dorthin, wo man herkam. Mit `context.go` stünden Verlauf und Detail im Listen-Tab.
  Für die Mitteilung (A-V11) nutzt A `push`.
- **A-V19:** `ItemRepository.addItemsSkippingOpen(listId, items)` lässt offene Dubletten weg statt zusammenzuführen,
  `AddItemsResult.skipped` nennt sie. Eigene Methode statt eines Parameters an `addItems`, damit die Test-Fakes, die
  `addItems` überschreiben (auch B's `history_test_harness.dart`), weiter kompilieren.
- **A-V23:** `ItemRepository.removeItems(listId, ids)`: ein Löschaufruf, Liste einmal angefasst, kein Push pro Artikel.
- **Gegenprüfung B8** (V1–V13): `bash tool/design_check.sh B` ohne Treffer in `screens/history` und
  `home_sections/home_history.dart` (alle Treffer liegen in Kalorien- und Avo-Dateien, die B6b und B5b neu bauen),
  keine Sheets und Slider, Prüfmatrix für V1–V12 vorhanden (`test/layout/screens/b/history_*`), Dialoge über
  `showAvoConfirm`. Kein Fund. Simulator-Stichprobe nicht gemacht (Platte, Absprache mit B, Anmeldung).

## Braucht den Owner

- A10: Maskottchen F-17-11 (3D-Figur behalten oder neu flach). Ohne Entscheidung kein A10.
- Avo antwortet nicht: das Supabase-Secret `ANTHROPIC_API_KEY` fehlt (laut B, `supabase secrets list`); setzen kann
  es nur der Owner.
- Platte: 13–16 GB frei. Unter 15 GB keine Worktrees, unter 10 GB keine Builds.

## Von Teil B

1. Umstellen (B macht das als eigenes Paket B8b, Antwort vom 09.11.): `HistoryAmountField` → `AmountField(label:)`; `SpendingBars` in `month_review.dart` →
   `AvoBarChart(selectedIndex:, onSelected:)` und `AvoBarEntry.secondaryLabel` statt eigener Trefferfläche; Home-
   Monatskarte → `context.colors.monthCardGradient`; eigene „Bezahlt von“-Zeile → `MenuValueRow`; „Anderer Markt …“ →
   `AppFilterChip(trailing:)`; die 2-min-Sperre der Mitteilungen → `AvoToast.show(onDismissed:)`; „Alle wieder auf die
   Liste“ → `addItemsSkippingOpen`; Rückfall ohne Migration → `removeItems`.
2. A-V14: Soll „Letzte Einkäufe“ bzw. Avo „Ansehen“ den Verlauf unter dem Detail haben, `go` statt `push` nutzen
   (dann führt Zurück in den Verlauf, nicht nach Home). A empfiehlt `push`; B bleibt dabei.
3. Offen bei A für B: „alle oder keine“ Wertebeschriftung des Diagramms nach Messung (A-V4), Token `numberXL`,
   A-V20 (`FullScreenEditor` mit Tastatur-Kapsel), A-V17 (gemeinsamer Wisch- und Kontextmenü-Baustein), A-V18
   (`Avatar` 20/28/40), A-V21 (großer Titel dritter Ebene), A-V5 (Kapsel 4,5:1), A-V15 (Glas-Budget), A-V22, W11 M10.

## Offen bei A

- Gegenprüfung von B7 (Wochenplan) und B6b (Kalorien-Woche, Gewicht, Challenges), sobald sie auf `main` sind.
- A-V4 „alle oder keine“ Wertebeschriftung, `numberXL`, A-V5, A-V15, A-V17, A-V18, A-V20, A-V21 (siehe oben).
- Erhöhter Kontrast: `chartBar` (#8A8A8E) und `chartHighlight` (#248A3D) liegen in der Helligkeit nah beieinander;
  die gewählte Spalte unterscheidet sich über Farbton, fettes Kürzel und den Wert. Im Simulator ansehen.
- Reste aus [`abschlussbericht-A.md`](abschlussbericht-A.md) „Offen bei A“ (`ListCard` ab AX1 ohne Cover, Galerie und
  gestrichelter Kreis im Simulator).

## Bewusst abgewichen

- A-V9 „Einkaufsmodus beenden“ bei 0 abgehakten Artikeln: Der Knopf bleibt wie in D2 gedimmt (schließen geht über
  den Zurück-Knopf), statt die Beschriftung zu wechseln.
- A-V19 als eigene Methode statt `addItems(skipOpenDuplicates:)` (siehe oben).
