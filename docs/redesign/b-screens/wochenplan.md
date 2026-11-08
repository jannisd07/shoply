# Wochenplan: Screen-Spezifikation (Teil B, Paket B7)

Stand 08.11.2026. Bauplan für alle Screens des Moduls `AppModule.mealPlan`, damit B7 direkt nach S2a/S2b von Teil A
gebaut werden kann. Diese Datei enthält keinen Code.

Quellen und Rang: Jannis' Plan (Punkt 5: „Rezepte wählen, Portionen anpassen, ein Tipp → alles auf der Liste“), dann
D2 · Glas (`X-Wochenplan`, `D2-Komponenten`, `D2-Rezepte`, `D2-FuerDich` Abschnitt 10 „Heute kochen“, `D2-Artikel`
und `X-Essen` als Muster für Vollbild-Screens, `X-Angebote` als Muster für Einstellungen), dann Konzept
`docs/redesign/konzept/14-wochenplan.md` (Funktionen, Abläufe, Zustände, Texte, Barrierefreiheit). Verträge aus
`status-A.md` (Routen, Module, Übersetzungen) und `prompt-b-vorrang.md` (Komponentennamen S2a/S2b, Home-Abschnitt
`HomeCookToday`). Owner-Regeln gelten immer: keine Bottom-Sheets, Slide-in-Panels, Drawer oder Slider; Bearbeiten und
Auswählen als eigener Vollbild-Screen mit eigener Route; kurze Bestätigungen als zentrierter Dialog; Avo nur als echte
Figur aus `assets/avo/`, höchstens eine pro Bildschirmhöhe; Trefferflächen mindestens 44 pt.

Wo D2 und Konzept sich widersprechen, steht in Abschnitt 5 eine Empfehlung. Sie gilt, bis der Owner entscheidet.
Komponentennamen in `Code-Schrift` sind Bausteine von Teil A (S2a/S2b, Tokens aus `lib/core/design/design.dart`) oder
B-eigene Bausteine in `lib/presentation/screens/plan/widgets/` (Abschnitt 2.3). Alle Texte stehen hier Deutsch und
Englisch und kommen nach `lib/core/localization/translations/plan.dart` mit Präfix `plan_`. Sie sind mit
`design:ux-copy` und danach `humanizer` geprüft: Du-Form, Satzanfang groß, keine Ausrufezeichen, keine Emojis, keine
Werbesprache, Aktionen heißen nach dem, was passiert, dieselbe Sache heißt überall gleich. Angebote nur mit „in deiner
Region“, „laut Händler“, „ca.“; Kalorien nur mit „Richtwerte, kein ärztlicher Rat“.

Geprüft mit den Skills `apple-design` (Federn, Unterbrechbarkeit, Wischen mit Wurfprojektion, Materialien, Reduce
Motion), `design-taste-frontend` (App-Screen-Regeln: eine Frage pro Screen, ein Befund zuerst, Hauptaufgabe einen Tipp
entfernt, ehrliche Leer- und Fehlerzustände; auf iOS gewinnt Apples Liquid Glass gegen die Web-Regel „kein Glas“),
`frontend-design`, `ui-ux-pro-max` (Pre-Delivery-Checkliste Mobil), `design:ux-copy`, `humanizer`,
`design:accessibility-review` (alle Kontraste in 3.7 nachgerechnet, nicht aus dem Konzept übernommen).

## Inhalt

0. Überblick
1. Routen und Navigation
2. Bausteine und Maße aus D2
3. Regeln für alle Screens
4. Screens S1 bis S13, Dialoge D1 und D2
5. Konflikte zwischen D2 und Konzept
6. Anfragen an Teil A
7. Datenquellen und Lücken
8. Tests beim Bau
9. Prüfliste für Screenshots

---

## 0. Überblick

**Hauptfrage des Bereichs:** Was essen wir diese Woche, und ist alles auf der Liste?

**Befund, der zuerst gelesen wird:** wie viele Zutaten noch fehlen. Er steht zweimal: pro Rezept in der Metazeile
(„2 Zutaten fehlen“) und als Zahl in der einen Hauptaktion („5 Zutaten auf Wocheneinkauf“).

**Hauptaufgabe, einen Tipp entfernt:** fehlende Zutaten auf die Liste setzen (getönte Kapsel über der Tab-Leiste).
Planen selbst (Rezept auf einen Tag legen, Portionen, verschieben, entfernen) passiert sofort, lokal zuerst, ohne
Speichern-Knopf und mit Rückgängig.

| Nr. | Screen | Art | D2-Vorlage |
|---|---|---|---|
| S1 | Wochenplan (Segment „Wochenplan“ im Rezepte-Tab) | Segment | `X-Wochenplan` |
| S2 | Rezept wählen | Vollbild (V) | aus `D2-Rezepte` (Suchfeld, Segment, Rezeptzeile) |
| S3 | Zutaten der Woche | V | aus `D2-Komponenten` (Artikelzeile, Pille), `X-Essen` (Kapsel unten) |
| S4 | Menge ändern | V, Folgeschritt | `D2-Artikel` (Menge, Einheit) |
| S5 | Hast du meist da (aus S3) | V, Folgeschritt | gleiches Widget wie S13 |
| S6 | Verschieben | V | wie S8 |
| S7 | Woche wählen | V | aus `D2-Komponenten` |
| S8 | Zum Wochenplan („Anderes Datum …“) | V | `D2-Artikel` (Kopf, Gruppen) |
| S9 | Rezeptdetail aus dem Plan | Screen von A, Slot von B | `D2-Rezepte` (Detail von A) |
| S10 | Home-Abschnitt „Heute kochen“ | Abschnitt auf Home | `D2-FuerDich` Abschnitt 10 |
| S11 | Einstellungen Wochenplan | Einstellung (E) | `X-Angebote`, `X-Profil` |
| S12 | Liste für neue Wochen | E, Folgeschritt | `X-Angebote` |
| S13 | Hast du meist da | E, Folgeschritt | `X-Angebote` |
| D1 | „Wochenplan ist ausgeschaltet“ | zentrierter Dialog | – |
| D2 | Erinnerung erlauben (vor der Systemabfrage) | zentrierter Dialog | – |

Erfolgsmoment, Rückgängig-Hinweis und alle Menüs gehören zu S1 (4.1.10, 3.6, 4.1.6). Widget, Siri und Avo-Werkzeuge
sind nicht Teil dieser Datei (B9, B5); sie lesen dieselben Provider (Abschnitt 7).

---

## 1. Routen und Navigation

### 1.1 Arten von Routen (Vertrag aus `status-A.md`, Datei `lib/routes/areas/plan_routes.dart`)

Gleiche Einteilung wie `b-screens/kalorien.md`, damit sich alle B-Bereiche gleich verhalten:

| Art | Liste in der Bereichsdatei | Wo es öffnet | Kopf | Tab-Leiste |
|---|---|---|---|---|
| Segment | `buildPlanSegment(context)` | unter A's Segment „Entdecken / Wochenplan“ im Rezepte-Tab, Pfade `/plan` und `/recipes?segment=plan` | Toolbar des Rezepte-Tabs (A) mit B-Knöpfen (6, A-P2) | sichtbar |
| V (Vollbild) | `planRootRoutes`, Pfade absolut (`'/plan/add'`) | Root-Navigator über der Tab-Leiste, über dem Tab, aus dem man kommt | `xmark` „Schließen“ am Anfang eines Ablaufs, `chevron.left` „Zurück“ im Folgeschritt | nicht sichtbar |
| Kind eines Rezepts | `planRecipeRoutes`, relativ zu `/recipes/:recipeId` | nur `to-plan` als Weiterleitung auf S8 | – | – |
| E (Einstellung) | `planSettingsRoutes`, relativ zu `/settings` | Profil-Tab | Glas-Knopf 44 `chevron.left` | sichtbar |

Warum V-Routen und keine Kinder von `/plan`: „Zutaten der Woche“ öffnet auch aus dem Avo-Tab (Ergebniskarte
„Ansehen“), „Zum Wochenplan“ auch aus einem Rezept, das auf Home geöffnet wurde. Als Kind von `/plan` würde GoRouter den
Rezepte-Tab darunterbauen und „Schließen“ landete im Wochenplan statt dort, wo man war. Dafür müssen `planRootRoutes`
vor der Shell stehen (Anfrage A-R1, dieselbe wie bei Kalorien).

**Übergang:** Jede V- und E-Route öffnet mit dem normalen iOS-Push von rechts (`CupertinoPage`, Zurück-Wischen vom
linken Rand folgt dem Finger). Nie `fullscreenDialog: true`, weil das von unten hereingleitet (Owner-Regel). Kein Screen
dieses Bereichs öffnet als Sheet, halbhohes Modal oder Popup.

### 1.2 Alle Pfade

| Nr. | Pfad | Name | Art | Parameter | Zurück führt zu |
|---|---|---|---|---|---|
| S1 | `/plan`, `/recipes?segment=plan` | `plan` | Segment | `week=YYYY-MM-DD` (Montag; fehlt: laufende Woche), `day=YYYY-MM-DD` (öffnet dessen Woche und scrollt zu ihm) | – (Tab-Wurzel) |
| S2 | `/plan/add` | `plan-add` | V | `day=YYYY-MM-DD` (Pflicht) | S1 |
| S3 | `/plan/to-list` | `plan-to-list` | V | `week=` (fehlt: laufende Woche), `from=avo` (nur Analytics) | Ausgangsort |
| S4 | `/plan/to-list/amount` | `plan-amount` | V, Kind von S3 | `key=` (Gruppenschlüssel der Zutat, kommt aus S3) | S3 |
| S5 | `/plan/to-list/pantry` | `plan-pantry` | V, Kind von S3 | – | S3 (Auswahl in S3 bleibt erhalten) |
| S6 | `/plan/move` | `plan-move` | V | `entry=<entryId>` | S1 |
| S7 | `/plan/week` | `plan-week` | V | `from=YYYY-MM-DD` (gerade gezeigte Woche) | S1 |
| S8 | `/plan/schedule/:recipeId` | `plan-schedule` | V | `servings=` (aus dem Detail), `day=` (optional vorgewählt) | Ausgangsort (Rezeptdetail, Avo) |
| S8 | `/recipes/:recipeId/to-plan` | `recipe-to-plan` | Weiterleitung | wie S8 | leitet auf `/plan/schedule/:recipeId` um |
| S9 | `/recipes/:recipeId?entry=<entryId>` | `recipe-detail` (A) | Push im Rezepte-Tab (A) | `entry=` | S1 |
| S11 | `/settings/plan` | `settings-plan` | E | – | Profil |
| S12 | `/settings/plan/list` | `settings-plan-list` | E | – | S11 |
| S13 | `/settings/plan/pantry` | `settings-plan-pantry` | E | – | S11 |

Statische Pfade stehen vor Pfaden mit Parameter. Unter `/plan` gibt es keinen Parameter auf erster Ebene, damit kein
`/plan/:x` die festen Pfade fängt (Falle aus `app_router.dart`: `/recipes/:recipeId` fängt sonst `/recipes/plan`).

**Modul aus:** Jeder Builder in `plan_routes.dart` prüft zuerst `moduleEnabledProvider(AppModule.mealPlan)`. Ist es
aus, rendert die Route nichts, ruft `showModuleOffAlert(context, AppModule.mealPlan, onEnable: …)` (D1) und kehrt dorthin
zurück, wo man herkam; bei Deep Links auf `/recipes`. Nach „Einschalten“ öffnet die ursprünglich gewünschte Route.

### 1.3 Deep Links, Mitteilungen, Avo

| Quelle | Ziel |
|---|---|
| `shoply://plan`, `shoply://plan?day=2026-11-12` | A's Deep-Link-Übersetzung (S2a) → `/plan?day=…` |
| Mitteilung „Nächste Woche ist noch leer. Jetzt planen?“ | `/plan?week=<Montag der nächsten Woche>` |
| Avo „Ansehen“ nach `plan_to_list` | `/plan/to-list?week=…&from=avo` |
| Avo „Ansehen“ nach `add_to_plan`, `fill_plan`, `move_in_plan` | `/plan?day=…` |
| Widget, Siri (B9) | `/plan?day=…` bzw. `/recipes/:id?entry=…` |
| Home „Heute kochen“ (S10) | Karte: `/recipes/:id?entry=…`; „Alle“: `/plan?day=<heute>` |

Jeder Plan-Screen setzt beim Erscheinen `avoScreenContextProvider` auf `screen: 'plan'` bzw. `'plan_to_list'` (Vertrag
aus `prompt-b-vorrang.md`, Datei von B), damit Avo im Avo-Tab weiß, worum es gerade geht.

---

## 2. Bausteine und Maße aus D2

### 2.1 Grundmaße (aus `X-Wochenplan`, `D2-Komponenten`, `D2-Artikel`, `X-Essen`, `X-Angebote`)

| Element | D2-Wert | A-Token |
|---|---|---|
| Hintergrund Segment Wochenplan | #F2F2F7 (`X-Wochenplan`) | `context.colors.background` |
| Hintergrund Segment Entdecken | #FFFFFF (`D2-Rezepte`) | `backgroundPlain` (A wechselt den Grund mit dem Segment, A-P4) |
| Seitenrand | 16 pt | `AvoSpacing.screen` |
| Großer Titel „Rezepte“ (A) | 34/41 Bold, Inhalt ab 106 pt | `AvoTextStyle.largeTitle` |
| Segment „Entdecken / Wochenplan“ (A) | 36 hoch, Innenabstand 2, Daumen weiß mit Schatten `0 1 3 rgba(0,0,0,.12)`, 15/20 (gewählt 600, sonst 500) | `AppSegmentedControl`; Trefferfläche 44 (A-K1) |
| Wochenkopf | 20/25 Semibold links, 13/18 #6C6C70 tabellarisch rechts, Abstand 14 oben, 10 unten | `title3`, `footnote` |
| Tageskarte | weiß, Radius 26, Innenabstand 12 oben/unten und 14 links/rechts, 10 pt Abstand zwischen Karten | `surface`, `AvoRadii.group` |
| Tageskopf | 15/20, Wochentag bzw. „Heute“ fett (D2 `<b>`), Datum #6C6C70, kcal rechts #6C6C70 tabellarisch, 8 pt bis zur ersten Zeile | `subhead` (fette Variante A-K5) |
| Rezeptfoto im Plan | 56 × 56, Radius 14 | fehlt als Token (A-K6) |
| Rezepttitel | 17/22 Semibold, bricht um, nie Ellipse | `headline` |
| Metazeile | 13/18 #6C6C70 tabellarisch; Warnung #A8521A | `footnote`; Warnfarbe fehlt als Token (A-T1) |
| Stepper im Plan | Kapsel 34 hoch, Fläche `fill`, Knöpfe sichtbar 34 breit, Wert 15/20 600 | `ValueStepper` kompakt, Knöpfe 44 × 44 Treffer (A-K2) |
| Link „Rezept wählen“ | Plus 20 pt (Strich 2,2, Grün), Abstand 8, 17/22 Grün, Mindesthöhe 44 | `tint`, `AvoSizes.hitTarget` |
| Hauptaktion im Segment | getönte Glas-Kapsel, 52 hoch, Radius 26, 12 pt über der Tab-Leiste, 16 pt Rand, Plus 18 pt (Strich 2,6), 17/22 600 weiß | `AppButton` primary auf Glas, `ShellInsets.aboveTabBar`, `AvoSizes.accessoryHeight` |
| Toolbar | obere Kante 54 pt; Glas-Knopf 44; Glas-Gruppe 44 hoch, Radius 22 | `GlassToolbar`, `GlassIconButton`, `GlassButtonGroup` (Knöpfe 44 breit statt 40, A-K3) |
| Scroll-Kante | Verlauf 104 pt Hintergrundfarbe 30 % → transparent | `ScrollEdgeFade`, `AvoSizes.scrollEdge` |
| Tab-Leiste (A) | Glas, 64 hoch, Radius 32, 12 pt Rand, 20 pt über dem Rand | `ShellInsets.tabBarBottom` |
| Vollbild-Kopf | Glas-Knopf 44 links (`xmark` oder `chevron.left`), Inline-Titel 17/22 Semibold zentriert, rechts getönte Kapsel 44 hoch mit 18 pt Innenrand („Fertig“, „Hinzufügen“) | `FullScreenEditor` (S2b) |
| Kapsel unten auf V-Screens | getönt, 54 hoch, Radius 27, 34 pt über dem Rand (Safe Area), 16 pt Rand, 17/22 600 (`X-Essen`) | `AppButton` primary groß |
| Gruppe (Einstellungen, V-Screens) | weiß, Radius 26, 16 pt Rand; Zeile mindestens 50 (Einstellungen) bzw. 56 (Bearbeiten), Innenrand 16; Trenner 0,5 pt #E5E5EA ab Textkante | `InsetSection`, `NavRow`/`ToggleRow`/`ValueRow` |
| Gruppenkopf | GROSS 13/18 Semibold #6C6C70, +0,3 Laufweite, 18 pt über der Gruppe, bei 32 pt | `SectionCaps` (Semantik-Label in normaler Schreibung) |
| Fußnote | 13/18 #6C6C70, 6 pt unter der Gruppe, bei 32 pt | `footnote` |
| Artikelzeile (S3) | 44er-Trefferfläche um den 26-pt-Kreis (Rand −9), Bild 44 Radius 10, Abstand 12, Name 17/22, Unterzeile 15/20 #6C6C70, Trenner ab 94 pt | `CheckCircle`, `ArticleImage`, `AvoRadii.imageSmall` |
| Angebots-Pille | 11/13 600 #1F7A3A auf #E7F3EA, Innenrand 3 × 8, Kapsel, Text „0,89 € · Lidl“ | `caption2`, `tintSoft` |
| Suchfeld (S2) | 40 hoch, Kapsel, `fill`, Lupe #6C6C70, 17/22, Platzhalter #6C6C70 | `AvoSearchField` (Treffer 44) |
| Filter-Chip | sichtbar 34, Treffer 44, 15/20 500, Innenrand 14 | `AppFilterChip` |
| Schalter | 51 × 31, an #34C759 | `ToggleRow` |
| Hero „Heute kochen“ | Foto 220 hoch Radius 26; Status-Kapsel oben links (weiß 92 % + Blur 12, 13/16 600 Grün, Innenrand 5 10 5 7); Glas-Panel unten 12 pt vom Rand, Radius 20, Innenrand 12; Titel 20/25 600; Meta 13/18 #2C2C2E; getönter Knopf 44, Radius 22, 15/20 600, Grün 96 % | `RecipeHeroCard` (S2b, A-K8) |
| Avo-Figur | `assets/avo/avo_waving.png`, `avo_thinking.png`, `avo_celebrating.png` mit grüner Schatten-Ellipse | `AvoFigure(pose:)` |

### 2.2 Farben im Bereich (Tokens von A, `AvoColors`)

| Rolle | Hell (D2) | Token | Einsatz |
|---|---|---|---|
| Text | #1C1C1E | `label` | alles Lesbare |
| Sekundär | #6C6C70 | `secondaryLabel` | Datum, Metazeilen, Zähler, Fußnoten; nie auf Glas über Fotos (3.7) |
| Akzent | #1F7A3A | `tint` / `tintFill` | Links, Kapseln, Häkchen, Auswahl im Kalender |
| Warnung als Text | #A8521A | **fehlt** (A-T1, Vorschlag `warningText`, dunkel #F29A4A) | „2 Zutaten fehlen“, „Enthält Erdnuss“ |
| Destruktiv | #D70015 | `destructive` | „Entfernen“, „Woche leeren“, Wisch-Aktion „Entfernen“ |
| Rot | #FF3B30 | `red` | nie als Text und nie als Fläche unter weißem Text (3,55:1) |
| Kreis nicht gewählt | #8A8A8E (Owner-Entscheidung, statt D2 #C7C7CC) | `uncheckedRing` | S3 |
| Angebot | #1F7A3A auf #E7F3EA | `tint` auf `tintSoft` | Pille in S3 |
| Text auf Glas über Foto | #2C2C2E (D2-FuerDich) | **fehlt** (A-T2, Vorschlag `labelOnGlass`) | Meta im Hero-Panel |

