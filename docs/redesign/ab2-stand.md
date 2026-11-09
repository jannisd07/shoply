# AB2 Anfragen von B: Listen, Router, Reste aus A5–A8 – Ergebnis (09.11.2026)

Auftrag: [`ab2-auftrag.md`](ab2-auftrag.md) (Teile „Router“, „Listen“, „Reste“). Commit: `git log --grep AB2`.
Gesamtsuite und `dart analyze` in einer sauberen Kopie von `origin/main`; nicht im Simulator angesehen.

## Ergebnis

**Router** (status-B 15, 16; A-R1–A-R3)
- Alle Vollbild-Routen von B (`bRootRoutes()` in `app_router.dart`) hängen **vor** der Shell; neue `RoutePaths`:
  `offersOfferPattern`, `offersRecipePattern`, `offersListPattern`, `storesPick`, `storesRegion`, `caloriesAdd`,
  `caloriesScan`, `caloriesGoalsSetup`. Test: aus dem Rezepte-Tab öffnen und schließen, Rezepte-Tab bleibt.
- `/offers` ohne A's `ModuleGate` (B's `_OffersGate` reicht). Kalorien `health`, `health/goals` waren schon da.
- Deep Link `shoply://offers?filter=regulars&q=…` → `weeklyOffersLocation(regulars:, query:)`.
- Kalorien A-R3 (festgehalten, nicht geändert): `/recipes/:id` aus Home wechselt in den Rezepte-Tab; `/recipe/:id`
  öffnet über jedem Tab.
- `lib/routes/areas/system_routes.dart` (gehört B, `systemSettingsRoutes = []`) unter `/settings` eingehängt.
- Einstellungssuche `_visible` prüft Modul der Zeile **und** der Seite. `SettingsExternalActions.openUrl` →
  `Future<bool>`.

**Listen** (A-C4, A-L1–A-L4, a7/a8-Reste)
- Vorschlags-Panel über dem Eingabefeld (`add_suggestion_panel.dart`): oben B's `OfferSuggestionsBar`, darunter
  Startvorschläge (Milch, Brot, Eier, Bananen, Butter; ab 5 eigenen häufigen die eigenen), je höchstens 5 Zeilen,
  höchstens 40 % Höhe; Fokus zurück nach Rückkehr von einer Route. `add_item_accessory.dart` unverändert.
- Listen-Info: Zeile „Markt der Liste“ (`openStorePicker(from: info)`) und Schalter „Angebote anzeigen“; Menü
  „Angebote dieser Liste“; Übersicht Sektion „Sparen“ mit „Angebote der Woche“. `StoreChip`, „ausblenden“,
  `ListOfferSummary` und einklappende Polsterung gab es schon.
- `ListOfferCountBadge` in den Zeilen „Andere Listen“/„Geteilt mit mir“.
- `openNewListEditor(context, {initialName, storeChainId})`, `openNewListEditorForId(...)` → `String?`, Zeile „Markt“
  im Editor.
- `todayListProvider` (angeheftet → zuletzt geöffnet → zuletzt geändert), `listsTodayFirstProvider`, `orderTodayFirst`.
- Listen-Schalter wirken: `showItemImages` (Liste, Zeilen, Einkaufsmodus), `suggestions` (neue Sektion „Vielleicht
  auch“, `list_maybe_also.dart`), `keepScreenOn` (Wakelock im Einkaufsmodus).
- `PinnedListNotifier._load` lässt einen vorher gesetzten Pin stehen. Leere Liste bei `arrival=new` ohne doppelten T1.

**Reste**
- `DestructiveRow(onTap: null, subtitle:)` gedimmt, `enabled: false`. `StatusRow`: Aktion rutscht unter den Text,
  wenn sie mehr als die halbe Zeile bräuchte.
- `NotificationCategory` + `shoppingStarted`, `cookingTimer`, `planReminder`, `dinnerIdeas`, `costSplitOpen`; Kochtimer
  übergeben `cookingTimer`.
