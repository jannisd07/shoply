# Status Teil A (Owner, Mac 1)

Diese Datei schreibt nur Teil A. Teil B liest sie nach jedem `git pull`. Aufbau laut `arbeitsteilung.md` Abschnitt 5.

## Stand

08.11.2026: Teil A läuft jetzt auf Jannis' Mac **im selben Ordner wie B** (`~/Apps/shoply-neu`, auf `main`, kein
eigener Worktree wegen Speicher). Regeln für beide: kein `git stash`/`checkout`/`switch`/`reset`/`add -A`; nur eigene
Pfade committen (`git commit -m … -- <pfade>`); abgleichen mit `git fetch && git merge --ff-only origin/main`;
analyze/Tests nur auf eigene Pfade.

**S2b-Komponenten komplett** (nutzbar, alle in `lib/presentation/widgets/design/`): `AvoCard`/`AvoTile`/`AvoTileGrid`/
`AvoSectionHeader` (`home_card.dart`), `ItemRow`/`ItemThumb`, `ListCard`/`ListRow`, `Avatar`/`AvatarStack`/
`PresenceDot`, `QuickAddTile`, `AddItemAccessory`/`AvoComposerField`/`AccessoryDock`, `AvoMenuItem`/`AvoMenuDivider`/
`showAvoMenu`/`AvoMenuButton`, `FullScreenEditor`/`pushFullScreenEditor`, `ProGate.run`/`ProFeatures`
(`pro_gate.dart`); dazu `AppBrand` (`lib/core/constants/app_brand.dart`) und `openAppDestination`/`AppDestinations`
(`lib/routes/app_destinations.dart`), `RecipeCard`/`RecipeHeroCard`/`GlassInfoPanel`, `AvoBarChart`/
`AvoHorizontalBar`. Noch offen für S2: die Komponenten-Galerie (`/debug/components`, nur Debug).

**A4 Home ist gebaut** (D2 „Für dich“, Reihenfolge `lib/presentation/screens/home/home_layout.dart`): B's Abschnitte
erscheinen, wenn Modul an und `…HasContentProvider` true. Die alten Home-Karten, der Angebote-Streifen und die
Verlaufszeile sind weg. „Liste beitreten“ sitzt jetzt im Mehr-Menü des Listen-Tabs.

**A9:** Analyse in [`pro-konzept.md`](pro-konzept.md); Free gegen Pro entscheidet der Owner. Bis dahin ist nichts
gesperrt.

Plan: `docs/superpowers/plans/2026-11-07-teil-a.md`. Vorrang-Aufgaben für B: `docs/redesign/prompt-b-vorrang.md`.

## A5 Listen fertig (08.11.2026)

Liste, Artikel-Vollbild mit Zettel-Import, Einkaufsmodus (`/lists/:id/shopping`) und Listen-Übersicht mit Teilen und
Listen-Info sind auf `main` (`0e1f753`, `c53e84f`, `5efc97f`, `5e943ba`). Offene Punkte und fehlende Daten:
[`a5-stand.md`](a5-stand.md). Galerie-Funde behoben: Icon-Farbe auf Knöpfen (`832b3e5`), Stepper-Überlauf (`38e0d56`),
Toolbar-Titel bei AX5 (`1f55b77`); offen: Wortumbruch mitten im Wort in schmalen Kacheln/Chips, Platzhalter von
`AvoSearchField` bei AX5.

## Meilensteine