D2 ist nur hell. Die Dunkel-Werte kommen aus `AvoColors.dark`; für `warningText` und `labelOnGlass` braucht es neue
Dunkel-Werte (A-T1, A-T2).

### 2.3 B-eigene Bausteine (Ordner `lib/presentation/screens/plan/widgets/`)

Nur aus A-Tokens und A-Komponenten gebaut, keine eigenen Farben, Größen oder Dauern:

- `PlanWeekHeader`: Wochenkopf mit Pull-down-Menü und Zähler.
- `PlanWeekPager`: waagerechtes Wischen zwischen Wochen, Nachbarwochen schon gezeichnet (3.4).
- `PlanDayCard`: Tageskarte mit Kopf, `PlanEntryRow`s und Link „Rezept wählen“.
- `PlanEntryRow`: Rezeptzeile mit Foto, Titel, Status, Stepper; Varianten in 4.1.4.
- `PlanActionCapsule`: die Hauptaktion über der Tab-Leiste (4.1.5), tauscht mit dem `AvoToast` den Platz.
- `PlanPastDaysRow`: einklappbare Zeile „Vergangene Tage (2)“.
- `PlanCopyLastWeekRow`: „Rezepte der Vorwoche übernehmen“.
- `PlanIngredientRow`: Zutaten-Auswahlzeile in S3, falls A keine `IngredientPickRow` liefert (A-K7).
- `PlanDayCalendar`: Kalender für S6, S7, S8 auf A's `InlineCalendar` (A-K9).
- `PlanEntryMeta`: Slot im Rezeptdetail (S9).
- `HomeCookToday`: Home-Abschnitt (S10), exportiert über `lib/presentation/widgets/slots/b_slots.dart`.

---

## 3. Regeln für alle Screens

### 3.1 Lokal zuerst

- Der Plan liegt auf dem Gerät: laufende Woche, vier Wochen voraus, zwei zurück, vor dem ersten Frame gewärmt
  (`meal_plan_service`, 7). Jeder Screen zeigt sofort diesen Stand; der Abgleich läuft danach im Hintergrund.
- Kein Spinner, nirgends. Nur beim allerersten Laden ohne lokalen Stand ein ruhiges Skelett ohne Schimmer
  (`SkeletonSection`), höchstens bis zur ersten Antwort; nach 10 s wird daraus der Fehlerzustand.
- Jede Änderung (Rezept einplanen, Portionen, verschieben, entfernen, Woche leeren, Vorwoche übernehmen, Zutaten auf die
  Liste) erscheint im selben Frame und geht in die Warteschlange. Einträge haben vom Gerät erzeugte IDs, damit Offline,
  Rückgängig und Wiederholen eindeutig sind.
- Änderungen von einem zweiten Gerät desselben Kontos (Owner und Jannis) wachsen ein bzw. schrumpfen weg, ohne dass
  sichtbare Zeilen springen.

### 3.2 Zustände, die überall gleich aussehen

| Zustand | Darstellung | Text DE | Text EN |
|---|---|---|---|
| Offline | `StatusRow` unter dem Wochenkopf bzw. unter dem Kopf des Screens, erscheint nach 1 s | Offline. Deine Änderungen werden gespeichert, sobald du wieder online bist. | Offline. Your changes will be saved when you're back online. |
| Ausstehend | `StatusRow` nach 3 s, verschwindet nach dem Abgleich | 3 Änderungen werden gesendet | Sending 3 changes |
| Speichern fehlgeschlagen | Zeile rollt zurück, `StatusRow` über der betroffenen Tageskarte, Fehler-Haptik | „Shakshuka mit Feta“ konnte nicht gespeichert werden. Erneut versuchen | Couldn't save "Shakshuka with feta". Try again |
| Modul aus | Route öffnet nicht, Dialog D1 | siehe D1 | siehe D1 |
| Pro gesperrt (nur wenn der Owner den Plan zu Pro macht, 5) | Planen bleibt frei; nur „auf die Liste“ trägt `ProBadge` und öffnet über `ProGate.run(context, feature: 'meal_plan', origin: …, onUnlocked: …)` die Paywall, danach läuft die Aktion weiter | – | – |
| Pro unbekannt | keine Badge, Prüfung erst beim Tippen | – | – |

Die Offline-Zeile ist derselbe Wortlaut wie in allen B-Bereichen (Kap. 20). „Erneut versuchen“ ist ein Text-Knopf im
Satz, Trefferfläche 44.

### 3.3 Module, Kill-Switch, Pro

| Element | `mealPlan` aus | `calories` aus | Angebote nicht verfügbar (`offersAvailableProvider` false: Modul aus oder Kill-Switch) | `avo` aus |
|---|---|---|---|---|
| Segment „Wochenplan“, alle Plan-Routen | weg (A blendet das Segment aus), Routen → D1 | – | – | – |
| kcal im Tageskopf, Kalorien-Fuß, kcal in Metazeilen und VoiceOver | – | weg ohne Lücke | – | – |
| Kontextmenü „Ins Tagebuch“, „Mahlzeit“ | – | weg | – | – |
| Angebots-Pille und Ersparnis-Zeile in S3 | – | – | weg ohne Lücke, kein Hinweis „nicht verfügbar“ | – |
| `StoreChip` in S3 (Kern) | – | – | bleibt | – |
| Angebot an neu angelegte Artikel hängen | – | – | nichts anhängen | – |
| Angebotszeile im Erfolgsmoment (falls behalten, 5) | – | – | weg | – |
| Home „Heute kochen“ | `SizedBox.shrink()`, `homeCookTodayHasContentProvider` false | ohne kcal | – | – |
| `PlanEntryMeta` im Rezeptdetail | `SizedBox.shrink()` | – | – | – |
| Avo-Figur (Maskottchen) | – | – | – | bleibt (Marke, kein Modul) |

`aiRemoteEnabledProvider` hat hier keine sichtbare Wirkung: Neue Artikel bekommen ihre Kategorie lokal, die Verfeinerung
läuft still im Hintergrund oder gar nicht.

`AppModule.mealPlan` ist heute `released: false`. Zum Bauen `setDebugUnlocked(AppModule.mealPlan, true)` im
Debug-Build; nach Abnahme von B7 Anfrage an A, das Modul freizuschalten (A-M1).

### 3.4 Bewegung (Federn aus `AvoMotion`)

| Was | Feder | Reduce Motion |
|---|---|---|
| Zeile einplanen, entfernen, Realtime-Änderung | Höhe und Deckkraft, `standard` (0,35 s, Dämpfung 1,0) | Überblendung 200 ms (`fadeReduced`), keine Höhenbewegung der Nachbarn, sie stehen sofort am neuen Platz |
| Woche wechseln per Wischen | folgt dem Finger 1:1 nach 10 pt Hysterese (nur wenn waagerecht mindestens doppelt so weit wie senkrecht); beim Loslassen Wurfprojektion `AvoMotion.project(v)`; wechselt, wenn die projizierte Strecke über die halbe Breite reicht; Ausrollen `fling` (0,35 s, 0,8) mit der Fingergeschwindigkeit; an der Grenze ±52 Wochen `rubberBand` | Inhalt folgt dem Finger nicht; ein Wisch über 60 pt wechselt nach dem Loslassen per Überblendung |
| Woche wechseln per Knopf oder Menü | alte Woche gleitet zur Seite, neue herein, `standard`; Wochenkopf überblendet | Überblendung |
| Zahl in der Kapsel, im Zähler, im Stepper | rollt, `digits` | Überblendung |
| Kapsel ein- und ausblenden | 16 pt von unten plus Deckkraft, `standard`; gedrückt 0,97 (`pressedScale`) mit `quick` | nur Deckkraft |
| Kapsel ↔ Rückgängig-Hinweis | Kapsel blendet aus, Hinweis erscheint an derselben Stelle, `standard` | Überblendung |
| Menüs | wachsen aus ihrem Auslöser, `menu` | Überblendung |
| Erfolgsmoment | Skalierung von 0,9 auf 1 plus Deckkraft, `celebrate` (0,40 s, 0,8) | nur Einblenden |
| Bearbeiten-Modus | Minus-Kreis und Griff blenden ein, Stepper aus, `standard` | Überblendung |
| „Vergangene Tage“ auf und zu | Höhe, Chevron dreht 90°, `standard` | sofort, Chevron wechselt ohne Drehung |
| Foto lädt | blendet in 0,2 s ein | ohne Blende |

Jede Bewegung startet vom aktuellen Wert auf dem Bildschirm und lässt sich mitten im Lauf greifen und umkehren
(`apple-design` §3). Keine Bewegung sperrt Eingaben.

### 3.5 Haptik (sparsam, nur über `AvoHaptics`)

| Moment | Haptik |
|---|---|
| Stepper ein Schritt | `selection` |
| Woche rastet nach dem Wischen ein | `selection` |
| Rezept rastet beim Verschieben im Bearbeiten-Modus auf einem neuen Platz ein | `selection` |
| Erfolgsmoment (erstes Senden einer Woche) | `success`, im selben Frame wie das Bild |
| Senden oder Speichern endgültig fehlgeschlagen | `error` |

Keine Haptik beim Einplanen eines Rezepts, beim Antippen einer Zutat in S3, beim Rückgängig, beim Öffnen von Menüs (das
System macht dort seine eigene).

### 3.6 Rückgängig-Hinweis (`AvoToast` mit `AvoToastHost`)

- Steht in S1 an der Stelle der Hauptaktion (12 pt über der Tab-Leiste), nie zusätzlich zu ihr (Glas-Budget, 3.13).
- Glas, 52 hoch, Radius 26; Text 15/20 `label` links, rechts Text-Knopf „Widerrufen“ 15/20 600 `tint`, Treffer 44.
- 4 s sichtbar, mit VoiceOver (`MediaQuery.accessibleNavigationOf(context)`) 10 s. Wischen nach unten schließt ihn.
- Ein neuer Hinweis ersetzt den alten; damit gilt die alte Aktion als bestätigt.
- VoiceOver: Beim Erscheinen höfliche Ansage des Textes über
  `SemanticsService.sendAnnouncement(View.of(context), text, textDirection)`. Der Hinweis nimmt den Fokus nicht an sich;
  er ist ein eigener Knoten mit Knopf „Widerrufen“, erreichbar durch Wischen.
- Texte des Bereichs:

| Schlüssel | DE | EN |
|---|---|---|
| `plan_undo` | Widerrufen | Undo |
| `plan_toast_removed` | „{recipe}“ entfernt | "{recipe}" removed |
| `plan_toast_moved` | Auf {day} verschoben | Moved to {day} |
| `plan_toast_cleared` | Woche geleert | Week cleared |
| `plan_toast_copied` | {n} Rezepte übernommen | {n} recipes copied |
| `plan_toast_items_added` | {n} Zutaten zu {list} hinzugefügt (1: 1 Zutat zu {list} hinzugefügt) | {n} ingredients added to {list} (1: 1 ingredient added to {list}) |
| `plan_toast_planned` | Für {day} eingeplant | Planned for {day} |
| `plan_toast_module_hidden` | Wochenplan ausgeblendet | Meal plan hidden |
| `plan_toast_cook_hidden` | „Heute kochen“ ausgeblendet | "Cook today" hidden |
| `plan_toast_staple_removed` | {name} entfernt | {name} removed |

`{day}` ist das kurze Datum mit Wochentag: DE „Do., 12. Nov.“, EN „Thu, Nov 12“ (`DateFormat.MMMEd(locale)`).

### 3.7 Kontrast (WCAG 2.1 AA, aus den D2-Werten berechnet)

| Paar | Verhältnis | Ziel | Ergebnis und Korrektur |
|---|---|---|---|
| Weiß auf getönter Glas-Kapsel 88 % über #F2F2F7 | 4,37:1 | 4,5:1 (17 pt Semibold ist kein großer Text) | **zu wenig.** Kapseln mit Text: Tönung 96 % (über Weiß 4,99:1, über Schwarz 5,74:1) oder deckend `tintFill` (5,38:1). Gilt für S1-Kapsel, S3/S8-Kapsel unten, Kopf-Kapseln „Fertig“/„Hinzufügen“ (A-T3) |
| Weiß auf getönter Kapsel 88 % über Weiß | 4,25:1 | 4,5:1 | wie oben |
| #6C6C70 auf Weiß / auf #F2F2F7 | 5,23 / 4,69:1 | 4,5:1 | in Ordnung |
| #6C6C70 auf Glas 64 % über dunklem Foto | 2,07:1 | 4,5:1 | **zu wenig.** Auf Glas über Fotos nie `secondaryLabel`; Meta im Hero-Panel #2C2C2E (5,52:1 im schlechtesten Fall, A-T2) |
| #3A3A3C (`tertiaryLabel`) auf Glas über Schwarz | 4,50:1 | 4,5:1 | knapp; nicht für Text auf Fotos verwenden |
| #1F7A3A auf Glas 64 % über dunklem Foto | 2,13:1 | 4,5:1 | **zu wenig.** Kein grüner Text auf Glas über Fotos |
| #1F7A3A auf Weiß 92 % über Schwarz (Status-Kapsel „Heute kochen“) | 4,51:1 | 4,5:1 | knapp; Kapsel auf 96 % Weiß (4,94:1); bei Reduce Transparency deckend Weiß (5,38:1) |
| #A8521A auf Weiß / auf #F2F2F7 | 5,40 / 4,84:1 | 4,5:1 | in Ordnung (eine frühere Notiz nannte 7,6:1, das stimmt nicht) |
| #1F7A3A auf Weiß / auf #F2F2F7 | 5,38 / 4,82:1 | 4,5:1 | in Ordnung |
| #1F7A3A 11 pt auf #E7F3EA (Pille) | 4,72:1 | 4,5:1 | in Ordnung |
| #FF3B30 auf Weiß | 3,55:1 | 4,5:1 | **nie als Text**; Text in `destructive` #D70015 (5,38:1, auf #F2F2F7 4,83:1). Auch die Wisch-Aktion „Entfernen“ in S13 hat #D70015 als Fläche (weißer Text 5,38:1), nicht #FF3B30 |
| Ring nicht gewählt #C7C7CC auf Weiß (D2) | 1,68:1 | 3:1 (Bedienelement) | **zu wenig**; `uncheckedRing` #8A8A8E (3,44:1) ist schon so entschieden |
| Stepper-Fläche `fill` auf Weiß | 1,15:1 | – | Grenze der Kapsel trägt keine Information; die Zeichen − und + (14,8:1) erkennen das Element. Bei „Kontrast erhöhen“ `fillStrong` |
| Segment-Daumen Weiß auf Spur über #F2F2F7 | 1,28:1 | 3:1 (Zustand) | Zustand hängt nicht nur an der Fläche: gewählter Text 600 statt 500, VoiceOver „ausgewählt“. Bei „Kontrast erhöhen“ 1 pt Rand `uncheckedRing` um den Daumen (A-K1) |

Der orange Kalorien-Ring aus Kap. 15 kommt in diesem Bereich nicht vor; kcal stehen hier nur als Text.
Farbe trägt nie allein Bedeutung: „2 Zutaten fehlen“ ist Text, das Warnsymbol steht vor „Enthält Erdnuss“, „Heute“ steht
als Wort im Kopf.

### 3.8 Trefferflächen

- Alles Bedienbare mindestens 44 × 44 pt, auch wenn D2 kleiner zeichnet: Stepper-Knöpfe (D2 34 × 34) bekommen
  44 × 44 Treffer, die Kapsel bleibt sichtbar 34 hoch; Toolbar-Gruppenknöpfe (D2 40 × 44) werden 44 × 44; Segment
  „Entdecken / Wochenplan“ (D2 36 hoch) bekommt 44 Treffer; Chips und Tag-Knopf (sichtbar 34) 44 Treffer.
- Zwischen zwei Trefferflächen mindestens 0 pt Überlappung, nie Überschneidung: Stepper mit 44er-Knöpfen ist 112 pt
  breit (44 + 24 + 44).
- Die Status-Kapsel auf dem Hero-Foto ist keine Taste.

### 3.9 Große Schrift und Breiten

Prüfmatrix für jeden Screen und Zustand: Breiten 320 × 568, 320 × 693, 375 × 667, 390 × 844, 402 × 874, 440 × 956;
Textgrößen L, xxxL, AX3, AX5; fetter Text an und aus; hell und dunkel. Kontrast, Reduce Motion und Reduce Transparency je
einmal bei 390, L.

Allgemeine Regeln (Einzelheiten je Screen):

- Nie eine feste Höhe um Text, nie Ellipse in Titeln oder Rezeptnamen; alles bricht um.
- Ab 320 pt oder ab xxxL: Zähler „4 von 7 Tagen geplant“ rutscht unter den Wochenkopf, kcal rutschen unter das Datum,
  Stepper unter die Metazeile.
- Ab AX1: Rezeptfotos oben bündig zur ersten Titelzeile; Artikelbilder in S3 entfallen; Avo im leeren Zustand entfällt;
  Gruppen in Einstellungen werden randlos (A-Regel); Werte in `NavRow` stapeln unter den Titel.
- Ab AX3: Rezeptfotos in Zeilen entfallen; die Hauptaktion zeigt nur noch die Zahl („5 Zutaten“), voller Text bleibt in
  VoiceOver.
- Zahlen tabellarisch; Pille und Stepper-Wert wachsen nur bis AX2 (Deckel von A).
- Segmente mit zwei Teilen werden zum Pull-down-Menü, sobald die Texte nicht mehr in eine Zeile passen (`AppSegmentedControl`, A-K1).
- Flutter hat keinen Large Content Viewer. Deshalb bricht jeder Text in Kapseln und Knöpfen um und wird nie gekürzt.

### 3.10 VoiceOver-Grundregeln

- Reihenfolge = Lesereihenfolge von oben nach unten; schwebende Kapsel nach dem Inhalt, vor der Tab-Leiste.
- Tagesköpfe sind Überschriften (`Semantics(header: true)`), damit der Rotor „Überschriften“ von Tag zu Tag springt.
- Eine Rezeptzeile ist ein Element und „einstellbar“ (Wischen hoch/runter ändert die Portionen über `onIncrease`/
  `onDecrease` mit `value`, `increasedValue`, `decreasedValue`); die Stepper-Knöpfe sind dann aus der Semantik
  genommen, damit nichts doppelt kommt. Weitere Aktionen als `customSemanticsActions`.
- Wochenwechsel: Knöpfe in der Toolbar, Aktionen auf dem Wochenkopf und Drei-Finger-Wischen (`onScrollLeft` = nächste
  Woche, `onScrollRight` = vorige Woche auf dem Pager).
- Ansagen höflich und gebündelt (höchstens eine pro 2 s): Wochenwechsel, Änderungen von einem anderen Gerät,
  Rückgängig-Hinweise, Erfolgsmoment.
- Bilder: Rezeptfotos sind dekorativ, wenn der Titel daneben steht (aus der Semantik genommen); das Hero-Foto auf Home
  ebenso, der Titel trägt die Bedeutung.
- Großbuchstaben-Gruppenköpfe bekommen ein Semantik-Label in normaler Schreibung („Obst und Gemüse“, nicht buchstabiert).

### 3.11 Reduce Transparency, Kontrast erhöhen, fetter Text

- Reduce Transparency und „Kontrast erhöhen“ lesen über `AvoDesignScope.reduceTransparencyOf(context)` (A, Kanal
  `shoply/accessibility`). Dann: Hauptaktion deckend `tintFill`; Rückgängig-Hinweis deckend `surface` mit Schatten;
  Toolbar und Tab-Leiste `glassFallback` (A); Hero-Panel deckend `surface`; Status-Kapsel deckend Weiß.
- „Kontrast erhöhen“ zusätzlich: Trenner `uncheckedRing` statt `separator`, Stepper-Fläche `fillStrong`, Segment-Daumen
  mit Rand.
