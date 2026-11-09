# AB1 Anfragen von B: Komponenten und Daten – gemeinsamer Auftrag (Teil A)

Stand 09.11.2026. Drei Teile laufen gleichzeitig: **„Zeilen“**, **„Eingabe“**, **„Menüs“**. Jeder Teil baut
Komponenten, die Teil B für seine Screens angefragt hat, und ersetzt die Behelfe, die A bisher selbst gezeichnet hat.
Ergebnis: B stellt seine Eigenbauten (`StoreFilterChip`, `PostcodeFieldRow`, sortierbare Zeilen in S13 …) auf diese
Komponenten um.

## Ort und harte Regeln

- Repo `/Users/jannisdietrich/Apps/shoply-neu` (Flutter-App „Avo“, Dart-Paket heißt noch `shoply`). Jeder Bash-Befehl
  beginnt mit `cd /Users/jannisdietrich/Apps/shoply-neu && …`.
- **Teil B und zwei weitere AB1-Agenten arbeiten gleichzeitig im selben Ordner.** Keine git-Befehle, die etwas ändern
  (kein add, commit, stash, checkout, switch, restore, reset, clean, rm). Committen macht die Hauptsitzung.
- **Nur die Dateien deines Teils** (unten). Texte nur in deiner Textdatei (Präfix `common_`); vorhandene Schlüssel
  anderer Dateien darfst du benutzen. Ein doppelter Schlüssel ist ein Compile-Fehler. Neue Texte sagen „Avo“, nie
  „Shoply“; keine `\n`. Deutsch und Englisch, kurz und konkret.
- **Bestehende Konstruktoren und Parameter nicht brechen** (B und die A-Screens nutzen sie). Nur optionale Parameter,
  neue benannte Konstruktoren, neue Enum-Werte am Ende, neue Klassen. Wenn ein Aufrufer sich ändern muss, steht er
  in deiner Dateiliste oder kommt in den Bericht.
- **`dart format` nur auf deine eigenen Dateien**, nie auf Ordner, in denen fremde Dateien liegen.
- Prüfen nur auf deine Dateien: `dart analyze <deine Dateien>` (0 Errors, 0 Warnings, keine neuen Infos) und
  `flutter test --no-pub <eine Testdatei>`. **RAM und Platte sind knapp:** Tests nur dateiweise; vorher
  `pgrep -x flutter_tester | wc -l`, bei 2 oder mehr mit einer until-Schleife warten (`until [ $(pgrep -x
  flutter_tester | wc -l) -lt 2 ]; do sleep 20; done`). Lange Befehle mit `timeout 600`. Keine Builds, keine
  Simulatoren, keine Worktrees, keine Gesamtsuite, keine Unteragenten.
- **Keine Änderungen an Supabase** (keine Migration, kein SQL, keine Edge Function). Server-Bedarf in den Bericht.
- `bash docs/redesign/owner.sh <pfad>` zeigt, wem eine Datei gehört. B-Dateien nie ändern (z. B. alles unter
  `lib/presentation/screens/offers/`, `list_offer_*`, `b_slots.dart`); Wünsche an B in den Bericht.

## Pflichtlektüre vor dem Schreiben

1. `CLAUDE.md` Abschnitt „Design System“ und die harte Regel: **keine Sheets, keine halbhohen Modals, keine Slider,
   Bearbeiten im Vollbild**; zentrierte Alerts und Pull-down-Menüs (`showAvoMenu`) sind erlaubt.
2. Die Komponenten-Regeln: Tokens nur aus `package:shoply/core/design/design.dart` (`context.colors`,
   `context.text(AvoTextStyle.…)`, `AvoSpacing`, `AvoRadii`, `AvoSizes`, `AvoMotion`, `AvoHaptics`); keine Hex-Werte,
   Schriftgrößen oder Dauern ohne Token (eine D2-Einzelmaßnahme ist eine private Konstante mit `// D2`). Text nie in
   fester Höhe; Trefferflächen ≥ 44 pt; Reduce Motion = kurzes Überblenden; Reduce Transparency/Increase Contrast =
   deckend. Jede Komponente hat eine Testdatei unter `test/presentation/widgets/design/` und besteht `layoutMatrix`
   aus `test/layout/layout_matrix.dart` (320–440 pt, Text 1,0–3,1, fett, dunkel, Kontrast).