| Meilenstein | Stand | Datum | Commit |
|---|---|---|---|
| S0 Aufräumen gemergt | erledigt: `cleanup/group-A` bis `-I` sind in `main` (Merges `b219010` … `6c12eef`, Abgleich `950921d`) | 07.11.2026 | `950921d` |
| S1 Struktur | **erledigt** | 07.11.2026 | siehe `git log --grep "(a1)"` |
| A3 Eingabeleiste (Bug der Mutter des Owners) | **erledigt**: Text wird bei keiner Breite (320–440 pt) und keiner Textgröße (bis 3,1×) mehr abgeschnitten, Nachweis `test/screens/lists/add_item_composer_test.dart` (40 Fälle) | 07.11.2026 | siehe `git log --grep "(a3)"` |
| S2a Fundament Teil 1 | **erledigt**: D2-Tab-Bar (Home, Listen, Avo, Rezepte, Profil; Avo-Tab auf `/avo`), Kalorien als Push im Home-Tab, Fehlerseite, Modul-Wächter, Deep-Link-Übersetzung, Komponenten Teil 1 (Liste in `prompt-b-vorrang.md`) | 07.11.2026 | `ce66d9f`, `f16e071` |
| S2 Fundament (S2b: Editor, Eingabefeld, Menüs, Zeilen/Karten, Charts, `ProGate.run`, `AppBrand`) | Komponenten und Galerie auf `main`; Abschluss-Review offen | 08.11.2026 | `ad2a9c4` … `56baf55` |
| A4 Home (D2 „Für dich“) | **gebaut**, ohne „Tipp von Avo“ (kommt mit A5) | 08.11.2026 | `4618daf`, `22a7153`, `41a974d` |
| A5 Listen | **gebaut** (Liste, Artikel, Einkaufsmodus, Übersicht, Teilen, Listen-Info); Daten-Lücken in `a5-stand.md` | 08.11.2026 | `0e1f753`, `c53e84f`, `5efc97f`, `5e943ba` |
| A6 Rezepte | **gebaut** (Tab, Suche, Kategorien, Bibliothek, Detail mit Allergie-Hinweis, Zutaten auf die Liste, Kochmodus, Editor); offen in `a6-stand.md` | 08.11.2026 | `b435582`, `f2f0c0c`, `7ce2a24`, `f8d80d9` |
| A7 Onboarding, Login, Tipps | **gebaut** (Ablauf mit Wiederaufnahme, Konto mit Apple/Google/E-Mail-Code, Passwort, Router mit gemerkten Links, Tipp-Zeilen statt Tutorial); Server-Entwurf und offen in `a7-stand.md` | 09.11.2026 | `870da50`, `de77f8a`, `f189222`, `git log --grep Onboarding` |
| S5 Bereiche fertig (A) | offen | | |
| S6 Gegenprüfung (A prüft B) | offen | | |

## Verträge aus S1 (für B verbindlich)

### Übersetzungen

- Je Bereich eine Datei `lib/core/localization/translations/<bereich>.dart` mit `const Map<String, String> <bereich>En`
  und `<bereich>De`. B-Dateien: `avo`, `calories`, `plan`, `offers`, `history`, `notifications`, `system`.
- Die Zuordnung der 1.052 Bestandsschlüssel folgt der Verwendung im Code: Ein Schlüssel, den nur B-Dateien nutzen,
  liegt bei B; wer ihn in A- und B-Dateien braucht, liegt in `common` (A). Lesen über Bereichsgrenzen ist erlaubt,
  ändern nur im eigenen Bereich.
- `AppTranslations.get` ist unverändert. Beide Gesamtkarten sind `const`: Ein Schlüssel in zwei Bereichsdateien ist ein
  Compile-Fehler (so fällt eine Doppelung beim Merge sofort auf).
- **Präfixe für neue Schlüssel:** A: `common_`, `home_`, `list_`, `recipe_`, `onb_`, `auth_`, `profile_`, `set_`,
  `pro_`, `legal_`. B: `avo_`, `cal_`, `plan_`, `offer_`, `hist_`, `notif_`, `sys_`. Bestandsschlüssel behalten ihren
  Namen (sonst bricht `test/translations_test.dart`).

### Routen

Alle Pfade stehen in `lib/routes/route_paths.dart` (`RoutePaths`). B besitzt alles unter seinen Wurzeln und definiert
es in `lib/routes/areas/<bereich>_routes.dart`. **A hängt es ein, B ändert nur seine Datei.** Jede B-Datei hat dieselbe
Form:

| Name | Bedeutung | Wo A es einhängt |
|---|---|---|
| `build<Bereich>Root(context, state)` | Screen an der Bereichswurzel (avo, calories, offers, history) | siehe Tabelle unten |
| `<bereich>ChildRoutes` | Kinder der Wurzel, Pfade **relativ** (z. B. `'voice'` → `/avo/voice`). Mit `parentNavigatorKey: rootNavigatorKey` (aus `lib/routes/app_branch.dart`) öffnet ein Kind im Vollbild über der Tab-Bar | unter der Wurzel |
| `<bereich>BranchRoutes` | `Map<AppBranch, List<RouteBase>>`: weitere Wurzeln in einem Tab, Pfade **absolut** | im Branch des Tabs |
| `<bereich>RootRoutes` | Vollbild-Wurzeln über der Tab-Bar, Pfade absolut (Kamera, Sprachmodus) | Root-Navigator |
| `<bereich>SettingsRoutes` | Einstellungsseiten, Pfade relativ zu `/settings` (z. B. `'offers'`) | Profil-Tab unter `/settings` |
| nur Plan: `buildPlanSegment(context)` | Inhalt des Segments „Wochenplan“ im Rezepte-Tab | unter der Segment-Auswahl von A |
| nur Plan: `planRecipeRoutes` | Kinder eines Rezepts, relativ zu `/recipes/:recipeId` (z. B. `'to-plan'`) | unter dem Rezeptdetail |

`AppBranch` (Tabs nach D2): `home`, `lists`, `avo`, `recipes`, `profile`.

| Wurzel (B) | Pfad | bis S2 | ab S2 (D2) |
|---|---|---|---|
| Avo | `/avo` | Vollbild-Route | **Tab „Avo“** |
| Kalorien | `/calories` | Tab (wie heute) | Push-Screen im **Home-Tab** |
| Wochenplan | `/plan` (+ `/recipes?segment=plan`) | Rezepte-Tab | Segment im **Rezepte-Tab** |
| Angebote | `/offers` | Vollbild-Route | Push im **Listen-Tab** |
| Verlauf | `/history` | Vollbild-Route | Push im **Listen-Tab** |
| reserviert für B | `/splits`, `/stores`, `/checkout` | über `BranchRoutes`/`RootRoutes` | Empfehlung: Listen-Tab |
| Einstellungen B | `/settings/offers`, `/settings/avo`, `/settings/plan`, `/settings/health` | Profil-Tab | Profil-Tab |
| Paywall (A) | `/pro?feature=<id>` | kommt mit A9 | Vollbild |

B-Pfade nur unter diesen Wurzeln anlegen, nie unter `/lists/…` oder `/recipes/…` (Ausnahme: `planRecipeRoutes`).
`buildAppRoutes()` in `app_router.dart` fügt alles zusammen; `test/routes/app_routes_test.dart` hält Namen und Pfade fest.
Deep Links (`shoply://plan`, `…/calories/add`, `…/avo/voice` usw.) gehen heute noch auf `/home`; eine gemeinsame
Übersetzungsstelle mit Fehlerseite kommt in S2.

### Module

- `lib/core/modules/app_modules.dart`: `enum AppModule { offers, mealPlan, calories, avo, costSplit }`,
  `moduleEnabledProvider(AppModule)` (bool, wirkt sofort), `appModulesProvider.notifier.setEnabled(m, on)` und
  `setAll(...)`.
- Gespeichert auf dem Gerät und in `user_preferences.modules` (jsonb). Die Migration
  `database/migrations/20261107230000_a_user_modules.sql` ist **angewendet** (07.11.2026, Projekt ShoplyAI, mit
  Freigabe des Owners).
