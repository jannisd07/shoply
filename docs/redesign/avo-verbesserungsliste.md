# Verbesserungsliste (Stand 07.11.2026, abgeglichen mit Jannis' Plan)

> **Umsetzung:** Diese Liste ist in das Designkonzept ([`konzept/`](konzept/)) und die beiden Prompts für die parallele Arbeit eingeflossen ([`prompt-teil-A.md`](prompt-teil-A.md) für den Owner, [`prompt-teil-B.md`](prompt-teil-B.md) für Jannis). Die Aufteilung regelt [`arbeitsteilung.md`](arbeitsteilung.md).

Arbeitsauftrag für Claude.

**Quellen:**
- Jannis' Plan [`docs/Shoply-Ideen-und-Plan.md`](../Shoply-Ideen-und-Plan.md) (kurz „Plan“).
- Die Recherche [`docs/research/Preise Angebote und Artikelbilder.md`](../research/Preise%20Angebote%20und%20Artikelbilder.md) (kurz „Recherche“).
- Die Wünsche vom 07.11. (kurz „Wunsch“).

**Bei Widersprüchen gilt der Plan.**

**Status wie im Plan:** ✅ entschieden · 🔍 erst prüfen · 💡 offen · ❌ verworfen. Bei jedem Punkt steht die Quelle.

Jeder Punkt hat ein Ziel, Anforderungen, Ansatzpunkte im Code und eine Definition von „fertig“.

## 0. Rahmen

- **Technik:** Flutter, iOS zuerst, Supabase, Riverpod. Es gilt die `CLAUDE.md` im Repo, inklusive der Zwei-Mac-Regeln.
- **Name noch offen:** Auf dem Home-Bildschirm heißt die App „Avo“ (`CFBundleDisplayName`). Der Plan und der Code sagen „Shoply“, auf der Paywall steht „SHOPLY PREMIUM“, und die Erfolgsmeldung nach dem Kauf sagt „Willkommen bei Avo Pro!“. Der Name muss geklärt sein, bevor Texte, Icon und Siri-Sätze final werden (siehe offene Entscheidungen).
- **Bei jeder Änderung:** `dart analyze` mit 0 Errors und 0 Warnings, dann `flutter build ios --simulator --debug`. Auf dem Mac ist der Speicher knapp: vorher `df -h /System/Volumes/Data` prüfen.
- **Nichts streichen:** Bestehende Funktionen bleiben erhalten, außer hier steht es anders. Die vollständige Liste der Funktionen steht in `docs/redesign/chatgpt-redesign-prompt.md`, Abschnitt 3.
- **Analyse-Aufgaben** (Punkte 15 und 16) enden als Dokument in `docs/redesign/` und gehen zur Freigabe, bevor gebaut wird.

---

## 1. Design aus einem Guss ✅ (Plan 2, Wunsch)

**Ziel:** Ein komplett neues, einheitliches Design im Stil von iOS 27 und Liquid Glass, so hochwertig, als käme die App von Apple. Das heutige „Paper“-Design fällt weg.

**Anforderungen:**
- **Erst fünf Richtungen als Bilder** (gleiche Screens, fünf Stile). Wir wählen eine (Plan 2). Den Prompt an ChatGPT (`docs/redesign/chatgpt-redesign-prompt.md`) entsprechend nutzen. Die Bilder kommen nach `docs/redesign/konzept/`.
- Danach **ein Abstands- und Schriftsystem für alles.** Es ersetzt `PaperColors`, `PaperTextStyles` und die Paper-Bausteine in `lib/presentation/widgets/common/paper_settings.dart`. Die einzigen Quellen für Werte sind `AppColors`, `AppDimensions` und `AppTextStyles`. Keine hart codierten Farben oder Größen in den Screens.
- **Die Startseite ist die Liste von heute** (Plan 2).
- **Alle Screens umstellen,** hell und dunkel: Listen, Einkaufsmodus, Rezepte, Kochmodus, Kalorien, Avo, Profil und Einstellungen, Paywall, Onboarding und Login, Sheets, Dialoge, leere Zustände, Fehlerzustände.
- **Neues App-Icon,** und das Maskottchen passend zur gewählten Richtung.

