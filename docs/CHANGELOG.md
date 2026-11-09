# Changelog

Größere Änderungen am Repo, neueste oben. Kleine Fixes stehen nur in der Git-Historie.

## 2026-11-09: Paywall wächst aus dem Element, Pro-Hinweis nach dem ersten Einkauf (Teil A, A9b)

- Paywall als Zoom-Seite aus dem angetippten Element (Zurück-Wischen 1:1, Reduce Motion: Überblendung).
- Preise der letzten StoreKit-Antwort erscheinen sofort; Kaufen erst, wenn StoreKit geantwortet hat.
- Startseite: „14 Tage Avo Pro gratis testen“ nach dem ersten Einkauf, höchstens einmal am Tag, „Nicht mehr zeigen“.

## 2026-11-09: Avo Pro und neue Paywall (Teil A, A9)

- Owner-Entscheidung Variante B: Pro = mehr KI pro Tag, Kochmodus ab Schritt 2, Avo-Wochenvorschläge, Statistiken.
  Liste, Teilen, Rezepte, Angebote und Verlauf bleiben frei.
- Neue D2-Paywall (`/pro?feature=`) mit Plänen, Testphase, Links zu Nutzungsbedingungen und Datenschutz und allen
  Zuständen; die alte Paper-Paywall ist gelöscht.
- Kochmodus: Zutaten und Schritt 1 frei als Vorschau, danach Paywall (auch beim Wischen).

## 2026-11-09: Bereiche fertig (Teil A, S5)

- Diät-Filter „Vegan“/„Vegetarisch“ und „Passt zu mir“ prüfen die Zutaten wie das Rezeptdetail.
- Wischaktionen: nur eine Zeile ist offen, Scrollen schließt sie.
- „Vielleicht auch“ zeigt Artikel mit gestricheltem Plus-Kreis (`ItemRow(suggestion: true)`).
- Galerie mit allen neueren Bausteinen; Abschlussbericht Teil A in `docs/redesign/abschlussbericht-A.md`.

## 2026-11-09: Qualität der A-Screens, zweiter Teil (Teil A, A11b)

- Für B's Wochenplan: Segment im Rezepte-Tab als Sliver, schwebende Leiste und eigene Toolbar-Knöpfe, grauer Grund.
- `showAvoMenu` kann Untermenüs (`AvoSubmenu`) und eine Vorschau (Kontextmenü).
- Simulator-Rundgang: Rezepte heißen nur noch „vegan“/„vegetarisch“, wenn keine Zutat dagegen spricht; Daten aus
  früheren Jahren zeigen das Jahr.
- Alle Symbole in A-Screens kommen aus `AvoIcons` (neu: Stern, Info, Buch, Glocke, Sortieren, Ersetzen, Anpassen).
- Entwürfe zeigen einen Fehlerzustand mit „Erneut versuchen“ statt „Keine Entwürfe“.

## 2026-11-09: Verlauf, Kosten teilen und Offene Beträge neu (Teil B, B8b/W11)

- Verlauf `/history` mit Monatsrückblick (Zahl des Monats, sechs Balken zum Wählen, Einkäufe und Artikel, Ersparnis
  nur als Satz mit „ca.“), Einkäufe nach Monat wie Buchungen, Filter nach Liste, Löschen mit Rückfrage je nach Fall.
- Einkauf-Detail `/history/:tripId` (Alle wieder auf die Liste, Kosten teilen mit „Bezahlt“, Artikel), Betrag und
  Kosten teilen als Vollbild statt Sheet, Offene Beträge `/splits` mit „Erledigt“. Home: „Dein November“, „Ausgaben im
  Vergleich“, „Letzte Einkäufe“ und ein Hinweis zum Teilen. Alter Verlauf, Split-Sheet und Nudge-Cache entfernt.

## 2026-11-09: Einkauf abschließen neu (Teil B, B8a/W10)

- „Einkauf abschließen“ ist ein Vollbild `/checkout/:listId` statt Alert, Markt-Sheet und Snackbar: Markt
  vorausgewählt (Liste, gelernt, Standort „(hier)“), Betrag optional („42,8“ → „42,80 €“), Kosten teilen als Schalter,
  Ersparnis nur mit „ca.“ und „laut Händler“. Danach Erfolgsmoment und „Einkauf gespeichert · Widerrufen“.
