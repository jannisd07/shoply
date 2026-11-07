# Status Teil A (Owner, Mac 1)

Diese Datei schreibt nur Teil A. Teil B liest sie nach jedem `git pull`. Aufbau laut `arbeitsteilung.md` Abschnitt 5.

## Stand

07.11.2026: **S1 ist erreicht.** Übersetzungen und Router liegen in Bereichsdateien, das Modulsystem steht. B darf ab
jetzt seine eigenen Übersetzungs- und Routendateien ändern und `moduleEnabledProvider` abfragen. Als Nächstes baut A das Fundament (A2: Tokens, Komponenten, D2-Tab-Bar,
Prüfgerüst). A3 ist erledigt. Aus A2 sind schon da und nutzbar: Tokens (`lib/core/design/design.dart`:
`context.colors`, `context.text(AvoTextStyle.body)`, `AvoSpacing`, `AvoRadii`, `AvoMotion`, `AvoHaptics`) und das
Prüfgerüst `test/layout/layout_matrix.dart` (`layoutMatrix('Name', (context) => Widget())`). Komponenten und Tab-Bar
folgen mit S2. Plan: `docs/superpowers/plans/2026-11-07-teil-a.md`.

## Meilensteine

| Meilenstein | Stand | Datum | Commit |
|---|---|---|---|
| S0 Aufräumen gemergt | erledigt: `cleanup/group-A` bis `-I` sind in `main` (Merges `b219010` … `6c12eef`, Abgleich `950921d`) | 07.11.2026 | `950921d` |
| S1 Struktur | **erledigt** | 07.11.2026 | siehe `git log --grep "(a1)"` |
| A3 Eingabeleiste (Bug der Mutter des Owners) | **erledigt**: Text wird bei keiner Breite (320–440 pt) und keiner Textgröße (bis 3,1×) mehr abgeschnitten, Nachweis `test/screens/lists/add_item_composer_test.dart` (40 Fälle) | 07.11.2026 | siehe `git log --grep "(a3)"` |
| S2 Fundament | offen | | |
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

## Anfragen an Teil B

1. **Routine `claude/daily` pausieren.** Sie ist in Dominiks Account nicht auffindbar (weder Cloud-Routinen noch lokale
   geplante Aufgaben) und läuft vermutlich über Jannis' Account. Bitte dort pausieren. Nach S6 wieder einschalten; A
   erinnert daran (letzte Aufgabe im Plan).
2. **Slot-Stubs früh pushen**, mit endgültiger Signatur und `SizedBox.shrink()` bzw. leerem Verhalten, damit A die neue
   Liste dagegen bauen kann: `StoreChip(listId:)`, `OfferSuggestionsBar(listId:, query:)`,
   `ItemOfferBadge(listId:, item:)`, `ListOfferSummary(listId:)`, `ArticleImage(item:)`,
   `openCheckoutFlow(context, listId)`, `RecipeOffersCard(recipe:)` (heute `request:`; bitte den alten Konstruktor
   behalten, bis A umgestellt hat), `openLogRecipe(context, recipe)`, `setOffersHiddenForList(listId, hidden)` und
   `offersHiddenForListProvider(listId)`, `OffersSetupStep(onDone:)`.
3. **`calorieTrackingEnabledProvider` zum Alias machen** auf `moduleEnabledProvider(AppModule.calories)` (lesen) und
   `setEnabled` auf `appModulesProvider.notifier.setEnabled(AppModule.calories, …)`. A ersetzt die Aufrufe in seinen
   Dateien (main_scaffold, profile, onboarding, recipe_detail) bei den Umbauten.
4. **Kill-Switch lesbar machen:** ein Provider `offersRemoteEnabledProvider` (bool, aus dem Cache von `app_flags`). A
   braucht ihn für eigene Flächen (Modul-Schalter in Onboarding und Einstellungen, Sektion „Sparen“, Paywall).
5. **Hinweise auf Home ohne Springen:** Für die Regel „höchstens zwei Hinweise“ braucht A pro B-Hinweis vorab (synchron
   aus dem Cache) die Info, ob er Inhalt hat. Vorschlag kommt mit dem A4-Plan; bitte bis dahin keine neue Home-Karte
   fest einbauen.

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
| 5 (Teil) | Remount-Schlüssel `ValueKey(themeMode-language)` in `app.dart` entfernt; synchroner Redirect folgt mit B3 | siehe `git log --grep "no app remount"` |

## Fragen an den Owner

Offen:
- Free gegen Pro (kommt nach der Analyse in A9).
- Neue Maskottchen-Grafiken und das finale App-Icon-Motiv (A10, mit Bild-Prompts).
- TestFlight und App Store (erst am Ende).

Beantwortet am 07.11.2026: App-Name, Module beim ersten Start, `claude/daily`, Paletten, Abhak-Ring, Migration der Modulwahl (siehe oben).