**Fertig, wenn:** Kein Screen mehr im Paper-Stil ist und jeder Screen der gewählten Richtung entspricht, geprüft per Screenshot hell und dunkel.

---

## 2. Korrekte Darstellung auf jedem iPhone 💡 (Wunsch)

**Gemeldeter Bug:** Auf dem iPhone 13 Pro der Mutter ist der Text in der Eingabeleiste einer Liste halb abgeschnitten.

**Vermutete Ursachen (zuerst prüfen):**
- **Anzeigezoom.** Unter *Anzeige & Helligkeit → Anzeigezoom → „Größerer Text“* hat das iPhone 13 Pro nur noch ca. 320 pt logische Breite statt 390 pt.
- **Größere Systemschrift** (Dynamic Type) oder **fetter Text**.
- **Feste Maße in der Eingabeleiste** (`lib/presentation/screens/lists/widgets/add_item_composer.dart`):
  - Die Kapsel hat eine Mindesthöhe von 38 pt (`_kControlSize`).
  - Die Schrift ist fest 17 pt, dazu 9 pt vertikales Padding.
  - Die Höhe wird erst nach dem Frame gemessen (`_height`, ca. Zeile 117).
  - Im Native-Glass-Pfad steckt alles in `SizedBox(height: h)` (ca. Zeile 212).

**Anforderungen:**
- Eingabeleiste fixen. Danach die ganze App systematisch prüfen. Gerätematrix:
  - iPhone SE 3. Gen (375×667)
  - iPhone 13 mini (375×812)
  - iPhone 13 / 13 Pro (390×844)
  - iPhone 15–17 Pro (393–402 pt)
  - Pro Max (430–440 pt)
  - jeweils auch mit Anzeigezoom (320 pt)
- Textgrößen: Standard, größte normale Stufe, eine Bedienungshilfen-Stufe (AX), fetter Text.
- Navigationsleiste: Die Metriken werden proportional zur Breite skaliert (Commit `f383053`). Bei 320 pt prüfen.
- Safe Areas prüfen: Dynamic Island, Home-Indikator, Tastatur.

**Fertig, wenn:** Für jedes Gerät der Matrix Screenshots der Hauptscreens existieren, ohne abgeschnittenen Text und ohne Überlappungen, und der Bug der Mutter bestätigt behoben ist.

---

## 3. Tempo und Bugs: Es muss super schnell sein ✅ (Plan 3, Wunsch)

**Ziel:** Die App buggt heute viel. Sie soll sich sofort und flüssig anfühlen, ohne dass der Nutzer Laden bemerkt.

**Anforderungen:**
- **Schneller App-Start:** Die Dienste in `main()` laufen heute nacheinander. Sie sollen parallel oder erst bei Bedarf starten (Plan 3).
- **Listen sofort da:** Erst den lokalen Stand zeigen, dann im Hintergrund abgleichen (Plan 3; `offline_cache_service.dart` existiert). Kein Vollbild-Spinner für Daten, die schon einmal geladen wurden.
- **Optimistische Updates** für Abhaken, Hinzufügen, Löschen und Umbenennen. Bei Fehlern zurückrollen, mit dezentem Hinweis.
- **Flüssiges Scrollen und Abhaken ohne Ruckeln** (Plan 3). Rebuilds reduzieren (Riverpod `select`), Bilder cachen. Angebots- und Netzabfragen blockieren nie den Screen und verschieben das Layout nicht.
- **Messen im Profile-Modus** auf einem älteren echten iPhone (Ziel: iPhone 13 Pro), mit Flutter DevTools.
- **Bug-Inventur:**
  - Crash-Reporting prüfen bzw. einrichten (Firebase ist vorhanden).
  - Die Hauptabläufe Ende-zu-Ende testen: Liste anlegen, teilen, hinzufügen, abhaken, abschließen, Rezept auf Liste, Avo.