- Fetter Text (`MediaQuery.boldTextOf`): alle Gewichte eine Stufe schwerer (A-Typografie), Umbrüche in der Prüfmatrix
  mit fettem Text abnehmen.

### 3.12 Avo-Figur

| Ort | Pose | Größe | Ab AX1 | Grund |
|---|---|---|---|---|
| S1 erster Start (leerer Zustand) | `avo_waving` | 96 pt | entfällt | Begrüßung, einmalig |
| S1 Erfolgsmoment | `avo_celebrating` | 120 pt | 96 pt; bei AX5 auf 320 pt oder unter 600 pt Höhe entfällt sie | Fest, einmal pro Woche |
| S2 keine gespeicherten Rezepte | `avo_waving` | 64 pt | entfällt | leerer Zustand |
| S2 keine Treffer | `avo_thinking` | 64 pt | statt Avo SF `magnifyingglass` 48 pt Light, `secondaryLabel` | suchen |
| Fehlerzustände, Offline, Dialoge, S3, S4, S6 bis S13, Home „Heute kochen“ | keine | – | – | Avo erscheint nie bei Fehler, Geld, Allergie oder Löschen; „Heute kochen“ steht direkt über „Tipp von Avo“ mit Figur |

Höchstens eine Figur pro Bildschirmhöhe: Der leere Zustand und der Erfolgsmoment schließen sich aus (Erfolg setzt
Einträge voraus).

### 3.13 Glas pro Screen

| Screen | Glasflächen |
|---|---|
| S1 | Tab-Leiste, Toolbar-Gruppe, Hauptaktion oder Rückgängig-Hinweis (nie beide) = 3; ein offenes Menü ersetzt seinen Auslöser |
| S1 mit Erfolgsmoment | wie oben; der Erfolgsmoment ist eine deckende weiße Karte, kein Glas |
| S2, S4 bis S8, S12, S13 | Kopf-Knopf links, ggf. Kopf-Kapsel rechts, ggf. Kapsel unten |
| S10 (Home) | Status-Kapsel und Panel liegen auf dem Foto; Home-Budget entscheidet A |

### 3.14 Wortlaut-Regeln

- Angebote: nur der Markt der Ziel-Liste, Wortlaut über `formatOfferSummary` (B2.2): „3 von 17 Zutaten diese Woche bei
  Lidl im Angebot, ca. 2,40 € gespart, in deiner Region“; statt-Preise nur mit „laut Händler“; Ersparnis unter 0,50 €
  entfällt, sonst auf 10 ct gerundet mit „ca.“; ohne echte PLZ keine Ersparnis und keine Anfrage. Kein Marktvergleich,
  keine Prozent-Rabatte, keine Händlerbilder, nie Pro.
- Kalorien: pro Person und Portion, keine Wochensumme, keine Bewertung gegen das Tagesziel, „ab …“ bei fehlenden
  Nährwerten, Fuß „Richtwerte, kein ärztlicher Rat.“
- Allergene: in „Für dich“ ausgeschlossen, sonst mit Warnung; nie „allergenfrei“ behaupten.
- „Hast du schon“ oder „da“ nur, wenn die App es belegen kann (5, Konflikt K6).

---

## 4. Screens

### S1 Wochenplan (Segment im Rezepte-Tab)

#### 4.1.1 Zweck und Einstieg

- Hauptfrage: Was essen wir diese Woche, und ist alles auf der Liste?
- Einstieg: Segment „Wochenplan“ im Rezepte-Tab; Home „Heute kochen“ → „Alle“; Mitteilung „Woche planen“; Avo
  „Ansehen“; Widget und Siri; Deep Link `shoply://plan?day=`.
- Erneutes Antippen des gewählten Segments scrollt zu „Heute“ und, wenn eine andere Woche offen ist, zurück zur
  laufenden Woche (A ruft `planSegmentReselected(ref)` auf, A-P5).

#### 4.1.2 Einbettung (Vertrag mit A)

- `buildPlanSegment(context)` liefert **Slivers** (eine `SliverMainAxisGroup`), die A in seinen `CustomScrollView` unter
  das Segment setzt; so scrollt der große Titel „Rezepte“ mit (A-P1).
- Die Hauptaktion und der Rückgängig-Hinweis liegen außerhalb der Scrollfläche: A setzt `buildPlanFloatingBar(context)`
  in den Stapel des Tabs über den Inhalt und unter die Tab-Leiste (A-P2).
- Die Toolbar-Knöpfe (vorige Woche, nächste Woche, Mehr) liefert B über `buildPlanToolbarActions(context)`; A zeigt sie
  rechts in der `GlassToolbar`, solange das Segment gewählt ist, statt der Knöpfe von „Entdecken“ (A-P3).
- Hintergrund `background` #F2F2F7, solange „Wochenplan“ gewählt ist (A-P4); Wechsel als Überblendung 200 ms.
- Query-Parameter `week` und `day` liest B über `GoRouterState.of(context).uri.queryParameters`; A behält sie beim
  Segmentwechsel bei.

#### 4.1.3 Aufbau von oben nach unten (Maße bei 390 pt, Textgröße L)

1. **Toolbar (A, Werte von B):** rechts eine `GlassButtonGroup` mit drei `GlassIconButton` je 44 × 44: `chevron.left`
   „Vorige Woche“, `chevron.right` „Nächste Woche“, `ellipsis` „Mehr“ (Menü 4.1.6 b). Links nichts (Tab-Wurzel).
2. **Großer Titel „Rezepte“ und Segment (A).**
3. **Wochenkopf** (`PlanWeekHeader`), Abstand 14 oben, 10 unten, Rand 16:
   - Links ein Pull-down-Knopf, Mindesthöhe 44: Text `title3` 20/25 Semibold `label`, dahinter `chevron.down` 13 pt
     Semibold `secondaryLabel`, 4 pt Abstand. Laufende Woche „9.–15. November“; andere Wochen „Nächste Woche · 16.–22.
     Nov.“, „Letzte Woche · 2.–8. Nov.“, sonst „KW 50 · 7.–13. Dez.“. Tipp öffnet das Wochen-Menü (4.1.6 a).
   - Rechts `footnote` 13/18 `secondaryLabel` tabellarisch: „4 von 7 Tagen geplant“, Grundlinie auf der des Titels.
4. **`StatusRow`** (nur wenn nötig, 3.2), Rand 16, 10 pt Abstand nach unten.
5. **„Rezepte der Vorwoche übernehmen“** (`PlanCopyLastWeekRow`, nur wenn die gezeigte Woche leer ist, laufend oder
   künftig, und die Woche davor Einträge hat): Gruppe Radius 26, Zeile mindestens 64: SF `doc.on.doc` 17 pt
   `secondaryLabel`, Titel `body` 17/22, Unterzeile `subhead` 15/20 `secondaryLabel` „6 Rezepte · 2.–8. Nov.“, rechts
   Text-Knopf „Übernehmen“ 17/22 600 `tint`, Treffer 44. 10 pt Abstand nach unten.
6. **„Vergangene Tage (2)“** (`PlanPastDaysRow`, nur laufende Woche, nur wenn Tage vor heute existieren): Gruppe Radius
   26, eine Zeile mindestens 50: `body` 17/22 `label`, rechts `chevron.right` 13 pt `secondaryLabel`; ausgeklappt zeigt
   der Chevron nach unten und darunter stehen die Tageskarten Mo und Di in derselben Form wie unten. Standard
   eingeklappt; der Zustand wird pro Gerät gemerkt.
7. **Tageskarten** (`PlanDayCard`), laufende Woche ab heute bis Sonntag, andere Wochen Montag bis Sonntag; Rand 16, 10 pt
   Abstand, Innenabstand 12/14, weiß, Radius 26, kein Schatten:
   - **Kopf** (Überschrift, keine Taste), `subhead` 15/20: „Heute“ fett `label`, 8 pt Abstand, „Mi., 11.“
     `secondaryLabel`; andere Tage Wochentag fett („Donnerstag“) und „12.“. Rechts mit Modul Kalorien „480 kcal“ bzw. „ab
     480 kcal“ `secondaryLabel` tabellarisch. 8 pt bis zur ersten Zeile.
   - **Rezeptzeilen** (`PlanEntryRow`, 4.1.4), zwischen zwei Zeilen 8 pt, Trenner 0,5 pt `separator` ab der Textkante
     (14 + 56 + 12 = 82 pt vom Kartenrand), 8 pt.
   - **„Rezept wählen“**: Link mit Plus 20 pt `tint` (Strich 2,2), 8 pt Abstand, `body` 17/22 `tint`, Mindesthöhe 44,
     ganze Zeile tippbar. Bei leerem Tag einziger Inhalt; bei belegtem Tag unter der letzten Zeile mit Trenner
     (Empfehlung, Konflikt K4). Öffnet S2 für diesen Tag.
8. **Kalorien-Fuß** (nur Modul Kalorien, nach der Sonntagskarte): `footnote` 13/18 `secondaryLabel`, 6 pt unter der
   Karte, bei 32 pt: „kcal pro Person, eine Portion je Rezept. Richtwerte, kein ärztlicher Rat.“ Fehlen Nährwerte:
   davor „Für Apfel-Crumble fehlen Nährwerte.“
9. **Unterer Abstand:** `ShellInsets.bottom(context, withAccessory: true)` in laufenden und künftigen Wochen, auch wenn
   die Kapsel gerade ausgeblendet ist (sonst springt der Inhalt); in vergangenen Wochen ohne `withAccessory`.
10. **Hauptaktion** (`PlanActionCapsule`, 4.1.5).
11. **Tab-Leiste (A)**, Tab „Rezepte“ aktiv.

Die Woche selbst ist ein `PlanWeekPager` in einem `SliverToBoxAdapter`: eine nicht-lazy Spalte der sieben Tage
(höchstens rund 20 Zeilen pro Woche). Beim Wischen sind die Nachbarwochen schon gezeichnet; ihre Daten und die zwei
ersten Fotos werden beim Öffnen im Hintergrund vorgeladen.

#### 4.1.4 Rezeptzeile (`PlanEntryRow`)

Aufbau links nach rechts: Foto 56 × 56 Radius 14 (`CachedNetworkImage`, `memCacheWidth` = 56 × Pixelverhältnis; bis
es geladen ist, eine flache Fläche in `photo_color` aus dem Snapshot, ohne Foto `fill`); 12 pt; Textspalte; 12 pt;
Stepper. Mindesthöhe 56. `RepaintBoundary` pro Zeile, Riverpod `select` auf den einzelnen Eintrag, damit ein
Stepper-Schritt nur seine Zeile und die Kapsel neu baut.

Textspalte:
- Titel `headline` 17/22 Semibold, bricht um.
- Metazeile `footnote` 13/18 tabellarisch: Zeit und Status, durch „ · “ getrennt.
- Optional zweite Zeile: Mahlzeit (nur Modul Kalorien, nur wenn gesetzt) `secondaryLabel`; Allergen-Warnung
  `exclamationmark.triangle.fill` 13 pt plus Text in `warningText`.

Status in der Metazeile:

| Fall | Schlüssel | DE | EN | Farbe |
|---|---|---|---|---|
| alles gedeckt (auf der Ziel-Liste, gesendet oder Grundzutat) | `plan_entry_all_on_list` | 25 Min · alles auf der Liste | 25 min · all on the list | `secondaryLabel` |
| eine Zutat fehlt | `plan_entry_missing_one` | 25 Min · 1 Zutat fehlt | 25 min · 1 ingredient missing | Zeit `secondaryLabel`, Status `warningText` |
| mehrere fehlen | `plan_entry_missing` | 25 Min · 2 Zutaten fehlen | 25 min · 2 ingredients missing | wie oben |
| gesendet, danach mehr Portionen | `plan_entry_missing_more` | 3 Zutaten fehlen für 2 weitere Portionen | 3 ingredients missing for 2 more servings | `warningText` |
| gesendet, danach weniger Portionen | `plan_entry_fewer` | alles auf der Liste · 2 Portionen weniger geplant | all on the list · 2 fewer servings planned | `secondaryLabel` |
| Rezept gelöscht | `plan_entry_unavailable` | Rezept nicht mehr verfügbar | Recipe no longer available | `secondaryLabel`, Zeile ohne Foto (Fläche `fill`), Titel aus dem Snapshot, Tipp öffnet das Kontextmenü mit „Entfernen“ |
| Rezept ohne Zutaten | `plan_entry_no_ingredients` | 25 Min · ohne Zutatenliste | 25 min · no ingredient list | `secondaryLabel` |
| vergangener Tag | – | 25 Min | 25 min | ohne Status |
| Allergen (zweite Zeile) | `plan_entry_contains` | Enthält Erdnuss | Contains peanuts | `warningText` mit Symbol |
| Mahlzeit (zweite Zeile) | `plan_meal_*` (Werte von `cal_` mitlesen) | Abendessen | Dinner | `secondaryLabel` |

Zeit: `plan_minutes` „{n} Min“ / „{n} min“. Weniger Portionen nehmen nie etwas von der Liste (FW-04).

Stepper (`ValueStepper` kompakt): 1 bis 20, Wert `subhead` 15/20 600 tabellarisch (mindestens 24 breit), Knöpfe 44
breit, sichtbar 34 hoch, Treffer 44 hoch; bei 1 ist „−“, bei 20 „+“ deaktiviert. Kein Dauer-Wiederholen beim Halten. Die
kcal im Tageskopf ändern sich nicht (pro Person).

**Umschaltung:** Stepper rechts neben dem Text bei Breite ab 390 pt und Textgröße bis xL; sonst unter der Metazeile,
bündig mit der Textkante, 5 pt Luft darüber und darunter (damit die 44er-Treffer nicht über die Zeile ragen). Ab AX1
Foto oben bündig zur ersten Titelzeile, ab AX3 ohne Foto, Titel über die volle Breite.

Bei 390 pt bleiben für den Text 330 − 56 − 12 − 12 − 112 = 138 pt; „Shakshuka mit Feta“ bricht dort in zwei Zeilen um.
Das ist so gewollt.

#### 4.1.5 Hauptaktion (`PlanActionCapsule`)

- Getönte Glas-Kapsel über volle Breite (Rand 16), unten bei `ShellInsets.aboveTabBar(context)`, Mindesthöhe 52, Radius
  26, Tönung 96 % (3.7); Plus 18 pt weiß (Strich 2,6), 8 pt, Text `headline` 17/22 Semibold `onTint`, zentriert, bricht
  um (Kapsel wächst, Radius bleibt 26).
- Text: „5 Zutaten auf Wocheneinkauf“ (Empfehlung, Konflikt K1). Die Zahl ist die Zahl der vorausgewählten,
  zusammengefassten Zeilen in S3 im Standard-Zeitraum (ohne Grundzutaten, ohne Vorhandenes, nur noch nicht gesendete
  Mengen; Konflikt K2). Nach Portionsänderungen an gesendeten Einträgen zählt sie nur den Unterschied.
- Sichtbar in der laufenden und in künftigen Wochen, wenn die Zahl über 0 ist. Ausgeblendet bei Zahl 0, in vergangenen
  Wochen, im Bearbeiten-Modus und solange der Rückgängig-Hinweis an ihrer Stelle steht.
- Tipp öffnet S3 (`/plan/to-list?week=…`). Gedrückt 0,97.
- Pro gesperrt: hinter dem Text `ProBadge` in der Variante „auf getönt“ (A-K4); Tipp → `ProGate.run(…, feature:
  'meal_plan', origin: 'plan_capsule', onUnlocked: () => S3 öffnen)`.
- Ab AX3 nur „5 Zutaten“.

| Schlüssel | DE | EN |
|---|---|---|
| `plan_action_add` | {n} Zutaten auf {list} (1: 1 Zutat auf {list}) | Add {n} ingredients to {list} (1: Add 1 ingredient to {list}) |
| `plan_action_add_short` | {n} Zutaten (1: 1 Zutat) | Add {n} |
| `plan_action_add_a11y` | {n} fehlende Zutaten auf {list} setzen | Add {n} missing ingredients to {list} |
| `plan_pro_suffix_a11y` | Pro-Funktion | Pro feature |

VoiceOver: „5 fehlende Zutaten auf Wocheneinkauf setzen, Taste“; mit Pro „…, Pro-Funktion“.

#### 4.1.6 Menüs (`AvoMenuButton` / `showAvoMenu`, wachsen aus dem Auslöser)

**a) Wochen-Menü (aus dem Wochenkopf):** „Diese Woche“ (mit Häkchen, wenn gewählt), „Nächste Woche“, „Letzte Woche“;
Trenner; die nächsten vier Wochen („KW 48 · 23.–29. Nov.“); Trenner; „Datum wählen …“ (öffnet S7).

**b) Menü „Mehr“ (Toolbar):**
1. „Zutaten der Woche“ (`cart`), auch wenn nichts fehlt (dann leerer Zustand in S3); bei Pro gesperrt mit `ProBadge`
   und Paywall.
2. „Liste: Wocheneinkauf“ (`list.bullet`) als Untermenü: alle Listen mit offener Anzahl rechts („4 offen“), die gewählte
   mit Häkchen; Trenner; „Neue Liste“ (`plus`). Gilt für diese Woche.
3. „Rezepte der Vorwoche übernehmen“ (`doc.on.doc`), nur wenn die Vorwoche Einträge hat und die Woche nicht vergangen ist.
4. „Bearbeiten“ (`pencil`), nur wenn die Woche Einträge hat.
5. Trenner. „Woche leeren“ (`trash`, destruktiv), nur mit Einträgen: sofort, Rückgängig-Hinweis „Woche geleert“, keine
   Rückfrage (umkehrbar, W-08).
6. Trenner. „Wochenplan-Einstellungen“ (`gearshape`) → `/settings/plan`.

**c) Kontextmenü einer Rezeptzeile (Langdruck, mit Foto-Vorschau und Titel):**
„Rezept ansehen“ (`book`) → S9; „Kochen“ (`frying.pan`) → Kochmodus von A mit den Plan-Portionen, mit `ProBadge`,
falls der Kochmodus Pro ist; „Auf anderen Tag“ (`calendar`) als Untermenü mit den sieben Tagen der Woche (aktueller mit
Häkchen) und „Anderes Datum …“ (→ S6); „Ins Tagebuch“ (`flame`, nur Modul Kalorien) → `openLogRecipe` mit 1 Portion,
dem Tag des Eintrags und seiner Mahlzeit (Lücke L5); „Mahlzeit“ (`fork.knife`, nur Modul Kalorien) als Untermenü
Frühstück, Mittagessen, Abendessen, Snack (keine Angabe zählt als Abendessen); Trenner; „Entfernen“ (`trash`,
destruktiv): sofort, Rückgängig-Hinweis.

Verschieben per Untermenü zeigt immer den Hinweis „Auf {day} verschoben“, auch innerhalb der Woche (VoiceOver bekommt so
eine Bestätigung). Ziehen direkt aus der Kontextmenü-Vorschau heraus (Konzept) gibt es nur, wenn A's Kontextmenü das
kann (A-K10); sonst verschiebt man per Untermenü oder im Bearbeiten-Modus.

| Schlüssel | DE | EN |
|---|---|---|
| `plan_toolbar_prev` | Vorige Woche | Previous week |
| `plan_toolbar_next` | Nächste Woche | Next week |
| `plan_toolbar_more` | Mehr | More |
| `plan_week_this` | Diese Woche | This week |
| `plan_week_next` | Nächste Woche | Next week |
| `plan_week_last` | Letzte Woche | Last week |
| `plan_week_number` | KW {n} · {range} | Week {n} · {range} |
| `plan_week_pick` | Datum wählen … | Choose a date… |
| `plan_menu_ingredients` | Zutaten der Woche | This week's ingredients |
| `plan_menu_list` | Liste: {list} | List: {list} |
| `plan_menu_list_open` | {n} offen | {n} open |
| `plan_menu_new_list` | Neue Liste | New list |
| `plan_menu_copy_last` | Rezepte der Vorwoche übernehmen | Copy last week's recipes |
| `plan_menu_edit` | Bearbeiten | Edit |
| `plan_menu_clear` | Woche leeren | Clear week |
| `plan_menu_settings` | Wochenplan-Einstellungen | Meal plan settings |
| `plan_ctx_view` | Rezept ansehen | View recipe |
| `plan_ctx_cook` | Kochen | Cook |
| `plan_ctx_move` | Auf anderen Tag | Move to another day |
| `plan_ctx_other_date` | Anderes Datum … | Other date… |
| `plan_ctx_log` | Ins Tagebuch | Add to food diary |
| `plan_ctx_meal` | Mahlzeit | Meal |
| `plan_ctx_remove` | Entfernen | Remove |