- `AppModule.mealPlan` ist `released: false`: Er zählt überall als aus und erscheint weder im Onboarding noch in den
  Einstellungen, bis B den Wochenplan fertig hat. Dann bitte als Anfrage melden, A schaltet ihn frei. Zum Entwickeln:
  `setDebugUnlocked(AppModule.mealPlan, true)` (nur Debug-Build).
- Konten ohne gespeicherte Wahl (alle heutigen Nutzer) behalten alles; Kalorien folgen dem alten Schalter
  `calorie_tracking_enabled`.

## Festlegungen des Owners (07.11.2026)

- **App-Name: Avo.** Abo „Avo Pro“, Siri-Sätze und Texte sagen „Avo“. Die Bundle-ID bleibt `com.dominik.shoply`.
- **Module beim ersten Start** (der Owner hat die Wahl an A gegeben): Preise & Angebote **an**, Wochenplan **an**,
  Avo **an**, Kalorien & Gesundheit **aus**, Kosten teilen **aus** (wird beim ersten Teilen einer Liste einmal
  vorgeschlagen, Konzept F-15). Grund: Sparen und Planen helfen fast allen; Kalorien sind ein Nischenthema mit
  Gesundheitsdaten, Kosten teilen betrifft nur geteilte Listen.
- `claude/daily`: während des Umbaus pausieren, danach wieder einschalten (siehe Anfrage 1).
- **Paletten freigegeben** (hell = D2, dunkel und erhöhter Kontrast abgeleitet, alle Texte ≥ 4,5:1).
- **Abhak-Ring dunkler als D2:** #8A8A8E (3,4:1 statt 1,7:1), damit Bedienelemente 3:1 erreichen.
- **Home = D2 „Für dich“ wie im Artboard** (Owner 07.11.2026, mit Screenshot bestätigt; ersetzt „Startseite = Liste
  von heute“ aus Plan 2). Reihenfolge: Avo-Karte (Spar-Hinweis, „Angebote ansehen“, Feld „Frag Avo …“ → Avo-Tab,
  Chips), Dein November, Ausgaben im Vergleich, Sparziel mit Avo, Kalorien heute, Für dich (Weiter einkaufen, Nochmal
  kaufen, Angebote in der Nähe, Wasser heute), Top-Listen, Letzte Einkäufe, Heute kochen, Tipp von Avo. Für B heißt
  das: Spar-Hinweis, Monat/Ausgaben, Sparziel, Kalorien, Angebote-/Wasser-Kachel, letzte Einkäufe und Heute kochen
  (Wochenplan) kommen als B-Widgets; A baut die Hülle, die Reihenfolge und blendet nach Modul aus. Spar-Texte im
  Pflicht-Wortlaut aus Plan 8 („in deiner Region“).
- **Einkaufsmodus** startet über einen getönten Wagen-Knopf oben rechts in der Liste (nur mit offenen Artikeln) und
  über das Mehr-Menü.
- **Summe „≈ 23,80 €“** nur mit Modul Angebote und mindestens einem gespeicherten Preis: Summe der gespeicherten
  Preise der offenen Artikel, nie ein Marktvergleich.
- Von A entschieden (Konzept-Vorschläge): Teilen-Code künftig 6 Ziffern (alte Codes bleiben gültig), große Karte in
  der Listen-Übersicht = angeheftete bzw. zuletzt genutzte Liste mit Cover aus fester Fotoauswahl (sonst
  Farbquadrat), Diktat erst mit B's Sprachdienst.

## Anfragen an Teil B

**Vorrang-Liste mit allen Signaturen: [`prompt-b-vorrang.md`](prompt-b-vorrang.md)** (Stufe 1: Slot-Hüllen und
Provider in `lib/presentation/widgets/slots/b_slots.dart`; Stufe 2: Home-Abschnitte als Hüllen; Stufe 3: Avo im Tab).

1. ~~Routine `claude/daily` pausieren~~: laut B gibt es sie in keinem Account, der Branch hat keine eigenen Commits.
   Gegenstandslos, sofern der Owner nichts anderes weiß.
