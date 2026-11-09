# AB2 Anfragen von B: Listen, Router, Reste aus A5–A8 – gemeinsamer Auftrag (Teil A)

Stand 09.11.2026. Drei Teile laufen gleichzeitig: **„Router“**, **„Listen“**, **„Reste“**. Jeder Teil erledigt
Anfragen von Teil B und offene Punkte aus `a5-stand.md` bis `a8-stand.md`. Vorher prüfen, ob ein Punkt schon erledigt
ist (Code lesen); dann nur im Bericht vermerken.

## Ort und harte Regeln

- Repo `/Users/jannisdietrich/Apps/shoply-neu` (Flutter-App „Avo“, Dart-Paket heißt noch `shoply`). Jeder Bash-Befehl
  beginnt mit `cd /Users/jannisdietrich/Apps/shoply-neu && …`.
- **Teil B und zwei weitere AB2-Agenten arbeiten gleichzeitig im selben Ordner.** Keine git-Befehle, die etwas ändern
  (kein add, commit, stash, checkout, switch, restore, reset, clean, rm). Committen macht die Hauptsitzung.
- **Nur die Dateien deines Teils** (unten). Texte nur in den Textdateien deines Teils; vorhandene Schlüssel anderer
  Dateien darfst du benutzen. Ein doppelter Schlüssel ist ein Compile-Fehler. Neue Texte sagen „Avo“, nie „Shoply“;
  keine `\n`. Deutsch und Englisch, kurz und konkret.
- **Bestehende öffentliche APIs nicht brechen** (B nutzt sie). Nur optionale Parameter, neue Konstruktoren, neue
  Klassen. Ändert sich ein Aufrufer außerhalb deines Teils, kommt er in den Bericht.
- **`dart format` nur auf deine eigenen Dateien.**
- Prüfen nur auf deine Dateien: `dart analyze <deine Dateien>` (0 Errors, 0 Warnings, keine neuen Infos) und
  `flutter test --no-pub <eine Testdatei>`. **RAM und Platte sind knapp:** Tests nur dateiweise; vorher
  `pgrep -x flutter_tester | wc -l`, bei 2 oder mehr warten (`until [ $(pgrep -x flutter_tester | wc -l) -lt 2 ]; do
  sleep 20; done`). Lange Befehle mit `timeout 600`. Keine Builds, keine Simulatoren, keine Worktrees, keine
  Gesamtsuite, keine Unteragenten.
- **Keine Änderungen an Supabase.** Server-Bedarf in den Bericht.
- `bash docs/redesign/owner.sh <pfad>` zeigt, wem eine Datei gehört. B-Dateien nie ändern (z. B.
  `lib/presentation/widgets/slots/b_slots.dart`, alles unter `screens/offers/`, `screens/avo/`, `screens/system/`,
  `list_offer_*`, `store_chip*`, `offer_*`, `lib/routes/areas/{avo,calories,plan,offers,history}_routes.dart`,
  `pinned_list_provider.dart`); Wünsche an B in den Bericht.

## Pflichtlektüre

1. `CLAUDE.md` Abschnitt „Design System“ und die harte Regel: **keine Sheets, keine halbhohen Modals, keine Slider,
   Bearbeiten im Vollbild**; zentrierte Alerts und Pull-down-Menüs (`showAvoMenu`) sind erlaubt.
2. Tokens nur aus `package:shoply/core/design/design.dart`; Text nie in fester Höhe; Ziele ≥ 44 pt; neue/geänderte
   Screens und Komponenten bestehen `layoutMatrix` (`test/layout/layout_matrix.dart`).
3. `docs/redesign/ab1-stand.md` „Neue API“ (die neuen Komponenten nutzen statt eigener Bauten).
4. `docs/redesign/status-B.md` „Anfragen an Teil A“ Nr. 15 und 16; die Quellen deines Teils (unten).
5. Die B-Schnittstellen in `lib/presentation/widgets/slots/b_slots.dart` (nur lesen).

## Teil „Router“