#### 4.1.7 Bearbeiten-Modus

- Aus „Mehr“ > „Bearbeiten“. Die Toolbar-Gruppe weicht einer getönten Kapsel „Fertig“ (44 hoch, 18 pt Innenrand).
- Jede Rezeptzeile zeigt links `minus.circle.fill` 22 pt in `destructive` (Treffer 44, „{recipe} entfernen“) und rechts
  den Griff `line.3.horizontal` `secondaryLabel` (Treffer 44, „{recipe} verschieben“); der Stepper und „Rezept wählen“
  sind ausgeblendet; die Hauptaktion ist ausgeblendet.
- Ziehen am Griff: Zeile hebt sich (Skalierung 1,03, Schatten wie Menüs), folgt dem Finger 1:1 mit dem Abstand zum
  Greifpunkt; über einem anderen Tag öffnet sich eine Lücke; Auto-Scroll am Rand; Loslassen legt ab (`selection`).
  Verschieben in eine andere Woche geht hier nicht, dafür gibt es S6.
- Minus-Kreis entfernt sofort mit Rückgängig-Hinweis.
- VoiceOver: Jede Zeile hat im Bearbeiten-Modus die Aktionen „Entfernen“, „Nach oben“, „Nach unten“, „Auf anderen Tag“.

| Schlüssel | DE | EN |
|---|---|---|
| `plan_edit_done` | Fertig | Done |
| `plan_edit_remove_a11y` | „{recipe}“ entfernen | Remove "{recipe}" |
| `plan_edit_move_a11y` | „{recipe}“ verschieben | Move "{recipe}" |
| `plan_edit_up_a11y` | Nach oben | Move up |
| `plan_edit_down_a11y` | Nach unten | Move down |

#### 4.1.8 Interaktionen

| Aktion | Verhalten | Haptik |
|---|---|---|
| Tipp auf eine Rezeptzeile (außerhalb des Steppers) | Push S9 (Rezeptdetail mit den Portionen des Eintrags); optional `Hero`-Übergang vom 56-pt-Foto, wenn A's Detail das Tag annimmt | – |
| Stepper | Portionen ±1, Zahl rollt, Status und Kapsel rechnen nur diesen Eintrag neu | `selection` |
| Langdruck auf Zeile | Kontextmenü 4.1.6 c | System |
| „Rezept wählen“ | S2 für diesen Tag | – |
| Waagerecht wischen auf dem Inhalt (nicht auf Kapsel, Tab-Leiste, Stepper) | Woche wechseln (3.4); nach dem Einrasten Ansage „Woche 16. bis 22. November, 2 von 7 Tagen geplant“ | `selection` beim Einrasten |
| Toolbar `chevron.left` / `chevron.right` | Woche wechseln | – |
| Wochenkopf | Menü 4.1.6 a | – |
| „Übernehmen“ (Vorwoche) | legt alle Einträge der Vorwoche mit gleichen Wochentagen und Portionen an, Hinweis „6 Rezepte übernommen“ | – |
| „Vergangene Tage“ | auf- und zuklappen | – |
| Hauptaktion | S3 | – |
| Nach unten ziehen am Anfang | neu laden (System) | System |

**Keine Wischaktionen auf Rezeptzeilen (W-04):** Waagerechtes Wischen gehört dem Wochenwechsel. Ein senkrechter
Scroll-Beginn sperrt das waagerechte Wischen für diese Geste und umgekehrt.

#### 4.1.9 Zustände

| Zustand | Darstellung | Schlüssel | DE | EN |
|---|---|---|---|---|
| Erster Start (noch nie ein Rezept geplant) | statt der Tageskarten `EmptyState` unter dem Wochenkopf: `AvoFigure(pose: waving)` 96 pt (ab AX1 ohne), Titel `title3`, Satz `body` `label`, Knopf `AppButton` primary 50 hoch, darunter Text-Knopf; keine Kapsel | `plan_empty_title` | Was essen wir diese Woche? | What are we eating this week? |
| | | `plan_empty_body` | Leg Rezepte auf die Tage. Mit einem Tipp kommen alle Zutaten auf deine Liste. | Put recipes on your days. One tap adds every ingredient to your list. |
| | | `plan_empty_cta` | Rezept für heute wählen | Choose a recipe for today |
| | | `plan_empty_hide` | Wochenplan ausblenden | Hide meal plan |
| | „Wochenplan ausblenden“ schaltet das Modul aus; das Segment verschwindet, Rezepte zeigt „Entdecken“, Hinweis „Wochenplan ausgeblendet · Widerrufen“ auf Entdecken (A-P6) | | | |
| Leere Woche (später) | alle Tageskarten nur mit „Rezept wählen“; darüber ggf. „Rezepte der Vorwoche übernehmen“ | `plan_copy_last_sub` | {n} Rezepte · {range} | {n} recipes · {range} |
| | | `plan_copy_last_action` | Übernehmen | Copy |
| Wochenzähler | | `plan_week_count` | {n} von 7 Tagen geplant | {n} of 7 days planned |
| | 0 Tage | `plan_week_count_none` | Noch nichts geplant | Nothing planned yet |
| | 7 Tage | `plan_week_count_all` | Alle 7 Tage geplant | All 7 days planned |
| Lädt mit lokalem Stand | Woche sofort, kein Indikator | – | – | – |
| Erstes Laden ohne lokalen Stand, online | `SkeletonSection`: Titel und Wochenkopf echt, sieben Tageskarten mit je einer Kopf-Fläche (96 × Zeilenhöhe `subhead`) und einer Zeilenfläche 56 hoch in `fill`, kein Schimmer; höchstens 10 s | – | – | – |
| Erstes Laden schlägt fehl (kein lokaler Stand, kein Netz oder 10 s ohne Antwort) | `EmptyState` ohne Avo: SF `icloud.slash` 48 pt Light `secondaryLabel`, Titel, Satz, Text-Knopf; Planen ist gesperrt, weil sonst lokale und gespeicherte Einträge kollidieren | `plan_load_error_title` | Wochenplan nicht geladen | Meal plan didn't load |
| | | `plan_load_error_body` | Der Plan ist noch nicht auf diesem iPhone. Verbinde dich mit dem Internet, dann lädt er. | Your plan isn't on this iPhone yet. Connect to the internet to load it. |
| | | `plan_retry` | Erneut versuchen | Try again |
| Offline, ausstehend, Speichern fehlgeschlagen | 3.2; geänderte Zeilen tragen bis zum Abgleich unten rechts am Foto `arrow.triangle.2.circlepath` 10 pt in einem 16-pt-Kreis `surface` (VoiceOver: „wird gesendet“) | `plan_save_error` | „{recipe}“ konnte nicht gespeichert werden. | Couldn't save "{recipe}". |
| | | `plan_syncing_a11y` | wird gesendet | sending |
| Senden auf die Liste fehlgeschlagen (nach S3) | Liste rollt die Artikel zurück; `StatusRow` unter dem Wochenkopf (fest, kein Glas) mit Text-Knopf; betroffene Einträge verlieren „alles auf der Liste“, die Kapsel zählt sie wieder; `error` | `plan_add_error` | {n} Zutaten konnten nicht hinzugefügt werden. | Couldn't add {n} ingredients. |
| | ein oder zwei Namen | `plan_add_error_names` | {names} konnten nicht hinzugefügt werden. (1: {name} konnte nicht hinzugefügt werden.) | Couldn't add {names}. |
| Vergangene Woche | lesbar und änderbar (Nachtragen fürs Tagebuch), ohne Kapsel, ohne „Vorwoche übernehmen“, ohne Status in den Zeilen | – | – | – |
| Andere Woche gezeigt | wie laufende Woche, alle sieben Tage offen, kein „Vergangene Tage“ | `plan_week_next_range`, `plan_week_last_range` | Nächste Woche · {range} / Letzte Woche · {range} | Next week · {range} / Last week · {range} |
| Modul aus | Segment fehlt (A); Routen → D1; Daten bleiben | – | – | – |
| Modul Kalorien aus | keine kcal, kein Fuß, keine Mahlzeit, kein „Ins Tagebuch“ | – | – | – |
| Pro gesperrt | 4.1.5 | – | – | – |
| Änderung von einem anderen Gerät | Zeile wächst ein bzw. schrumpft weg, Ansage | `plan_remote_added_a11y` | „{recipe}“ am {weekday} hinzugefügt | "{recipe}" added on {weekday} |
| | | `plan_remote_removed_a11y` | „{recipe}“ am {weekday} entfernt | "{recipe}" removed from {weekday} |

Weitere Texte des Wochenkopfs und der Tage:

| Schlüssel | DE | EN |
|---|---|---|
| `plan_past_days` | Vergangene Tage ({n}) | Earlier this week ({n}) |
| `plan_day_today` | Heute | Today |
| `plan_day_kcal` | {n} kcal | {n} kcal |
| `plan_day_kcal_from` | ab {n} kcal | from {n} kcal |
| `plan_kcal_footer` | kcal pro Person, eine Portion je Rezept. Richtwerte, kein ärztlicher Rat. | kcal per person, one serving per recipe. Guide values, not medical advice. |
| `plan_kcal_missing` | Für {recipe} fehlen Nährwerte. (mehrere: Für {n} Rezepte fehlen Nährwerte.) | No nutrition info for {recipe}. (several: No nutrition info for {n} recipes.) |
| `plan_choose_recipe` | Rezept wählen | Choose recipe |

Datumsformate: Wochenbereich DE „9.–15. November“ (laufende Woche, Monat ausgeschrieben), sonst „16.–22. Nov.“, über
den Monat „30. Nov. – 6. Dez.“; EN „Nov 9–15“, „Nov 30 – Dec 6“. Tageskopf DE „Mi., 11.“ bzw. „Donnerstag“ + „12.“,
EN „Wed 11“ bzw. „Thursday“ + „12“. Kalenderwoche nach ISO.

#### 4.1.10 Erfolgsmoment und Rückgängig

- Nur beim **ersten Senden einer Woche** (`meal_plans.first_sent_at` war leer). Weitere Sendungen derselben Woche zeigen
  nur den Rückgängig-Hinweis. Wird das erste Senden widerrufen, gilt das nächste wieder als erstes.
- Ablauf: S3 schließt (Pop), danach `showSuccessMoment` (A) mittig über S1: deckende weiße Karte, Radius 26,
  Innenabstand 24, höchstens 320 breit, Schatten wie Menüs; `AvoFigure(pose: celebrating)` 120 pt; Titel `title2`
  22/28 Bold; Unterzeile `subhead` 15/20 `secondaryLabel`. 1,5 s, Tippen schließt, `success` im selben Frame.
- **Gleichzeitig** erscheint der Rückgängig-Hinweis an der Stelle der Kapsel: „9 Zutaten zu Wocheneinkauf hinzugefügt ·
  Widerrufen“. So ist Widerrufen sofort erreichbar.
- Widerrufen: `ItemRepository.undoAddItems(token)` entfernt genau die neuen Artikel und setzt erhöhte Mengen zurück; die
  Einträge verlieren „gesendet“; die Kapsel zeigt wieder die Zahl; `first_sent_at` wird wieder leer, wenn es das erste
  Senden war.
- VoiceOver: statt der 1,5 s die Ansage „Wochenplan ist auf der Liste. 9 Zutaten zu Wocheneinkauf hinzugefügt.“; der
  Hinweis bleibt 10 s.
- Reduce Motion: nur Einblenden. Ab AX1 Avo 96 pt; bei AX5 auf 320 pt oder unter 600 pt Höhe ohne Avo, Text und Haptik
  bleiben.
- Mitglieder der Ziel-Liste sehen die Artikel live; eine gebündelte Mitteilung „Jannis hat 9 Artikel zu Wocheneinkauf
  hinzugefügt“ (B9, `notif_`).

| Schlüssel | DE | EN |
|---|---|---|
| `plan_success_title` | Wochenplan ist auf der Liste. | Your meal plan is on the list. |
| `plan_success_sub` | {n} Zutaten zu {list} hinzugefügt | {n} ingredients added to {list} |
| `plan_success_offers` (nur falls der Owner sie behält, K8) | {n} davon bei {store} im Angebot, laut Händler | {n} of them on offer at {store}, according to the retailer |

#### 4.1.11 Barrierefreiheit

Fokus-Reihenfolge: Toolbar (Vorige Woche, Nächste Woche, Mehr) → Titel „Rezepte“ (A) → Segment (A) → Wochenkopf →
`StatusRow` → Vorwoche übernehmen → Vergangene Tage → je Tag: Kopf, Rezeptzeilen, „Rezept wählen“ → Kalorien-Fuß →
Hauptaktion bzw. Rückgängig-Hinweis → Tab-Leiste.

| Element | Label / Wert DE | EN | Eigenschaften |
|---|---|---|---|
| Wochenkopf | Woche wählen, 9. bis 15. November, 4 von 7 Tagen geplant | Choose week, November 9 to 15, 4 of 7 days planned | Taste; Aktionen „Vorige Woche“, „Nächste Woche“ |
| Tageskopf | Heute, Mittwoch, 11. November, 480 Kilokalorien pro Person | Today, Wednesday, November 11, 480 kilocalories per person | Überschrift |
| Rezeptzeile | Shakshuka mit Feta, 25 Minuten, 2 Portionen, alles auf der Liste (mit Kalorien: …, 480 Kilokalorien pro Portion) | Shakshuka with feta, 25 minutes, 2 servings, all on the list | einstellbar: Wert „2 Portionen“, Hinweis „Wische nach oben oder unten, um die Portionen zu ändern.“ / „Swipe up or down to change servings.“; Aktionen: Rezept ansehen, Kochen, Auf anderen Tag, Ins Tagebuch (Modul), Mahlzeit ändern (Modul), Entfernen |
| „Rezept wählen“ | Rezept für Freitag wählen | Choose a recipe for Friday | Taste |
| Vergangene Tage | Vergangene Tage, 2 | Earlier this week, 2 | Taste, „eingeklappt“/„ausgeklappt“ |
| Vorwoche | Rezepte der Vorwoche übernehmen, 6 Rezepte, 2. bis 8. November | Copy last week's recipes, 6 recipes, November 2 to 8 | Taste „Übernehmen“ als eigener Knoten |
| Kapsel | 5 fehlende Zutaten auf Wocheneinkauf setzen | Add 5 missing ingredients to Weekly shop | Taste |
| Pager | – | – | Drei-Finger-Wischen links = nächste Woche, rechts = vorige Woche |

Schlüssel für die zusammengesetzten Labels: `plan_a11y_week_header`, `plan_a11y_day_header`, `plan_a11y_entry`,
`plan_a11y_entry_hint`, `plan_a11y_servings`, `plan_a11y_choose_for_day`, `plan_a11y_kcal_per_serving`,
`plan_a11y_kcal_per_person`.

Voice Control: Weil die Stepper-Knöpfe aus der Semantik genommen sind, kann man „Mehr Portionen“ nicht per Sprache
antippen; „Nummern einblenden“ funktioniert. Das ist der Preis für eine ruhige VoiceOver-Liste und so akzeptiert.

#### 4.1.12 320 pt und große Schrift

| Stufe | Wochenkopf | Tageskopf | Rezeptzeile | Kapsel |
|---|---|---|---|---|
| 390+ und bis xL | eine Zeile | eine Zeile | Stepper rechts | eine Zeile |
| 320 bis 375 oder xxL bis xxxL | Zähler unter dem Titel | kcal unter dem Datum | Stepper unter der Metazeile | bricht in zwei Zeilen um („5 Zutaten auf“ / „Wocheneinkauf“), Kapsel wächst |
| AX1 bis AX2 | wie oben | wie oben | Foto oben bündig, Stepper unter der Metazeile | wie oben |
| AX3 bis AX5 | wie oben, Titel bricht um | wie oben | ohne Foto | nur „5 Zutaten“ |

Bei 320 × 568 und L passen Titel, Segment, Wochenkopf und die Karte „Heute“ in den ersten Bildschirm über Kapsel und
Tab-Leiste.

#### 4.1.13 Daten

`planWeekProvider(weekStart)` (Einträge, lokal zuerst), `planWeekSummaryProvider(weekStart)` (Zähler, Status pro
Eintrag, Kapsel-Zahl aus `aggregatePlanIngredients`), `planSettingsProvider`, `planTargetListProvider(weekStart)`,
`moduleEnabledProvider(AppModule.mealPlan/calories)`, `isSubscribedProvider`/`ProGate` (A), `itemsNotifierProvider(listId)`
(A, offene Artikel der Ziel-Liste), `recipesProvider` (A, Rezepte-Cache) plus `recipe_snapshot` am Eintrag,
`connectionStateProvider` (B, Lücke L8). Einzelheiten in Abschnitt 7.

---

### S2 Rezept wählen (`/plan/add?day=`)

**Zweck:** Welches Rezept kommt auf diesen Tag? Kein Sheet (Konzept), sondern V-Screen.

**Aufbau** (Hintergrund `background`, Inhalt ab 110 pt):
1. Kopf (`FullScreenEditor`): links Glas-Knopf 44 `xmark` „Schließen“, Inline-Titel „Rezept wählen“; rechts nichts
   (Tipp auf eine Zeile übernimmt sofort).
2. **Tag-Knopf** (Rand 16): Kapsel `fill`, sichtbar 34 hoch, Treffer 44, Innenrand 12; SF `calendar` 15 pt `label`, 6 pt,
   „Für Do., 12. Nov.“ `subhead` 15/20 `label`, 4 pt, `chevron.down` 11 pt `secondaryLabel`. Tipp öffnet ein Menü mit den
   sieben Tagen dieser Woche (aktueller mit Häkchen).
3. **`AvoSearchField`** (8 pt darunter, Rand 16): sichtbar 40 hoch, Treffer 44, Platzhalter „Rezepte suchen“. Ein
   Mikrofon nur, wenn A's Suchfeld es überall hat; die Tastatur-Diktierfunktion reicht.
4. **`AppSegmentedControl`** (12 pt darunter, 44 hoch): „Gespeichert“ / „Für dich“. Standard „Gespeichert“, wenn es
   mindestens ein gespeichertes Rezept gibt, sonst „Für dich“; Wahl pro Gerät gemerkt.
5. **Ergebnisse** (12 pt darunter): Gruppe Radius 26 mit Rezeptzeilen (`RecipeCard` Zeilen-Variante, S2b): Innenrand
   8/16, Foto 56 Radius 14, 12 pt, Titel `headline` (bricht um), Metazeile `footnote` „35 Min · 540 kcal“ (kcal nur mit
   Modul Kalorien), Unterzeilen `footnote` `secondaryLabel`: „von dir“ (eigene Rezepte), „Schon im Plan: Di., 10. Nov.“,
   Allergen-Warnung in `warningText`. Zeile mindestens 72, Trenner ab 84 pt. Kein Element rechts.
   - „Gespeichert“: gemerkte und eigene Rezepte (auch private, keine Entwürfe), neueste zuerst.
   - „Für dich“: Personalisierung von A, höchstens 30 Zeilen. Rezepte mit einem eingetragenen Allergen erscheinen nicht.
     Ist die Allergen-Angabe eines Rezepts unbekannt und hat die Person Allergien eingetragen, erscheint es hier auch
     nicht (fail closed). B filtert zusätzlich selbst mit der Allergien-Liste von A (Lücke L10).
   - Suche (sobald Text im Feld): Segment blendet aus; Gruppen „Gespeichert“ und „Alle Rezepte“ mit `SectionCaps`;
     lokale Treffer sofort, Online-Treffer 300 ms entprellt unten angefügt (Überblendung).
