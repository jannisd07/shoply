# Arbeitsteilung Avo-Redesign: Teil A und Teil B

Zwei Claude-Code-Sessions bauen die App gleichzeitig um, auf zwei Macs, im selben Repo, mit demselben Account.

- **Teil A:** der Owner auf Mac 1. Fundament und Kern-App.
- **Teil B:** Jannis auf Mac 2. KI, Daten, Module und System.

Dieses Dokument ist für beide verbindlich. Es regelt drei Dinge: wer welche Datei ändern darf, wie die Teile ineinandergreifen und wie man sich abstimmt, ohne sich zu blockieren.

**Das Aussehen** kommt verbindlich aus dem D2-Glas-Artifact, siehe [`design-quelle.md`](design-quelle.md).

**Funktionen, Abläufe und Zustände** stehen im Konzept in `docs/redesign/konzept/`. Dessen optische Angaben sind überholt.

| Datei | Inhalt |
|---|---|
| `00-grundlagen.md` | Tokens, Komponenten, Regeln |
| `01-navigation-und-struktur.md` | Tabs, Routen, Screen-Karte, Abläufe |
| `10-…` bis `20-…` | Screens pro Bereich |

Außerdem gelten:
- [`docs/Shoply-Ideen-und-Plan.md`](../Shoply-Ideen-und-Plan.md) (Jannis' Plan; bei Widersprüchen gilt der Plan)
- [`docs/research/Preise Angebote und Artikelbilder.md`](../research/Preise%20Angebote%20und%20Artikelbilder.md)
- [`docs/redesign/avo-verbesserungsliste.md`](avo-verbesserungsliste.md)

---

## 1. Wer macht was

### Teil A (Owner, Mac 1): Fundament und Kern-App

| Arbeitspaket | Konzept | Quelle |
|---|---|---|
| Struktur-Umbau: Übersetzungen und Router pro Bereich, Modulsystem | 01, 00 Kap. 15 | Plan 1 |
| Designsystem: Tokens, Typografie, Material, Komponenten, Tab-Bar mit Avo-Einstieg, Layout-Testgerüst | 00, 01 | Plan 2 |
| Heute (Startseite = Liste von heute), Anordnung der Hinweis-Karten | 10 | Plan 2, 4 |
| Listen, Hinzufügen („2 Milch“, Vorschläge), Einkaufsmodus, geteilte Listen live mit Präsenz, Teilen, Listen-Einstellungen, Hintergründe, Kategorie-Reihenfolge, Aktivitäten | 11 (ohne Angebots-Widgets) | Plan 4, Liste 2 |
| Rezepte, Rezeptdetail, Erstellen, Kochmodus, Creator | 13 | Funktionsliste |
| Onboarding, Login, Modulwahl beim ersten Start | 17 | Plan 1, Liste 5 |
| Profil, Einstellungen (ohne die Seite „Preise & Angebote“), Paywall, Pro-Konzept-Analyse | 18 | Liste 15 |
| App-Icon und Maskottchen-Assets | 19 (Icon) | Plan 2 |
| Geräte-Robustheit: Eingabeleisten-Bug, Prüfmatrix für alle Screens (Gerüst für beide Teile) | 20 | Liste 2 |
| Tempo im eigenen Bereich: lokaler Stand zuerst, optimistische Updates (Listen, Artikel, Rezepte) | 20 | Plan 3, Liste 3 |
| Rest des Repo-Aufräumens nach dem laufenden Aufräum-Workflow, Analyse „Tägliche Nutzung und Alleinstellung“ | – | Plan 6, Liste 14, 16 |

### Teil B (Jannis, Mac 2): KI, Daten, Module und System

| Arbeitspaket | Konzept | Quelle |
|---|---|---|
| Claude statt Gemini: Supabase Edge Function als Proxy, Claude-Client, alle KI-Services umstellen | 00 Kap. 17 | Plan 7, Liste 8 |
| Angebote absichern (Keys raus, Remote-Kill-Switch, Wortlaut, nie Pro), „günstigster Korb“ ersetzen, Markt pro Liste (Daten + Markt-Chip), Seite „Preise & Angebote“, Angebote der Woche | 12 | Plan 8, Liste 6 |
| Verlauf, Ersparnis, Kosten teilen | 12 | Funktionsliste |
| Avo: Chat, Sprachmodus, Antwortkarten, Tool-Abdeckung, Löschen nur mit Rückfrage | 16 | Plan 12 |
| Wochenplan (neu) | 14 | Plan 5 |
| Kalorien vollwertig: Foto, Barcode-Kamera, Suche, Workouts, Apple Health lesen und schreiben | 15 | Plan 9 |
| Widgets, Sperrbildschirm, StandBy, Kontrollzentrum, Siri, Mitteilungen | 19 (ohne Icon) | Plan 10, 11 |
| App-Start und Tempo: Dienste in `main.dart` parallel oder bei Bedarf starten, KI-Latenz | 20 | Plan 3, Liste 3 |
| Artikelbilder: Illustrationen und Open-Food-Facts-Fotos mit Quellenangabe | 00 Kap. 9 | Plan 8, Liste 7 |
| Hinweis-Karten der Startseite aus B-Bereichen (Nachkauf, Prospekt, Angebots-Hinweis, Kosten teilen, Kalorien-Rezept) als eigene Widgets | 10 | Plan 2 |

---

## 2. Dateibesitz

**Regel:** Jede Datei gehört genau einem Teil. Du änderst nur deine eigenen Dateien. Brauchst du eine Änderung in einer fremden Datei, trägst du sie als Anfrage in deine Status-Datei ein (siehe Abschnitt 5). Der andere Teil setzt sie um.

**Werkzeuge:**
- `bash docs/redesign/owner.sh <pfad> …` zeigt den Besitzer eines Pfads.
- `bash docs/redesign/check-ownership.sh A` (bzw. `B`) **vor jedem Commit**. Es bricht ab, wenn eine gestagte Datei dem anderen Teil gehört oder unklar ist.

**Kurzfassung** (maßgeblich ist `owner.sh`):

| Teil A | Teil B |
|---|---|
| `lib/core/constants`, `theme`, `widgets`, `mascot`, `modules` (neu), `design` (neu), `utils` (außer drei Dateien, siehe B) | `lib/core/config`, `lib/core/services`, `lib/main.dart`, `firebase_options*` |
| `lib/core/localization/*` (Gerüst und A-Bereichsdateien) | `lib/core/localization/translations/{avo,calories,plan,offers,history,notifications,system}*` |
| `lib/app.dart`, `main_scaffold.dart`, `lib/routes/*` (Gerüst und A-Bereiche) | `lib/routes/areas/{avo,calories,plan,offers,history}*` |
| Screens `home`, `lists`, `recipes`, `onboarding`, `auth`, `splash`, `profile`, `subscription`, `legal`, `admin` | Screens `ai`/`avo`, `calories`, `history`, `plan` (neu), `offers` (neu), `scanner` |
| — | **Ausnahmen in A-Ordnern:** Angebots-Widgets der Liste (`offer_*`, `list_price_summary_bar`, `list_offer_*`, `item_offer_*`, `zip_code_sheet`, `checkout_store_sheet`, `store_chip*`), `recipe_offers_card`, `weekly_deals_screen`, die Hinweis-Karten `avo_nudge_card`, `calorie_recipe_nudge_card`, `pending_splits_banner`, `personal_flyer_card`, `price_comparison_nudge_card`, `split_trip_nudge_card`, `profile/settings/offers_settings_screen.dart` |
| Widgets `common`, `recipes`, `recommendations`, `tutorial`, `design` | übrige `lib/presentation/widgets/*` (`deals` usw.) |
| Provider `auth`, `items`, `last_list`, `lists`, `recipes`, `saved_recipes`, `theme`, `language`, `subscription`, `ml_recommendations` | alle übrigen Provider (Angebote, Avo, Kalorien, Verlauf, Kosten teilen, Wochenplan …) |
| `lib/data/repositories/*` und die Modelle für Listen, Artikel, Rezepte, Nutzer, Kategorien | übrige Modelle (Angebote, Märkte, Kalorien, Verlauf, Kosten teilen …) |
| Services für Listen, Rezepte, Konto, Einstellungen, Tutorial, Teilen, Deep Links, Offline-Cache, Abo | Services für KI (alle Gemini/Claude-Nutzer inkl. Kategorisierung, Foto-Import, Empfehlungen), Angebote, Standort/Märkte, Verlauf, Kosten teilen, Kalorien, Avo, Mitteilungen/Push, Widgets, Supabase-Kern, Analytics |
| `ios/Runner/LiquidGlassViewFactory.swift`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/*` | alles andere unter `ios/` (Widgets, Siri, Health, `Info.plist`, `project.pbxproj`, `Podfile`, `AppDelegate`), `supabase/functions/*`, bestehende Migrationen |
| `assets/*` (außer Artikelbilder) | `assets/illustrations/*`, `assets/articles/*` |
| `test/layout/*` (Prüfmatrix) | — |

**Gemeinsam (GETEILT):** `pubspec.yaml`, `pubspec.lock`, `CLAUDE.md`, `analysis_options.yaml`, `README.md`, `.gitignore`, `docs/*`.

**Regeln für geteilte Dateien:**
- `pubspec.yaml`: Neue Pakete in einem eigenen, winzigen Commit, sofort pushen. Bei Konflikt beide Abhängigkeiten behalten, `flutter pub get`, `pubspec.lock` neu erzeugen.
- `CLAUDE.md`: A ändert nur den Designsystem-Abschnitt, B nur die KI/Gemini-Abschnitte.
- `docs/`: Jeder schreibt nur seine eigenen Dateien.

**Neue Dateien:** Beide dürfen neue Dateien in ihren eigenen Ordnern anlegen. Neue Migrationen dürfen beide anlegen, Name `YYYYMMDDHHMMSS_<a|b>_<thema>.sql`. Bestehende Migrationen gehören B.

**Tests** gehören dem Besitzer der getesteten Datei.

---

## 3. Verträge zwischen A und B

Die Verträge sind so geschnitten, dass beide sofort losarbeiten können. Wer eine Schnittstelle liefert, hält ihre Signatur stabil. Änderungen laufen nur über eine Anfrage in der Status-Datei.

1. **Modulsystem (A liefert bis S1).**
   - Datei: `lib/core/modules/app_modules.dart`.
   - Inhalt: `enum AppModule` mit allen Modulen aus Konzept 00 Kap. 15 (mindestens Angebote, Kalorien, Wochenplan, Kosten teilen, Avo), dazu der Riverpod-Provider `moduleEnabledProvider(AppModule)` (bool, lokal gespeichert und mit dem Konto synchronisiert) und das Setzen aus Onboarding und Einstellungen.
   - B fragt nur ab und versteckt seine Funktionen, wenn das Modul aus ist.
   - Der bisherige `calorieTrackingEnabledProvider` wird von B auf das Modulsystem umgestellt.
2. **Remote-Kill-Switch für Angebote (B).** B legt eine Supabase-Tabelle `app_flags` mit einem Service an. Alle Angebots-Widgets und -Provider von B verschwinden selbstständig, wenn das Flag aus ist. A muss dafür nichts tun.
3. **Slots: A baut den Platz, B füllt ihn.** Jedes B-Widget rendert `SizedBox.shrink()`, wenn das Modul aus ist, der Kill-Switch greift oder keine Daten da sind. A setzt die Widgets genau an die Stellen, die das Konzept zeigt.

   | Ort (A) | Widget/Funktion (B) |
   |---|---|
   | Listen-Kopf | `StoreChip(listId:)` (Markt pro Liste, Kapitel 11/12) |
   | Hinzufügen-Feld, beim Tippen | `OfferSuggestionsBar(listId:, query:)` |
   | Artikel-Zeile | `ItemOfferBadge(listId:, item:)` |
   | Liste unten | `ListOfferSummary(listId:)` („4 von 11 im Angebot …“, ersetzt `ListPriceSummaryBar`) |
   | Artikel-Zeile, Bild | `ArticleImage(item:)` (Illustration oder Open-Food-Facts-Foto mit Quellenangabe) |
   | „Einkauf abschließen“ | `openCheckoutFlow(context, listId)` (Markt-Frage, Verlauf, Ersparnis) |
   | Rezeptdetail | `RecipeOffersCard(recipe:)` und `openLogRecipe(context, recipe)` |
   | Listen-Menü („Angebote für diese Liste ausblenden“) | `setOffersHiddenForList(listId, hidden)` und `offersHiddenForListProvider(listId)` |
   | Onboarding, wenn das Angebots-Modul an ist | `OffersSetupStep(onDone:)` (Standort bzw. PLZ, Lieblingsmärkte) |
   | Onboarding, wenn das Kalorien-Modul an ist | Zielberechnung über die stabile API von `nutrition_goal_service` (die Oberfläche bleibt bei A) |
   | Startseite | Hinweis-Karten von B als je ein Widget im B-Ordner. A ordnet sie an (`home_nudge_card_order.dart`). |
   | Einstellungen | A verlinkt auf B-Seiten („Preise & Angebote“, Apple Health und weitere B-Seiten laut Kapitel 18) |
   | Tab-Bar und Avo-Einstieg | A baut die D2-Tab-Bar (Home, Listen, Avo, Rezepte, Profil). Der Avo-Tab führt auf die B-Route. Wochenplan ist ein Segment im Rezepte-Tab (Inhalt von B), Kalorien läuft über Home und Push-Screens (B). A legt die Pfade in S1 fest und trägt sie in `status-A.md` ein. |

4. **Bausteine von A für B (bis S2):**
   - alle Komponenten aus 00 Kap. 12, auch `RecipeCard` für den Wochenplan und die Pro-Kennzeichnung
   - das Layout-Prüfgerüst `test/layout/` (Helfer, der einen Screen in allen Breiten und Schriftgrößen rendert)
5. **Stabile Daten-APIs:**
   - B hält die öffentlichen Methoden der Kategorisierung, des Foto-Imports und der Empfehlungen stabil. Die KI-Umstellung ist eine interne Änderung.
   - A hält die öffentlichen Methoden von `ItemRepository`, `ListRepository` und den Listen-/Artikel-Providern stabil (nur erweitern, nichts umbenennen), weil B sie nutzt (Avo-Tools, Wochenplan, Widgets).
6. **Routen und Texte:**
   - A teilt `app_router.dart` in Bereichsdateien unter `lib/routes/areas/` und `app_translations.dart` in Bereichsdateien unter `lib/core/localization/translations/` (Deutsch und Englisch je Bereich).
   - Danach pflegt jeder nur seine eigenen Bereichsdateien.
   - Schlüssel-Präfix = Bereich (z. B. `list_`, `recipe_`, `onb_` bei A; `avo_`, `cal_`, `plan_`, `offer_`, `hist_` bei B).

---

## 4. Meilensteine

Jeder Teil trägt seine Meilensteine in seine Status-Datei ein. Vor Arbeitsschritten, die auf einen Meilenstein des anderen warten, prüft man nach `git pull` dessen Status-Datei.

| Meilenstein | Wer | Inhalt | Wer wartet darauf |
|---|---|---|---|
| **S0 Aufräumen gemergt** | A | Der laufende Aufräum-Workflow (Branches `cleanup/group-A` bis `-I`, Session „Shoply App Version“ auf Mac 1) ist in `main` und gepusht. | Beide: vorher keine Codeänderungen, nur lesen und planen |
| **S1 Struktur** | A | Übersetzungen und Router in Bereichsdateien aufgeteilt, Modulsystem-Gerüst da, gepusht. Ziel: so früh wie möglich, als Erstes. | B: vorher keine Änderungen an Übersetzungen, Routen oder Modul-Abfragen |
| **S2 Fundament** | A | Tokens, Typografie, Komponenten, Tab-Bar mit Avo-Einstieg, Layout-Prüfgerüst, Designsystem-Abschnitt in `CLAUDE.md` | B: vorher keine sichtbaren Screens umbauen (Backend, Logik, nativer Code und Edge Function gehen schon) |
| **S3 Claude live** | B | Edge Function und Client laufen, Kategorisierung umgestellt (der Owner muss den API-Schlüssel in Supabase setzen) | A profitiert beim Hinzufügen; kein Warten nötig |
| **S4 Angebote abgesichert** | B | Ersatz-Keys raus, Kill-Switch, Wortlaut, die Slot-Widgets aus Abschnitt 3 fertig | A baut die Slots in die neue Liste ein |
| **S5 Bereiche fertig** | jeder für sich | Alle eigenen Arbeitspakete fertig und geprüft | – |
| **S6 Gegenprüfung** | beide | Jeder prüft die Screens des anderen (nur lesen), Funde als Anfrage in der Status-Datei | – |

---

## 5. Abstimmung über Status-Dateien

- **A schreibt nur `docs/redesign/status-A.md`, B nur `docs/redesign/status-B.md`.** Beide lesen nach jedem `git pull` die Datei des anderen.
- **Aufbau beider Dateien:**
  - **Stand:** ein Absatz, was gerade läuft
  - **Meilensteine:** S0 bis S6 mit Datum
  - **Anfragen an Teil X:** nummeriert, mit Datei, gewünschter Änderung und Grund
  - **Erledigte Anfragen von Teil X:** Nummer und Commit
  - **Fragen an den Owner**
- **Eine Anfrage blockiert nicht.** Wer anfragt, arbeitet woanders weiter, bis sie erledigt ist.
- **Notfall** (der Build bricht nach einem Merge wegen einer fremden Datei): kleinste mögliche Korrektur, eigener Commit `fix(<teil>): …`, sofort Eintrag in der eigenen Status-Datei. Nichts sonst in fremden Dateien.
- **Optional:** Zeigt `ListAgents` die Session des anderen Macs (gleicher Account, Remote Control), sind kurze Rückfragen per `SendMessage` erlaubt. Maßgeblich bleiben die Status-Dateien.

---

## 6. Git-Protokoll (ergänzt die Zwei-Mac-Regeln in CLAUDE.md)

1. **Vor jeder Aufgabe:** `git pull --rebase origin main`. Danach die Status-Datei des anderen lesen.
2. **Ein Branch pro Arbeitspaket:** kurz, `feature/a-<thema>` bzw. `feature/b-<thema>`. Kleine Commits.
3. **Vor jedem Commit:** `bash docs/redesign/check-ownership.sh A|B`, dann `dart analyze` (0 Errors, 0 Warnings).
4. **Vor jedem Push:**
   - `git fetch`, `origin/main` hereinholen, `dart analyze` erneut
   - bei UI-Änderungen der Simulator-Build (Speicher prüfen)
   - dann `main` vorspulen, `git push origin main`, Branch löschen
   - in einem Satz melden, dass der andere Mac pullen kann
5. **Geteilte Dateien** sofort nach der Änderung pushen, nie auf einem Branch liegen lassen.
6. **Niemals:**
   - Force-Push auf `main`
   - veröffentlichte Historie umschreiben
   - geheime Dateien pushen (`env.dart`, `firebase_options.dart`, `GoogleService-Info.plist`)
   - ungefragt Migrationen auf die echte Datenbank anwenden oder Edge Functions deployen (das macht der Owner bzw. nur nach seiner Freigabe)
   - TestFlight auslösen
7. **Der Branch `claude/daily`** (tägliche Routine) wird nicht ungefragt gemergt.

---

## 7. Ressourcen

- **Speicher:** Die Platte ist chronisch voll.
  - vor Builds `df -h /System/Volumes/Data`
  - unter 15 GB keine neuen Worktrees
  - unter 10 GB keine Builds, stattdessen den Owner bitten, Platz zu schaffen (siehe CLAUDE.md)
  - iOS-Builds nur im Haupt-Checkout, nicht in Worktrees
  - in Worktrees nur `flutter pub get` und `dart analyze`
  - nicht mehr benötigte Worktrees sofort entfernen
- **Gleicher Claude-Account:** Zwei Sessions mit Multi-Agent-Workflows teilen sich die Nutzungslimits. Workflows nur für echte Fan-outs (viele Screens umbauen, Prüfmatrix, Reviews), höchstens 4–6 parallele Agenten.
- **Simulator auf Mac 1:** Nur die iOS-27.2-Runtime ist installiert. Breiten und Schriftgrößen werden deshalb hauptsächlich per Flutter-Widget-Test geprüft (`test/layout/`), der Simulator dient für Stichproben und Screenshots.

---

## 8. Nur der Owner entscheidet

1. App-Name (Avo oder Shoply) und damit Abo-Name, Siri-Sätze, Icon-Schriftzug.
2. Freigabe der Design-Richtung nach den ChatGPT-Bildern.
3. Welche Module beim ersten Start vorausgewählt sind.
4. Welche Funktionen Pro werden (Angebote nie).
5. Partneranfrage für Angebote (marktguru, Bonial, Shopfully/Publitas).
6. Claude-API-Schlüssel, Modellwahl, Budget; Anwenden von Migrationen; Deploy von Edge Functions.
7. Supermarkt-Logos (nur mit Erlaubnis), TestFlight und App Store.

Solche Fragen stellt jede Session mit `AskUserQuestion` und arbeitet bis zur Antwort an etwas anderem weiter.