3. D2-Vorlage (verbindlich für die Optik):
   `/private/tmp/claude-501/-Users-jannisdietrich-Apps-RoadTo1Billion-/76ad5c46-b5c2-4efd-a1ef-f81b6109f927/scratchpad/d2/project/D2-Komponenten.dc.html`
   und die übrigen Artboards im selben Ordner (groß: mit `grep -o` nach Stichworten suchen, nicht ganz lesen).
4. Die Anfragen von B mit genauen Maßen (die Nummern unten): `docs/redesign/b-screens/angebote.md` §6 und die dort
   genannten Screens, `b-screens/avo.md` §2.11 und §15, `b-screens/kalorien.md` §6, `b-screens/verlauf-kosten.md` §6,
   `b-screens/wochenplan.md` §6, `docs/redesign/status-B.md` Anfragen 13–15. Wo B und D2 sich widersprechen, gewinnt
   D2; wo D2 schweigt, gilt B's Anfrage.
5. Die Komponente, die du änderst, ganz lesen, samt ihrer Testdatei.

## Gemeinsame Schnittstellen (schon auf `main`)

- **`AvoIcons`** hat jetzt auch `photo`, `camera`, `checklist`, `history`, `personCircle`, `flame`, `sync` (aus dem
  gelöschten `account_icons.dart`) und `stopFill` (Quadrat für „Antwort anhalten“). Weitere Symbole baut Teil
  „Menüs“; die anderen Teile nutzen nur vorhandene Symbole und melden fehlende im Bericht.
- **Textdateien**, je Teil eine, schon in `app_translations.dart` registriert (leer):
  `lib/core/localization/translations/components_rows.dart` (`componentsRowsEn/De`, Teil „Zeilen“),
  `components_input.dart` (`componentsInputEn/De`, Teil „Eingabe“), `components_menus.dart`
  (`componentsMenusEn/De`, Teil „Menüs“).
- Die Komponenten-Galerie (`widgets/design/gallery/`) fasst kein Teil an; neue Galerie-Einträge in den Bericht.

## Teil „Zeilen“

Dateien: `widgets/design/item_row.dart`, `check_circle.dart`, `hint_row.dart`, neu `select_circle.dart`,
`reorderable_section.dart`, `swipe_actions.dart`; `lib/presentation/state/lists_provider.dart` (nur ergänzen),
`lib/presentation/screens/lists/shopping_mode_screen.dart` (nur den Provider setzen); die zugehörigen Tests.
Texte: `components_rows.dart`.

- **A-C1 `ItemRow`** (angebote.md §6 A-C1, S3 `ItemOfferBadge`, S4):
  - Neuer Parameter für den rechten Slot, dessen Semantik in das Zeilen-Label eingeht (z. B. „Milch, 2 Liter,
    Angebot 1,29 € bei Lidl“), und dessen eigene Aktionen („Angebot ansehen“) als Custom Actions der Zeile erscheinen.
    Vorschlag: `trailingSemanticsLabel` (String?) und `trailingActions` (`Map<String, VoidCallback>`), zusammen mit den
    vorhandenen `semanticActions`.
  - Einträge für ein Kontextmenü (Langdruck) aus dem Slot: `contextMenuItems` (`List<AvoMenuEntry>`), geöffnet mit
    `showAvoMenu` am Langdruck-Punkt; gilt auch in der großen Variante (Einkaufsmodus).
  - Ab AX1 rückt der Slot unter den Namen neben die Menge (statt rechts zu quetschen); `AdaptiveTrailing` gibt es schon,
    prüfen, ob es das schon kann.
  - Tipp auf den Slot erreicht den Slot (die Pille), nicht `onTap` der Zeile. Test dafür.
  - **Kompakte Variante** `ItemRowSize.compact` (avo.md §15, D2 `X-Avo`): mindestens 56 hoch, Kreis 22 (in 44 Treffer),
    Bild 36 mit Radius 9, Trennlinie ab 88. Dazu ggf. `CheckCircleSize.small` (22) in `check_circle.dart`.