6. Unterer Abstand bis zur Safe Area; keine schwebende Leiste.

**Interaktionen:** Tipp auf eine Zeile legt das Rezept mit den Standard-Portionen (Einstellung, Standard 2) ans Ende
des gewählten Tags, der Screen schließt, die Zeile wächst in S1 ein, S1 scrollt zum Tag. Kein Hinweis, keine Haptik
(das Ergebnis ist sichtbar); VoiceOver-Ansage „Shakshuka für Donnerstag eingeplant“. Langdruck: Kontextmenü mit
Foto-Vorschau, „Rezept ansehen“ (Push des Rezeptdetails über S2, Zurück führt in die Auswahl), „Merken“ bzw. „Nicht
mehr merken“. Keine Mehrfachauswahl; wer dasselbe Rezept zweimal kocht, wählt es zweimal. Schließen ohne Auswahl ohne
Rückfrage.

**Zustände und Texte:**

| Zustand | Darstellung | Schlüssel | DE | EN |
|---|---|---|---|---|
| Titel | | `plan_add_title` | Rezept wählen | Choose recipe |
| Schließen | | `plan_close` | Schließen | Close |
| Tag-Knopf | | `plan_add_for_day` | Für {day} | For {day} |
| | VoiceOver | `plan_add_day_a11y` | Tag: {dayFull}, ändern | Day: {dayFull}, change |
| Suche | | `plan_add_search` | Rezepte suchen | Search recipes |
| Segmente | | `plan_add_saved` / `plan_add_for_you` | Gespeichert / Für dich | Saved / For you |
| Gruppen bei Suche | | `plan_add_saved_section` / `plan_add_all_section` | Gespeichert / Alle Rezepte | Saved / All recipes |
| Unterzeilen | | `plan_add_by_you` | von dir | by you |
| | | `plan_add_already` | Schon im Plan: {day} | Already planned: {day} |
| Keine gespeicherten | `EmptyState` im Segment mit `AvoFigure(pose: waving)` 64 pt (ab AX1 ohne), Text-Knopf wechselt das Segment | `plan_add_empty_title` | Noch keine gespeicherten Rezepte | No saved recipes yet |
| | | `plan_add_empty_body` | Tippe bei einem Rezept auf das Lesezeichen, dann findest du es hier. | Tap the bookmark on a recipe to find it here. |
| | | `plan_add_empty_cta` | „Für dich“ ansehen | See "For you" |
| Keine Treffer | `AvoFigure(pose: thinking)` 64 pt (ab AX1 SF `magnifyingglass` 48 Light) | `plan_add_no_results` | Kein Rezept zu „{q}“ | No recipes for "{q}" |
| | | `plan_add_no_results_body` | Versuch ein anderes Wort oder eine Zutat. | Try another word or an ingredient. |
| Lädt | aus dem Rezepte-Cache, kein Indikator; ohne Cache fünf ruhige Zeilenflächen (Foto 56, eine Titelzeile), kein Schimmer, höchstens bis zur ersten Antwort, sonst „Offline“ | – | – | – |
| Offline | `StatusRow` unter dem Suchfeld | `plan_add_offline` | Offline. Du siehst nur Rezepte, die schon auf diesem iPhone sind. | Offline. Showing only recipes already on this iPhone. |
| Online-Suche fehlgeschlagen | Zeile am Ende der Ergebnisse mit Text-Knopf; lokale Treffer bleiben | `plan_add_load_error` | Weitere Rezepte konnten nicht geladen werden. | Couldn't load more recipes. |
| Langdruck | | `plan_add_save` / `plan_add_unsave` | Merken / Nicht mehr merken | Save / Remove from saved |
| Eingeplant (Ansage) | | `plan_add_done_a11y` | {recipe} für {weekday} eingeplant | {recipe} planned for {weekday} |
| Modul aus | Route → D1 | – | – | – |
| Pro gesperrt | nie (Planen ist frei, W-07) | – | – | – |

**Barrierefreiheit:** Reihenfolge Schließen → Titel → Tag-Knopf → Suchfeld → Segment → Ergebnisse. Zeile: „Ofengemüse
mit Feta, 35 Minuten, schon im Plan am Dienstag“ mit Tipp-Hinweis „für Donnerstag einplanen“ / „plan for Thursday“
(`onTapHint`, Schlüssel `plan_add_row_hint`); Allergen: „Achtung, enthält Erdnuss“ / „Warning, contains peanuts“
(`plan_a11y_allergen`).

**320 und große Schrift:** Tag-Knopf bricht als Kapsel um (zweizeilig, nie abgeschnitten); Segment wird ab etwa AX2 bei
320 pt zum Pull-down; Zeilen wie 4.1.4 (Foto oben bündig ab AX1, entfällt ab AX3).

**Daten:** `savedRecipesProvider`, `recipesProvider`, Personalisierung (A), Allergien (A), `planWeekProvider` (für
„Schon im Plan“), `planSettingsProvider` (Standard-Portionen), `addRecipeToPlan(recipeId, day, servings)` (B).

---

### S3 Zutaten der Woche (`/plan/to-list?week=`)

**Zweck:** Was davon muss wirklich auf die Liste? Kein Sheet (Konzept), sondern V-Screen. Die Hauptaktion sitzt unten fest.

**Aufbau** (Hintergrund `background`, Inhalt ab 110 pt):
1. Kopf: Glas-Knopf 44 `xmark` „Schließen“, Inline-Titel „Zutaten der Woche“, rechts nichts.
2. **Gruppe ohne Kopf:**
   - Zeile „Liste“ (mindestens 56): links `body` „Liste“; rechts Listenname `body` `secondaryLabel`, 8 pt, `StoreChip(listId:)`
     (nur Anzeige), 6 pt, `chevron.up.chevron.down` 13 pt `secondaryLabel`. Tipp öffnet das Listen-Menü (wie 4.1.6 b
     Punkt 2). Ohne Liste zeigt die Zeile „Neue Liste“ in `tint`.
   - Nur laufende Woche, Trenner, dann Zeile mit `AppSegmentedControl` „Ab heute“ / „Ganze Woche“ (Innenrand 8/16,
     Standard „Ab heute“). Künftige Wochen: Zeile entfällt, immer ganze Woche.
3. **Zutaten nach Kategorie** (Reihenfolge im Markt der Ziel-Liste, A), je Gruppe mit `SectionCaps`-Kopf (Kategorie in
   Großbuchstaben, rechts Anzahl der gewählten tabellarisch), 24 pt zwischen Gruppen. Zeilen (`IngredientPickRow`, A-K7):
   - links `CheckCircle` 26 pt in 44er-Trefferfläche (gewählt: Füllung `tintFill` mit weißem Häkchen; nicht gewählt:
     Ring `uncheckedRing`);
   - `ArticleImage` 44 Radius 10 (ab AX1 aus; braucht eine Variante für Zutaten ohne Artikel, Lücke L2);
   - Name `body` 17/22 `label` (auch wenn abgewählt, nicht ausgegraut);
   - Unterzeile `subhead` 15/20 `secondaryLabel`: Herkunft, Grund oder Ersetzung (Tabelle unten);
   - rechts Menge `body` 17/22 `label` tabellarisch („3“, „600 g“, „2 Dosen“, „1 Bund“; ohne Menge leer), darunter
     rechtsbündig die Angebots-Pille „0,89 € · Lidl“ (nur Markt der Ziel-Liste, nie an Grundzutaten, Lücke L3);
   - Trenner ab der Namenskante (94 pt).
4. **„Ohne Zutatenliste“** (nur wenn ein Rezept keine Zutaten hat): Gruppe mit Rezeptname und Unterzeile, ohne Kreis.
5. **Fuß der letzten Kategorie-Gruppe:** `footnote` `secondaryLabel` mit Text-Knopf „Liste bearbeiten“ (öffnet S5;
   die Auswahl in S3 bleibt dabei erhalten).
6. **Ersparnis** (nur `offersAvailableProvider`, Liste nicht ausgeblendet, echte PLZ, Treffer): eigene Gruppe mit
   `HintRow` ohne Aktion: SF `tag` 16 pt `secondaryLabel`, Text `callout` 16/21 `label`. Ohne echte PLZ statt der Zahl die
   Zeile mit Text-Knopf „Postleitzahl festlegen“ (öffnet die Region-Seite unter `/settings/offers`, Bereich Angebote).
7. **Hauptaktion unten** (fest, 34 pt über dem Rand, Rand 16): getönte Kapsel 54 hoch, Radius 27, Tönung 96 %,
   `headline` 17/22 Semibold: „17 Zutaten hinzufügen“, Zahl rollt bei jeder Auswahl. Bei 0 gewählten deaktiviert: Fläche
   `fill`, Text `secondaryLabel` „Nichts ausgewählt“. Darüber ein weicher Verlauf in `background` (keine Linie).
8. Unterer Abstand für Kapsel und Safe Area.

**Was eine Zeile zeigt (Algorithmus in 7, Ergebnis `AggregationResult`):**

| Fall | Kreis | Unterzeile DE | EN | Schlüssel |
|---|---|---|---|---|
| ein oder zwei Rezepte | gewählt | für Chili sin Carne, Gemüse-Curry | for Chili sin carne, Vegetable curry | `plan_ing_for` |
| ab drei Rezepten | gewählt | für 3 Rezepte | for 3 recipes | `plan_ing_for_n` |
| schon auf der Ziel-Liste, Menge reicht | nicht gewählt | Schon auf Wocheneinkauf (1 kg) | Already on Weekly shop (1 kg) | `plan_ing_on_list` |
| schon auf der Liste, Menge reicht nicht | gewählt, nur der Rest | 2 schon auf Wocheneinkauf | 2 already on Weekly shop | `plan_ing_partly` |
| Grundzutat | nicht gewählt | Hast du meist da | Pantry staple | `plan_ing_staple` |
| ersetzt nach Ernährung | gewählt | Hafermilch statt Milch · wegen Laktose | Oat milk instead of milk · lactose | `plan_ing_substitute` |
| „Original verwenden“ gewählt | gewählt | Original statt Hafermilch | Original instead of oat milk | `plan_ing_original` |
| Menge von Hand geändert | gewählt | angepasst | changed | `plan_ing_changed` |
| Allergen ohne Ersatz | gewählt, Warnsymbol vor dem Namen | Enthält Erdnuss | Contains peanuts | `plan_entry_contains` |

Was der Plan selbst schon gesendet hat, zählt nicht als „schon auf der Liste“ (W-17).

**Interaktionen:**
- Tipp auf eine Zeile schaltet die Auswahl um; Kreis füllt bzw. leert sich (`quick`), Zahlen im Knopf und im Gruppenkopf
  rollen; nichts springt; keine Haptik.
- Tipp auf die Menge oder Langdruck > „Menge ändern“ → S4.
- Langdruck-Menü: „Menge ändern“ (`pencil`); „Original verwenden: Milch“ (`arrow.uturn.backward`, nur bei Ersetzungen);
  „Immer weglassen“ (`minus.circle`): setzt die Zutat auf „Hast du meist da“, Zeile wird abgewählt, ihre Unterzeile lautet
  4 s (VoiceOver 10 s) „Hast du meist da · Widerrufen“ mit Text-Knopf (kein schwebender Hinweis); „Rezepte ansehen“
  (Untermenü, Tipp öffnet das Rezeptdetail über S3).
- Zeitraum umschalten: Zeilen wachsen ein oder schrumpfen weg (`standard`), Zahlen rollen; `selection` nur beim Wischen
  über das Segment (A-Komponente).
- Liste wechseln: „Schon auf …“ und Angebote rechnen lokal sofort neu; Pillen anderer Märkte erscheinen nie (W-10).
- „17 Zutaten hinzufügen“: S3 schließt sofort (optimistisch). Ein Aufruf `ItemRepository.instance.addItems(listId,
  [NewItem(name:, quantity:, unit:, category:, notes:)])` (A5, geliefert): Kategorie lokal (`categorizeLocal`), Notiz
  „für Chili sin Carne, Gemüse-Curry“ an neuen Artikeln (bestehende Notizen bleiben), Mengen bestehender offener Artikel
  werden erhöht; Angebot nur des Ziel-Markts anhängen, bei Modul aus oder Kill-Switch nichts. Danach Einträge als
  gesendet markieren (`sent_list_id`, `sent_servings`, `sent_at`), Token für Rückgängig behalten, dann 4.1.10. Kein
  Fortschritt „3 von 17“, keine Sperre, kein Knopf „Ansehen“.
- Schließen ohne Hinzufügen: Auswahländerungen werden nicht gespeichert, keine Rückfrage (W-06). „Immer weglassen“ und
  „Menge ändern“ bleiben gespeichert.

**Zustände und Texte:**

| Zustand | Darstellung | Schlüssel | DE | EN |
|---|---|---|---|---|
| Titel | | `plan_tolist_title` | Zutaten der Woche | This week's ingredients |
| Zeile Liste | | `plan_tolist_list` | Liste | List |
| | VoiceOver | `plan_tolist_list_a11y` | Liste: {list}, Markt: {store}, ändern | List: {list}, store: {store}, change |
| Zeitraum | | `plan_tolist_from_today` / `plan_tolist_whole_week` | Ab heute / Ganze Woche | From today / Whole week |
| Gruppenkopf VoiceOver | | `plan_tolist_section_a11y` | {category}, {n} ausgewählt | {category}, {n} selected |
| Ohne Zutatenliste | | `plan_tolist_no_list_section` | Ohne Zutatenliste | No ingredient list |
| | | `plan_tolist_no_list_row` | Im Rezept stehen keine Zutaten. | This recipe lists no ingredients. |
| Fuß | `{a}`, `{b}` sind zwei Einträge aus „Hast du meist da“ | `plan_tolist_staples_footer` | Zutaten, die du meist da hast, sind abgewählt, zum Beispiel {a} und {b}. | Pantry staples such as {a} and {b} are unticked. |
| | Text-Knopf | `plan_tolist_staples_edit` | Liste bearbeiten | Edit staples |
| Ersparnis | Text aus `formatOfferSummary` | – | 3 von 17 Zutaten diese Woche bei Lidl im Angebot, ca. 2,40 € gespart, in deiner Region | 3 of 17 ingredients on offer at Lidl this week, about €2.40 saved, in your area |
| | Ersparnis unter 0,50 € | – | 3 von 17 Zutaten diese Woche bei Lidl im Angebot, in deiner Region | 3 of 17 ingredients on offer at Lidl this week, in your area |
| | ohne echte PLZ | `plan_tolist_set_zip` (Wortlaut aus `offer_`) | Für Angebote in deiner Region: Postleitzahl festlegen | For offers in your area: set your postcode |
| Pille VoiceOver | | `plan_tolist_offer_a11y` | im Angebot {price} laut Händler, statt {was} (ohne statt-Preis ohne Zusatz) | on offer, {price} according to the retailer, was {was} |
| Knopf | | `plan_tolist_add` | {n} Zutaten hinzufügen (1: 1 Zutat hinzufügen) | Add {n} ingredients (1: Add 1 ingredient) |
| | 0 gewählt | `plan_tolist_nothing` | Nichts ausgewählt | Nothing selected |
| Langdruck | | `plan_tolist_change_amount` | Menge ändern | Change amount |
| | | `plan_tolist_use_original` | Original verwenden: {orig} | Use original: {orig} |
| | | `plan_tolist_always_leave_out` | Immer weglassen | Always leave out |
| | | `plan_tolist_view_recipes` | Rezepte ansehen | View recipes |
| Nichts zu tun (nur über „Mehr“ erreichbar) | `EmptyState` ohne Avo: SF `checkmark.circle` 48 Light `secondaryLabel`, Titel, Satz, Text-Knopf (wechselt in den Listen-Tab zu dieser Liste) | `plan_tolist_done_title` | Alles ist auf der Liste | Everything's on the list |
| | | `plan_tolist_done_body` | Die Zutaten für diese Woche stehen auf {list}. | This week's ingredients are on {list}. |
| | | `plan_tolist_open_list` | {list} öffnen | Open {list} |
| Keine Liste vorhanden | Zeile „Liste“ zeigt „Neue Liste“; Tipp öffnet A's „Neue Liste“ (Vollbild) mit Vorschlag „Wocheneinkauf“; danach zurück, die neue Liste steht in der Zeile (A-P7) | `plan_menu_new_list` | Neue Liste | New list |
| Lädt | sofort aus lokalem Stand (Plan, Rezepte-Cache, offene Artikel der Ziel-Liste, Angebots-Cache); fehlende Pillen erscheinen nicht nachträglich in sichtbaren Zeilen, erst beim nächsten Öffnen | – | – | – |
| Offline | `StatusRow` unter dem Kopf; Hinzufügen geht in die Warteschlange; Pillen nur aus dem Cache | `plan_tolist_offline` | Offline. Die Zutaten kommen auf die Liste, sobald du wieder online bist. | Offline. The ingredients will be added when you're back online. |
| Fehler nach dem Hinzufügen | in S1 (4.1.9) | – | – | – |
| Angebote nicht verfügbar | Pillen und Ersparnis fehlen ohne Lücke; `StoreChip` bleibt | – | – | – |
| Kalorien aus | keine Änderung (S3 zeigt keine kcal) | – | – | – |
| Pro gesperrt | S3 öffnet erst nach dem Kauf; auch „Mehr“ > „Zutaten der Woche“ öffnet die Paywall | – | – | – |
| Modul aus | Route → D1 | – | – | – |

**Barrierefreiheit:** Reihenfolge Schließen → Titel → Liste → Zeitraum → je Kategorie Kopf und Zeilen → Ohne
Zutatenliste → Fuß → Ersparnis → Knopf. Zeile als Ankreuzfeld (`checked`): „Zwiebeln, 3, für Chili sin Carne und
Gemüse-Curry, ausgewählt“; Aktionen „Menge ändern“, „Immer weglassen“, „Original verwenden“ (wenn vorhanden). Abgewählt:
„Reis, 475 Gramm, schon auf Wocheneinkauf, 1 Kilogramm, nicht ausgewählt“. Einheiten werden ausgeschrieben gesprochen
(`plan_a11y_unit_*`). Knopf: „17 Zutaten zu Wocheneinkauf hinzufügen, Taste“ (`plan_tolist_add_a11y`).

**320 und große Schrift:** Menge und Pille rutschen ab AX1 unter den Namen (wie `ItemRow`), der Kreis bleibt oben bündig
zur ersten Zeile; in der Listen-Zeile bricht `StoreChip` unter den Listennamen; das Segment wird bei Platzmangel zum
Pull-down; der Knopf bricht um und wächst, der Text bleibt vollständig.

**Daten:** `aggregatePlanIngredients` (B, rein, 7.2), `planWeekProvider`, `planTargetListProvider`,
`itemsNotifierProvider(listId)` (A), `pantryStaplesProvider` (A, Lücke L9), `RecipeAdaptation` bzw.
`IngredientSubstitutionService` (A), `storeForListProvider(listId)` (B), Angebots-Cache des Markts (B, Lücke L4),
`offersAvailableProvider`, `offersHiddenForListProvider` (B), `regionProvider` (B2.1, Lücke L7), `formatOfferSummary`
(B2.2), `ItemRepository.addItems`/`undoAddItems` (A).

---

### S4 Menge ändern (`/plan/to-list/amount?key=`)

**Zweck:** Wie viel brauche ich davon, für diesen Einkauf? Folgeschritt in S3, Muster `D2-Artikel`.

**Aufbau:**
1. Kopf: Glas-Knopf 44 `chevron.left` (VoiceOver „Zurück zu Zutaten der Woche“), Inline-Titel = Zutat („Zwiebeln“),
   rechts getönte Kapsel 44 „Fertig“ (deaktiviert bei 0 oder leer).
