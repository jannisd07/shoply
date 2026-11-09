ultracode

# Avo-Redesign – Teil B (Mac 2, Jannis): KI, Daten, Module und System

Du übernimmst **Teil B** eines kompletten Redesigns und Umbaus unserer iPhone-App „Avo“ (im Code noch „Shoply“; Flutter, iOS zuerst, Supabase, Riverpod) im Repo, in dem du gerade arbeitest.

**Teil A** macht gleichzeitig eine zweite Claude-Code-Session auf dem Mac des Owners: im selben GitHub-Repo (`jannisd07/shoply`), mit demselben Claude-Account, die ganze Zeit parallel zu dir.

Dieser Prompt verfolgt zwei Ziele:
1. Die App wird so gut, als käme sie von Apple.
2. A und B kommen sich nie in die Quere.

Arbeite selbstständig und gründlich. Frag nur bei den Entscheidungen in Abschnitt 10 nach, und arbeite bis zur Antwort an etwas anderem weiter. Beginne jede Antwort mit der Zeile „Bereich: …“, wie es die Zwei-Mac-Regeln in `CLAUDE.md` verlangen.

---

## 1. Ziel

- **Alle KI läuft über Claude** statt Gemini, sicher über eine Supabase Edge Function. Der API-Schlüssel kommt nie in die App.
- **Angebote rechtlich abgesichert und ehrlich:**
  - „4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region“
  - kein „günstigster Korb“
  - nie Teil von Pro
  - per Modul und Remote-Kill-Switch abschaltbar
- **Markt pro Liste:** Pro Liste wird der Supermarkt erkannt, und die Liste zeigt nur dessen Angebote.
- **Avo kann alles in der App**, auch per Sprache, und löscht nur nach Rückfrage.
- **Neu:** Wochenplan.
- **Kalorien-Tracking vollwertig** mit Apple Health, Barcode-Kamera und Workouts.
- **Widgets, Siri und Kontrollzentrum** sind richtig gut.
- **Schneller App-Start.**
- **Alle B-Screens im neuen Apple-Design** aus `docs/redesign/konzept/`, auf jedem iPhone korrekt:
  - Breiten 320 pt (Anzeigezoom), 375, 390/393, 402 und 440 pt
  - Dynamic Type bis AX5, fetter Text, Reduce Motion und Reduce Transparency

## 2. Pflichtlektüre (vor der ersten Änderung, vollständig)

