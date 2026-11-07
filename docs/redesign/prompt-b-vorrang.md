# Teil B: Vorrang-Aufgaben, damit niemand wartet (von Teil A, 07.11.2026)

Für die Claude-Session von Teil B (Jannis). Zuerst `git pull --rebase origin main`, dann dieses Dokument und
`docs/redesign/status-A.md` lesen. Danach diese Aufgaben **vor** allem anderen erledigen, in dieser Reihenfolge. Jede
Stufe sofort pushen (eigene kleine Commits, `bash docs/redesign/check-ownership.sh B`, `dart analyze` 0/0).

**Prinzip:** Teil B liefert zuerst **leere Hüllen mit der endgültigen Signatur** (rendern `SizedBox.shrink()` bzw. tun
nichts). Teil A baut seine Screens dagegen und muss nie auf echte Daten warten. Die Inhalte füllt B danach in Ruhe;
eine Signatur ändert sich nur per Anfrage in `status-B.md`. Umgekehrt liefert A die S2-Komponenten in Teilen (S2a, S2b,
siehe unten), damit B seine Screens früh darauf bauen kann.

---

## Stufe 1 (sofort, Ziel: unter 2 Stunden): Slot-Hüllen und Provider

Eine einzige Import-Datei **`lib/presentation/widgets/slots/b_slots.dart`** (gehört B), die alle Slots exportiert. Die
Implementierungen dürfen in beliebigen B-Dateien liegen; A importiert nur diese eine Datei.

| Name und Signatur | Wo A es einsetzt | Hülle bis S4 |
|---|---|---|
| `StoreChip({required String listId})` | Listenkopf, Einkaufsmodus, Listen-Info | `SizedBox.shrink()` |
| `OfferSuggestionsBar({required String listId, required String query, VoidCallback? onAdded})` – B legt den gewählten Artikel selbst an (mit Preis), `onAdded` lässt A das Feld leeren | Vorschlags-Panel beim Tippen | `SizedBox.shrink()` |
| `ItemOfferBadge({required String listId, required ShoppingItemModel item, bool compact = false})` – `compact`: nur Preis (Einkaufsmodus) | Artikelzeile rechts | `SizedBox.shrink()` |
| `ItemOfferCard({required String listId, required ShoppingItemModel item})` | Artikel-Vollbild (D2-Artikel, grüne Angebotskarte) | `SizedBox.shrink()` |
| `ListOfferSummary({required String listId})` | Liste unten, Einkaufsmodus oben | `SizedBox.shrink()` |
| `ListOfferCountBadge({required String listId})` („2 Angebote“ auf dem Cover) | Listenkarte | `SizedBox.shrink()` |
| `ArticleImage({required ShoppingItemModel item, double size = 44, double radius = 10})` | Artikelzeile, Kacheln, Artikel-Vollbild | `SizedBox.square(dimension: size)` mit neutraler Fläche (`context.colors.fill`) |
| `Future<bool> openCheckoutFlow(BuildContext context, String listId)` – `true`, wenn der Einkauf gespeichert wurde | „Einkauf abschließen“ | ruft vorerst den heutigen Abschluss auf oder liefert `false` |
| `RecipeOffersCard({required Recipe recipe})` (den alten Konstruktor `request:` bis zum Umbau behalten) | Rezeptdetail | `SizedBox.shrink()` |
| `Future<void> openLogRecipe(BuildContext context, Recipe recipe)` | Rezeptdetail, Menü | ruft vorerst `showLogRecipeSheet` oder nichts |
| `Future<void> setOffersHiddenForList(WidgetRef ref, String listId, bool hidden)` und `offersHiddenForListProvider` (`Provider.family<bool, String>`) | Listen-Menü „Angebote für diese Liste ausblenden“ | speichert lokal, liefert `false` |
| `OffersSetupStep({required VoidCallback onDone})` | Onboarding, wenn das Angebots-Modul an ist | ruft `onDone` sofort |
| `storeForListProvider` (`Provider.family<StoreInfo?, String>`), `StoreInfo { String id; String name; String shortLabel; Color? brandColor; }` | Einkaufsmodus, Präsenz-Text („Lena kauft gerade bei Lidl ein“), Gang-Reihenfolge | `null` |
| `offersRemoteEnabledProvider`, `offersAvailableProvider` (Modul an **und** Kill-Switch an) | Onboarding, Einstellungen, Home, Listen | wie geplant |

Dazu (schon in Arbeit): `calorieTrackingEnabledProvider` als Alias auf `moduleEnabledProvider(AppModule.calories)`.

Hinweis: `ShoppingItemModel.barcode` gibt es schon (nullable); Anfrage 11 ist damit erledigt.

## Stufe 2 (direkt danach): Home-Abschnitte als Hüllen

Home wird **genau wie D2 „Für dich“** (Owner-Entscheidung, siehe `status-A.md`). A baut den Rahmen, die Reihenfolge
und das Ausblenden nach Modul. B liefert die Abschnitte als Widgets in derselben Datei `b_slots.dart`, jeweils mit einem
**synchronen** Provider aus dem kontobezogenen Cache, ob es Inhalt gibt (sonst springt das Layout):