- Datenschicht: Verlauf lokal pro Konto (3 Monate, mindestens 50), Seiten zu 30, beim Abschluss ergänzt statt neu
  geladen; Betrag nur aus Eingabe (Bug 7); Markt als Ketten-ID. Migration-Entwurf `b_trip_checkout` (Owner wendet an),
  bis dahin Rückfall auf die alten Inserts.

## 2026-11-09: Qualität der A-Screens, erster Teil (Teil A, A11)

- Prüfmatrix für die noch fehlenden A-Screens: Rezepte-Tab, Alle Rezepte, Kategorie, Bibliothek, Home als Ganzes,
  Einkaufsmodus-Hülle, E-Mail-Code-Seite (zusammen über 600 Fälle mit Zuständen und Touch-Zielen).
- `tool/design_check.sh` prüft die D2-Regeln; A-Dateien sind sauber.
- Messtests `integration_test/perf/` für das echte iPhone im Profile-Modus.
- Fehler behoben: Angebotspille gehört in Liste und Einkaufsmodus zur Zeile (VoiceOver, Menü), Rezeptdetail beachtet
  „Rezepte automatisch anpassen“, Home lud nach Kontowechsel doppelt, Onboarding-Hinweis lag im Verlauf der
  Aktionsleiste; Glas-Ersatz und Dialoge nehmen die Farbtokens (auch „Kontrast erhöhen“).

## 2026-11-09: Aufräumen und Feature-Analyse (Teil A, A12)

- 13 tote Dateien gelöscht (u. a. `paper_widgets.dart`, `app_text_styles.dart`, altes `common/empty_state.dart`,
  `liquid_glass_button.dart`, ML-Empfehlungs-Abschnitt und -Provider), tote Symbole (`AuthService`,
  `navigateToDietPreferences`, `unsentChangesProvider`, alte Sterne-Widgets).
- 543 ungenutzte Textschlüssel aus A's Übersetzungsdateien entfernt (Deutsch und Englisch).
- Paper in A-Dateien nur noch in der Paywall (A9).
- Analyse `docs/redesign/feature-ideen.md`: Wettbewerbsvergleich und 22 Ideen mit Nutzen, Aufwand, Free/Pro.

## 2026-11-09: Einstellungen von Teil B und Schnittstellen für A8 (Teil B, BA8)

- Neue Einstellungsseiten im Profil-Tab: Avo (`/settings/avo`: Einwilligungen, Gespeichertes, Gespräch löschen,
  Hinweis zu Claude), Kalorien & Gesundheit (`/settings/health`: Ziele, Ideen fürs Abendessen mit Uhrzeit, Erlaubnis
  erst beim Einschalten), Siri (`/settings/siri`) und Widgets (`/settings/widgets`) als Info-Seiten bis B9.
- Eigene Suchliste von Teil B (`bSettingsSearchEntries`) mit Seiten und Zeilen, Modul- und Kill-Switch-Regeln; jede
  B-Seite hebt die gesuchte Zeile hervor (`?row=`), auch „Preise & Angebote“.
- `b_slots`: `pendingChangesCountProvider` (zählt jetzt die richtigen Warteschlangen pro Konto),
  `openSplitBalancesCountProvider`, `proSubscriptionDetailsProvider`, `subscriptionRenewsOnProvider` und
  `subscriptionFamilySharedProvider` (ehrlich `null` bis zur Belegprüfung), `sharePresenceProvider`;
  `SupabaseService.requestEmailChange`/`verifyEmailChange`.
- Abmelden leert B's Zwischenspeicher (Standort, Angebotssuchen, Regalpreise, Märkte in der Nähe, Foto-Links).
- Avo: `update_setting` kennt die A8-Schalter und -Uhrzeiten mit Widerrufen, `accent_color` ist weg; „Lösch mein
  Konto“ führt zu einer Zeile „Konto löschen“ statt zu einer Aktion (braucht den Deploy von `ai`).
- Avos Erinnerungen kommen zu den gewählten Uhrzeiten; „Ideen fürs Abendessen“ hat einen eigenen Schalter.

## 2026-11-09: Avo-Antwortkarten für alle Werkzeuge und Foto an Avo (Teil B, B5 W1b)