**Fertig, wenn:**
- Startseite, Liste und Rezepte zeigen beim zweiten Öffnen keinen Lade-Indikator.
- Keine Frames über 16 ms in den Hauptabläufen.
- Die Bug-Liste ist abgearbeitet oder bewusst zurückgestellt.

---

## 4. Kern-Ablauf: Hinzufügen, Einkaufsmodus, gemeinsam einkaufen ✅ (Plan 4)

**Anforderungen:**
- **Hinzufügen:**
  - Ein Eingabefeld mit Vorschlägen aus dem eigenen Verlauf.
  - „2 Milch“ wird zu Menge 2 und Artikel „Milch“.
  - Die Kategorie wird im Hintergrund gesetzt, ohne zu warten.
- **Einkaufsmodus:**
  - Große Häkchen, nach Gang sortiert.
  - Der Bildschirm bleibt an.
  - Ist für die Liste ein Markt bekannt (Punkt 6), kann die Gang-Reihenfolge später daran hängen.
- **Geteilte Listen:**
  - Man sieht, wer gerade einkauft.
  - Abgehaktes erscheint live bei allen.
- ❌ **Keine Live Activity / Dynamic Island** (Plan 5).

**Fertig, wenn:** Die drei Abläufe mit zwei Geräten auf derselben geteilten Liste getestet sind.

---

## 5. Module beim ersten Start wählen und neues Onboarding ✅ (Plan 1, Wunsch)

**Ziel:** Beim ersten Öffnen sieht man die Features und schaltet nur die ein, die man will. Später ist das in den Einstellungen änderbar. Das Onboarding wird designtechnisch deutlich besser.

**Anforderungen:**
- **Kern:** Einkaufsliste und Rezepte sind immer da. **Alles andere ist ein Modul:** Angebote, Kalorien, Kosten teilen, Avo, Wochenplan usw. (Plan 1).
- **Modulwahl im Onboarding:** Ein Schritt zeigt die Module mit kurzem Nutzen und Schalter.
  - Welche Module vorausgewählt sind, ist noch offen (Plan, Abschnitt „Offen“).
  - Wunsch vom 07.11.: Die Spar-Funktionen (Angebote) standardmäßig an.
  - Wenn das Angebots-Modul an ist, folgen Standort bzw. PLZ und die Lieblingsmärkte im selben Ablauf.
- **Halbfertiges liegt hinter einem Schalter** und ist unsichtbar, bis es fertig ist (Plan 1).
- **Onboarding neu gestalten** nach Punkt 1:
  - Kurz halten, jeder Schritt hat sichtbaren Nutzen, Überspringen ist möglich.
  - Mitteilungen nur mit klarem Nutzen erfragen.
  - Die Pro-Testphase erst nach einem Aha-Moment anbieten, nicht als Hürde.
- **Dateien:** `lib/presentation/screens/onboarding/` und `lib/presentation/screens/auth/`, Texte `onb_*` in `app_translations.dart` (Deutsch und Englisch). Das Kalorien-Modul gibt es heute schon als Schalter (`calorieTrackingEnabledProvider`). Es ist das Vorbild für die anderen Module.

**Fertig, wenn:**
- Jedes Modul lässt sich im Onboarding und in den Einstellungen an- und ausschalten und blendet sich überall sofort ein bzw. aus.
- Ein neuer Nutzer ist in unter 60 Sekunden durch.
- Das Onboarding sieht auf allen Geräten aus Punkt 2 sauber aus.

---

## 6. Angebote: absichern, Markt pro Liste, alles abschaltbar 🔍 (Plan 8, Recherche, Wunsch)