| Widget | `…HasContentProvider` (`Provider<bool>`) | D2-Abschnitt | Modul |
|---|---|---|---|
| `HomeSavingsHint()` | `homeSavingsHintHasContentProvider` | Text in der Avo-Karte oben („Lidl lohnt sich …“) + „Angebote ansehen“ – Wortlaut nach Plan 8 („in deiner Region“) | offers |
| `HomeMonthCard()` | `homeMonthHasContentProvider` | „Dein November“ (Ausgaben, Gespart nur mit offers, Einkäufe) | – |
| `HomeSpendingComparison()` | `homeSpendingHasContentProvider` | „Ausgaben im Vergleich“ (6 Balken, ab AX1 als Liste) | – |
| `HomeSavingsGoal()` | `homeSavingsGoalHasContentProvider` | „Sparziel mit Avo“ | offers |
| `HomeCaloriesToday()` | `homeCaloriesHasContentProvider` | „Kalorien heute“ + „Mahlzeit hinzufügen“ | calories |
| `HomeRestockTile()` | `homeRestockHasContentProvider` | Kachel „Nochmal kaufen“ (Plus nutzt `addItems` + Rückgängig) | – |
| `HomeOffersTile()` | `homeOffersTileHasContentProvider` | Kachel „Angebote …“ (nie „in der Nähe“ ohne Standort) | offers |
| `HomeWaterTile()` | `homeWaterHasContentProvider` | Kachel „Wasser heute“ | calories |
| `HomeRecentTrips()` | `homeRecentTripsHasContentProvider` | „Letzte Einkäufe“ (max. 3, „Alle anzeigen“ → `/history`) | – |
| `HomeCookToday()` | `homeCookTodayHasContentProvider` | „Heute kochen“ (Wochenplan; „Fehlende n auf die Liste“ über `addItems`) | mealPlan |

Hüllen: Widget = `SizedBox.shrink()`, Provider = `false`. Die Karten zeichnet B später selbst mit A-Bausteinen
(`InsetSection`/Karte, `SectionCaps`, `AppButton`, `ProgressRing`, `ProgressLine`, `RecipeHeroCard`), außen ohne Rand:
A setzt 16 pt Seitenrand und die Abstände. Jeder Abschnitt muss `layoutMatrix` aus `test/layout/layout_matrix.dart`
bestehen. Die alten Karten (`avo_nudge_card`, `personal_flyer_card`, `calorie_recipe_nudge_card`,
`pending_splits_banner`, `price_comparison_nudge_card`, `split_trip_nudge_card`) zeigt Home ab A4 nicht mehr; B
überführt oder löscht sie.

## Stufe 3 (sobald S2a in `main` ist): Avo im Tab

- `/avo` ist ab S2a die Wurzel des Avo-Tabs. Der Avo-Chat darf dort **nicht** `context.pop()` aufrufen (Zurück-Knopf
  weg; X-Avo hat keinen). Die Eingabe sitzt über der Tab-Bar: unterer Abstand `ShellInsets.bottom(context)` bzw.
  `ShellInsets.aboveTabBar(context)` aus `lib/core/design/design.dart`.
- `buildAvoRoot` liest `state.uri.queryParameters['q']` und schickt die Frage **genau einmal** als Nutzer-Nachricht
  (Feld „Frag Avo …“ auf Home öffnet `/avo?q=…`).
- `avoScreenContextProvider` legt **B** in einer eigenen Datei an (`StateProvider<AvoScreenContext?>`,
  `AvoScreenContext { String screen; String? listId; String? listName; }`) und meldet den Pfad in `status-B.md`; A setzt
  ihn in seinen Screens. Den Navigations-Helfer `openAppDestination(BuildContext, String id)` liefert A mit S2b.

## Stufe 4: wie geplant

`categorizeLocal`/`refineCategory` (A stellt `item_repository.dart` dann sofort um), dann der übrige Plan von Teil B.

---

## Was A wann liefert (Antwort auf Anfragen 6–12 in `status-B.md`)

- **S2a (als Nächstes, heute):** Tokens (schon da), D2-Tab-Bar mit **Avo-Tab auf `/avo`**, Kalorien als Push im
  Home-Tab, Fehlerseite, Modul-Wächter, Deep-Link-Übersetzung (`shopping?list=`, `lists/<id>?focus=add`, `avo/voice`,
  `plan?day=`, `calories/water?ml=`) und diese Komponenten: `GlassToolbar`, `GlassIconButton`, `GlassButtonGroup`,
  `ScrollEdgeFade`, `AppButton` (getönte Kapsel = `primary`), `InsetSection`, `SectionCaps`, `NavRow`/`ToggleRow`/
  `ValueRow`, `AppFilterChip`/`ChipRow`, `AppSegmentedControl`, `ValueStepper` (kompakt), `CheckCircle`, `ProgressLine`,
  `ProgressRing`, `AvoSearchField`, `StatusRow`, `EmptyState`, `SkeletonSection`, `AvoToast` + `AvoToastHost`,
  `showSuccessMoment`, `showAvoConfirm`, `showModuleOffAlert`, `HintRow`, `ProBadge`, `AvoFigure`, `AvoIcons`.
- **S2b (direkt danach):** `FullScreenEditor` (= EditorScaffold, Vollbild-Bearbeiten mit Schließen/Fertig),
  `AddItemAccessory` (Glas-Eingabefeld, auch als Vorlage für den Avo-Composer), `AvoMenuButton`/`showAvoMenu`,
  `ItemRow`, `ListCard`, `RecipeCard`, `RecipeHeroCard`, `Avatar`, einfache Balken-Charts, `openAppDestination`,
  `AppBrand` (Name „Avo“) und `ProGate.run` (bis A9 entschieden ist: führt die Aktion aus bzw. öffnet `/pro`).
- Danach Home (A4) mit den Slots aus Stufe 2, dann Listen (A5) mit den Slots aus Stufe 1.

Alles Weitere wie in `arbeitsteilung.md`: nur eigene Dateien, Anfragen über die Status-Dateien.
