# S5b Auftrag: B's Wünsche nach B8 und Gegenprüfung B8

Stand 09.11.2026. B8 (Einkauf abschließen, Verlauf, Kosten teilen) ist auf `main`. A-V9 hat B mit A's OK erledigt.
Quelle der Wünsche: `status-B.md` Nr. 19 und 20, Einzelheiten in `b-screens/verlauf-kosten.md` (Tabelle ab Zeile
~1600, „A-V…“). B6b und B7 sind noch nicht auf `main`.

## Regeln für Agenten

- Lies `CLAUDE.md` (harte Regel: keine Sheets, keine Slider; Design-System D2, Tokens aus
  `package:shoply/core/design/design.dart`, keine Hex-Werte/Schriftgrößen/Dauern in Screens).
- Ändere nur die Dateien deines Teils. Vor jeder anderen Datei `bash docs/redesign/owner.sh <pfad>`: B-Dateien
  (`lib/presentation/screens/history/**`, `b_slots.dart`, `home_sections/**` …) nie ändern.
- Ein gemeinsamer Ordner: nie `git add`, `commit`, `stash`, `checkout`, `reset`, `restore`, `clean`. Du committest nicht.
- `dart format` nur auf deine Dateien. `dart analyze <deine Dateien>` 0 Errors, 0 Warnings.
- Tests nur dateiweise (`flutter test --no-pub <datei>`), vorher `pgrep -x flutter_tester | wc -l`; bei 2 oder mehr
  warten. Neue Komponenten bekommen einen Test mit `layoutMatrix` aus `test/layout/layout_matrix.dart`.
- Bestehende Aufrufer dürfen nicht brechen: neue Parameter optional, Verhalten ohne sie unverändert.
- Platte ist knapp (≈ 13 GB): keine Builds, keine Worktrees.

## Teil 1 (Agent „Komponenten“)

Dateien: `lib/presentation/widgets/design/amount_field.dart` (neu), `settings_rows.dart`, `filter_chip.dart`,
`avo_icons.dart`, `success_moment.dart`, je der Test in `test/widgets/design/` (Ordner prüfen), Galerie-Eintrag in
`lib/presentation/widgets/design/gallery/` falls die Galerie Einträge je Komponente hat.

1. **A-V3 `AmountField`** (neu): Varianten kompakt (in Zeilen, rechtsbündig, `body`, tabellarische Ziffern) und groß
   (`AvoTextStyle` für große Zahlen aus den Tokens, linksbündig, höchstens 51 pt). Eingabe nach Locale („1.234,56“,
   „42,8“, Komma und Punkt), Währungszeichen nach Locale, keine feste Breite, Fehlerzustand (`errorText`),
   `onChanged(int? cents)`, `placeholder`. Ziffernblock mit Komma (`TextInputType.numberWithOptions(decimal: true)`).
   Regel zum Parsen: B's `parseAmountCents` in `lib/data/services/trip_split_math.dart` lesen und dieselbe Regel
   nutzen (importieren, wenn die Datei rein ist; sonst eigene Funktion mit gleichen Testfällen). Vorbild: B's
   `lib/presentation/screens/history/widgets/amount_field.dart` (nur lesen).
2. **A-V6** in `settings_rows.dart`: `ValueRow` mit optionaler Unterzeile (`subtitle`), und eine Zeile mit Wert und
   Pull-down (`PullDownValueRow` oder Parameter an vorhandener Zeile): Titel links, Wert in `secondaryLabel`, Glyph
   `chevron.up.chevron.down`, Tipp öffnet `showAvoMenu` (aus `avo_menu.dart`) mit den übergebenen Einträgen;
   VoiceOver: Taste mit Wert.
3. **`AppFilterChip(trailing:)`**: optionales Widget hinter dem Label (B: „Anderer Markt …“ mit `chevron.right` 11).
4. **A-V16 `AvoIcons`**: fehlende Glyphen ergänzen, soweit nicht vorhanden: `eurosign.circle`, `person.badge.plus`,
   Filter (`line.3.horizontal.decrease.circle`, Kontur und gefüllt), `exclamationmark.circle`, `checkmark.circle`,
   `cart.badge.plus`, Einkaufstasche, Balken, Liste, Pfeil nach unten, Sync (`arrow.triangle.2.circlepath`),
   `chevron.up.chevron.down`, `storefront`, Standort. Gleiche Bauart wie die vorhandenen Einträge.
5. **A-V7 `showSuccessMoment`**: Figur ab AX3 weglassen (heute ab AX1 72 pt, das bleibt), Unterzeile bis 3 Zeilen,
   mit VoiceOver bleibt der Moment, bis die Ansage fertig ist (mindestens die VoiceOver-Dauer, wie `AvoToast` es macht).

## Teil 2 (Agent „Diagramm und Hinweis“)

Dateien: `lib/presentation/widgets/design/bar_chart.dart`, `undo_toast.dart`, `lib/core/design/avo_colors.dart`, je der
Test.

1. **A-V4 `AvoBarChart`**: Auswahl durch Antippen und Ziehen (`selectedIndex`, `onSelected(int)`), Auswahl-Haptik pro
   Spalte über `AvoHaptics`, optionale zweite Kürzelzeile je Eintrag (`secondaryLabel`, z. B. „bisher“), ab AX1 Werte
   als Zeilen (prüfen, ob schon da). Tokens in `avo_colors.dart`: `chartBar` (hell #ECECF0, erhöhter Kontrast #8A8A8E,
   dunkel passend), `chartHighlight` (#34A853 hell, dunkel passend), `monthCardGradient` (Start #EEF7EF → Ende
   `surface`, dunkel passend); in allen vier Farbvarianten. Das Diagramm nutzt `chartBar`/`chartHighlight` als
   Standard. Heute wählt B über eine eigene Trefferfläche (`lib/presentation/screens/history/widgets/month_review.dart`,
   nur lesen, damit die API passt).
2. **A-V24 `AvoToast.show(onDismissed:)`**: Rückruf, wenn der Hinweis verschwindet (Ablauf, Wischen, Aktion, ersetzt
   durch einen neuen), auch nach VoiceOver-Pause; genau einmal.

## Teil 1/2 Bericht

Am Ende kurz: geänderte Dateien, neue APIs (Signaturen), Tests und ihr Ergebnis, was offen blieb.

## Teil 3 (A selbst, ohne Agent)

A-V9 Rest (freie Schlüssel in `translations/lists.dart` löschen, bei 0 abgehakten Artikeln kein `openCheckoutFlow`),
A-V11 (`navigation_service.dart`), A-V12 (Listen-Übersicht „Verlauf“), A-V13 (Home `HomeSplitHint`), A-V14 (prüfen),
A-V19/A-V23 (`ItemRepository`), Gegenprüfung der B8-Screens.
