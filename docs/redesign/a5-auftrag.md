# A5 Listen nach D2 – gemeinsamer Auftrag für die A5-Agenten (Teil A)

Stand 08.11.2026. Grundlage der vier A5-Teile „detail“, „item“, „shopping“, „overview“ (Zuordnung der Dateien:
`status-A.md`, Abschnitt „Unterbrechung“).

## Ort und harte Regeln (wie S2b)

- Repo `/Users/jannisdietrich/Apps/shoply-neu` (Flutter-App „Avo“, Code `shoply`). Jeder Bash-Befehl beginnt mit
  `cd /Users/jannisdietrich/Apps/shoply-neu && …`.
- **Eine andere Claude-Session (Teil B) arbeitet gleichzeitig im Ordner, dazu drei weitere A5-Agenten.** Keine
  git-Befehle, die etwas ändern (kein add, commit, stash, checkout, switch, restore, reset, clean). Committen macht die
  Hauptsitzung.
- **Nur die Dateien deines Teils** (unten) anlegen oder ändern. Texte nur in deiner Textdatei
  `lib/core/localization/translations/lists_<teil>.dart` (Maps `lists<Teil>En`/`lists<Teil>De`, Präfix `list_`;
  vorhandene Schlüssel aus anderen Dateien darfst du lesen und benutzen). Brauchst du eine Änderung an einer anderen
  Datei (Provider, Repository, Router, Komponente, B-Datei), schreib sie in den Bericht statt sie zu machen.
- Prüfen nur auf deine Dateien: `flutter test --no-pub <deine Tests>` und `dart analyze <deine Dateien>` (0 Errors,
  0 Warnings, 0 Infos in deinen Dateien). Lange Befehle mit `timeout 600`; bei „Waiting for another flutter command“
  warten. Fehler aus fremden halbfertigen Dateien ignorieren und nennen.
- Keine iOS-Builds, keine Simulatoren, keine Worktrees (Speicher knapp).
- `bash docs/redesign/owner.sh <pfad>` zeigt, wem eine Datei gehört. B-Dateien nie ändern.

## Pflichtlektüre vor dem Schreiben

1. `CLAUDE.md` Abschnitt „Design System“ und die harte Regel oben (**keine Sheets, keine Slider, Bearbeiten im
   Vollbild**).
2. Komponenten in `lib/presentation/widgets/design/` (alle fertig, nutze sie statt Eigenbau): `ItemRow`/`ItemThumb`,
   `ListCard`/`ListRow`, `Avatar`/`AvatarStack`/`PresenceDot`, `QuickAddTile`, `AddItemAccessory`/`AccessoryDock`,
   `AvoMenuButton`/`showAvoMenu`/`AvoMenuItem`/`AvoMenuDivider`, `FullScreenEditor`/`pushFullScreenEditor`,
   `GlassToolbar`/`GlassIconButton`/`GlassButtonGroup`/`ScrollEdgeFade`, `AppButton`, `InsetSection`/`SectionCaps`/
   Settings-Rows, `CheckCircle`, `ValueStepper`, `AppSegmentedControl`, `StatusRow`, `EmptyState`, `SkeletonSection`,
   `AvoToast`/`AvoToastHost` (Rückgängig), `showAvoConfirm`, `showSuccessMoment`, `ProgressLine`/`ProgressRing`,
   `AvoIcons`. Tokens: `package:shoply/core/design/design.dart`. Prüfgerüst: `test/layout/layout_matrix.dart`.
3. D2-Vorlagen (verbindlich): Artifact https://claude.ai/artifact/FKDP5yDZnBeGzfn6HH19dU (Artifact-Tool,
   `action: "read"`, `paths: ["project/D2-Liste.dc.html", …]`): `D2-Liste` (Liste), `D2-Artikel` (Artikel bearbeiten),
   `X-Einkaufsmodus`, `D2-Home` (Listen-Übersicht), `D2-Komponenten`.