2. Gruppe „Menge“ (`SectionCaps`): Zeile mindestens 56: links `body` „Menge“, rechts `ValueStepper` kompakt und daneben
   ein Zahlenfeld (Kapsel `fill`, sichtbar 34 hoch, Treffer 44, 72 breit, `body` tabellarisch rechtsbündig, Tastatur
   `numberWithOptions(decimal: true)`, deutsches Komma über `parseLocaleDouble`).
3. Gruppe „Einheit“: höchstens vier sinnvolle Einheiten als Einheiten-Segment wie `D2-Artikel` (sichtbar 34 hoch, Teile
   52 breit, Treffer 44); mehr als vier als `AppFilterChip`-Reihe mit Umbruch.
4. Fuß `footnote`.

**Schrittweite:** Stück, Dose, Bund, Zehe, Packung 1; g und ml 10 unter 100, 25 ab 100, 100 ab 1.000; kg und l 0,5.

**Verhalten:** „Fertig“ setzt die Menge nur für diesen Einkauf (nicht im Rezept) und kehrt zurück; die Zeile in S3 zeigt
danach die neue Menge mit Unterzeile „angepasst“. Gespeichert bis zum Hinzufügen, auch wenn S3 zwischendurch geschlossen
wird. Zurück ohne „Fertig“ verwirft ohne Rückfrage. Stepper mit `selection`. Ungültige Eingabe: Hinweis unter dem Feld,
„Fertig“ deaktiviert.

| Schlüssel | DE | EN |
|---|---|---|
| `plan_amount_back_a11y` | Zurück zu Zutaten der Woche | Back to this week's ingredients |
| `plan_amount_done` | Fertig | Done |
| `plan_amount_section` | Menge | Amount |
| `plan_amount_unit_section` | Einheit | Unit |
| `plan_amount_footer` | Aus {n} Rezepten berechnet: {amount}. Gilt nur für diesen Einkauf, das Rezept bleibt gleich. (1: Aus dem Rezept berechnet: {amount}. …) | Worked out from {n} recipes: {amount}. Applies to this shop only. The recipe stays the same. |
| `plan_amount_invalid` | Gib eine Menge über 0 ein. | Enter an amount above 0. |
| `plan_unit_piece` / `_g` / `_kg` / `_ml` / `_l` / `_bunch` / `_can` / `_pack` / `_clove` | Stück / g / kg / ml / l / Bund / Dose / Packung / Zehe | pcs / g / kg / ml / l / bunch / can / pack / clove |

**Barrierefreiheit:** Feld-Label „Menge“, Wert gesprochen mit Einheit („3 Stück“); Stepper-Knöpfe „Weniger“/„Mehr“
(eigene Knoten, hier nicht zusammengelegt); Einheiten als Auswahl mit „ausgewählt“.

**320 und große Schrift:** ab AX1 stehen Stepper und Feld untereinander unter „Menge“; Einheiten brechen um; die
Tastatur hebt den Inhalt, der Kopf bleibt stehen.

**Zustände:** offline wie überall (lokal); Modul aus → D1 (nur bei Deep Link denkbar).

---

### S5 Hast du meist da, aus S3 (`/plan/to-list/pantry`)

Gleiches Widget wie S13, Kopf mit `chevron.left` „Zurück zu Zutaten der Woche“. Beim Zurückkehren rechnet S3 die
Vorauswahl neu; was die Person in S3 vorher von Hand an- oder abgewählt hat, bleibt.

---

### S6 Verschieben (`/plan/move?entry=`)

**Zweck:** Ein Rezept auf einen Tag außerhalb der laufenden Woche legen („Auf anderen Tag“ > „Anderes Datum …“).

**Aufbau:** Kopf `xmark` „Schließen“, Inline-Titel „Verschieben“, rechts getönte Kapsel 44 „Verschieben“. Gruppe mit der
Rezeptzeile (nicht tippbar) und Unterzeile „Jetzt: Fr., 13. Nov.“. Gruppe „Tag“ mit `PlanDayCalendar` wie S8. Keine
Portionen-Gruppe (die Portionen bleiben).

**Verhalten:** „Verschieben“ setzt das Datum, schließt, S1 zeigt die Zielwoche nicht von selbst; Hinweis „Auf Mo., 23.
Nov. verschoben · Widerrufen“. Ist der Eintrag schon gesendet, bleibt er gesendet (die Artikel stehen ja schon auf der
Liste).

| Schlüssel | DE | EN |
|---|---|---|
| `plan_move_title` | Verschieben | Move |
| `plan_move_action` | Verschieben | Move |
| `plan_move_now` | Jetzt: {day} | Now: {day} |

Zustände: Eintrag gelöscht (zweites Gerät) → `EmptyState` „Dieses Rezept ist nicht mehr im Plan.“ / „This recipe is no
longer in your plan.“ (`plan_move_gone`) mit Text-Knopf „Schließen“; offline lokal; Modul aus → D1.

---

### S7 Woche wählen (`/plan/week?from=`)

**Zweck:** Eine weit entfernte Woche öffnen („Datum wählen …“ im Wochen-Menü).

**Aufbau:** Kopf `xmark` „Schließen“, Inline-Titel „Woche wählen“. Gruppe mit `PlanDayCalendar` im Wochenmodus: Tipp auf
einen Tag markiert seine ganze Wochenreihe (`tintSoft`) und schließt sofort; S1 blendet auf diese Woche über. Bereich ±52
Wochen; Tage mit Plan tragen einen 4-pt-Punkt `secondaryLabel` unter der Zahl. Fuß „Tippe auf einen Tag, um seine Woche
zu öffnen.“ Ab AX1 statt des Kalenders eine Liste der Wochen („KW 48 · 23.–29. Nov.“, laufende Woche markiert und
zuerst sichtbar).

| Schlüssel | DE | EN |
|---|---|---|
| `plan_week_picker_title` | Woche wählen | Choose week |
| `plan_week_picker_footer` | Tippe auf einen Tag, um seine Woche zu öffnen. | Tap a day to open its week. |
| `plan_a11y_has_plan` | geplant: {recipes} | planned: {recipes} |

---

### S8 Zum Wochenplan („Anderes Datum …“) (`/plan/schedule/:recipeId?servings=&day=`)

**Einstieg:** Im Rezeptdetail (A) > `ellipsis` > „Zum Wochenplan“ (`calendar`) als Untermenü an derselben Stelle, ebenso
im Kontextmenü jeder `RecipeCard` (A baut das Menü, B liefert Inhalt und Aktion, A-P8). Untermenü:

| Eintrag | DE | EN | Schlüssel |
|---|---|---|---|
| heute | Heute, Mi., 11. Nov. | Today, Wed, Nov 11 | `plan_sched_today` |
| morgen | Morgen, Do., 12. Nov. | Tomorrow, Thu, Nov 12 | `plan_sched_tomorrow` |
| weitere fünf Tage | Fr., 13. Nov. … Di., 17. Nov. | Fri, Nov 13 … Tue, Nov 17 | – |
| Untertitel je Tag | schon geplante Rezepte („Chili sin Carne“), sonst nichts | – | – |
| Trenner, dann | Anderes Datum … | Other date… | `plan_ctx_other_date` |