**Dateien:** `lib/routes/**` außer den B-Dateien oben (neu erlaubt: `lib/routes/areas/system_routes.dart`),
`lib/presentation/screens/profile/settings_search_index.dart`, `lib/presentation/screens/profile/settings/data/settings_services.dart`,
`test/routes/**`, `test/screens/profile/settings_search*`, `docs/redesign/owner.sh`. Texte: `common.dart`.

1. **A-R1:** `offersRootRoutes`, `caloriesRootRoutes`, `planRootRoutes` (und die übrigen B-`…RootRoutes`) **vor** der
   Shell einhängen, Pfade in `RoutePaths`. Test: `/offers/offer/x` und `/calories/add` aus dem Rezepte-Tab öffnen und
   schließen, der Rezepte-Tab ist wieder sichtbar (`b-screens/angebote.md` §6 A-R1, `kalorien.md` A-R1,
   `wochenplan.md` A-R1).
2. **A-R2 `/offers`:** den `ModuleGate` um `buildOffersRoot` weglassen (B's `_OffersGate` deckt es ab, status-B 15).
   `/stores/*` und `/settings/offers*` ohne Wächter. Kalorien A-R2 (`caloriesSettingsRoutes` `health`,
   `health/goals`) prüfen.
3. **A-R3 Deep Links:** `shoply://offers`, `?filter=regulars`, `?q=` → `weeklyOffersLocation(regulars:, query:)`.
   Kalorien A-R3: Rezeptdetail aus dem Home-Tab – heutiges Verhalten im Bericht festhalten.
4. **status-B 16:** `system_routes.dart` mit `final List<RouteBase> systemSettingsRoutes = [];` anlegen, in
   `profile_routes.dart` unter `/settings` einhängen, in `owner.sh` B zuordnen (B verschiebt Siri/Widgets dorthin).
   Suche `_visible`: Modul der Zeile **und** der Seite prüfen (Test: Avo aus + Kalorien an → „Kalorien, Gewicht und
   Ziele“ wird nicht gefunden). `SettingsExternalActions.openUrl` → `Future<bool>` (false, wenn nichts öffnet).

## Teil „Listen“

**Dateien:** `lib/presentation/screens/lists/**` (nur A-Dateien), `lib/presentation/widgets/design/add_item_accessory.dart`,
`lib/presentation/state/lists_provider.dart`, `items_provider.dart`, `last_list_provider.dart`,
`lib/data/repositories/list_repository.dart`, `test/screens/lists/**`, Tests der genannten Dateien. Texte:
`lists*.dart`.

1. **A-C4** (`angebote.md` §6 und Z. 815): `AddItemAccessory` mit B-Block am oberen Ende des Vorschlags-Panels
   (höchstens 5 Zeilen, internes Scrollen), Fokus zurück ins Feld nach Rückkehr von einer Route (z. B. `/stores/region`).
   Dazu **Startvorschläge** vor dem ersten Buchstaben (a7-stand, Konzept 11 §9.8: Milch, Brot, Eier, Bananen, Butter
   bzw. die häufigsten eigenen).
2. **A-L1:** `StoreChip` in der Metazeile des Listenkopfs; Listen-Info: Zeile „Markt“ →
   `openStorePicker(…, from: StorePickerOrigin.info)` und `ToggleRow` „Angebote anzeigen“; Listenmenü „Angebote dieser
   Liste“ → `context.push(offerListLocation(listId))` und „Angebote für diese Liste ausblenden“, beide nur mit
   `offersAvailableProvider`; Übersicht „Angebote der Woche“ → `weeklyOffersLocation()`; `ListOfferSummary` nach der
   letzten offenen Kategorie vor „Erledigt“ und im Einkaufsmodus unter dem Kopf, **Polsterung klappt ein**, wenn sie
   nichts zeigt (heute 24 pt Lücke).
3. **A-L2:** Listenkarte: `ListOfferCountBadge` in der Metazeile, wenn das Cover ab AX1 fehlt.
4. **A-L3:** „Neue Liste“-Editor mit vorausgewähltem Markt und Rückgabe der neuen Listen-ID (für „Neue Liste …“ im
   Menü „Auf welche Liste?“ von B; API im Bericht).
5. **A-L4:** Provider „Liste von heute“ (Reihenfolge im Menü, Ziel-Liste im Rezept); Definition in `angebote.md` (L9).
6. **Listen-Schalter verdrahten** (a8-stand): `listPreferencesProvider.showItemImages` und `.suggestions` in der
   Liste, `.keepScreenOn` im Einkaufsmodus (ohne neues Paket; gibt es keins im `pubspec.yaml`, in den Bericht).
7. **PinnedListNotifier-Rennen** (status-B 16): Liegt der Notifier in einer A-Datei, lässt `_load` einen vorher
   gesetzten Pin stehen; liegt er bei B, in den Bericht.
8. Leere Liste bei `arrival=new` doppelt T1 nicht (a7-stand); Test-Fund `list_settings_screen_test.dart` „all changes:
   sections per day“ zwischen 0 und 2 Uhr (feste Uhr statt `now`).

## Teil „Reste“

**Dateien:** `lib/presentation/widgets/design/settings_rows.dart`, `status_row.dart`,
`lib/data/services/notification_preferences_service.dart`, `lib/presentation/state/theme_provider.dart`,
`lib/presentation/state/recipes_provider.dart` und weitere A-Rezept-Provider, `lib/presentation/screens/recipes/**`,
`lib/presentation/screens/profile/**` **außer** `settings_search_index.dart` und `settings/data/settings_services.dart`,
`lib/presentation/screens/home/**`, ihre Tests. Texte: `profile*.dart`, `settings*.dart`, `recipes*.dart`, `home*.dart`.

1. **`DestructiveRow`** mit `onTap: null` und `subtitle`: gedimmt, `Semantics(enabled: false)`.
2. **`StatusRow`:** die Aktion bricht bei 320 pt ×1,35 nicht mehr über (umbrechen oder unter den Text stapeln).
3. **Mitteilungs-Kategorien durchsetzen** (a8-stand): `shoppingStarted`, `cookingTimer`, `planReminder`, `dinnerIdeas`,
   `costSplitOpen` – dort, wo A-Code Mitteilungen auslöst, die Kategorie prüfen; B-Sender in den Bericht
   (`dinnerIdeas` setzt B schon über `notif_dinner_ideas` durch).
4. `recipeDietProfileProvider` liest `recipeAutoAdaptProvider`; `theme_provider.dart` Standard `ThemeMode.system` (K-32).
5. **T6 im Rezepte-Tab:** `RecipesBrowseContent(tip:)` einbauen, danach den Ernährungs-Hinweis von A6 durch T7 als
   Tipp-Zeile ersetzen (Test `recipes_browse_screen_test.dart` anpassen; a7-stand).
6. **A-C6 Rezept:** `RecipeOfferSummary(recipe:, listId:)` als letzte Zeile der Gruppe „Zutaten“,
   `IngredientOfferBadge(listId:, ingredient:)` an den Zutatenzeilen, statt `RecipeOffersCard`; keine Lücke, wenn
   nichts kommt (status-B 15).
7. **Aufrufer umstellen** (status-B 16): `unsentChangesProvider` → `pendingChangesCountProvider`, eigene
   E-Mail-Änderung → `SupabaseService.requestEmailChange`/`verifyEmailChange`, `DeletionSummary.openBalances` →
   `openSplitBalancesCountProvider`, Pro-Zeile → `proSubscriptionDetailsProvider`, Präsenz → `sharePresenceProvider`.
   Nur, wo die B-Provider schon auf `main` sind.
8. **Persönliche Daten:** PLZ-Feld in `personal_info_screen.dart` entfernen (Region wohnt in `/settings/offers/region`).
9. Prüfen und nur bei Bedarf: `home_avo_card.dart` nutzt `openAvoWithQuestion` aus `b_slots.dart` (keine eigene
   Funktion mehr); Datenquellen-Seite ist eine Route unter Rechtliches.

## Bericht (letzte Antwort, höchstens 40 Zeilen)

1. Erledigt: je Punkt ein Satz mit Datei(en); „war schon erledigt“ ausdrücklich.
2. Geänderte und neue Dateien (vollständige Liste, für den Commit).
3. Prüfung: `dart analyze` (Zahlen) und welche Testdateien grün liefen.
4. Neue API für B.
5. Offen, Wünsche an B, Server-Bedarf, bewusst abgewichen.