4. Inhalt und Abläufe: `docs/redesign/konzept/11-listen.md` (dein Abschnitt), `00-grundlagen.md` Kap. 10–15. Optik dort
   ist überholt, D2 gewinnt. Wo das Konzept „Sheet“ sagt, wird es ein Vollbild (`pushFullScreenEditor`) oder ein Menü.
5. Ist-Zustand: `docs/redesign/konzept/inventar/lists-core.md`, `lists-more.md` und die heutigen Dateien deines Teils.
6. Slots von Teil B: nur über `import 'package:shoply/presentation/widgets/slots/b_slots.dart';` (Signaturen in
   `docs/redesign/prompt-b-vorrang.md` Stufe 1). B-Widgets zeichnen nichts, wenn Modul aus oder keine Daten.

## Feste Owner-Entscheidungen (status-A.md, 07.11.2026)

- **Einkaufsmodus** startet über einen getönten Wagen-Knopf oben rechts in der Liste (nur wenn offene Artikel da sind)
  und über das Mehr-Menü. Pfad `RoutePaths.shopping(listId)` = `/lists/<id>/shopping`.
- **Summe „≈ 23,80 €“** im Eingabefeld nur mit Modul Angebote (`offersAvailableProvider`) und mindestens einem
  gespeicherten Preis: Summe der gespeicherten Preise der offenen Artikel, nie ein Marktvergleich.
- Diktat (Mikrofon) erst mit B's Sprachdienst: Mikrofon vorerst nicht zeigen.
- Große Karte in der Listen-Übersicht = angeheftete bzw. zuletzt genutzte Liste mit Cover (Foto der Liste), sonst
  Farbquadrat.
- Keine Marktvergleiche, kein „günstigster Korb“ (Plan 8).
- Avo-Kontext: Screens setzen `avoScreenContextProvider` (aus `b_slots.dart`) beim Öffnen
  (`AvoScreenContext(screen: 'list' | 'shopping' | 'lists', listId:, listName:)`).

## Gemeinsame Schnittstellen (schon auf main)

- `openItemEditor(context, listId:, item:, prefill:)` in `lib/presentation/screens/lists/item_editor_screen.dart`:
  der eine Einstieg zum Artikel-Vollbild (Teil „item“ füllt ihn, die anderen rufen ihn nur auf).
- `RoutePaths.shopping(listId)`; die Route baut Teil „shopping“.
- `openAppDestination`/`AppDestinations` (`lib/routes/app_destinations.dart`), `ProGate.run` (nichts gesperrt).
- Mengen-Parser `parseItemInput(text)`/`parseSingleItem(text)` in `lib/core/utils/item_input_parser.dart`;
  `ItemRepository.instance.addItems`/`undoAddItems` für mehrere Artikel mit Rückgängig.
- Vorhandene Provider (`items_provider.dart`, `lists_provider.dart` usw.) nur benutzen, nicht ändern.

## Qualität

- Jeder neue Screen/jedes neue Widget mit Test: `layoutMatrix` (Breiten 320–440, Schrift bis 3,1×, fett, dunkel,
  Kontrast) und Verhaltenstests. Screens, die Supabase oder Provider brauchen, im Test mit `ProviderScope(overrides:)`
  und Testdaten; was sich so nicht testen lässt, in einen testbaren Teil-Widget auslagern.
- Zustände gestalten: leer, lädt (lokaler Stand sofort, nie Vollbild-Spinner), Fehler, offline, Modul aus.
- VoiceOver-Labels, 44-pt-Ziele, Reduce Motion, Dunkelmodus. Texte DE/EN, kurz und konkret.
- Alter Code, den dein Teil ersetzt, darf in deinen Dateien gelöscht werden; Dateien anderer Teile nicht.

## Bericht (deine letzte Antwort)

1. Geänderte/neue/gelöschte Dateien. 2. Was jetzt wie aussieht und funktioniert (kurz). 3. Letzte Zeile von
`flutter test` und `dart analyze`. 4. Abweichungen von D2/Konzept mit Grund; nötige Änderungen an fremden Dateien
(genau, mit Signatur); offene Punkte.