- **A-C9 / A-V2 `SelectCircle`** (E-08): 22 pt in 44-pt-Ziel, gewählt `checkmarkCircleFill` in `tint`, sonst Ring in
  `uncheckedRing`; VoiceOver als Schalter (`toggled`), keine Haptik; bewusst getrennt von `CheckCircle` (kein Abhaken,
  kein Durchstreichen). `SelectCircle({required bool selected, required ValueChanged<bool>? onChanged, required String
  semanticLabel})`.
- **A-C9 sortierbare Zeilen** (angebote.md S13): `ReorderableInsetSection` (oder ähnlich) im Look von `InsetSection`
  (Radius 26, Trennlinien), Zieh-Griff `line3Horizontal` mit 44er Ziel rechts, Ziehen per Langdruck auf dem Griff mit
  Feder und Selektions-Haptik (`AvoHaptics`), VoiceOver-Aktionen „Nach oben“, „Nach unten“ (und Ansage der neuen
  Position), `onReorder(oldIndex, newIndex)`. Kein Sheet. Reduce Motion: ohne Federn.
- **A-C3 `HintRow`** (angebote.md S7 `ListOfferSummary`): optionaler fetter `title` über dem `text` (zweizeilige
  Ersparnis-Karte), Wisch-Aktion (z. B. „Ausblenden“) und Kontextmenü (`contextMenuItems`). Bestehende Aufrufer
  bleiben gleich.
- **Wisch-Aktionen als gemeinsamer Baustein** (`swipe_actions.dart`, A-V17, A-K12): Zeile nach links (und optional nach
  rechts) wischen zeigt Aktionsflächen (destruktiv: `destructive`-Fläche), Schwelle mit leichtem Impuls, volles Wischen
  löst die erste Aktion aus, Federn aus `AvoMotion`; alle Aktionen zusätzlich als VoiceOver-Custom-Actions. `HintRow`
  nutzt ihn; `ItemRow` darf ihn optional anbieten (nicht Pflicht).
- **Einkaufsmodus aktiv** (A-C3 zweiter Teil): in `lists_provider.dart` ein `StateProvider<ShoppingModeSession?>
  shoppingModeSessionProvider` mit `ShoppingModeSession { String listId; DateTime startedAt; }`;
  `shopping_mode_screen.dart` setzt ihn beim Öffnen und leert ihn beim Schließen (nur wenn er noch zu dieser Liste
  gehört). Mehr nicht an diesem Screen ändern.

## Teil „Eingabe“

Dateien: `widgets/design/app_button.dart`, `add_item_accessory.dart` (nur `AvoComposerField` und was es braucht),
`search_field.dart`, `filter_chip.dart`, `settings_rows.dart`, `avatar.dart`, neu `text_field_row.dart`;
`lib/core/design/avo_colors.dart` (nur das Token `destructiveFill` ergänzen, in allen vier Paletten, Kontrast weißer
Text ≥ 4,5:1) und sein Test `test/core/design/avo_colors_test.dart`; Aufrufer-Umstellung in
`lib/presentation/screens/profile/profile_root_screen.dart`, `profile/account/profile_edit_screen.dart`,
`profile/account/account_widgets.dart` (`ProfilePhotoAvatar` entfällt), dem Name-Schritt des Onboardings
(`lib/presentation/screens/onboarding/steps/`, Datei mit dem selbst gezeichneten Kreis) und der Mitteilungs-Seite
(`lib/presentation/screens/profile/settings/notifications_settings_screen.dart`, nur das Warndreieck); die
zugehörigen Tests (auch `test/screens/profile/account/profile_photo_avatar_test.dart` umziehen oder löschen).
Texte: `components_input.dart`.