2. Slot-Hüllen mit endgültiger Signatur → jetzt genau festgelegt in `prompt-b-vorrang.md` Stufe 1 (inkl.
   `ItemOfferCard`, `ListOfferCountBadge`, `ArticleImage(size:, radius:)`, `storeForListProvider`,
   `openCheckoutFlow` mit Rückgabe `bool`, `OfferSuggestionsBar(onAdded:)`).
3. `calorieTrackingEnabledProvider` als Alias auf `moduleEnabledProvider(AppModule.calories)` (B: in Arbeit).
4. `offersRemoteEnabledProvider` und `offersAvailableProvider` (B: in Arbeit).
5. ~~Home-Hinweise ohne Springen~~ → ersetzt durch 6.
6. **Home-Abschnitte als Hüllen** mit synchronem `…HasContentProvider`: `prompt-b-vorrang.md` Stufe 2.
7. **Avo im Tab** ab S2a (kein `pop()` in der Tab-Wurzel, `/avo?q=` genau einmal, `avoScreenContextProvider` in einer
   B-Datei): `prompt-b-vorrang.md` Stufe 3.

## Antworten auf Anfragen von B (status-B 6–12)

| Nr. | Antwort | Wann |
|---|---|---|
| 6 S2-Komponenten | kommt in zwei Teilen: **S2a** (Tab-Bar mit Avo-Tab, Toolbar, Buttons, Gruppen, Chips, Segment, Stepper, Ring, Status, Leer, Skelett, Toast, Erfolg, Dialoge, ProBadge, Icons) und **S2b** (Vollbild-Editor, Glas-Eingabefeld, Menüs, Zeilen/Karten, Charts, `ProGate.run`) – Liste in `prompt-b-vorrang.md` | S2a heute, S2b direkt danach |
| 7 Avo-Kontext | `avoScreenContextProvider` legt B an (Signatur in `prompt-b-vorrang.md`), A setzt ihn; `openAppDestination` liefert A | mit S2b |
| 8 Home-Hinweise | Vertrag = Home-Abschnitte mit `…HasContentProvider` (Stufe 2) | ab jetzt |
| 9 `AppBrand`, `pro_features` | `AppBrand` (Name „Avo“) mit S2b; die Pro-Liste nach der Owner-Entscheidung in A9 | S2b / A9 |
| 10 Deep Links + Fehlerseite | fertig gebaut und getestet, kommt mit S2a | S2a |
| 11 `ShoppingItemModel.barcode` | gibt es schon (nullable) | erledigt |
| 12 Übergänge `ListPriceSummaryBar`, `OfferSuggestionsBar(query:, onSelect:)` | A nutzt beim Listen-Umbau nur `ListOfferSummary(listId:)` und `OfferSuggestionsBar(listId:, query:, onAdded:)` | A5 |

## Anfragen von B aus den Angebots-Slots (`b-screens/angebote.md` §6, status-B 13)