**Ausgangslage laut Recherche:**
- Die heutige Quelle ist die inoffizielle marktguru-API. **Deren AGB verbieten automatisches Auslesen und geschäftliche Nutzung.**
- Angebote gelten nur pro Postleitzahl, nicht pro Markt.
- **Normalpreise gibt es in Deutschland nicht als Datenquelle.**

### 6a. Sofort absichern (Recherche, „nächster Schritt“)
- Die fest eingebauten Ersatz-Keys aus `lib/data/services/offer_price_service.dart` entfernen (`_fallbackApiKey`, `_fallbackClientKey`).
- **Remote-Kill-Switch** einbauen: ein Supabase-Flag, das das ganze Angebots-Feature abschaltet.
- **Angebote aus jedem Premium-Versprechen nehmen.** Betroffen sind die Paywall-Texte `premium_feat_deals` und `AvoAppKnowledge`. Solange keine Lizenz besteht, sind Angebote nie Teil von Pro.
- Texte anpassen:
  - „in deiner Region“ statt „in deinem Markt“.
  - Mit der Fallback-PLZ `10115` keine Ersparnis behaupten.
  - „statt“-Preise als „laut Händler“ kennzeichnen.
- Angebotsbilder (Hotlink auf `mg2de.b-cdn.net`) nur mit Lizenz behalten, sonst die Kategorie-Illustration aus Punkt 7.
- Kein Vorladen ganzer Kataloge oder vieler PLZ.

### 6b. Kein „günstigster Korb“ mehr ❌ (Plan 8)
- `comparableTotal` und die Zeile „günstigster Korb“ in `lib/presentation/providers/price_comparison_provider.dart` ersetzen.
- Neu: **„4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region“**, verglichen über den Grundpreis (`referencePrice`), nicht über den Packungspreis.
- Keine Hinweise wie „bei Kaufland wäre dein Einkauf X € günstiger“ und kein Gesamtsummen-Vergleich zwischen Märkten.

### 6c. Markt pro Liste erkennen (Wunsch)
Avo erkennt, für welchen Markt eine Liste ist, und zeigt in dieser Liste nur dessen Angebote. Dafür werden mehrere Signale kombiniert:
1. **Listenname:** „Lidl“, „REWE Wocheneinkauf“, „Aldi Süd“, auch mit Tippfehlern. Dafür ein Verzeichnis der Ketten mit Aliasen.
2. **Expliziter Markt-Chip** mit Logo im Listenkopf, beim Anlegen wählbar und änderbar. Eine eigene Wahl schlägt immer alle anderen Signale.
3. **Gelernt:** `checkout_store_resolver.dart` speichert bereits, wo eine Liste abgeschlossen wurde. Nach zweimal demselben Markt wird dieser Markt vorgeschlagen.
4. **Standort:** Liste in oder vor einem Markt geöffnet, erkannt per `store_locator_service.dart` (OpenStreetMap). Das wird als Frage gestellt, nie automatisch gesetzt.
5. **Handelsmarken** als schwaches Zusatzsignal, z. B. „Milbona“ = Lidl, „ja!“ = REWE, „Gut & Günstig“ = Edeka.
6. **Fallback:** „Kein fester Markt“. Dann die Angebote aller Märkte der Region.

**Technik:**
- `ShoppingList` (`lib/data/models/shopping_list_model.dart`) hat kein Markt-Feld. Nötig ist eine Supabase-Migration (z. B. `shopping_lists.store_chain`, `store_source`) mit Doku in `database/migrations/`.
- Den Ketten-Filter an `offer_price_service.dart` weitergeben.
- Der Markt ist auch ohne Angebote nützlich, z. B. für den Einkaufsmodus und den Verlauf.

### 6d. Alles abschaltbar, schnell auffindbar (Wunsch)
- Ein eigener Bereich **„Preise & Angebote“** in den Einstellungen, weit oben und über die Suche findbar. Er enthält:
  - den Modul-Schalter
  - Angebote in Listen
  - Vorschläge beim Tippen
  - die Anzeige „X von Y im Angebot / gespart“
  - Spar-Karten auf der Startseite
  - die automatische Markt-Erkennung
  - Standort bzw. PLZ und Lieblingsmärkte