- **`AppButton` gefüllt neutral und gefüllt destruktiv** (status-B 14, a8-stand): `AppButton.filledNeutral` (graue
  Fläche `fill`/`secondaryFill`, Text `label`) und `AppButton.destructiveFilled` (Fläche `destructiveFill`, weißer
  Text). Neues Token `destructiveFill` (D2/kalorien.md: #D70015 hell; dunkel/Kontrast abgeleitet, weiß ≥ 4,5:1).
  Gleiche Größen, `working`, `expand`, Press-Federn wie die anderen Varianten.
- **`AvoComposerField`** (avo.md §2.11, status-B 14): dritter Zustand „Antwort anhalten“ – rechts ein getönter Knopf
  mit `AvoIcons.stopFill`, solange `onStop != null` und `responding == true` (Label `stopLabel`, Text-Schlüssel wie
  avo.md `avo_stop_answer` gehört B; eigener Fallback-Schlüssel in deiner Datei); `enabled` (aus = grau, nicht
  fokussierbar); `maxLength` mit Zähler, der erst kurz vor der Grenze erscheint; eigenes `semanticLabel` für das Feld;
  Foto-Knopf links öffnet statt `onCamera` optional ein Pull-down (`photoMenuItems: List<AvoMenuEntry>`, z. B.
  „Foto aufnehmen“ `AvoIcons.camera`, „Foto auswählen“ `AvoIcons.photo`) über `showAvoMenu`. Der Bug der Mutter des
  Owners (A3) darf nicht zurückkommen: `test/screens/lists/add_item_composer_test.dart` muss grün bleiben.
- **`AvoSearchField` mit Mikrofon** (a6-stand, kalorien A-C12): `onDictate` + `dictateLabel` zeigen rechts im Feld ein
  `AvoIcons.mic` (44er Ziel), solange das Feld leer ist; mit Text das vorhandene Löschen. Form gegen D2 prüfen (a6-stand
  nennt Kapsel 40 pt, kalorien.md 48/Radius 24); nur ändern, wenn D2 es klar zeigt, und dann alle Aufrufer prüfen.
- **A-C5 Textfeld-Zeile** (angebote.md S11 Region, kalorien A-C1 Feld-Zeile): `TextFieldRow` für `InsetSection`:
  Beschriftung links, Feld rechtsbündig, `keyboardType`, `autofillHints`, `textInputAction`, `inputFormatters`,
  `controller`/`onChanged`/`onSubmitted`, Platzhalter, Fehler- oder Hinweiszeile darunter (Fehler in `destructive`, als
  VoiceOver-Hinweis), ab AX1 gestapelt (Beschriftung über dem Feld). Mindesthöhe statt fester Höhe.
- **A-C2 / A-V1 `AppFilterChip` und `ChipRow`**: Platz `leading` (Widget, z. B. B's `StoreMark` oder ein 8-pt-Punkt,
  wächst bis AX2 mit) und `secondaryLabel` („· 400 m“ in `secondaryLabel`-Farbe); `ChipRow(wrap: true)` bricht um statt
  zu scrollen; Einfachauswahl-Variante (VoiceOver als Radiogruppe: „ausgewählt, 1 von 4“, erneutes Tippen hebt auf, wenn
  `allowDeselect`). Bestehende Aufrufer bleiben gleich.
- **`NavRow(valueLeading:)`** (a8-stand): optionales Widget vor dem Wert (z. B. Warndreieck
  `exclamationmarkTriangleFill` in `warning`); in der Mitteilungs-Seite vor „In iOS aus“ einsetzen.
- **`AvatarSize.xl` mit Foto** (a7/a8-stand, verlauf-kosten A-V18): `AvatarSize.xl` (64) am Ende des Enums, `Avatar`
  nimmt optional `image` (ImageProvider) und zeigt das Foto rund, mittig gefüllt (`BoxFit.cover`, Querformat füllt den
  Kreis, vgl. `523b3fd`), sonst die Initiale; ggf. weitere Größen 28/40 aus A-V18. `ProfilePhotoAvatar` und der Kreis
  im Name-Schritt werden durch `Avatar(size: AvatarSize.xl, image: …)` ersetzt (Optik bleibt, Tests umziehen).

## Teil „Menüs“

Dateien: `widgets/design/avo_menu.dart`, `module_off_alert.dart`, `undo_toast.dart`, `avo_icons.dart`;
`lib/data/repositories/item_repository.dart`, `lib/data/repositories/item_batch.dart`, bei Bedarf
`lib/data/models/shopping_item_model.dart` (nur ergänzen); die zugehörigen Tests (`test/presentation/widgets/design/…`,
Tests des Repositorys unter `test/`). Texte: `components_menus.dart`.

- **A-C8 Pull-down-Menü** (angebote.md S1 Menü „Markt“, S10 Menü „Auf welche Liste?“, wochenplan A-K10):
  Titelzeile ohne Aktion (`AvoMenuTitle`), Sektionen mit Trennern (vorhandenes `AvoMenuDivider` oder `AvoMenuSection`),
  Häkchen vorn (`checked` gibt es, prüfen, ob vorn), Unterzeile pro Eintrag (`subtitle` gibt es), Glyph vorn, internes
  Scrollen bei vielen Einträgen oder großer Schrift, Ursprung am Auslöser auch bei einem Knopf unten am Bildschirm (Menü
  öffnet nach oben), `ProBadge` im Eintrag (optional `trailing`). Untermenüs an derselben Stelle (A-K10) nur, wenn es
  ohne Umbau geht; sonst in den Bericht.
- **A-C7 / A-V8 / A-P3 `showModuleOffAlert(…, body:)`**: optionaler Satz, der den Nutzen des Moduls nennt, statt des
  Standardtextes. Bestehende Aufrufe bleiben gültig.
- **`AvoToast` mit Ziel** (Konzept 13 E-16, 00 §12.28; verlauf-kosten A-V10): optional `targetLabel` + `onTarget`:
  Tippen auf den Text öffnet das Ergebnis (z. B. die Liste), „Widerrufen“ bleibt die Aktion; VoiceOver-Aktion mit
  `targetLabel` („Liste öffnen“). Dazu, wenn ohne Umbau möglich, A-V10: die Zeit läuft nicht, solange der
  VoiceOver-Fokus auf dem Hinweis liegt.
- **Fehlende `AvoIcons`** (SVG-Pfade auf dem 24er Raster, D2-Strich 1,8, wie die vorhandenen; jeder Name auch in
  `AvoIcons.all`, Test „stays on the 24 grid“ grün – Achtung: `Path.getBounds` zählt Kontrollpunkte, große Bögen in
  zwei Bögen teilen): `plusBubble`, `leaf`, `switch2` (status-B 14), `eurosignCircle`, `filter` und gefüllt
  (`line.3.horizontal.decrease.circle`), `checkmarkCircle` (Kontur), `cartBadgePlus`, `bag` (Einkaufstasche D2 „Dein
  November“), `chartBar` (Balken D2 „Dein November“), `listBullet`, `arrowDown` (D2 Vergleich), `chevronUpChevronDown`
  (verlauf-kosten A-V16). D2-Artboards zuerst nach dem passenden SVG durchsuchen und dann übernehmen.
- **A-D1 Preis-Schnittstelle im `ItemRepository`** (angebote.md §6 A-D1, §7): Angebotspreis an einen Artikel hängen und
  entfernen – Preis, Währung, Händler als Ketten-ID, Einheit, Vergleichspreis (`priceOldValue`), Datum – z. B.
  `setItemPrice(String itemId, ItemPrice price)` und `clearItemPrice(String itemId)`, beide mit Rückgabe eines
  Rückgängig-Tokens wie `addItems`/`undoAddItems` (oder `undoPriceChange(token)`), über denselben Schreibweg wie die
  anderen Methoden (optimistisch, Realtime, Warteschlange, falls vorhanden). `NewItem` bekommt dieselben Felder (optional),
  `addItems` schreibt sie. Spalten gibt es schon (`price`, `price_currency`, `price_retailer`, `price_unit`,
  `price_updated_at`, `price_old_value`); keine Migration. Tests mit Fake/Mocks wie die vorhandenen Repository-Tests.

## Bericht

Schreibe deinen Bericht nach
`/private/tmp/claude-501/-Users-jannisdietrich-Apps-shoply-neu/796330a7-8f9b-40c1-a39a-1200d6f36de6/scratchpad/ab1-<teil>-bericht.md`
(`zeilen`, `eingabe`, `menues`) und antworte zum Schluss nur mit Status (FERTIG / FERTIG MIT BEDENKEN / BLOCKIERT), der
Dateiliste und je einer Zeile Testergebnis. Inhalt des Berichts:

1. Geänderte/neue/gelöschte Dateien.
2. Neue API je Komponente mit genauer Signatur (das geht 1:1 an B).
3. Letzte Zeile von `flutter test` je Testdatei und von `dart analyze` über deine Dateien.
4. Abweichungen von D2/Anfrage mit Grund; nötige Änderungen an fremden Dateien (genau); fehlende Symbole; Galerie-
   Einträge; offene Punkte.
