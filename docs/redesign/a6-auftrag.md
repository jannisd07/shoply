# A6 Rezepte nach D2 – gemeinsamer Auftrag für die A6-Agenten (Teil A)

Stand 08.11.2026. Grundlage der vier A6-Teile „browse“, „library“, „detail“, „cook“ (Dateien je Teil stehen im
Auftrag des Agenten).

## Ort und harte Regeln (wie S2b)

- Repo `/Users/jannisdietrich/Apps/shoply-neu` (Flutter-App „Avo“, Code `shoply`). Jeder Bash-Befehl beginnt mit
  `cd /Users/jannisdietrich/Apps/shoply-neu && …`.
- **Eine andere Claude-Session (Teil B) arbeitet gleichzeitig im Ordner, dazu drei weitere A6-Agenten.** Keine
  git-Befehle, die etwas ändern (kein add, commit, stash, checkout, switch, restore, reset, clean). Committen macht die
  Hauptsitzung.
- **Nur die Dateien deines Teils** (unten) anlegen oder ändern. Texte nur in deiner Textdatei
  `lib/core/localization/translations/recipes_<teil>.dart` (Maps `recipes<Teil>En`/`recipes<Teil>De`, Präfix `recipe_`;
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
3. D2-Vorlagen (verbindlich): Artifact https://claude.ai/artifact/FKDP5yDZnBeGzfn6HH19dU, lokale Kopien in
   `/private/tmp/claude-501/-Users-jannisdietrich-Apps-RoadTo1Billion-/76ad5c46-b5c2-4efd-a1ef-f81b6109f927/scratchpad/d2/project/`:
   `D2-Rezepte.dc.html` (Tab Rezepte), `D2-FuerDich.dc.html` („Heute kochen“-Hero), `D2-Komponenten.dc.html`
   (Rezeptkarte, Hero, Buttons, Stepper, Segment) und `../komp-clean.html`. Für Detail, Kochmodus, Editor und die
   Bibliotheks-Screens gibt es kein eigenes D2-Artboard: Sie entstehen aus den D2-Komponenten und dem Stil der
   vorhandenen D2-Screens (Großtitel 34/41, Inset-Gruppen Radius 26, Glas-Toolbar, Abblendung, getönte Kapsel als eine
   Hauptaktion).
4. Inhalt und Abläufe: `docs/redesign/konzept/13-rezepte.md` (Kap. 2 gilt für alle, dazu dein Abschnitt),
   `00-grundlagen.md` Kap. 10–15. Optik dort
   ist überholt, D2 gewinnt. Wo das Konzept „Sheet“ sagt, wird es ein Vollbild (`pushFullScreenEditor`) oder ein Menü.
5. Ist-Zustand: `docs/redesign/konzept/inventar/recipes-browse.md`, `recipes-detail.md` und die heutigen Dateien
   deines Teils.
6. Slots von Teil B: nur über `import 'package:shoply/presentation/widgets/slots/b_slots.dart';`: `RecipeOffersCard(recipe:)`,
   `openLogRecipe(context, recipe)`, `avoScreenContextProvider`. B-Widgets zeichnen nichts, wenn Modul aus oder keine Daten.
   Wochenplan-Segment: `buildPlanSegment(context)` aus `lib/routes/areas/plan_routes.dart` (B).

## Feste Regeln für A6

- **Allergien zuerst** (Konzept 13 §2.3): Was die Person nicht essen darf, wird nie versteckt oder klein gezeigt.
- **Pro:** Bis zur Owner-Entscheidung (A9) ist nichts gesperrt. Den heutigen `isSubscribedProvider`-Riegel vor dem
  Kochmodus ersetzt `ProGate.run(context, ref, feature: 'cook_mode', action: …)`; Angebote sind nie Pro.
- **Höchstens drei Push-Ebenen** (Konzept 13 §2.6). Was das Konzept als „Sheet“ beschreibt (Zutaten auf die Liste,
  Variante, Kommentare, Melden), wird Vollbild (`pushFullScreenEditor`) oder Menü; nie ein Bottom-Sheet.
- **Wochenplan** ist ein Segment im Rezepte-Tab und nur sichtbar, wenn `moduleEnabledProvider(AppModule.mealPlan)` true
  ist (heute noch `released: false`, also unsichtbar).
- **Avo-Kontext:** Screens setzen `avoScreenContextProvider` beim Öffnen (`AvoScreenContext(screen: 'recipes' |
  'recipe')`) und setzen ihn beim Verlassen zurück.
- Keine Marktvergleiche (Plan 8); Angebotsbezug nur über B's `RecipeOffersCard`.

## Gemeinsame Schnittstellen (schon auf main)

- `openCookingMode(context, recipe:, servings:)` in `lib/presentation/screens/recipes/cooking_mode_screen.dart`: der eine
  Einstieg in den Kochmodus (Teil „cook“ füllt ihn, „detail“ ruft ihn).
- Rezept-Editor über die Route `/recipes/add` (`draftId`, `recipeId`) wie heute.
- `lib/routes/areas/recipes_routes.dart` gehört Teil „browse“; braucht ein anderer Teil eine Route, steht das im
  Bericht.
- Komponenten: `RecipeCard`/`RecipeHeroCard`/`GlassInfoPanel`, `AvoBarChart`/`AvoHorizontalBar`, `AvoSearchField`,
  `AppFilterChip`/`ChipRow`, `AppSegmentedControl`, `ValueStepper`, `ProgressRing`, `AvoSectionHeader`, `AvoCard`,
  `InsetSection`, `ProBadge`/`ProGate`, `EmptyState`, `SkeletonSection`, `StatusRow`, `AvoToast`, `showAvoConfirm`,
  `showSuccessMoment`, `FullScreenEditor`/`pushFullScreenEditor`, `AvoMenuButton`, `GlassToolbar`, `ScrollEdgeFade`.
- `openAppDestination`/`AppDestinations`, `ItemRepository.instance.addItems`/`undoAddItems`, `parseItemInput`,
  `formatQuantity` (`lib/core/utils/item_quantity.dart`).
- Vorhandene Provider und Services nur benutzen, nicht ändern (Änderungswunsch in den Bericht).

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