- Karten nach `docs/redesign/b-screens/avo.md` §5.2–§5.7 für jedes Werkzeug, das der Server heute anbietet:
  Verlauf (aufklappbar, „Alle wieder auf …“), Nachkauf („Vielleicht auch“, Tippen setzt auf die Liste), Kosten
  teilen, Rezepte (höchstens drei, kcal nur mit Modul Kalorien, Allergen-Hinweis), Nährwerte, Wochenplan (nur mit
  Modul; belegter Tag fragt „Dazulegen / Ersetzen“), Angebote nur am Markt der Liste und mit echter Region
  („laut Händler“, „in deiner Region“, „ca.“), Kalorien-Stand mit Ring, Wochen-Balken, Challenges, Ziel-Vorschau,
  Wasser, Gewicht, Training, Einstellungen in der Sprache der Person, Module, Allergie entfernen nur über die
  Sicherheits-Rückfrage. Jede Änderung mit „Widerrufen“, solange die Daten unverändert sind.
- `log_food` speichert nie selbst: Schätzungskarte mit Mahlzeit (Menü), Portionen (Stepper), Nährwerten und
  „Eintragen“.
- Foto an Avo über den Kamera-Knopf der Eingabe: Essen schätzen, Einkaufszettel lesen (abwählbare Zeilen, Ziel-Liste),
  Fehler- und Limit-Zustände, Kamera-Erklärung vor der Systemabfrage, „Kamera ist aus“.
- Aus W1 mitgenommen: Teilergebnis von `plan_to_list` zählt als erledigt, der Platz der Statuszeile verschiebt
  keine Runden mehr, Namen mit Anführungszeichen kommen nicht in die Erneut-Notiz.
- Übergangskarten (`avo_interim_sections.dart`) und die alte Deals-Zusammenfassung entfernt.

## 2026-11-09: Angebots-Screens (Teil B, W4)

Die übrigen Angebots-Screens im D2-Stil (`docs/redesign/b-screens/angebote.md` S9–S16): „Angebote bei {Markt}“
(`/offers/list/:listId`, aus der Ersparnis-Zeile), „Angebote der Woche“ (`/offers`) mit „Deine Listen“, „Oft
gekauft“, Suche nach Markt gruppiert und dem Menü „Auf welche Liste?“, Region als Vollbild (`/stores/region`,
`/settings/offers/region`) statt Postleitzahl-Sheet, „Preise & Angebote“ (`/settings/offers`), Lieblingsmärkte
(`/settings/offers/markets`), der Onboarding-Schritt `OffersSetupStep` mit Inhalt und die Rezept-Zeile mit „Angebote
für {Rezept}“ (`/offers/recipe/:recipeId`). Ohne Region zeigen Liste und Eingabefeld „Postleitzahl festlegen“. Weg
sind `weekly_deals_screen.dart`, `zip_code_sheet.dart`, die alte Rezept-Angebotskarte und ihre Texte.
## 2026-11-09: Essen eintragen komplett, Ziele ohne Slider (Teil B, B6 W3b)
- **„Essen eintragen“** hat jetzt „Foto | Barcode | Suche“. Die Suche findet eigene Lebensmittel sofort und Open Food
  Facts nach einer kurzen Pause; „Manuell eintragen“ für alles andere. „Zuletzt gegessen“: Plus trägt ein, der Text
  öffnet die Menge.
- **Neue Vollbild-Screens:** Foto aufnehmen (eigene Kamera, öffnet mit Überblendung statt von unten), Schätzung prüfen
  (ca.-Werte, Sicherheit in Worten, Bestandteile mit Gramm, Allergie-Hinweis, Foto privat behalten), Barcode mit
  Nachschlagen und Ziffern-Feld, Menge mit Portion und Packung, Manuell mit „Kalorien schätzen lassen“, Eintrag
  bearbeiten (Tippen auf eine Zeile im Tagebuch), Rezept ins Tagebuch, Ziele und Ziel berechnen.
- **Ziele ohne Slider:** Werte mit Feld und Stepper, Tempo „Gemütlich | Normal | Zügig“; „Richtwerte, kein ärztlicher
  Rat.“ auf beiden Screens.
- **Fehler behoben:** Ein hängender Abruf blockiert das Tagebuch nicht mehr (Zeitlimit 20 s); Open Food Facts meldet
  Netzfehler, statt „nichts gefunden“ zu zeigen; kein englisches „Unknown product“ mehr.