- In jeder Liste ein Schnellschalter: „Angebote für diese Liste ausblenden“.
- Avo kann die Schalter per Chat ändern (`update_setting` in `avo_assistant_service.dart`).

**Fertig, wenn:**
- Keine Ersatz-Keys mehr im Repo sind und der Kill-Switch funktioniert.
- Die Formulierung „günstigster Korb“ nirgends mehr steht.
- Eine Liste „Lidl“ nur Lidl-Angebote zeigt.
- Jeder Schalter sofort wirkt und einen Neustart übersteht.

**Offen (Plan):** Die Partneranfrage bei marktguru, ersatzweise Bonial oder Shopfully/Publitas.

---

## 7. Artikelbilder 🔍 (Plan 8, Recherche: „bauen“)

- **Eigene Illustrationen** im Stil der neuen Designrichtung: für alle Kategorie-IDs und die ca. 200 häufigsten generischen Artikel.
- **Produktfotos von Open Food Facts** nur bei erkanntem Markenprodukt oder Barcode, mit „Foto: Open Food Facts, CC BY-SA“ und Link.
- Keine Fotos aus Händler-Shops oder Prospekten. Das ist urheberrechtlich ausgeschlossen.
- **Open-Food-Facts-Abfragen:**
  - Den User-Agent in `open_food_facts_service.dart` auf das verlangte Format `AppName/Version (Kontakt-E-Mail)` ändern. Heute steht dort `Shoply-App/1.0 (Flutter; …)`.
  - Rate-Limits beachten: 15 Produktabfragen bzw. 10 Suchen pro Minute.
  - Bei Bedarf später den deutschen OFF-Export in Supabase spiegeln.

**Fertig, wenn:** Jeder Listenartikel ein Bild hat (Illustration oder lizenziertes Foto) und die Quellenangaben stimmen.

---

## 8. Claude statt Gemini, und wofür die Claude-Credits taugen ✅ (Plan 7, Wunsch)

**Entschieden (Plan 7):**
- Alle KI-Funktionen laufen über Claude.
- Die Aufrufe gehen über eine **Supabase Edge Function**, der API-Key kommt nicht in die App.
- Ein kleines, schnelles Modell für Kategorien, ein starkes Modell für Avo und Fotos.

**Heute nutzen Gemini:**
- `gemini_categorization_service.dart`
- `avo_assistant_service.dart`
- `meal_photo_analysis_service.dart`
- `ai_recipe_labeling_service.dart`
- `ai_ingredient_analyzer.dart`
- `ingredient_scanner_screen.dart` (toter Code, siehe Punkt 14)

Nach der Umstellung die Gemini-Regeln in der `CLAUDE.md` anpassen (1100-ms-Pause, Cache).