1. `CLAUDE.md`: Zwei-Mac-Regeln, Skills-Tabelle, Build- und Analyse-Befehle, Gemini-Regeln (die du später ablöst), Speicher-Hinweise.
2. `docs/redesign/arbeitsteilung.md`: **verbindlich** für Dateibesitz, Verträge, Meilensteine, Status-Dateien und Git-Protokoll.
3. **Das Design:**
   - `docs/redesign/design-quelle.md` und `docs/DESIGN-STATUS.md` (feste Owner-Regeln: **keine Bottom-Sheets, keine Schieberegler, Bearbeiten immer im Vollbild**; Avo immer als echte 3D-Figur)
   - das D2-Glas-Artifact selbst (https://claude.ai/artifact/FKDP5yDZnBeGzfn6HH19dU, Artifact-Tool `action: "read"`). Lies mindestens `project/D2-Komponenten.dc.html` und die Screens deiner Bereiche: `X-Avo`, `X-AvoSprache`, `X-Wochenplan`, `X-Essen`, `X-Angebote`, `X-Einkaufsmodus` (Angebots-Teile), `D2-Widgets`, Kalorien-Karte in `D2-FuerDich`.
   - Danach `docs/redesign/konzept/00-grundlagen.md` und `01-navigation-und-struktur.md`, aber **nur inhaltlich** (Abläufe, Zustände, Barrierefreiheit, Module). Ihr Aussehen ist überholt, D2 gewinnt.
4. **Deine Kapitel** in `docs/redesign/konzept/`:
   - `12-angebote-verlauf.md`
   - `14-wochenplan.md`
   - `15-kalorien.md`
   - `16-avo.md`
   - `19-system.md` (ohne den Icon-Teil)
   - die B-Anteile in `20-qualitaet.md` (App-Start, KI-Latenz)
5. **Die Kapitel von Teil A nur überfliegen**, damit du weißt, wo deine Slots sitzen: `10-heute.md`, `11-listen.md`, `13-rezepte.md`, `17-onboarding.md`, `18-profil-pro.md`.
6. **Ist-Zustand deiner Bereiche** mit Datei:Zeile: `docs/redesign/konzept/inventar/` (avo, calories, history, lists-more, native, perf, brand).
7. **Weitere Quellen:**
   - `docs/Shoply-Ideen-und-Plan.md` (dein Plan; **bei Widersprüchen gilt er**)
   - `docs/research/Preise Angebote und Artikelbilder.md` (die rechtlichen Grenzen bei Angeboten, Preisen und Bildern sind verbindlich)
   - `docs/redesign/avo-verbesserungsliste.md`
8. `docs/redesign/status-A.md`, falls schon vorhanden.

## 3. Skills

Lade die passenden Skills nach der Tabelle in `CLAUDE.md`, ohne zu fragen:

| Wofür | Skills |
|---|---|
| Planung und Umsetzung | `superpowers:writing-plans` für deinen Plan; danach `superpowers:subagent-driven-development` oder Workflows; `planning-with-files` für den Fortschritt über die lange Arbeit |
| Claude-Umstellung (Pflicht vor jeder Zeile KI-Code) | `claude-api`: Modelle, SDK, Tool-Use, Bilder, Prompt-Caching, Refusal-Fallbacks, Kosten |
| KI messen (Kategorisierungs-Genauigkeit, Prompt-Injection gegen Avo; nur erfundene Testdaten) | `promptfoo-evals` mit `promptfoo-provider-setup` |
| Jeder B-Screen | `apple-design`, `design-taste-frontend` (dessen App-Screen-Regeln; seine Web-Regel „kein Glas“ gilt in iOS nicht, hier gilt Apples Liquid-Glass-Regel), `frontend-design`, `ui-ux-pro-max` |
| Barrierefreiheit | `design:accessibility-review` |
| Alle sichtbaren Texte | `design:ux-copy`, danach `humanizer` |
| Flows testen | `idiotensicher-testen` für Avo, Essen loggen, Wochenplan und Kosten teilen |
| Bugs | `superpowers:systematic-debugging` |
| Vor jedem „fertig“ | `superpowers:verification-before-completion` |
| Größere Pakete | `superpowers:requesting-code-review` |
| Vor einem Release | `claude-security` |
| Flutter-, Riverpod-, Supabase-, HealthKit-Paketfragen | Context7 |

Fehlt ein Plugin auf diesem Mac, sag es einmal und arbeite weiter.

## 4. Zuerst, in dieser Reihenfolge

1. **Synchronisieren:** `git fetch` und `git pull --rebase origin main`.
2. **Meilenstein S0 (Aufräumen)** abwarten:
   - Auf dem Mac des Owners lief ein Aufräum-Workflow (Branches `cleanup/group-A` bis `cleanup/group-I`), den Teil A nach `main` bringt.
   - Solange S0 nicht in `docs/redesign/status-A.md` steht, nur lesen und planen, keinen Code ändern.
   - Steht `status-A.md` noch gar nicht im Repo, warte. Ist nach einer Weile nichts da, frag den Owner.
3. **Design steht fest:**
   - Verbindlich ist D2 · Glas (siehe `design-quelle.md`).
   - Hängt der Owner neue Bilder an oder ändert er das Artifact, gilt der neueste Stand.
   - Das Designsystem im Code (Tokens, Komponenten) baut Teil A. Wünsche dazu trägst du als Anfrage in `status-B.md` ein.
4. **Status-Datei:** Lege `docs/redesign/status-B.md` an (Aufbau laut `arbeitsteilung.md` Abschnitt 5) und pushe sie.
5. **Plan:** Schreibe deinen Plan mit `superpowers:writing-plans` nach `docs/superpowers/plans/<datum>-teil-b.md`. Zerlege die Arbeitspakete B1 bis B10 in kleine, einzeln prüfbare Aufgaben.

## 5. Arbeitspakete Teil B

**Was du sofort machen kannst:** B1 bis B4 sind unsichtbar, die Edge Function, die Logik und der native Code gehen sofort, sobald S0 erreicht ist.

**Was du vorher nicht anfasst:**
- Texte und Routen: erst ab S1 von Teil A, danach nur in deinen Bereichsdateien.
- Sichtbare Screens: erst ab S2 (Fundament von Teil A).

### B1 Claude statt Gemini, Meilenstein S3

- **Edge Function** unter `supabase/functions/` (Deno/TypeScript, offizielles Anthropic-SDK laut `claude-api`-Skill):
  - prüft den Supabase-Login (JWT)
  - Limits pro Nutzer
  - Modellwahl laut Plan 7: kleines, schnelles Modell (`claude-haiku-5-5`) für Kategorien, starkes Modell (`claude-opus-5-5`) für Avo und Fotos. `claude-sonnet-5-5` als günstigere Alternative nur nach Owner-Freigabe.
  - Tool-Use für Avo, Bild-Eingabe für Essensfotos und Foto-Import
  - Prompt-Caching, Refusal-Fallbacks und Fehlerbehandlung nach dem Skill
  - Der Schlüssel liegt als Supabase-Secret. **Das setzt der Owner, und Deploys nur nach seiner Freigabe.**
- **Dart-Client** `claude_service.dart` (über `supabase.functions.invoke`), Antworten so schnell wie möglich (Streaming, wo sinnvoll).
- **Umstellen**, die öffentlichen Methoden bleiben stabil, weil Teil A sie nutzt:
  - `gemini_categorization_service` (und die Kategorisierungskette: `smart_categorization_service`, `product_classifier_service` als Offline-Fallback)
  - `avo_assistant_service` mit allen Tools aus `avo_tool_declarations`
  - `meal_photo_analysis_service`, `ai_recipe_labeling_service`, `ai_ingredient_analyzer`, `ml_recommendation_service`, `calorie_recipe_nudge_service`
  - der Foto-Import (`list_import_service` plus die Edge Function `extract-shopping-list`)
  - alle weiteren Gemini-Nutzer (`grep -rn "GenerativeModel\|gemini" lib`)
- **Messen** mit `promptfoo-evals`: Kategorisierungs-Genauigkeit gegen den heutigen Stand und Prompt-Injection gegen Avo. Nur erfundene Testdaten.
- **Danach:** Gemini-Paket und Gemini-Regeln entfernen; die KI-Abschnitte in `CLAUDE.md` auf Claude umschreiben (geteilte Datei: eigener Commit, sofort pushen). Kosten pro aktivem Nutzer und Monat messen und melden.

### B2 Angebote absichern und umbauen, Meilenstein S4

Kapitel 12 und Recherche.

- **Sofort:**
  - die Ersatz-Keys `_fallbackApiKey` und `_fallbackClientKey` aus `offer_price_service.dart` entfernen
  - **Remote-Kill-Switch:** Tabelle `app_flags` plus Service; alle Angebots-Widgets und -Provider verschwinden spurlos, wenn er greift (Vertrag 3.2)
  - kein Vorladen ganzer Kataloge oder vieler PLZ
  - Angebotsbilder (Hotlink auf `mg2de.b-cdn.net`) nur mit Lizenz, sonst `ArticleImage`
- **Wortlaut:**
  - „in deiner Region“; mit der Fallback-PLZ keine Ersparnis behaupten
  - „statt“-Preise als „laut Händler“
  - Angebote aus jedem Pro-Versprechen streichen: `AvoAppKnowledge` (deine Datei). Die Paywall-Texte gehören A, dafür eine Anfrage an A stellen.
- **Kein Korbvergleich mehr:** `comparableTotal` und „günstigster Korb“ in `price_comparison_provider.dart` ersetzen durch „X von Y Artikeln diese Woche bei [Markt] im Angebot, ca. Z € gespart, in deiner Region“, verglichen über den Grundpreis (`referencePrice`).
- **Markt pro Liste:**
  - Speicherung: neue Migration (z. B. `list_store_assignments` oder eigene Spalten, Name `…_b_…`), nicht über das Listen-Modell von Teil A.
  - Ketten-Verzeichnis mit Aliasen und Tippfehlern.
  - Erkennung aus diesen Signalen:
    1. Listenname
    2. ausdrückliche Wahl (schlägt alles)
    3. gelernt aus abgeschlossenen Einkäufen (`checkout_store_resolver`)
    4. Standort per `store_locator_service`, nur als Vorschlag
    5. Handelsmarken als schwaches Signal
  - Angebote nach Kette filtern.
- **Slot-Widgets für Teil A** (Vertrag 3.3), jedes rendert nichts, wenn das Modul aus ist, der Kill-Switch greift oder keine Daten da sind:
  - `StoreChip`, `OfferSuggestionsBar`, `ItemOfferBadge`, `ListOfferSummary`
  - `openCheckoutFlow` (Markt-Frage, Verlauf, Ersparnis)
  - `setOffersHiddenForList` und `offersHiddenForListProvider`
  - `RecipeOffersCard`, `OffersSetupStep` (Onboarding)
- **Einstellungsseite „Preise & Angebote“** (`profile/settings/offers_settings_screen.dart`, deine Datei):
  - Modul-Schalter
  - Angebote in Listen, Vorschläge beim Tippen, Anzeige „X von Y / gespart“
  - Spar-Karten auf der Startseite
  - automatische Markt-Erkennung
  - Standort bzw. PLZ, Lieblingsmärkte
  - Avo kann die Schalter über `update_setting` ändern.
- **Partneranfrage:** Entwurf für den Owner in `docs/redesign/angebote-partneranfrage.md` (marktguru, ersatzweise Bonial oder Shopfully/Publitas; Argument „Reichweite für Händler-Angebote“). **Er verschickt sie selbst.**
- **Abschluss:** S4 melden.

### B3 App-Start und Tempo

Sofort möglich, unsichtbar.
- `lib/main.dart` startet heute viele Dienste nacheinander. Was der erste Frame nicht braucht, startet parallel oder bei Bedarf (Firebase, FCM, KI, Widgets, Siri, Benachrichtigungen).
- Startzeit vorher und nachher messen (Profile-Modus, echtes Gerät, wenn möglich).
- KI-Aufrufe blockieren nie die Oberfläche.
- Realtime- und Stream-Provider in deinen Bereichen sparsam halten.
- Crash-Reporting prüfen. Ein neues Paket nur nach Owner-Freigabe.

### B4 Artikelbilder

Plan 8 und Recherche.
- `ArticleImage(item:)`: eigene Illustration für Kategorien und häufige Artikel; ein Open-Food-Facts-Foto nur bei erkanntem Markenprodukt oder Barcode, mit „Foto: Open Food Facts, CC BY-SA“ und Link.
- Den User-Agent in `open_food_facts_service.dart` auf `AppName/Version (Kontakt-E-Mail)` setzen; Rate-Limits einhalten.
- **Illustrationen kannst du nicht selbst zeichnen:** Stil passend zu den Artikelbildern im D2-Artifact festlegen (D2 zeigt freigestellte Fotos), eine Liste der ca. 200 häufigsten Artikel erstellen, präzise Bild-Prompts schreiben. **Der Owner erzeugt die Bilder**, du baust sie ein (`assets/illustrations/`).
- Bis dahin: SF-Symbol-Fallback je Kategorie.

### B5 Avo nach Kapitel 16

Die Oberfläche erst ab S2; Tools und Logik sofort.
- **Genau ein Einstieg:** der Avo-Tab der D2-Tab-Bar. Die Tab-Bar baut A, der Tab führt auf deine Avo-Route (Pfad steht nach S1 in `status-A.md`).
- **Chat neu gestaltet:** Antwortkarten für alle Tool-Ergebnisse (Listen, Artikel, Rezepte, Angebote, Kalorien, Wochenplan, Einstellungen, Verlauf, Kosten teilen); leerer Chat mit Schnellaktionen.
- **Sprachmodus:** sprechen statt tippen, Avo antwortet mit Stimme. Möglichst über iOS-eigene Spracherkennung und -ausgabe; neue Pakete nur als eigener Mini-Commit in `pubspec`.
- **Tool-Abdeckung prüfen:** Avo kann alles in der App. Lücken gegen alle Funktionen der App schließen, auch Wochenplan, Workouts und Module.
- **Sicherheit:** Löschen nur nach Rückfrage; alles nur mit den Rechten der angemeldeten Person; Allergien beachten.
- **Wissen:** `AvoAppKnowledge` auf den Stand nach dem Redesign bringen (Pro-Inhalte, sobald der Owner entschieden hat; Teil A liefert sie per Anfrage).

### B6 Kalorien und Gesundheit nach Kapitel 15

Daten und nativer Code sofort, Screens ab S2.
- **Tagesübersicht.**
- **Essen per Foto** (Claude, mit angezeigter Sicherheit).
- **Barcode-Kamera-Scanner** statt der heutigen Zifferneingabe (`add_food_barcode_hint`).
- **Suche** (Open Food Facts) und manuelle Eingabe.
- **Gewicht und Wasser**, **Workouts (neu)**.
- **Ziele, Verlauf, Wochenübersicht, Challenges**, „Was kann ich heute noch essen?“.
- **Apple Health lesen und schreiben:**
  - HealthKit-Capability und Entitlement
  - Berechtigungstexte in `Info.plist`
  - Berechtigungsabfrage im richtigen Moment, nicht beim Start
- **Modul:** `calorieTrackingEnabledProvider` auf das Modulsystem von Teil A umstellen (`moduleEnabledProvider`, ab S1).

### B7 Wochenplan nach Kapitel 14

Neu, Screens ab S2.
- Rezepte für die Woche wählen, Portionen anpassen, ein Tipp: alle Zutaten zusammengefasst auf die Liste.
- Zum Zusammenfassen nutzt du die stabile API von `item_merge_service` und `ItemRepository` (beide gehören A; Erweiterungen per Anfrage).
- **Daten:** neue Migration (z. B. `meal_plans`, `meal_plan_entries`).
- **Bausteine von A:** `RecipeCard` und die Rezeptauswahl.
- Ist das Kalorien-Modul an: Kalorien pro Tag zeigen.
- Liefert eine Hinweis-Karte „Heute kochen“ für die Startseite.

### B8 Verlauf, Ersparnis, Kosten teilen, Angebote der Woche nach Kapitel 12

Screens ab S2.
- Monatsrückblick und Ersparnis (nur ehrliche Werte laut Recherche).
- Kosten teilen (gleich oder individuell, Zahlungserinnerung), offene Aufteilungen.
- Angebote der Woche.
- **Hinweis-Karten der Startseite aus deinen Bereichen** als eigene Widgets in deinen Ordnern: Nachkauf („Milch geht dir bald aus“), persönlicher Prospekt, Angebots-Hinweis im erlaubten Wortlaut, Kosten teilen, Kalorien-Rezept, Wochenplan heute. Teil A ordnet sie an.

### B9 Widgets, Siri, Kontrollzentrum, Mitteilungen nach Kapitel 19

- Ein gemeinsamer Satz **App Intents** für Siri, Kurzbefehle, Kontrollzentrum und interaktive Widgets: Artikel hinzufügen, Abhaken, Liste öffnen, „Was steht auf meiner Liste?“.
- **Widgets** im Design von `D2-Widgets` (Farben aus den D2-Tokens, auch getönte und Glas-Darstellung):
  - Liste mit **Abhaken direkt im Widget**
  - Schnell hinzufügen
  - Wochenplan
  - Rezept
  - Kalorien und Wasser, nur wenn das Modul an ist
- **Größen:**
  - Home-Bildschirm klein, mittel, groß
  - Sperrbildschirm rund, rechteckig, inline
  - StandBy
- **Konfiguration:** Liste wählen, Erledigtes ein oder aus, nach Kategorie gruppieren.
- **Daten in beide Richtungen zuverlässig** über die App Group `group.com.shoply.app`; Widgets nach jeder Änderung neu laden; offline sauber.
- **Siri-Sätze mit dem App-Namen** erst nach der Namensentscheidung finalisieren.
- **Mitteilungen** im neuen Ton und Stil, nur mit echtem Nutzen.
- ❌ **Keine Live Activity und keine Dynamic Island** (Plan 5).

### B10 Qualität und Gegenprüfung

- **Prüfmatrix** (`test/layout/`, Helfer von Teil A ab S2) für jeden B-Screen, grün.
- **Barrierefreiheit:** VoiceOver, Kontrast, Reduce Motion, Reduce Transparency.
- **Flows testen** mit `idiotensicher-testen`: Avo, Essen loggen, Wochenplan, Kosten teilen.
- **KI messen:** promptfoo-Evals grün.
- **Widgets und Siri** auf einem echten Gerät testen (den Owner bzw. Jannis um das iPhone bitten).
- **Vor einem Release:** `claude-security` (Änderungen scannen).
- **Gegenprüfung (S6):** die Screens von Teil A nur lesend prüfen. Funde als Anfragen in `status-B.md`.

## 6. Dateibesitz (Kurzfassung, maßgeblich ist `docs/redesign/owner.sh`)

**Deine Dateien:**
- `lib/main.dart`, `lib/core/config`, `lib/core/services`, `firebase_options*`
- deine Bereichsdateien unter `lib/core/localization/translations/` (avo, calories, plan, offers, history, notifications, system) und unter `lib/routes/areas/` (avo, calories, plan, offers, history)
- Screens `ai`/`avo`, `calories`, `history`, `plan`, `offers`, `scanner`
- **in Ordnern von A:**
  - Angebots-Widgets der Liste: `offer_*`, `list_price_summary_bar`, `list_offer_*`, `item_offer_*`, `zip_code_sheet`, `checkout_store_sheet`, `store_chip*`
  - `recipe_offers_card`, `weekly_deals_screen`
  - die Hinweis-Karten `avo_nudge_card`, `calorie_recipe_nudge_card`, `pending_splits_banner`, `personal_flyer_card`, `price_comparison_nudge_card`, `split_trip_nudge_card`
  - `profile/settings/offers_settings_screen.dart`
- alle Provider, Modelle und Services für KI, Angebote, Märkte und Standort, Verlauf, Kosten teilen, Kalorien, Avo, Mitteilungen und Push, Widgets, Supabase-Kern und Analytics
- `lib/core/utils/{category_detector,product_name_normalizer,request_throttle}.dart`
- alles unter `ios/` außer `LiquidGlassViewFactory.swift` und `AppIcon.appiconset`
- `supabase/functions/*`, die bestehenden Migrationen, `assets/illustrations/` und `assets/articles/`

**Nicht deine Dateien:**
- das Designsystem (`lib/core/constants`, `theme`, `widgets`, `design`, `modules`)
- das Übersetzungs- und Router-Gerüst, `lib/app.dart`, `main_scaffold.dart`
- die Screens `home`, `lists`, `recipes`, `onboarding`, `auth`, `splash`, `profile`, `subscription`, `legal` (bis auf deine Ausnahmen oben)
- die Repositories und die Listen-, Artikel-, Rezept- und Nutzer-Modelle und -Provider
- `offline_cache_service`, `item_merge_service`, `sharing_service`, `subscription_service` und die weiteren A-Services laut `owner.sh`

**Werkzeuge:**
- Vor jedem Commit: `bash docs/redesign/check-ownership.sh B`. Bricht es ab, nimmst du die fremde Datei aus dem Commit und trägst eine Anfrage in `status-B.md` ein.
- Bei Zweifel: `bash docs/redesign/owner.sh <pfad>`.

**Geteilte Dateien:**
- `pubspec.yaml` und `pubspec.lock`: neue Pakete (z. B. HealthKit, Barcode-Scanner, Sprache) als eigener Mini-Commit, sofort pushen. Bei Konflikt beide behalten, `flutter pub get`.
- `CLAUDE.md`: nur die KI- und Gemini-Abschnitte.
- `docs/`: nur deine Dateien und deine Konzeptkapitel. Das sind 12, 14, 15, 16 und 19 ohne den Icon-Teil.

**Neue Migrationen:** Name `YYYYMMDDHHMMSS_b_<thema>.sql`. **Anwenden nur der Owner bzw. nach seiner Freigabe.**

## 7. Arbeitsweise mit ultracode (Workflows)

- **Eine Sitzung je Arbeitspaket** (Owner, 09.11.2026, Wochenlimit): Jede Sitzung bearbeitet genau ein Paket, schreibt
  das Ergebnis in `status-B.md` und `b-sitzungen.md`, pusht, erinnert den Owner an eine neue Sitzung und gibt ihm den
  Start-Prompt für die nächste. Ablauf, Pakete, Arbeitsweise und Start-Prompt: [`b-sitzungen.md`](b-sitzungen.md).
- **Workflows lohnen sich hier:**
  - KI-Services parallel umstellen (ein Agent pro Service, gemeinsamer Client zuerst)
  - Tool-Abdeckung von Avo gegen alle App-Funktionen prüfen
  - B-Screens umbauen (ein Agent pro Screen)
  - Widgets in allen Größen
  - Prüfmatrix
  - unabhängige Reviews vor dem Push großer Pakete (Sicherheit der Edge Function, Recht und Wortlaut bei Angeboten, Barrierefreiheit, Regressionen)
- **Dosierung:** Höchstens 4–6 Agenten gleichzeitig. Ihr teilt euch einen Claude-Account mit A.
- **Worktree-Isolation** nur, wenn Agenten parallel Dateien ändern, höchstens 3 gleichzeitig. In Worktrees nur `flutter pub get` und `dart analyze`, nie iOS-Builds. Worktrees danach entfernen.
- **Speicher:** vor jedem Build `df -h /System/Volumes/Data`. Unter 15 GB keine neuen Worktrees. Unter 10 GB keine Builds. Platz schaffen ist erlaubt (Owner, 09.11.2026), aber nur Regenerierbares (Xcode `iOS
  DeviceSupport` und `DerivedData`, SwiftPM-Cache, Update-Reste, ungenutzte Simulatoren); nie Downloads, Papierkorb,
  fremde Projekte oder das macOS-Update.

## 8. Git-Protokoll und Abstimmung mit Teil A

1. **Vor jeder Aufgabe:** `git pull --rebase origin main`, dann `docs/redesign/status-A.md` lesen (Meilensteine S0, S1, S2 und Anfragen an dich).
2. **Branch pro Arbeitspaket:** `feature/b-<thema>`, kleine Commits.
3. **Vor jedem Commit:** `bash docs/redesign/check-ownership.sh B`, dann `dart analyze` (0 Errors, 0 Warnings; die bekannten Info-Lints ignorieren).
4. **Vor jedem Push:**
   - `git fetch`, `origin/main` hereinholen, `dart analyze` erneut
   - bei UI- oder nativen Änderungen `flutter build ios --simulator --debug` (Speicher prüfen)
   - `main` vorspulen, `git push origin main`, Branch löschen
   - ein Satz, dass der Owner-Mac pullen kann
5. **Anfragen von A** haben Vorrang, wenn A sonst blockiert ist. Erledigt wird mit Commit-Hash in `status-B.md`.
6. **Niemals:**
   - Force-Push oder Umschreiben veröffentlichter Historie
   - geheime Dateien pushen
   - API-Schlüssel in App, Repo oder Log
   - Migrationen auf der echten Datenbank anwenden oder Edge Functions deployen ohne Owner-Freigabe
   - TestFlight auslösen
   - `claude/daily` ungefragt mergen
7. **Notfall:** Bricht der Build durch eine Datei von A, machst du die kleinste mögliche Korrektur als eigenen Commit `fix(b): …` und trägst sie sofort in `status-B.md` ein.

## 9. Qualitätsmaßstab (gilt für jedes Arbeitspaket)

- **Designtreue:** sieht aus wie im D2-Artifact; im Code nur die Tokens und Komponenten von Teil A. Fehlt ein Baustein, Anfrage an A (nicht selbst ins Designsystem schreiben).
- **Barrierefreiheit:** Prüfmatrix grün; VoiceOver-Labels; Touch-Ziele mindestens 44 pt.
- **Zustände:** leer, lädt (sofort lokaler Stand), Fehler, offline, Modul aus, Kill-Switch, Pro gesperrt. Jeder Zustand ist gestaltet.
- **Ehrlichkeit:** keine erfundenen Zahlen, keine Ersparnis ohne echte Datengrundlage.
- **KI-Sicherheit:** Allergien, Löschen nur nach Rückfrage, keine Daten anderer Nutzer, Schlüssel nur serverseitig.
- **Texte:** Deutsch und Englisch, mit `design:ux-copy` und `humanizer` geprüft.
- **„Fertig“:** erst nach `superpowers:verification-before-completion` und mit Belegen (Testausgabe, Screenshots, Eval-Ergebnisse).

## 10. Nur der Owner entscheidet

Stelle diese Fragen mit `AskUserQuestion` und arbeite weiter:
1. Claude-API-Schlüssel und Credits (nur API-Credits aus der Claude Console sind nutzbar), Modellwahl für Avo, Budget pro Monat.
2. Setzen des Supabase-Secrets, Deploy der Edge Functions, Anwenden der Migrationen.
3. Neue Pakete mit Datenschutz-Bezug (HealthKit, Crash-Reporting) und die Berechtigungstexte.
4. Partneranfrage für Angebote verschicken; Supermarkt-Logos nur mit Erlaubnis.
5. Illustrationen für Artikelbilder erzeugen (deine Bild-Prompts).
6. App-Name für Siri-Sätze und Widgets.
7. Welche deiner Funktionen Pro werden (Angebote nie).

## 11. Fertig, wenn

- B1 bis B10 erledigt sind und jeder Meilenstein in `status-B.md` steht.
- Keine Gemini-Abhängigkeit mehr da ist.
- Die Angebote abgesichert und ehrlich sind.
- Avo jede Kernaktion per Text und Sprache kann.
- Kalorien inklusive Apple Health funktionieren.
- Der Wochenplan saubere Listen erzeugt.
- Widgets und Siri auf einem echten Gerät zuverlässig laufen.
- Alle B-Screens dem Konzept entsprechen und die Prüfmatrix grün ist.
- Die Anfragen von A erledigt sind und die Gegenprüfung (S6) abgeschlossen ist.
- Der Owner einen Abschlussbericht hat: Kosten der KI pro Nutzer, was offen ist, welche Entscheidungen noch ausstehen.

**Starte jetzt mit Abschnitt 4, Schritt 1.**