- `recipeDietProfileProvider` liest `recipeAutoAdaptProvider`; Standard-Thema `ThemeMode.system` (K-32).
- Rezepte-Tab: `RecipesBrowseContent(tip:)` mit T6/T7 im `TipSlot`; alte Ernährungs-Hinweiszeile entfernt.
- Rezeptdetail: `RecipeOfferSummary` als letzte Zeile der Zutaten, `IngredientOfferBadge` an den Zutaten,
  `RecipeOffersCard` und die Lücke weg.
- Auf B's Provider umgestellt: `pendingChangesCountProvider` (alter Name bleibt als `@Deprecated`), E-Mail-Änderung
  über `SupabaseService`, `openSplitBalancesCountProvider`, `subscriptionRenewsOnProvider`,
  `proSubscriptionDetailsProvider` (`ProRowStatus.ofDetails`).
- War schon erledigt: PLZ-Feld (Seite gibt es nicht mehr), `home_avo_card` mit `openAvoWithQuestion`, Datenquellen als
  Route `/settings/legal/sources`.

## Braucht den Owner

- Server: Pushes bei geschlossener App kennen die neuen Mitteilungs-Kategorien erst mit `user_notification_prefs`
  (Entwurf in `a8-server-entwurf.sql`).

## Von Teil B (gewünscht)

- Siri/Widgets aus `avoSettingsRoutes` nach `systemSettingsRoutes` ziehen; in `siri_settings_screen.dart` bei
  `openUrl` == false einen Hinweis zeigen. Kommentar über `offersRootRoutes` (Shell-Rückfall) ist veraltet;
  `offer_paths.dart` könnte die Muster aus den neuen `RoutePaths` ableiten.
- `todayListProvider`/`listsTodayFirstProvider` in `b_slots.dart` exportieren und `offerTargetListsProvider` darauf
  umstellen; `listStoreRepositoryProvider` und `storeInfoForChain` exportieren (A importiert sie heute direkt aus
  `store_for_list_provider.dart`); `_toNewList` kann `storeChainId:` übergeben.
- `FCMService._categoryForType`: Push-Typen „Jemand kauft ein“ und „Offene Beträge“ auf die neuen Kategorien; der
  Wochenplan-Sender übergibt `planReminder`.
- Ein öffentlicher Provider „Zeile sichtbar?“ für `RecipeOfferSummary` (heute liest `recipe_detail_screen.dart`
  `recipeOffersCachedProvider`, `recipeOfferKey`, `offerListNameProvider`, `recipeIngredientOffersProvider.remember`).
- Fehler bei B: `RecipeOfferSummary` meldet Angebote nur bei Änderung an die Badges; wird sie eingehängt, wenn die Daten
  schon da sind, bleiben die Badges leer.

## Offen bei A

- Rezeptdetail (`recipe_detail_adaptation.dart`, `RecipeDietProfile.ofUser`) beachtet „Rezepte automatisch anpassen“
  noch nicht.
- Präsenz im Einkaufsmodus (`shopping_mode_header.dart`) soll `sharePresenceProvider` beachten.
- „Vielleicht auch“ nutzt `ListInfoActionRow`; eine `ItemRow`-Vorschlagsvariante (gestrichelter Kreis) fehlt.
- `ListCard` blendet das Cover ab AX1 nie aus; die Angebotspille bleibt dort auf dem Cover.
- Aus AB1 weiter offen: A-K10 Untermenüs, Galerie-Einträge, `SwipeActions`-Reste, Kalender-Menü, `AmountField`,
  `NutritionRow`, Charts mit Ziellinie, `InlineCalendar`, einklappbare `InsetSection`.
- Im Simulator ansehen (A11): Vorschlags-Panel, Listen-Info, Rezept-Zutaten mit Angeboten, Rezepte-Tab mit Tipp.

## Bewusst abgewichen

- `test/screens/profile/settings/settings_test_helpers.dart` (`FakeExternalActions.openUrl` → `Future<bool>`, Feld
  `urlOpens`) wurde mitgeändert, sonst kompiliert die Hilfsdatei nicht.
- A hat `system_routes.dart` als leere B-Datei angelegt (mit B abgesprochen).
- Wer die alte Ernährungs-Hinweiszeile weggewischt hat, bekommt T7 nicht mehr.