**Modellvorschlag** (Preise Stand Oktober 2026, vor Umsetzung auf https://platform.claude.com/docs/en/about-claude/pricing prüfen):
- Claude Haiku 5.5 (0,10 $ Input / 0,50 $ Output pro Million Tokens) für Kategorien und Kassenbon-Erkennung.
- Claude Sonnet 5.5 (2 $ / 10 $) oder Claude Opus 5.5 (4 $ / 20 $) für Avo und Essensfotos. Die Wahl nach einem kleinen Qualitätstest treffen.

**Frage vom 07.11.: Können wir mit den Claude-Credits Produktpreise online abrufen?**
- Für App-Funktionen gehen nur **API-Credits** (Claude Console). Ein Claude-App-Abo lässt sich dafür nicht nutzen. Zuerst klären, welche Credits wir haben.
- Die Websuche über die API kostet **10 $ pro 1.000 Suchen** plus die Tokens der Ergebnisse. Das sind grob **3–5 Cent pro Produkt**, also ca. 0,60–1 € für eine Liste mit 20 Artikeln.
- **Empfehlung: nicht machen.** Laut Recherche gibt es in Deutschland keine verlässliche und lizenzierbare Quelle für Normalpreise. Eine Websuche fände veraltete oder falsche Preise, mit demselben Rechtsrisiko wie Scraping.
- **Wofür die Credits stattdessen da sind:** die Claude-Umstellung selbst (Avo, Kategorien, Fotos) und Hintergrund-Jobs über die Batch API (50 % günstiger).

**Fertig, wenn:**
- Kein Gemini-Aufruf mehr in der App.
- Kein API-Key in der App.
- Die Edge Function läuft mit Limits pro Nutzer.
- Die Kosten pro aktivem Nutzer und Monat sind gemessen.

---

## 9. Avo: ein Einstieg, kann alles, mit Stimme ✅ (Plan 1, Plan 12)

**Anforderungen:**
- **Einen** Einstiegspunkt für Avo statt mehrerer (Plan 1).
- **Voice-Modus:** sprechen statt tippen, Avo antwortet mit Stimme.
- **Avo kann alles in der App:** Listen, Rezepte, Kalorien (Foto vom Essen wird eingetragen), alle Einstellungen. Heute gibt es 35 Tools in `avo_assistant_service.dart`. Lücken gegen die App-Funktionen abgleichen.
- **Nur für die Person, die ihn bedient:** Alles läuft mit deren Login und Rechten. **Löschen nur mit Rückfrage.**
- Avo läuft über Claude (Punkt 8).

**Fertig, wenn:** Jede Kernaktion der App per Text und per Stimme über Avo geht und jedes Löschen eine Bestätigung verlangt.

---

## 10. Kalorien-Tracking vollwertig ✅ (Plan 9)

**Anforderungen:**
- **Mahlzeit per Foto** (KI schätzt Kalorien und Makros), **Barcode-Scanner** und **Lebensmittelsuche**.
  - Heute wird der Barcode als Nummer eingetippt (`add_food_barcode_hint`). Ein echter Kamera-Scanner fehlt.
- **Gewicht, Wasser, Workouts.** Workouts sind neu.
- **Ziele, Verlauf, Wochenübersicht.**
- **Apple Health lesen und schreiben.**
- Nur sichtbar, wenn das Modul an ist (Punkt 5).

**Fertig, wenn:**
- Ein Tag lässt sich komplett per Foto, Barcode-Kamera und Suche loggen.
- Gewicht, Wasser und Workouts landen in Apple Health und kommen von dort zurück.

---

## 11. Wochenplan ✅ (Plan 5)

- Rezepte für die Woche wählen, Portionen anpassen, mit einem Tipp landet alles auf der Liste.
- Gleiche Zutaten zusammenfassen (`item_merge_service.dart` existiert).
- Ist das Kalorien-Modul an, die Kalorien pro Tag anzeigen.

**Fertig, wenn:** Ein Wochenplan mit 5 Rezepten eine saubere, zusammengefasste Liste erzeugt.

---

## 12. Siri ✅ (Plan 10)

- Sätze wie „Füg Milch zu [App-Name] hinzu“ und „Was steht auf meiner Liste?“.
- Den App-Namen erst nach der Namensentscheidung festlegen (Punkt 0).
- Über App Intents bauen, die auch die Widgets (Punkt 13) und die Kurzbefehle nutzen.
- Heute vorhanden: `ios/Runner/VoiceAssistantPlugin.swift`, `lib/data/services/voice_assistant_service.dart`.

**Fertig, wenn:** Die Sätze auf einem echten Gerät funktionieren, auch bei gesperrtem Gerät soweit iOS das erlaubt.

---

## 13. Widgets: richtig gut ✅ (Plan 11, Wunsch)

**Ist-Stand** in `ios/ShoppingListWidget/` (App Group `group.com.shoply.app`):
- `ShoppingListWidget.swift` (klein/mittel/groß)
- `QuickAddWidget.swift` (interaktiv)
- `SavedRecipesWidget.swift`
- `ShoppingListWidgetControl.swift` (ein Gerüst)
- Flutter-Seite: `widget_service.dart`

**Anforderungen:**
- **Schnell und schön, abhaken direkt im Widget** (Plan 11). Design exakt im neuen App-Stil, auch in der getönten bzw. Glas-Darstellung.
- **Viel Auswahl:**
  - Widget-Typen: Liste, Schnell hinzufügen, Wochenplan, Rezept, Kalorien und Wasser (nur wenn das Modul an ist), Angebote (nur wenn das Modul an ist und lizenzrechtlich erlaubt).
  - Konfiguration: Liste wählen, Erledigtes zeigen oder ausblenden, nach Kategorie gruppieren.
- **Größen:** Home-Screen klein, mittel, groß; Sperrbildschirm rund, rechteckig, inline; StandBy.
- **Control Center / Action Button:** „Artikel hinzufügen“, „Liste öffnen“.
- **Daten in beide Richtungen zuverlässig:** App, andere Mitglieder (Realtime) und Widget. Offline sauber verhalten.

**Fertig, wenn:** Jede Widget-Art in jeder Größe auf einem echten Gerät getestet ist und Abhaken bzw. Hinzufügen zuverlässig synchron bleiben, auch bei großer Schrift.

---

## 14. Repo aufräumen ✅ (Plan 6)

**Läuft gerade (Stand 07.11., 20:20):** Ein Aufräum-Workflow, vermutlich aus der Session „Shoply App Version“, arbeitet in 9 Branches `cleanup/group-A` bis `cleanup/group-I` (Worktrees unter `.claude/worktrees/`). Er ist noch nicht in `feature/repo-cleanup` gemergt. Die Branches löschen schon die toten Screens unten, außer dem Admin-Screen. Vor eigener Arbeit an diesem Punkt das Ergebnis des Workflows abwarten.

**Anforderungen:**
- Struktur reinbringen, toten Code und Altlasten entfernen, den Code kürzen.
- Kurze Doku-Dateien statt der riesigen Status-Datei.
- Klären, ob die tägliche Claude-Routine weiterläuft. Davon hängt die Branch-Regel `claude/daily` in der `CLAUDE.md` ab.
- **Gefundene Kandidaten für toten Code** (nirgends eingebunden; vor dem Löschen noch einmal prüfen):
  - `screens/ai/ai_screen.dart` und `screens/ai/ai_dashboard_screen.dart` (verweisen nur aufeinander)
  - `screens/scanner/ingredient_scanner_screen.dart`
  - `screens/recipes/add_recipe_screen.dart`, `add_recipe_screen_new.dart`, `add_recipe_screen_old.dart` (die Route nutzt `MultiStepRecipeScreen`)
  - `screens/admin/recipe_batch_labeling_screen.dart`

**Fertig, wenn:** Der tote Code entfernt ist, `dart analyze` sauber bleibt und der Simulator-Build durchläuft.

---

## 15. Pro-Konzept: Free gegen Pro 💡 (Wunsch)

**Ziel:** Die App bleibt kostenlos, aber Pro muss sich spürbar lohnen.

**Feste Grenze:** Angebote sind nie Pro, solange keine Lizenz besteht (Punkt 6a).

**Analyse** als `docs/redesign/pro-konzept.md`:
1. **Ist-Stand:** Wo wird `isPremium` geprüft (`subscription_service.dart`)? Was ist tatsächlich gesperrt? Was verspricht die Paywall (`premium_feat_*`)? Was sagt `AvoAppKnowledge`? Die Aussagen widersprechen sich heute.
2. **Vorschlag Free gegen Pro:**
   - Der Kern (Liste, Rezepte, Teilen) bleibt Free und muss allein überzeugen.
   - Kandidaten für Pro: Wochenplan, Avo mit Stimme, vollwertiges Kalorien-Tracking mit Apple Health, Statistiken, neue Ideen aus Punkt 16.
   - Jeweils mit Begründung, Aufwand und erwartetem Nutzen.
3. **Wertbeweis und Paywall-Strategie:**
   - Wann wird die Paywall gezeigt (nach einem Aha-Moment)?
   - Testphase 14 Tage, Jahresabo hervorheben.
   - Familienfreigabe für das Abo prüfen.
   - Preise: 2,99 €/Monat bzw. 29,99 €/Jahr.

**Entscheidung:** Der Owner entscheidet nach dem Vorschlag.

---

## 16. Tägliche Nutzung und Alleinstellungsmerkmale 💡 (Wunsch)

**Ziel:** Heute öffnet man die App nur zum Einkaufen. Sie soll täglich genutzt werden und etwas bieten, das andere Einkaufslisten-Apps nicht haben.

**Analyse** als `docs/redesign/feature-ideen.md`:
- Wettbewerber: Bring!, Listonic, AnyList, Apple Erinnerungen, marktguru, kaufDA, die REWE- und Lidl-App, Yazio, MyFitnessPal.
- Tägliche Anlässe (morgens, unterwegs, abends, im Laden) und was davon die App übernehmen kann. Kein Benachrichtigungs-Spam.
- Neue Features mit Einzigartigkeit, Nutzen, Aufwand, Free oder Pro und Priorität.

**Ideen-Startpunkte** (zum Prüfen, nicht beschlossen):
- **Kassenbon scannen** (Claude Haiku, Bruchteile eines Cents pro Bon):
  - persönliches Haushaltsbuch mit echten, bezahlten Preisen
  - automatische Kostenaufteilung in geteilten Listen
  - gekaufte Artikel werden automatisch abgehakt
  - Ein Preisvergleich für alle daraus wäre laut Recherche ein eigenes Produkt (smhaggle ist damit 2026 insolvent gegangen), also nicht das Ziel.
- **„Ich bin im Laden“:** Mitglieder einer geteilten Liste bekommen eine Nachricht, z. B. „Lena ist bei REWE – noch was?“. Das passt zu Plan 4 („sehen, wer gerade einkauft“).
- **Vorrat und Mindesthaltbarkeit**, mit passenden Reste-Rezepten. Verbindet sich mit dem Wochenplan.
- **Monatsbudget und Spar-Ziel**, dazu ein teilbarer Jahresrückblick.
- **Apple Watch:** Liste am Handgelenk.
- ❌ Live Activity / Dynamic Island ist verworfen (Plan 5).

---

## Offene Entscheidungen

1. **App-Name:** „Avo“ (Home-Bildschirm, Assistent) oder „Shoply“ (Plan, Code), und davon abgeleitet der Name des Abos.
2. **Design-Richtung:** Auswahl aus fünf Beispielen (Plan, „Offen“).
3. **Welche Module beim ersten Start standardmäßig an sind** (Plan, „Offen“). Wunsch vom 07.11.: die Spar-Funktionen an.
4. **Partneranfrage für Angebote** stellen? An marktguru, ersatzweise Bonial oder Shopfully/Publitas (Plan, „Offen“).
5. **Welche Claude-Credits** wir haben (API oder App), und welches starke Modell für Avo genutzt wird.
6. **Free gegen Pro** (Punkt 15) und **welche neuen Features** gebaut werden (Punkt 16).

## Verworfen

- ❌ Live Activity / Dynamic Island (Plan 5).
- ❌ „Günstigster Markt für den ganzen Einkauf“ bzw. Korbsummen-Vergleich zwischen Märkten (Plan 8). Erst neu prüfen, wenn Deutschland Händler zur Veröffentlichung von Preisen verpflichtet.
- ❌ Produktpreise per Claude-Websuche (Punkt 8).