- Weg: `goal_setup_screen.dart` (mit `Slider`), `log_recipe.dart`, 16 alte Texte.
- **Nachbesserung:** Das Essensfoto wird jetzt wirklich am Eintrag gespeichert (vorher ging der Pfad verloren, sobald
  der Screen zu war), und mit dem Eintrag gelöscht. Die Nummer unter dem Strichcode lässt sich mit „Suchen“ abschicken
  (der Ziffernblock hat keine Return-Taste). Eigene Lebensmittel halten die Grenzen der Datenbank ein.
- **Zweite Nachbesserung:** „Widerrufen“ nach dem Hochladen löscht auch das Foto, liegengebliebene Foto-Löschungen
  laufen beim Start, Avo löscht das Foto mit. Eine getippte Menge in „Eintrag bearbeiten“ rechnet die Kalorien richtig
  (vorher rundete jede Ziffer weiter). „Als eigenes Lebensmittel merken“ sagt, wenn es nicht geht; bei den Zielen
  erscheint „Bitte mindestens …“ erst beim Verlassen des Feldes.

## 2026-11-08: Avo-Tab im D2-Design (Teil B, B5 W1)

- Neuer Avo-Tab (`lib/presentation/screens/avo/`) nach `docs/redesign/b-screens/avo.md` §1–§6: großer Titel mit
  Avo-Figur, Nutzer-Blase, Avo-Text Wort für Wort, Arbeits-Zeile mit Stopp, eine Ergebniskarte pro Antwort,
  Auswahlkarte „Auf welche Liste?“, Rückfrage-Karte Löschen, Pro- und Modul-Zeile, Kontext-Kapsel, Folge-Chips,
  leerer Chat mit Vorschlägen nach Herkunfts-Screen, alle Fehlerzustände (offline, Limit, Kill-Switch, Anmeldung).
- Antwortkarten für Listen und Artikel mit „Widerrufen“ (hinzufügen, abhaken, ändern, verschieben, anlegen,
  umbenennen); `?prompt=` füllt das Feld nur vor.
- Alte Chat-Dateien unter `screens/ai/` und ihre Texte (`chip_*`, `how_can_i_help` …) entfernt.

## 2026-11-08: Kalorien-Tagebuch im D2-Stil (Teil B, B6 W3)

- **Tagebuch `/calories`** neu: wie viel heute noch geht (Zahl, Ring, Makros), vier Mahlzeiten mit Wischen zum
  Löschen, Kontextmenü und Rückgängig, Wasser mit Menü und Mengen-Dialog, Woche, Links zu Gewicht, Challenges und
  Zielen. Tageswechsel per Wischen oder Datums-Menü. Ohne Ziel der Einstieg „Wie viel willst du am Tag essen?“.
- **„Essen eintragen“ `/calories/add`** als Vollbild statt Bottom-Sheet: Mahlzeit im Titel-Menü, „Zuletzt gegessen“
  mit einem Tipp, Suche im eigenen Verlauf. Foto, Barcode, Menge und Manuell folgen mit den nächsten Paketen.
- **Home:** Karte „Kalorien heute“ und Kachel „Wasser heute“ mit echten Zahlen aus dem Gerätespeicher im ersten Frame.
- **Fehler behoben:** „Heute“ wechselt um Mitternacht und beim Zurückkommen aus dem Hintergrund (vorher schrieb ein
  über Nacht offener Screen in gestern); ein eigener Eintrag, der beim Neuladen noch unterwegs war (etwa offline
  eingetragen, dann zurück im Netz), verschwindet nicht mehr und kommt nicht doppelt; ein Ziel-Ladefehler sieht nicht
  mehr wie „kein Ziel“ aus; nach der Rückkehr ins Netz lädt das Tagebuch selbst.
- Weg: altes Kalorien-Dashboard, die Sheets `food_entry_sheet` und `log_recipe_sheet` (Rezept öffnet jetzt den
  Vollbild-Screen „Ins Tagebuch“), 42 alte Texte.

## 2026-11-08: Angebote an Artikeln und Markt pro Liste (Teil B, W2)