| Nr. | Stand | Wann |
|---|---|---|
| A-T1 Warnfarbe | **erledigt**: `context.colors.warning` (hell #A8521A, 4,5:1 in allen Paletten) | `d1b9eea` |
| A-T2, A-T3 Glas mit Text | **erledigt**: `ContentGlass` hell 92 %, getöntes Glas hell 96 % | `be2971f` |
| A-C10 Symbole | **erledigt**: location, storefront, eyeSlash, plusCircle, questionmarkCircle, exclamationmarkCircle, exclamationmarkTriangleFill, line3Horizontal, checkmarkCircleFill (dazu eye, circle, lightbulb, envelope, personBadgePlus, bookmarkSlash) | `54a2ee5` |
| A-Q1 Layout-Tests | **erledigt**: `test/layout/screens/b/*` gehört B | `ac3fb9a` |
| A-O1 Region im Onboarding | **festgelegt wie vorgeschlagen**: B zeichnet Inhalt und „Weiter“ und ruft `onDone`; A zeichnet Rahmen, Titel, Satz, Fortschritt, Zurück, „Überspringen“ (`OnboardingStepPage` ohne eigene Hauptaktion) | mit A7 |
| A-C1, A-C2, A-C3, A-C5, A-C7, A-C8, A-C9, A-D1 | angenommen; Komponenten und `ItemRepository` | direkt nach A7 |
| A-C4, A-L1–A-L4, Polsterung um `ListOfferSummary` | angenommen; Listen-Screens (A7-Teil „Tipps“ hat `list_detail_screen.dart` gerade in Arbeit, die Polsterung ist ihm mitgegeben) | nach A7 |
| A-R1–A-R3 | angenommen; Router (A7-Teil „Ablauf“ hat `app_router.dart` gerade in Arbeit) | nach A7 |
| A-P1 | angenommen; Profil | A8 |
| `openAvoWithQuestion` | `home_avo_card.dart` stellt A auf den b_slots-Helfer um und löscht die eigene Funktion, sobald B ihn liefert | wenn B meldet |

## Hinweise für B

- `item_merge_service.dart` gibt es nicht. **Geliefert (A5, vorgezogen):**
  `ItemRepository.instance.addItems(listId, [NewItem(name:, quantity:, unit:, category:, notes:)])` →
  `AddItemsResult(token, items)` und `undoAddItems(token)`. Ein Insert für alles, Zusammenführen mit offenen Artikeln
  gleichen Namens und gleicher Einheit, fehlende Kategorien im Hintergrund. Sobald `categorizeLocal` (B1.5) da ist,
  stellt A die Hintergrund-Kategorisierung darauf um.
- **Mengen-Parser** für alle Eingaben: `parseItemInput(text)` / `parseSingleItem(text)` in
  `lib/core/utils/item_input_parser.dart` („2 Milch“, „500 g Mehl“, „eine halbe Melone“). Avo und Siri können ihn
  ebenfalls nutzen.
- Lokal läuft auf Mac 1 Flutter 3.44.8; `pubspec.lock` wird dadurch beim Testen verändert. A committet die Lock-Datei
  nicht mit.

## Erledigte Anfragen von Teil B

| Nr. (status-B) | Was | Commit |
|---|---|---|
| 1 | Paywall verspricht keine Angebote mehr, `premium_feat_deals` entfernt | siehe `git log --grep "B request 1"` |
| 2 | `showAppBottomSheet` bleibt, bis B meldet, dass keine B-Datei es braucht | – (vorgemerkt) |
| 3 | `owner.sh`: `lib/presentation/screens/system/*` und `evals/*` gehören B | siehe `git log --grep "B request 3"` |
| 4 | `ItemRepository` kategorisiert lokal sofort (`categorizeLocal`), verfeinert im Hintergrund (`refineCategory`, `categorizeBatch`); kein A-Code nutzt mehr `GeminiCategorizationService`. Profil ohne `userZipCodeProvider` | `356168d`, `0c034cd` |
| 5 (Teil) | Remount-Schlüssel `ValueKey(themeMode-language)` in `app.dart` entfernt; synchroner Redirect folgt mit B3 | siehe `git log --grep "no app remount"` |

## Fragen an den Owner

Offen:
- Free gegen Pro: Varianten A/B/C in [`pro-konzept.md`](pro-konzept.md) (Analyse fertig 08.11.2026), dazu die dort
  genannten offenen Fakten (Testzeitraum, Beleg-Prüfung, RPC-Rechte, rechtliche Links).
- Neue Maskottchen-Grafiken und das finale App-Icon-Motiv (A10, mit Bild-Prompts).
- TestFlight und App Store (erst am Ende).

Beantwortet am 07.11.2026: App-Name, Module beim ersten Start, `claude/daily`, Paletten, Abhak-Ring, Migration der Modulwahl (siehe oben).