Ein Tipp auf einen Tag ruft `addRecipeToPlan(recipeId, day, servings)` mit den Portionen, die im Detail gerade
eingestellt sind (sonst Standard), schließt das Menü und zeigt den Hinweis „Für Do., 12. Nov. eingeplant · Widerrufen“
im Rezeptdetail (A's `AvoToastHost`). Keine Haptik. Danach steht unter dem Titel des Details `PlanEntryMeta` (S9).

**„Anderes Datum …“ = S8-Screen:**
1. Kopf: `xmark` „Schließen“, Inline-Titel „Zum Wochenplan“, rechts getönte Kapsel 44 „Hinzufügen“.
2. Gruppe mit der Rezeptzeile (Foto 56, Titel, „35 Min · 540 kcal“), nicht tippbar; ggf. „Schon im Plan: Di., 10. Nov.“.
3. Gruppe „Tag“ (`SectionCaps`): `PlanDayCalendar` als Monatsblatt (`InlineCalendar`, A-K9): Auswahl Kreis 36 `tintFill`
   mit weißer Zahl, Treffer 44; heute Zahl in `tint` 600; Tage mit Plan mit 4-pt-Punkt; Bereich 52 Wochen zurück bis 52
   voraus; vorausgewählt `day=` oder der erste freie Tag nach den sieben Tagen des Untermenüs. Darunter in derselben Gruppe
   eine Zeile `footnote` `secondaryLabel`: „Schon geplant: Chili sin Carne“ oder „Noch nichts geplant“.
4. Gruppe „Portionen“: Zeile `body` „Portionen“ mit `ValueStepper` (1–20), vorbelegt aus `servings`.
5. Fuß: „Die Zutaten kommen erst auf die Liste, wenn du sie im Wochenplan hinzufügst.“

**Verhalten:** „Hinzufügen“ legt den Eintrag an, schließt, Hinweis „Für Mo., 23. Nov. eingeplant · Widerrufen“ dort, wo
man herkam. Schließen ohne Auswahl ohne Rückfrage. Dasselbe Rezept zweimal in einer Woche ist erlaubt.

| Schlüssel | DE | EN |
|---|---|---|
| `plan_sched_title` | Zum Wochenplan | Add to meal plan |
| `plan_sched_add` | Hinzufügen | Add |
| `plan_sched_day_section` | Tag | Day |
| `plan_sched_already` | Schon geplant: {recipes} | Already planned: {recipes} |
| `plan_sched_nothing` | Noch nichts geplant | Nothing planned yet |
| `plan_sched_servings` | Portionen | Servings |
| `plan_sched_footer` | Die Zutaten kommen erst auf die Liste, wenn du sie im Wochenplan hinzufügst. | Ingredients go on your list only when you add them from the meal plan. |
| `plan_sched_gone_title` | Rezept nicht mehr verfügbar | Recipe no longer available |
| `plan_sched_gone_body` | Es wurde gelöscht oder wird nicht mehr geteilt. | It was deleted or is no longer shared. |
| `plan_sched_gone_back` | Schließen | Close |
| `plan_a11y_calendar_day` | {dayFull}{, heute}{, geplant: …}{, ausgewählt} | {dayFull}{, today}{, planned: …}{, selected} |

**Zustände:** Rezept gelöscht (Deep Link, Avo) → `EmptyState` ohne Avo mit den `plan_sched_gone_*`-Texten, ohne
„Hinzufügen“; offline lokal (Warteschlange, Sync-Zeichen in S1); Modul aus → Menüeintrag fehlt, Route → D1; Pro nie.

**320 und große Schrift:** Ab AX1 ersetzt eine Tageszeile den Kalender: „Mo., 23. Nov.“ in der Mitte, links und rechts
Glas-Knöpfe 44 „Tag davor“ / „Tag danach“, Tipp aufs Datum öffnet ein Menü mit den nächsten 14 Tagen; der Stepper steht
in eigener Zeile unter „Portionen“. Untermenü-Einträge brechen wie Systemmenüs um.

**Barrierefreiheit:** Kalender als Raster mit Tagen als Tasten („Montag, 23. November, ausgewählt“); Wischen zwischen
Monaten auch über Knöpfe „Voriger Monat“ / „Nächster Monat“ (44, im Kalenderkopf) und Drei-Finger-Wischen.

---

### S9 Rezeptdetail aus dem Plan (Screen von A, Slot von B)

- Tipp auf eine Rezeptzeile in S1 pusht das Rezeptdetail von A im Rezepte-Tab: `/recipes/:recipeId?entry=<entryId>`.
  Mit `entry` übernimmt das Detail die Portionen des Eintrags; ändert man sie dort, schreibt das Detail ohne Rückfrage
  über `setPlanEntryServings(entryId, n)` in den Eintrag (A-P9).
- Slot unter dem Titel: `PlanEntryMeta(recipeId:, entryId:)` (B), `subhead` 15/20 `secondaryLabel` mit SF `calendar`
  13 pt: „Im Plan: Mi., 11. Nov. · 4 Portionen“; ohne `entryId` die nächsten Einträge dieses Rezepts („Im Plan: Mi., 11.
  Nov. und Sa., 14. Nov.“); kein Eintrag, Modul aus → `SizedBox.shrink()`. Tipp öffnet S1 bei diesem Tag.
- „Zutaten auf die Liste“ im Detail (A) markiert den Plan-Eintrag als gesendet: `markPlanEntrySent(entryId, listId,
  servings)` (B).
- „Kochen“ öffnet den Kochmodus mit den Plan-Portionen.

| Schlüssel | DE | EN |
|---|---|---|
| `plan_meta_entry` | Im Plan: {day} · {n} Portionen (1: 1 Portion) | Planned: {day} · {n} servings (1: 1 serving) |
| `plan_meta_days` | Im Plan: {day1} und {day2} (mehr: Im Plan: {day1} und {n} weitere Tage) | Planned: {day1} and {day2} (more: Planned: {day1} and {n} more days) |

VoiceOver: „Im Wochenplan am Mittwoch, 11. November, 4 Portionen. Taste, öffnet den Wochenplan.“

---

### S10 Home-Abschnitt „Heute kochen“ (`HomeCookToday()`, `homeCookTodayHasContentProvider`)

**Ort und Vertrag:** Abschnitt 10 von `D2-FuerDich`, A ordnet ihn ein (Vertrag Stufe 2 in `prompt-b-vorrang.md`). B
liefert Widget und **synchronen** `Provider<bool>` aus dem kontobezogenen Cache, damit beim ersten Frame feststeht, ob der
Abschnitt da ist (nichts springt nachträglich ein). Direkt darunter folgt „Tipp von Avo“ mit Avo-Figur; dieser
Abschnitt zeigt deshalb **keine** Avo-Figur, auch nicht die Mini-Figur aus der D2-Rezeptkarte.

**Aufbau (Fall „heute geplant, Zutaten fehlen“), Maße aus D2:**
1. Abschnittskopf: `title3` 20/25 Semibold „Heute kochen“ links (Überschrift), rechts Text-Knopf „Alle“ `subhead` 15/20
   `tint`, Treffer 44 → `/plan?day=<heute>` (Wechsel in den Rezepte-Tab).
2. Karte 8 pt darunter, Rand 16: `RecipeHeroCard` (S2b, A-K8), Foto 220 hoch, Radius 26, Schatten `0 1 2 .04`.
3. Status-Kapsel oben links (12/12): Weiß 96 % (3.7) mit Blur 12, Innenrand 5 10 5 7, `footnote` 13/16 600.
4. Glas-Panel unten (12 pt Rand), Radius 20, Innenrand 12: Titel `title3` 20/25 600 `label` (Link zum Detail), Meta
   `footnote` 13/18 `labelOnGlass` #2C2C2E: „25 Min · ★ 4,8“ (mit Modul Kalorien zusätzlich „ · 480 kcal“), dann 10 pt
   und `AppButton` primary 44 hoch über volle Breite, Grün 96 %, Plus 17 pt, `subhead` 15/20 600.

**Fälle** (immer nur einer; Rangfolge von oben):

| Fall | Kopf | Status-Kapsel | Knopf | Tipp auf Karte |
|---|---|---|---|---|
| heute geplant, 1 bis 2 Zutaten fehlen | Heute kochen | „Koriander und Paprika fehlen noch“ (`label`) | „2 Zutaten auf Wocheneinkauf“ | Detail mit `entry` |
| heute geplant, 3 oder mehr fehlen | Heute kochen | „7 Zutaten fehlen noch“ (`label`) | „7 Zutaten auf Wocheneinkauf“ | Detail |
| heute geplant, alles auf der Ziel-Liste oder gekauft | Heute kochen | `checkmark.circle.fill` `tint` + „Alles auf der Liste“ (`tint`) | kein Knopf, Panel kürzer | Detail |
| heute geplant, Zutaten stehen auf einer anderen Liste | Heute kochen | „Zutaten stehen auf Grillabend“ | „Grillabend öffnen“ | Detail |
| ab 20 Uhr, morgen geplant | Morgen kochen | wie oben für morgen | wie oben | Detail |
| Sonntag ab 16 Uhr, nächste Woche leer, Plan in den letzten 4 Wochen genutzt | Heute kochen entfällt; kompakte Form: Gruppe Radius 26 mit `HintRow`: SF `calendar` 16 pt `secondaryLabel`, „Nächste Woche ist noch leer.“ `callout`, Text-Knopf „Planen“ → `/plan?week=<nächster Montag>` | – | – | – |
| Rezept gelöscht | kompakte Form ohne Foto: „Heute im Plan: Chili sin Carne“ + „Rezept nicht mehr verfügbar“ `secondaryLabel`, kein Knopf | – | – | S1 bei heute |
| nichts geplant, Modul aus, Einstellung „‚Heute kochen‘ zeigen“ aus, heute ausgeblendet | kein Abschnitt (`SizedBox.shrink()`, Provider false) | – | – | – |

Mehrere Rezepte heute: das erste nach Mahlzeit, dann Position; „Alle“ führt zum Rest.

**Interaktionen:** Knopf ruft `addItems` mit genau den fehlenden Zutaten dieses Eintrags (gleiche Regeln wie S3:
Grundzutaten weg, Vorhandenes weg, Ziel-Markt-Angebot), markiert den Eintrag als gesendet, Hinweis auf Home „2 Zutaten
zu Wocheneinkauf hinzugefügt · Widerrufen“; die Karte wechselt in den Fall „Alles auf der Liste“ (Überblendung). Kein
Erfolgsmoment. Langdruck auf die Karte: Kontextmenü „Heute ausblenden“, „Nicht mehr zeigen“ (schaltet die Einstellung
aus, Hinweis „‚Heute kochen‘ ausgeblendet · Widerrufen“), „Wochenplan öffnen“.

**Zustände:** offline aus dem lokalen Stand, der Knopf geht in die Warteschlange (die Offline-Zeile gehört Home, A);
Pro gesperrt (nur falls „auf die Liste“ Pro ist): `ProBadge` vor dem Knopftext, `ProGate.run(…, origin: 'home_cook_today')`,
nach dem Kauf laufen die Zutaten auf die Liste; Pro unbekannt: keine Badge; Kalorien aus: ohne kcal.

| Schlüssel | DE | EN |
|---|---|---|
| `plan_cook_today` | Heute kochen | Cook today |
| `plan_cook_tomorrow` | Morgen kochen | Cook tomorrow |
| `plan_cook_all` | Alle | All |
| `plan_cook_all_a11y` | Alle im Wochenplan | All in meal plan |
| `plan_cook_missing_names` | {names} fehlen noch (1: {name} fehlt noch) | {names} still missing (1: {name} still missing) |
| `plan_cook_missing_n` | {n} Zutaten fehlen noch | {n} ingredients still missing |
| `plan_cook_all_on_list` | Alles auf der Liste | Everything's on the list |
| `plan_cook_other_list` | Zutaten stehen auf {list} | Ingredients are on {list} |
| `plan_cook_open_list` | {list} öffnen | Open {list} |
| `plan_cook_next_week_empty` | Nächste Woche ist noch leer. | Next week is still empty. |
| `plan_cook_plan` | Planen | Plan |
| `plan_cook_today_in_plan` | Heute im Plan: {recipe} | In today's plan: {recipe} |
| `plan_cook_hide_today` | Heute ausblenden | Hide for today |
| `plan_cook_dont_show` | Nicht mehr zeigen | Don't show again |
| `plan_cook_open_plan` | Wochenplan öffnen | Open meal plan |
| Knopf | `plan_action_add` (gleicher Schlüssel wie S1) | |

Namen in `{names}`: „Koriander und Paprika“ (DE), „coriander and peppers“ (EN), aus der Zutat, nicht aus dem Rezepttext.

**Barrierefreiheit:** Karte ein Element: „Heute kochen: Shakshuka mit Feta, 25 Minuten, Bewertung 4,8, Koriander und
Paprika fehlen noch“ (`plan_a11y_cook_card`), Taste, öffnet das Rezept; Aktionen „Heute ausblenden“, „Wochenplan
öffnen“. Knopf eigener Knoten: „2 fehlende Zutaten auf Wocheneinkauf setzen“. Foto und Stern dekorativ.

**Reduce Transparency:** Panel deckend `surface`, Status-Kapsel deckend Weiß.

**320 und große Schrift:** Text bricht um; der Knopf wächst in der Höhe. Ab AX1 steht das Foto (160 hoch, oben Radius 26)
über dem Text, das Panel wird eine deckende Fläche unter dem Foto in derselben Karte; ab AX3 ohne Foto.

**Daten:** `homeCookTodayProvider` (B, synchron aus dem Plan-Cache: Eintrag heute/morgen, fehlende Zutaten,
Ziel-Liste), `planSettingsProvider.showCookToday`, `moduleEnabledProvider`, `itemsNotifierProvider` (A), `addItems` (A).
Regel für A: „Noch 640 kcal heute · Ideen“ erscheint nicht, wenn heute ein Rezept geplant ist (A-P10).

---

### S11 Einstellungen Wochenplan (`/settings/plan`)

**Einstieg:** Profil (A, `X-Profil`) > Zeile „Wochenplan“ (nur mit Modul, A-P11); „Mehr“ > „Wochenplan-Einstellungen“.

**Aufbau** (Muster `X-Angebote`): Glas-Knopf 44 `chevron.left` „Zurück“; großer Titel „Wochenplan“ 34/41 ab 106 pt;
Gruppen mit `SectionCaps`-Kopf und Fußnote:

| Gruppe | Zeile | Bauteil | Wert / Standard |
|---|---|---|---|
| Standard | Portionen | `ValueRow` mit `ValueStepper` kompakt rechts | 2 (1–20) |
| | Liste | `NavRow` → S12 | „Zuletzt geöffnete Liste“ bzw. Listenname |
| Zutaten | Hast du meist da | `NavRow` → S13 | Anzahl, z. B. „6“ |
| (Fuß) | | | „Diese Zutaten sind abgewählt, wenn du Zutaten aus dem Wochenplan oder aus einem Rezept auf die Liste setzt.“ |
| Home | „Heute kochen“ zeigen | `ToggleRow` | an |
| Mitteilungen | An die nächste Woche erinnern | `ToggleRow` | aus |
| | Tag | `NavRow` mit Pull-down-Menü Montag … Sonntag (nur wenn an) | Sonntag |
| | Uhrzeit | `ValueRow`; Tipp klappt an Ort und Stelle einen Zeit-Rad-Wähler (`CupertinoDatePicker`, Modus Zeit, 216 hoch) in der Gruppe auf, erneuter Tipp klappt ihn zu (kein Popup) | 18:00 |
| (Fuß) | | | „Nur wenn die nächste Woche noch leer ist.“ |
| ohne Kopf | Module | `NavRow` mit Unterzeile „Wochenplan ausschalten“ → `/settings/modules` (A) | – |

**Mitteilungen einschalten:** Beim ersten Einschalten erst D2 (Vorab-Erklärung), dann die Systemabfrage. Abgelehnt:
Schalter springt zurück auf aus, unter der Gruppe die Zeile „Mitteilungen für Avo sind aus.“ mit Text-Knopf „In
Einstellungen erlauben“ (`openAppSettings()` aus `permission_handler`). Die Mitteilung selbst („Nächste Woche ist noch
leer. Jetzt planen?“) baut B9 (`notif_plan_reminder`), nur wenn die nächste Woche leer ist.

| Schlüssel | DE | EN |
|---|---|---|
| `plan_settings_title` | Wochenplan | Meal plan |
| `plan_settings_defaults` | Standard | Defaults |
| `plan_settings_servings` | Portionen | Servings |
| `plan_settings_list` | Liste | List |
| `plan_settings_last_list` | Zuletzt geöffnete Liste | Last opened list |
| `plan_settings_ingredients` | Zutaten | Ingredients |
| `plan_settings_staples` | Hast du meist da | Pantry staples |
| `plan_settings_staples_footer` | Diese Zutaten sind abgewählt, wenn du Zutaten aus dem Wochenplan oder aus einem Rezept auf die Liste setzt. | These are unticked when you add ingredients from the meal plan or a recipe. |
| `plan_settings_home` | Home | Home |
| `plan_settings_show_cook` | „Heute kochen“ zeigen | Show "Cook today" |
| `plan_settings_notifications` | Mitteilungen | Notifications |
| `plan_settings_remind` | An die nächste Woche erinnern | Remind me to plan next week |
| `plan_settings_remind_footer` | Nur wenn die nächste Woche noch leer ist. | Only if next week is still empty. |
| `plan_settings_day` | Tag | Day |
| `plan_settings_time` | Uhrzeit | Time |
| `plan_settings_notif_off` | Mitteilungen für Avo sind aus. | Notifications for Avo are off. |
| `plan_settings_notif_allow` | In Einstellungen erlauben | Allow in Settings |
| `plan_settings_modules` | Module | Modules |
| `plan_settings_modules_sub` | Wochenplan ausschalten | Turn off Meal plan |

**Zustände:** lokal sofort, Änderungen gelten sofort und gleichen sich über das Konto ab; offline mit Sync-Zeichen an der
geänderten Zeile; Modul aus: Seite nicht erreichbar (Zeile im Profil fehlt), Deep Link → D1.

**Barrierefreiheit:** Portionen-Zeile einstellbar („Portionen, 2“); Schalter mit Zustand; Zeit-Wähler aufgeklappt meldet
„ausgeklappt“; Großbuchstaben-Köpfe mit normalem Semantik-Label.

**320 und große Schrift:** Werte rutschen ab AX1 unter die Titel (`NavRow` stapelt); der Stepper steht unter „Portionen“;
der Rad-Wähler wächst mit der Schrift (System).

**Daten:** `planSettingsProvider` (Tabelle `meal_plan_settings`, lokal gespiegelt), `listsNotifierProvider` und
`lastAccessedListProvider` (A), `pantryStaplesProvider` (A, L9), Mitteilungsrechte (`permission_handler`).

---

### S12 Liste für neue Wochen (`/settings/plan/list`)

Kopf `chevron.left` „Zurück“, Inline-Titel „Liste“. Gruppe: erste Zeile „Zuletzt geöffnete Liste“, dann alle Listen
(Name `body`, rechts „4 offen“ `secondaryLabel`), die gewählte mit SF `checkmark` 17 pt 600 `tint` rechts; Trenner;
„Neue Liste“ (`tint`, A's Vollbild „Neue Liste“, danach gewählt). Fuß: „Gilt für neue Wochen. Für eine einzelne Woche
wählst du die Liste in „Zutaten der Woche“.“ Tipp wählt und kehrt zurück.

| Schlüssel | DE | EN |
|---|---|---|
| `plan_list_title` | Liste | List |
| `plan_list_footer` | Gilt für neue Wochen. Für eine einzelne Woche wählst du die Liste in „Zutaten der Woche“. | Used for new weeks. To change it for one week, pick the list in "This week's ingredients". |

VoiceOver: „Wocheneinkauf, 4 offen, ausgewählt“. Keine Listen: nur „Zuletzt geöffnete Liste“ und „Neue Liste“.

---

### S13 Hast du meist da (`/settings/plan/pantry`, gleiches Widget wie S5)

**Zweck:** Was soll beim Hinzufügen zur Liste abgewählt sein? Eine Liste für die ganze App (Wochenplan und „Zutaten auf
die Liste“ im Rezept); die Daten gehören A (E-16, L9), die Seite baut B. Ist das Modul aus, hängt A dieselbe Seite unter
`/settings/lists` ein (A-P12).

**Aufbau:** Kopf `chevron.left`, Inline-Titel „Hast du meist da“. Oben ein Feld (Kapsel `fill`, 44 hoch, SF `plus` 17 pt
`secondaryLabel` statt Lupe, Platzhalter „Zutat hinzufügen“, Return fügt hinzu und die Zeile wächst oben ein). Gruppe mit
den Zutaten als Zeilen (`body`, mindestens 50). Wischen nach links zeigt „Entfernen“ (Fläche `destructive` #D70015, weiß;
volles Wischen entfernt), sofort mit Hinweis „Mehl entfernt · Widerrufen“. Wischaktionen auf Zeilen sind kein
Slide-in-Panel und erlaubt. Fuß unter der Gruppe.

**Startwerte** (FW-06, Vorschlag aus dem Konzept, Owner entscheidet): Salz, Pfeffer, Wasser, Öl, Zucker, Mehl. „Öl“
deckt Olivenöl und Rapsöl.

| Zustand | Schlüssel | DE | EN |
|---|---|---|---|
| Titel | `plan_staples_title` | Hast du meist da | Pantry staples |
| Feld | `plan_staples_add` | Zutat hinzufügen | Add an ingredient |
| Wisch-Aktion | `plan_staples_remove` | Entfernen | Remove |
| Fuß | `plan_staples_footer` | Diese Zutaten sind abgewählt, wenn du Zutaten auf die Liste setzt. Du kannst sie dort jederzeit wieder auswählen. „Öl“ gilt auch für Olivenöl und Rapsöl. | These are unticked when you add ingredients to a list. You can still tick them there. "Oil" also covers olive oil and rapeseed oil. |
| Leer | `plan_staples_empty` | Keine Zutaten. Alles kommt auf die Liste. | No staples. Everything goes on the list. |
| Doppelt eingegeben (Zeile leuchtet kurz in `fillStrong`, keine zweite Zeile, Ansage) | `plan_staples_duplicate_a11y` | {name} ist schon dabei. | {name} is already there. |

Offline lokal mit Sync-Zeichen. Kein Avo (Arbeits-Screen). VoiceOver: jede Zeile mit Aktion „Entfernen“; Feld „Zutat
hinzufügen, Textfeld“. AX/320: Zeilen brechen um, das Feld wird höher, nie abgeschnitten.

---

### D1 Dialog „Wochenplan ist ausgeschaltet“ (`showModuleOffAlert`)

Zentriert (A), zwei Knöpfe; „Einschalten“ schaltet `AppModule.mealPlan` ein und öffnet die ursprünglich gewünschte Route.

| Schlüssel | DE | EN |
|---|---|---|
| `plan_module_off_title` | Wochenplan ist ausgeschaltet | Meal plan is turned off |
| `plan_module_off_body` | Schalte ihn ein, um deine Woche zu planen. Was du schon geplant hast, ist noch da. | Turn it on to plan your week. Anything you planned is still there. |
| `plan_module_off_later` | Nicht jetzt | Not now |
| `plan_module_off_enable` | Einschalten | Turn on |

### D2 Dialog „Erinnerung erlauben“ (vor der Systemabfrage)

Zentriert (`showAvoConfirm` bzw. A's Dialog), zwei Knöpfe; „Weiter“ löst die iOS-Abfrage aus, „Nicht jetzt“ lässt den
Schalter aus.

| Schlüssel | DE | EN |
|---|---|---|
| `plan_remind_ask_title` | Erinnerung am {weekday}? | Get a reminder on {weekday}? |
| `plan_remind_ask_body` | Avo meldet sich jeden {weekday} um {time}, wenn die nächste Woche noch leer ist. Dafür fragt dein iPhone gleich nach der Erlaubnis für Mitteilungen. | Avo will remind you every {weekday} at {time} if next week is still empty. Your iPhone will ask you to allow notifications next. |
| `plan_remind_ask_later` | Nicht jetzt | Not now |
| `plan_remind_ask_continue` | Weiter | Continue |

---

## 5. Konflikte zwischen D2 und Konzept (Empfehlung gilt bis zur Owner-Entscheidung)

| Nr. | D2 | Konzept | Empfehlung | Grund |
|---|---|---|---|---|
| K1 | Kapsel „5 fehlende Zutaten auf die Liste“, kein Ziel-Listen-Knopf | „17 Zutaten auf Wocheneinkauf“ plus runder Ziel-Listen-Knopf | eine Kapsel wie D2, Text mit Listennamen „5 Zutaten auf Wocheneinkauf“; Listenwahl in S3 und im Menü „Mehr“ | Aussehen D2; man sieht, wohin es geht (Konzept); kürzer, passt bei 390 pt in eine Zeile |
| K2 | Zahl 5 = Summe der Fehlenden pro Rezept (2 + 3) | Zahl = zusammengefasste Zeilen in S3 | zusammengefasste Zeilen | Eine Zwiebel für zwei Rezepte zählt sonst doppelt; Kapsel und Knopf in S3 zeigen dieselbe Zahl. Die Metazeilen pro Rezept summieren sich dann nicht immer zur Kapsel-Zahl |
| K3 | Tageskopf „Donnerstag“ + „12.“, Wochenkopf „9.–15. November“ | „Do., 12. Nov.“ und „Diese Woche · 9.–15. Nov.“ | D2 für die laufende Woche; in anderen Wochen „Nächste Woche · 16.–22. Nov.“ usw. im selben Kopf; VoiceOver immer mit vollem Datum | D2-Optik; ohne relative Angabe weiß man in fremden Wochen nicht, wo man ist |
| K4 | belegte Tage ohne „Rezept wählen“ | jeder Tag endet mit „Rezept hinzufügen“ | „Rezept wählen“ auch unter belegten Tagen (44er-Zeile mit Trenner), Wortlaut D2 | Sonst lässt sich ein zweites Rezept (Mittag und Abend) nur über einen Umweg anlegen |
| K5 | keine Wochennavigation gezeigt | Toolbar-Chevrons, Menü, Wischen | alle drei: Chevrons in der Toolbar-Gruppe, Pull-down am Wochenkopf (mit `chevron.down`), Wischen | Wischen allein ist keine Bedienung für alle (WCAG 2.5.1); Chevrons sind der schnelle Weg |
| K6 | „Heute kochen“: „4 von 6 Zutaten hast du schon“, Knopf „Fehlende 2 auf die Liste“ | „Heute im Plan: … 7 Zutaten fehlen noch.“ / „Hinzufügen“ | Kapsel „2 Zutaten fehlen noch“ bzw. Namen bei 1–2, „Alles auf der Liste“; Knopf „2 Zutaten auf Wocheneinkauf“ | Die App weiß nicht, was im Schrank ist, nur was auf der Liste steht; „hast du schon“ wäre unbelegt |
| K7 | Rezepte-Grund #FFFFFF (Entdecken), Wochenplan #F2F2F7 | – | Grund wechselt mit dem Segment (Überblendung) | weiße Tageskarten brauchen den grauen Grund |
| K8 | – | Erfolgsmoment mit „2 davon bei Lidl im Angebot, laut Händler“ neben Avo | Zeile im Erfolgsmoment weglassen; die Angebote stehen in S3 und in der Liste | Owner-Regel „Avo erscheint nie bei Geld“ streng gelesen |
| K9 | kcal nur im Tageskopf | „40 Min · 480 kcal“ in der Metazeile | nur im Tageskopf, pro Rezept nur in VoiceOver | D2-Optik, ruhigere Zeile |
| K10 | Rezeptfoto Radius 14 | Radius 12 | 14 (D2) als neuer Token für 56er-Fotos | D2 gewinnt bei Optik |
| K11 | Vollbild-Bearbeiten mit sichtbarer Tab-Leiste (`D2-Artikel`) | Sheets | V-Screens über der Tab-Leiste wie Kalorien (`X-Essen`) | Abläufe öffnen auch aus Avo und Home; „Schließen“ muss dorthin zurückführen |
| K12 | Gruppenköpfe in Listen GROSS (D2) | Kategorie-Titel in normaler Schreibung | GROSS mit `SectionCaps` und normalem Semantik-Label | D2-Optik |

Weitere offene Owner-Fragen aus dem Konzept, die diese Screens berühren: FW-01 (Wochenplan Pro? Empfehlung frei; wenn
Pro, nur „auf die Liste“), FW-02 (Wochenbeginn Sonntag bei englischer Region?), FW-04 (weniger Portionen nehmen nichts
von der Liste; Empfehlung ja, so lassen), FW-05 (Einträge ohne Rezept wie „Reste“, Empfehlung Version 1.1), FW-06
(Startwerte „Hast du meist da“: Salz, Pfeffer, Wasser, Öl, Zucker, Mehl), FW-07 (Erinnerung standardmäßig aus;
Empfehlung ja).

---

## 6. Anfragen an Teil A

Komponenten (S2a/S2b) und Erweiterungen:

| Nr. | Was | Wofür |
|---|---|---|
| A-K1 | `AppSegmentedControl`: Trefferfläche 44 auch in der 36-pt-Variante des Rezepte-Segments; Pull-down-Fallback bei Platzmangel; bei „Kontrast erhöhen“ Rand um den Daumen | S1, S2, S3 |
| A-K2 | `ValueStepper` kompakt: Kapsel 34 sichtbar, Knöpfe 44 × 44 Treffer, Wert-Deckel AX2, Semantik abschaltbar (Zeile übernimmt „einstellbar“) | S1, S8, S11 |
| A-K3 | `GlassButtonGroup` mit 44 breiten Knöpfen (D2 40) | S1 Toolbar |
| A-K4 | `ProBadge` Variante „auf getönt“ | S1-Kapsel, S10-Knopf |
| A-K5 | fette `subhead`-Variante (D2 `<b>` im Tageskopf) | S1 |
| A-K6 | Token Foto 56 / Radius 14 (`AvoSizes.thumbPlan`, `AvoRadii.thumbPlan`) | S1, S2, S8 |
| A-K7 | `IngredientPickRow` (Kreis, Bild-Slot, Name, Unterzeile, Menge, Pillen-Slot, AX-Layout wie `ItemRow`); A braucht sie auch für „Zutaten auf die Liste“ im Rezept. Wenn A sie nicht baut, baut B `PlanIngredientRow` und A übernimmt sie | S3 |
| A-K8 | `RecipeHeroCard` mit Status-Kapsel, Panel-Knopf über volle Breite, ohne Mini-Avo, Reduce-Transparency-Fallback, AX-Layout (Foto oben, Panel deckend darunter, ab AX3 ohne Foto) | S10 |
| A-K9 | `InlineCalendar` (Monatsblatt, ±52 Wochen, Punkt-Markierung, Wochenreihen-Markierung, Monatsknöpfe 44, VoiceOver-Raster) | S6, S7, S8 |
| A-K10 | `showAvoMenu` mit Untermenüs an derselben Stelle, Untertiteln, Häkchen, Trennern, destruktiven Einträgen, `ProBadge` im Eintrag; Kontextmenü mit Vorschau; Ziehen aus der Vorschau heraus, falls machbar | S1, S3, S8 |
| A-K11 | `InsetSection` einklappbar | S1 „Vergangene Tage“ |
| A-K12 | Zeile mit Wischaktion „Entfernen“ (Fläche `destructive`) | S13 |
| A-K13 | Inline-Zeitwähler in einer Gruppe (`ValueRow` mit aufklappendem Rad) | S11 |
| A-K14 | Textfeld-Kapsel für Zahlen und für „Zutat hinzufügen“ (Leading-Symbol frei wählbar) | S4, S13 |
| A-K15 | `FullScreenEditor` mit `xmark`/`chevron.left` links und getönter Kapsel rechts (deaktivierbar) | S2 bis S8 |

Tokens:

| Nr. | Was |
|---|---|
| A-T1 | `warningText` hell #A8521A (5,40:1 auf Weiß), dunkel z. B. #F29A4A (7,69:1 auf #1C1C1E) |
| A-T2 | `labelOnGlass` hell #2C2C2E (5,52:1 auf Glas über Schwarz), dunkel passend |
| A-T3 | Textkapseln auf Glas mit 96 % Tönung oder deckend `tintFill` (88 % ergibt 4,25 bis 4,37:1) |

Router, Rezepte-Tab, Home, Profil:

| Nr. | Was |
|---|---|
| A-R1 | `planRootRoutes` vor der Shell einhängen (wie Kalorien), damit `/plan/add`, `/plan/to-list…`, `/plan/move`, `/plan/week`, `/plan/schedule/:id` über dem aktuellen Tab öffnen |
| A-P1 | `buildPlanSegment` liefert Slivers; A setzt sie in den `CustomScrollView` des Rezepte-Tabs unter das Segment |
| A-P2 | Neuer Vertrag `buildPlanFloatingBar(context)`: A legt ihn im Rezepte-Tab über den Inhalt und unter die Tab-Leiste, nur bei Segment „Wochenplan“ |
| A-P3 | Neuer Vertrag `buildPlanToolbarActions(context)`: A zeigt diese Knöpfe rechts in der Toolbar statt der Entdecken-Knöpfe |
| A-P4 | Grund des Rezepte-Tabs folgt dem Segment (`backgroundPlain` / `background`), Wechsel als Überblendung; Query `week`, `day` beim Segmentwechsel behalten |
| A-P5 | Erneutes Antippen des gewählten Segments ruft `planSegmentReselected(ref)` |
| A-P6 | Rückgängig-Hinweis „Wochenplan ausgeblendet“ auch nach dem Ausblenden des Segments auf Entdecken zeigen (Toast-Host im Tab, nicht im Segment) |
| A-P7 | `Future<String?> openNewList(BuildContext context, {String? suggestedName})` liefert die ID der neuen Liste |
| A-P8 | Untermenü „Zum Wochenplan“ im Rezeptdetail und im `RecipeCard`-Kontextmenü; Daten und Aktion von B (`planScheduleMenuProvider(recipeId)`, `addRecipeToPlan`), Slot `PlanEntryMeta` unter dem Titel |
| A-P9 | Rezeptdetail nimmt `?entry=` an (Portionen aus dem Eintrag, Rückschreiben über `setPlanEntryServings`), ruft `markPlanEntrySent` nach „Zutaten auf die Liste“; Detail von Home aus als Push im Home-Tab oder mit klarer Rückkehr nach Home |
| A-P10 | Home: keine Kalorien-Ideen-Zeile, wenn `homeCookTodayHasContentProvider` true ist |
| A-P11 | Profil-Zeile „Wochenplan“ → `/settings/plan`, nur mit Modul |
| A-P12 | Seite „Hast du meist da“ bei Modul aus unter `/settings/lists` einhängen |
| A-M1 | `AppModule.mealPlan` nach Abnahme von B7 freischalten (`released: true`) |

Daten von A: Grundzutaten-Liste „Hast du meist da“ pro Konto mit Abgleich-Funktion (E-16, L9); `RecipeAdaptation` mit
Grund der Ersetzung; Kategorie-Reihenfolge im Markt der Ziel-Liste; Allergen-Ausschluss in „Für dich“ (heute greift er
nicht, `inventar/recipes-browse.md` 4.4).

---

## 7. Datenquellen und Lücken

### 7.1 Was es gibt (Stand 08.11.2026)

| Quelle | Besitz | Stand | Nutzung |
|---|---|---|---|
| `moduleEnabledProvider(AppModule.mealPlan/calories)` | A | da | alle Screens |
| `offersAvailableProvider`, `offersRemoteEnabledProvider` | B | da | S3, S1 |
| `offersHiddenForListProvider(listId)` | B | da | S3 |
| `storeForListProvider(listId)` | B | da, aber `FutureProvider` (Vertrag sagt synchron `Provider.family<StoreInfo?, String>`) | S3 `StoreChip` |
| `ItemRepository.instance.addItems(listId, [NewItem…])` → `AddItemsResult(token, items)`, `undoAddItems(token)` | A | da (A5) | S3, S10 |
| `parseItemInput`, `parseSingleItem` | A | da | S4 (Mengen) |
| `itemsNotifierProvider(listId)`, `listsNotifierProvider`, `lastAccessedListProvider` | A | da | S3, S11, S12 |
| `recipesProvider`, `savedRecipesProvider` | A | da | S2, S1 |
| `IngredientSubstitutionService` | A | da | S3 (bis `RecipeAdaptation`) |
| `AvoDesignScope.reduceTransparencyOf` | A | da | alle |
| `AvoColors`, `AvoTextStyle`, `AvoSpacing`, `AvoRadii`, `AvoSizes`, `ShellInsets`, `AvoMotion`, `AvoHaptics` | A | da | alle |
| `permission_handler` (`openAppSettings`), `flutter_local_notifications`, `cached_network_image`, `uuid`, `intl` | Paket | da | S11, S1 |

### 7.2 Was B für diese Screens baut (Paket B7)

- Migration `supabase/migrations/<Zeit>_b_meal_plan.sql`: `meal_plans` (Woche, Ziel-Liste, `first_sent_at`),
  `meal_plan_entries` (vom Gerät erzeugte UUID, `plan_date`, `recipe_id`, `recipe_snapshot` inkl. Zutaten und
  `kcal_per_serving`, `servings` 1–20, `meal_type`, `position`, `sent_list_id`, `sent_servings`, `sent_at`),
  `meal_plan_settings` (Portionen, Liste, `show_cook_today`, Erinnerung Tag und Uhrzeit), RLS `auth.uid() = user_id`
  plus Prüfung der Listen-Verweise. Anwenden nur nach Owner-Ja; vorher den echten Typ von `recipes.id` prüfen (TEXT oder
  uuid) und die Realtime-Publikation (OPEN-ISSUES).
- `lib/data/models/meal_plan_entry.dart`, `meal_plan_settings.dart`.
- `lib/data/services/meal_plan_service.dart`: lokaler Speicher (laufende Woche, vier voraus, zwei zurück, vor dem ersten
  Frame gewärmt), Warteschlange (oder A's `WriteQueue`, falls bis dahin da), Realtime mit Filter `user_id`, Echo eigener
  Schreibvorgänge entprellt.
- `lib/data/services/plan_ingredient_aggregator.dart`: `aggregatePlanIngredients(...)` als reine Funktion
  (Konzept-Algorithmus Schritte 1–16: Zeitraum, Bedarf nach gesendeten Portionen, Skalieren mit Schutz gegen 0,
  Ersetzen vor dem Zusammenfassen, Namen und Einheiten normalisieren inklusive Deutsch/Englisch, Gruppieren, Aufrunden,
  Grundzutaten, „schon auf der Liste“ ohne Plan-eigene Mengen, Angebote nur Ziel-Markt, Sortieren, Zahl der Kapsel,
  „N Zutaten fehlen“ pro Eintrag); ab 30 Zutaten in `compute`.
- `lib/presentation/state/plan_provider.dart`: `planWeekProvider(weekStart)`, `planWeekSummaryProvider(weekStart)`,
  `planEntriesForDayProvider(date)` (Kalorien, Widget), `planSettingsProvider`, `planTargetListProvider(weekStart)`,
  `homeCookTodayProvider` und `homeCookTodayHasContentProvider` (synchron), `planScheduleMenuProvider(recipeId)`;
  Aktionen `addRecipeToPlan`, `moveEntry`, `removeEntries` (mit Rückgängig), `copyPreviousWeek`, `clearWeek`,
  `setPlanEntryServings`, `setPlanEntryMeal`, `markPlanEntrySent`, `sendWeekToList`.
- `lib/routes/areas/plan_routes.dart` (1.2), `lib/core/localization/translations/plan.dart` (alle `plan_`-Schlüssel
  dieser Datei), Screens unter `lib/presentation/screens/plan/`, Bausteine unter `…/plan/widgets/`, Export von
  `HomeCookToday` in `lib/presentation/widgets/slots/b_slots.dart`.

### 7.3 Lücken (müssen vor oder mit dem Bau geschlossen werden)

| Nr. | Lücke | Wer |
|---|---|---|
| L1 | Datenschicht 7.2 fehlt komplett (kein Modell, kein Dienst, kein Provider, keine Migration) | B7 |
| L2 | `ArticleImage` nimmt nur `ShoppingItemModel`; für Zutaten braucht es `ArticleImage.forName(name:, categoryId:, size:)` | B (andere Workflow-Datei `article_image.dart`) |
| L3 | Angebots-Pille für Zutaten: `ItemOfferBadge` nimmt nur Artikel; Vorschlag `IngredientOfferBadge(listId:, name:, categoryId:)` | B (Angebote) |
| L4 | synchroner Angebots-Cache pro Markt (`offersForChainProvider(chainId)`), damit S3 lokal zuerst rechnen kann | B (Angebote) |
| L5 | `openLogRecipe(context, recipe)` hat keine Parameter für Portionen, Datum und Mahlzeit; Kalorien-Spec plant `/calories/add/recipe/:id?servings=&date=&meal=` → Signatur erweitern | B (Kalorien) |
| L6 | `storeForListProvider` ist `FutureProvider`; Vertrag und S3 brauchen einen synchronen Wert aus dem Cache | B (Angebote) |
| L7 | `regionProvider` (echte PLZ) und `formatOfferSummary`/`summarizeListOffers` (B2.1, B2.2) fehlen noch | B (Angebote) |
| L8 | `connectionStateProvider` (online, offline, eingeschränkt) fehlt; ohne ihn keine `StatusRow` | B (Kap. 20) |
| L9 | Grundzutaten-Liste „Hast du meist da“ (Daten, Abgleich) | A |
| L10 | Allergien der Person als Provider und Allergen-Ausschluss in „Für dich“ | A |
| L11 | Mitteilung „Nächste Woche ist noch leer“ planen und abbrechen (Text `notif_`, Zeitplan) | B9 |
| L12 | Avo-Werkzeuge `get_plan`, `add_to_plan`, `fill_plan`, `plan_to_list`, `move_in_plan`, `remove_from_plan` (mit Rückfrage-Karte) lesen und schreiben über dieselben Provider | B5 |

---

## 8. Tests beim Bau (TDD, je Screen zuerst der fehlschlagende Test)

- `test/plan/plan_ingredient_aggregator_test.dart`: Abnahme-Woche aus dem Konzept (5 Rezepte, 17 Zeilen, Reis abgewählt
  „Schon auf Wocheneinkauf (1 kg)“, Mehl und Zucker „Hast du meist da“, Zwiebeln 3 „für Chili sin Carne, Gemüse-Curry“,
  Kokosmilch 275 ml nach Portionen 3 → 5, keine Doppelzeilen, keine Werte wie „133.333 g“, „Onion“ und „Zwiebel“ in einer
  Zeile).
- `test/layout/screens/b/plan_segment_test.dart` und je Screen eine Datei mit `layoutMatrix(...)` für alle Zustände aus 4:
  kein Überlauf, keine abgeschnittenen Texte, `iOSTapTargetGuideline`, `labeledTapTargetGuideline`,
  `textContrastGuideline`, kein Spinner.
- Widget-Tests: Modul aus → Route rendert nichts und zeigt D1; Angebote nicht verfügbar → keine Pille, keine Ersparnis,
  `StoreChip` da; Kalorien aus → kein „kcal“ im Baum; Pro gesperrt → Planen geht, Kapsel öffnet `ProGate`; Kapsel und
  Rückgängig-Hinweis nie gleichzeitig; Erfolgsmoment nur beim ersten Senden; Rückgängig ruft `undoAddItems(token)`;
  VoiceOver-Labels über `find.bySemanticsLabel`; Rezeptzeile hat `increase`/`decrease`.
- Routen: `test/routes/app_routes_test.dart` (A) um die Plan-Pfade; `/plan/to-list` aus dem Avo-Tab öffnen, schließen,
  Avo-Tab ist wieder sichtbar.
- `idiotensicher-testen` für den Ablauf „Woche planen und einkaufen“ auf dem Simulator (B10).

---

## 9. Prüfliste für Screenshots

Jeder Punkt an Screenshots bei 390 × 844, L, hell, sofern nicht anders genannt.

**S1 Wochenplan**
- [ ] Grund #F2F2F7, Tageskarten weiß, Radius 26, 10 pt Abstand, 16 pt Rand, kein Schatten.
- [ ] Wochenkopf „9.–15. November“ 20 pt Semibold mit kleinem Pfeil nach unten, rechts „4 von 7 Tagen geplant“ grau.
- [ ] Toolbar oben rechts: eine Glas-Gruppe mit Vorige Woche, Nächste Woche, Mehr; nichts links.
- [ ] Laufende Woche beginnt mit „Heute“; „Vergangene Tage (2)“ eingeklappt darüber.
- [ ] Tageskopf „Heute“ fett + „Mi., 11.“ grau, rechts „480 kcal“ nur mit Modul Kalorien.
- [ ] Rezeptfoto 56, Radius 14; Titel bricht um, nie „…“; Metazeile „25 Min · alles auf der Liste“ bzw. „2 Zutaten fehlen“ in #A8521A.
- [ ] Stepper rechts (390, L), 34 hoch sichtbar; bei 320 und bei xxxL unter der Metazeile.
- [ ] „Rezept wählen“ grün mit Plus, mindestens 44 hoch, auch unter belegten Tagen (falls K4 so entschieden).
- [ ] Genau eine getönte Kapsel, 12 pt über der Tab-Leiste, Text „5 Zutaten auf Wocheneinkauf“; keine Kapsel in vergangenen Wochen, bei Zahl 0 und im Bearbeiten-Modus.
- [ ] Rückgängig-Hinweis steht an der Stelle der Kapsel, nie beide gleichzeitig.
- [ ] Erfolgsmoment: weiße Karte mittig, Avo feiert 120 pt, „Wochenplan ist auf der Liste.“, nur beim ersten Senden der Woche; Hinweis unten gleichzeitig sichtbar.
- [ ] Erster Start: Avo winkt 96 pt, „Was essen wir diese Woche?“, Knopf „Rezept für heute wählen“, Text-Knopf „Wochenplan ausblenden“; ab AX1 ohne Avo.
- [ ] Fehler „Wochenplan nicht geladen“ mit Wolken-Symbol, ohne Avo.
- [ ] Offline: graue Statuszeile unter dem Wochenkopf, Sync-Zeichen an geänderten Fotos.
- [ ] Kalorien aus: nirgends „kcal“.
- [ ] Bearbeiten-Modus: rote Minus-Kreise links, Griffe rechts, keine Stepper, „Fertig“ oben rechts.
- [ ] Menüs wachsen aus ihrem Auslöser; kein Sheet, kein Panel von unten.
- [ ] 320 × 568: Titel, Segment, Wochenkopf und Karte „Heute“ im ersten Bildschirm; Kapsel zweizeilig, nichts abgeschnitten.
- [ ] AX3 und AX5: keine Fotos in Zeilen, Kapsel „5 Zutaten“, nichts abgeschnitten, nichts überlappt.
- [ ] Reduce Transparency: Kapsel deckend grün, Tab-Leiste und Toolbar deckend.
- [ ] Dunkel: Warnfarbe lesbar, kein Grün auf Grün.

**S2 Rezept wählen**
- [ ] Kopf mit Schließen links, „Rezept wählen“ mittig, rechts nichts; keine Tab-Leiste.
- [ ] Tag-Kapsel „Für Do., 12. Nov.“, Suchfeld „Rezepte suchen“, Segment „Gespeichert / Für dich“ 44 hoch.
- [ ] Zeilen mit Foto 56, „Schon im Plan: Di., 10. Nov.“ grau, Allergen-Warnung mit Symbol.
- [ ] Leer: Avo winkt 64 pt; keine Treffer: Avo überlegt 64 pt (ab AX1 Lupe).
- [ ] Offline-Zeile unter dem Suchfeld.

**S3 Zutaten der Woche**
- [ ] Kopf mit Schließen, „Zutaten der Woche“; Zeile „Liste“ mit Listenname, Markt-Chip und Doppelpfeil.
- [ ] Segment „Ab heute / Ganze Woche“ nur in der laufenden Woche.
- [ ] Gruppenköpfe in Großbuchstaben mit Anzahl rechts; Kreise gefüllt grün bzw. Ring #8A8A8E.
- [ ] Abgewählte Zeilen nicht ausgegraut, Grund in der Unterzeile („Schon auf Wocheneinkauf (1 kg)“, „Hast du meist da“).
- [ ] Mengen mit Dezimalkomma, keine Werte wie „133.333 g“.
- [ ] Angebots-Pille „0,89 € · Lidl“ nur Ziel-Markt; Ersparnis-Zeile mit „ca.“ und „in deiner Region“; ohne PLZ „Postleitzahl festlegen“.
- [ ] Angebote aus/Kill-Switch: keine Pille, keine Ersparnis, Markt-Chip bleibt, keine Lücke.
- [ ] Kapsel unten 54 hoch „17 Zutaten hinzufügen“; bei 0 grau „Nichts ausgewählt“.
- [ ] AX1+: Menge und Pille unter dem Namen, keine Artikelbilder.

**S4 Menge ändern**
- [ ] Zurück-Pfeil links, Zutat als Titel, „Fertig“ rechts (deaktiviert bei 0).
- [ ] Stepper und Zahlenfeld in einer Zeile (ab AX1 untereinander); Einheiten als Segment oder Chips.
- [ ] Fuß „Aus 2 Rezepten berechnet: 3. Gilt nur für diesen Einkauf, …“.

**S6, S7, S8**
- [ ] Kalender mit grünem Auswahlkreis, heute grün, Punkte unter geplanten Tagen; ab AX1 Tageszeile bzw. Wochenliste.
- [ ] S8: „Hinzufügen“ rechts oben, Portionen-Stepper, Fuß „Die Zutaten kommen erst auf die Liste, …“.
- [ ] Rezept gelöscht: leerer Zustand ohne Avo, ohne „Hinzufügen“.

**S9 Rezeptdetail**
- [ ] Unter dem Titel „Im Plan: Mi., 11. Nov. · 4 Portionen“ mit Kalender-Symbol; ohne Modul nichts.

**S10 Heute kochen (Home)**
- [ ] Kopf „Heute kochen“ + „Alle“; Foto 220, Radius 26; keine Avo-Figur in diesem Abschnitt.
- [ ] Status-Kapsel ehrlich („2 Zutaten fehlen noch“ bzw. Namen, „Alles auf der Liste“), nie „hast du schon“ (falls K6 so entschieden).
- [ ] Meta „25 Min · ★ 4,8“ dunkelgrau auf Glas, lesbar auch auf dunklen Fotos.
- [ ] Knopf „2 Zutaten auf Wocheneinkauf“, 44 hoch, volle Breite; nach Tipp Hinweis mit Widerrufen.
- [ ] Ab 20 Uhr „Morgen kochen“; Sonntag nachmittags kompakte Zeile „Nächste Woche ist noch leer.“ + „Planen“.
- [ ] Modul aus: Abschnitt fehlt ohne Lücke.

**S11 bis S13 Einstellungen**
- [ ] Großer Titel „Wochenplan“, Gruppen Radius 26, Köpfe in Großbuchstaben, Fußnoten grau bei 32 pt.
- [ ] Portionen mit kompaktem Stepper; Zeit-Wähler klappt in der Gruppe auf (kein Popup von unten).
- [ ] Mitteilungen abgelehnt: Zeile „Mitteilungen für Avo sind aus.“ + „In Einstellungen erlauben“.
- [ ] „Hast du meist da“: Feld mit Plus, Wisch-Aktion „Entfernen“ in #D70015, Fuß mit Öl-Hinweis; leer „Keine Zutaten. Alles kommt auf die Liste.“

**Überall**
- [ ] Kein Bottom-Sheet, kein halbhohes Modal, kein Drawer, kein Slider, nichts gleitet von unten herein.
- [ ] Höchstens eine Avo-Figur pro Bildschirmhöhe; keine bei Fehlern, Geld, Allergie, Löschen.
- [ ] Jede Trefferfläche mindestens 44 × 44 (Stepper-Knöpfe, Toolbar-Gruppe, Segment, Chips, Tag-Knopf).
- [ ] Kein #FF3B30 als Text; destruktiver Text #D70015.
- [ ] Kein Text auf getönter Kapsel unter 4,5:1 (Tönung 96 % oder deckend).
- [ ] Alle Texte Deutsch und Englisch vorhanden, keine Ausrufezeichen, keine Emojis, Schreibweise wie in dieser Datei.
- [ ] Reduce Motion: keine Gleit- oder Federbewegung, nur Überblendungen; Wochenwechsel nach Wisch über 60 pt.
- [ ] VoiceOver: Tagesköpfe als Überschriften, Rezeptzeile einstellbar, Rückgängig-Hinweis 10 s, Ansagen nach Änderungen.