Die Angebots-Slots, die Teil A in Liste, Artikel, Einkaufsmodus und Listen-Übersicht setzt, zeigen jetzt echte
Inhalte im D2-Stil (`docs/redesign/b-screens/angebote.md` S1–S8): Markt-Chip mit Menü, Vollbild „Markt wählen“
(`/stores/pick`), grüne Angebots-Pille, Angebotskarte im Artikel, Vollbild „Angebot“ (`/offers/offer/:offerId`)
statt Bottom-Sheet, Angebote beim Tippen, Ersparnis-Zeile im Pflicht-Wortlaut und „2 Angebote“ auf der Listenkarte.
Ohne echte Region, bei Modul aus, Kill-Switch oder ausgeblendeter Liste erscheint nichts und es geht keine Anfrage
raus. Die Einzel-Schalter und „Diese Woche ausblenden“ liegen vorerst nur auf dem Gerät.

## 2026-11-07: Großes Aufräumen

Ausgangslage: 292 Dart-Dateien, ~86.000 Zeilen, 59 Analyzer-Warnungen, App langsam und fehleranfällig.
Neun parallele Prüfer fanden 300 Probleme, ein zweiter Durchgang verwarf 10 davon als falsch.
Neun Fixer haben die Funde in getrennten Branches behoben, danach wurde alles zusammengeführt.

**Ergebnis:** 259 Dateien, ~64.000 Zeilen, `dart analyze` 0 Fehler / 0 Warnungen (59 Infos statt 541),
168 Tests grün, Simulator-Build grün.

**Schneller**
- Home lädt alle Listen in **einer** Abfrage statt 1+1+N. Realtime ist entprellt und hört nur noch auf das Nötige.
- Abhaken, Bearbeiten und Löschen sind sofort sichtbar (optimistisch). Pushes an Mitglieder blockieren nicht mehr.
- Artikel hinzufügen wartet nicht mehr auf zwei Gemini-Aufrufe, wenn keine Mengenangabe im Text steht.
- Rezepte-Tab lädt die Rezepttabelle einmal statt 3–4× und nicht mehr bei jedem Tastendruck.
- Router-Redirect ohne Netzwerkabfrage. App-Start initialisiert Dienste parallel.
- Keine nativen Glas-Views mehr in Scroll-Listen. Offscreen-Tabs werden nicht mehr gezeichnet.
- Eine dauerhaft laufende Animation an der App-Wurzel entfernt.

**Bugs (Auswahl von ~100)**
- Snackbars (Fehler- und Erfolgsmeldungen) warfen auf iOS eine Exception, weil der `ScaffoldMessenger` fehlte.
- Siri-/Deep-Links beim Kaltstart wurden doppelt ausgeführt, also Artikel doppelt hinzugefügt.
- Öffnen einer Liste löschte alle geplanten Erinnerungen.
- Abo-Bildschirm drehte nach abgebrochenem Kauf endlos.
- Deutsche Kommazahlen ("1,5") wurden in Kalorien-Feldern verworfen.
- Rezept bearbeiten löschte die Beschreibung, Zutaten wurden beim Hinzufügen doppelt skaliert.
- Diät-Warnungen griffen nie. Eine fehlerhafte DB-Zeile leerte den ganzen Rezept-Feed.
- Account-Daten (Listen, gespeicherte Rezepte, Cache) blieben nach dem Abmelden für den nächsten Nutzer sichtbar.
- Avo-Chat behielt den Verlauf über Account-Wechsel, Avo-Benachrichtigungen waren immer englisch.

**Aufgeräumt**
- ~10.000 Zeilen toter Code gelöscht (alte Screens, `*_old.dart`, Tutorial-Ketten, Achievements, KI-Labeling,
  ungenutzte Widgets und Provider), außerdem ~29 MB ungenutzte Assets und 13 ungenutzte Pakete.
- Riesendateien aufgeteilt: `list_detail_screen.dart` 3.457 → ~770 Zeilen, `recipes_screen.dart` 1.566 → ~450,
  Avo-Service in Prompt, Tool-Deklarationen und Modelle zerlegt.
- `print` → `debugPrint`, harte deutsche Texte in Übersetzungen verschoben, `scripts/` (zeigte auf alten Checkout)
  entfernt, `linux/` und `windows/` entfernt.
- CI: neue Prüfung bei jedem Push (`check.yml`), TestFlight-Workflow auf API-Key-Signierung umgebaut.
- Doku neu: README, `docs/ARCHITECTURE.md`, `docs/OPEN-ISSUES.md`, `docs/DESIGN-STATUS.md`. Die veraltete
  `FEATURE_IMPLEMENTATION_STATUS.md` (6.584 Zeilen) liegt in `docs/archive/`.

Offen: siehe [OPEN-ISSUES.md](OPEN-ISSUES.md).
