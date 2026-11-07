# 00 Grundlagen der Designsprache "Vorinstalliert"

> **Gilt nur noch inhaltlich (Stand 07.11.2026, 22 Uhr):** Das Aussehen der App kommt aus dem D2-Glas-Artifact, siehe [`../design-quelle.md`](../design-quelle.md). Hex-Werte, Tokens, Tab-Struktur, Avo-Kreis und Komponentenaussehen in dieser Datei sind überholt. Funktionen, Abläufe, Zustände, Barrierefreiheits- und Textregeln gelten weiter.

Stand: 07.11.2026. Verbindlich für Teil A (Owner, Mac 1) und Teil B (Jannis, Mac 2). Arbeitsname der App: **Avo** (austauschbar, siehe 3.1).

Grundlage: Gewinner-Richtung `richtungen/1-system.md` (Jury 254 Punkte), ergänzt um die Übernahmen der Jury aus den Richtungen 2 bis 5 und um die Jury-Warnungen. Bei Widersprüchen gilt Jannis' Plan (`docs/Shoply-Ideen-und-Plan.md`). Die Recherche (`docs/research/Preise Angebote und Artikelbilder.md`) setzt die Grenzen für Angebote, Preise und Bilder.

Markierungen:
- **K-xx** = Konzept-Entscheidung dieses Dokuments. Alle stehen gesammelt in Kapitel 18.
- **Teil A / Teil B** = wer baut, laut `arbeitsteilung.md`.
- Werte in pt sind logische Punkte bei Textgröße "Standard (L)", sofern nicht anders angegeben.

Inhalt: 1 Name und Absicht · 2 Prinzipien · 3 Marke · 4 Farbe · 5 Typografie · 6 Raster und Abstände · 7 Form · 8 Material und Tiefe · 9 Ikonografie und Bilder · 10 Bewegung · 11 Haptik · 12 Komponenten · 13 Zustände · 14 Barrierefreiheit · 15 Module · 16 Pro · 17 Umsetzung in Flutter · 18 Entscheidungen und offene Fragen

---

## 1. Name, Absicht, Ziele

### 1.1 Name und ein Satz

**Vorinstalliert.** Avo sieht aus und verhält sich, als wäre es mit iOS 27 auf das iPhone gekommen: Inhalte liegen auf festen Systemflächen, Liquid Glass gibt es nur in der schwebenden Bedienebene, ein tiefes Avocado-Grün ist die einzige Handlungsfarbe, und die Marke zeigt sich in wenigen, sorgfältig gebauten Momenten.

### 1.2 Absicht und Warum

- **Vertrauen verkauft Pro.** Eine App, die sich anfühlt wie ein Teil des iPhones, wirkt seriös. Das senkt die Hürde für ein Abo und hilft im App Store.
- **Robust auf jedem iPhone.** Systemflächen, Systemschrift und Systemmuster bringen Dynamic Type, Kontrast und VoiceOver fast mit. Der abgeschnittene Text in der Eingabeleiste (iPhone 13 Pro mit Anzeigezoom) wird durch die Regel "keine festen Höhen um Text" grundsätzlich gelöst, nicht nur an einer Stelle.
- **Zwei Leute bauen parallel.** Ein kleines Token-Set, eine Akzentfarbe und eine fertige Komponenten-Bibliothek verhindern, dass die Gestaltung zwischen Mac 1 und Mac 2 auseinanderläuft.
- **Altert gut.** Neue iOS-Versionen verändern Glas und Systemflächen; die App zieht mit.
- **Schnell.** Gruppierte Zeilen ohne Schatten und ohne Transparenz sind billig zu rendern. Glas sitzt nur dort, wo es wenig kostet.

Gegen die Hauptgefahr der Richtung, die Verwechselbarkeit mit Apples Erinnerungen, stehen vier Markenträger, die beim Kürzen **nicht** als Erstes wegfallen dürfen: das Akzentgrün, die eigenen Artikel-Symbole ("Avo Symbols"), der Avo-Kern und sorgfältig gebaute Momente (rollende Ziffern, Erfolgsmoment, Zoom-Übergang bei Rezepten, Essensfotos).

Übernommen aus den anderen Richtungen (Jury):
- aus "Ruhig und klar": rollende tabellarische Ziffern, Avo-Ergebnisse als Ergebniszeile wie eine Wallet-Transaktion, Nährwertzeile wie in Health, leere Zustände mit einem warmen Satz, Grün nur über semantische Tokens, Kochmodus immer schwarz, Rückgängig-Leiste im Einkaufsmodus, haftende Gang-Titel mit Anzahl, abschaltbare Artikelbilder.
- aus "Glas und Tiefe": Avo-Kreis wird bei ausgeschaltetem Modul zur Suche, Glas-Morph beim Start des Einkaufsmodus, "+"-Knopf im Laden, Paywall wächst aus dem gesperrten Element, Pro-Hinweise höchstens einmal pro Woche.
- aus "Frisch": Zoom-Übergang von Rezeptkarte zu Detail, `photo_color` als Platzhalter, Typo-Karte statt schlechter Fotos, Rezepte-Tab aus unterschiedlich geformten Abschnitten, Kalorien mit einer großen Zahl und einer Datenreihe, Foto-Kopf in der Paywall.
- aus "Avo als Begleiter": Verantwortungsregeln für Avo, Tab-Bar und Avo-Kreis als eine native Glasgruppe, Maße im Einkaufsmodus, echte Vorschau statt Schloss-Bildschirm.

### 1.3 Ziele (prüfbar)

| Ziel | Woran gemessen |
|---|---|
| Kein abgeschnittener oder überlappender Text | Prüfmatrix aus 14.3 ohne Befund: 320, 375, 390, 402, 440 pt; Textgröße L, xxxL, AX3, AX5; fetter Text an/aus; hell/dunkel |
| Nie sichtbares Laden | Startseite, Liste, Rezepte, Kalorien zeigen beim zweiten Öffnen keinen Ladezustand; kein Vollbild-Spinner in der ganzen App |
| Flüssig | Auf iPhone 13 Pro im Profile-Modus: Ziel 8,3 ms pro Frame (120 Hz), nie über 16 ms beim Scrollen, Abhaken, Hinzufügen, Tab-Wechsel |
| Eine Gestaltung | `grep` auf hart codierte Farben, Schriftgrößen, Dauern, Material-Icons und Snackbars in `lib/presentation` ergibt 0 Treffer (Regeln in 17.6) |
| Schneller Einstieg | Neuer Nutzer ist in unter 60 s vom ersten Start bis zur eigenen Liste |
| Tägliche Nutzung | Die Startseite beantwortet jeden Tag eine Frage (Liste von heute, plus Wochenplan, Kalorien, Nachkauf), ohne Banner |
| Pro-fähig | Jedes Feature lässt sich ohne Neugestaltung als Pro kennzeichnen (Kapitel 16) |

### 1.4 Nicht-Ziele

- Eine eigene Bildwelt für die Oberfläche (Illustrationsstil, Verläufe, Texturen). Farbe und Bild kommen aus Inhalten: Rezeptfotos, Produktfotos, Listenfarben.
- Ein eigenes Android-Design. Android läuft mit Fallbacks (Kapitel 17), wird aber jetzt nicht gestaltet.
- iPad- und Querformat-Layouts. Die App bleibt auf dem iPhone im Hochformat.
- Live Activity und Dynamic Island (verworfen, Plan 5).
- Jeder Marktvergleich, Korbsummen pro Markt, Hinweise "bei X wäre es Y € günstiger" (verworfen, Plan 8).
- Freie Gestaltung durch Nutzer (Akzentfarbe wählen, Listen-Hintergründe aus Bildern), siehe K-06 und K-07.

### 1.5 Anti-Ziele (aktiv vermeiden)

- Paper-Reste: kleine Großbuchstaben-Zeilen über Überschriften, Serifen, Creme und Terrakotta, `toUpperCase()` für Anzeige.
- Icons in getönten Quadraten oder Kreisen, Reihen identischer Karten, Kachel-Wände.
- Banner und Karten-Stapel auf der Startseite, Werbung für Avo in anderen Screens.
- Erfundene oder geschönte Zahlen, Prozent-Rabatte ohne Händlerangabe, "#1"-Aussagen.
- Regenbogen-Diagramme. Ein Diagramm beantwortet eine Frage mit einer Datenreihe.
- Glas auf Inhalten, Glas auf Glas, Unschärfe-Filter in scrollenden Listen.
- Vollbild-Spinner, schimmernde Skelette, Layout-Sprünge durch nachladende Inhalte.
- Bestätigungsdialoge für Umkehrbares. Rückgängig statt Rückfrage.
- Haptik bei jedem Tippen, beim Tab-Wechsel oder beim Zurück.
- Das Maskottchen in Arbeits-Screens (Listen, Einkaufsmodus, Rezeptdetail, Paywall, Fehler).
- Druck auf der Paywall: Countdown, durchgestrichene Fantasiepreise, verzögert erscheinendes Schließen.
- Emojis, Ausrufezeichen-Jubel und Werbesprache in Systemtexten und Mitteilungen.
- Blassgrauer Fließtext. Fließtext steht immer in voller Textfarbe.

---

## 2. Prinzipien

1. **Inhalt unten, Bedienung schwebt.** Listen, Rezepte und Zahlen liegen auf festen Flächen. Was man bedient (Tabs, Zurück, Teilen, Hinzufügen), schwebt als Glas darüber. *Beispiel:* Die Liste "Wocheneinkauf" scrollt unter der gläsernen Tab-Bar und dem Feld "Artikel hinzufügen" durch; die Artikelzeilen selbst sind weiß bzw. dunkelgrau und nie aus Glas.
2. **Systemmuster vor Eigenbau.** Große Titel, gruppierte Sektionen, Wischaktionen, Kontextmenüs, Sheets mit Teilhöhe. Ein eigenes Muster nur, wenn es nachweisbar besser ist. *Beispiel:* Das Hinzufügen-Feld folgt dem Mini-Player aus Musik; der Einkaufsmodus ist ein bewusstes Eigenmuster, weil man im Laden mit einer Hand im Gehen tippt.
3. **Grün heißt: hier passiert etwas.** Die Akzentfarbe steht auf antippbaren Dingen, auf dem erledigten Häkchen und auf Gesundheits- und Spar-Diagrammen, sonst nirgends. *Beispiel:* Ein leerer Abhak-Kreis ist grau; erst beim Abhaken füllt er sich grün. Die Fortschrittslinie im Einkaufsmodus ist schwarz bzw. weiß, nicht grün.
4. **Fließt mit jeder Schrift und jeder Breite.** Kein Text in einer festen Höhe. Wird es eng, bricht Inhalt um oder stapelt sich, statt abgeschnitten zu werden. *Beispiel:* Bei AX3 rutscht die Menge "2" unter den Artikelnamen, das Feld "Artikel hinzufügen" wird höher, die Tab-Beschriftungen weichen dem Large Content Viewer.
5. **Sofort da.** Alles erscheint aus dem lokalen Stand; Änderungen gelten sofort und gleichen sich im Hintergrund ab. *Beispiel:* "2 Milch" steht nach dem Drücken auf Return sofort als "Milch, Menge 2" in "Milch & Käse"; die KI bestätigt die Kategorie später, ohne dass die Zeile springt.
6. **Rückgängig statt Rückfrage.** Umkehrbare Aktionen passieren sofort und lassen sich widerrufen; ein Dialog kommt nur bei endgültigem Löschen. *Beispiel:* Artikel wegwischen löscht sofort, unten erscheint "Milch gelöscht · Widerrufen". "Liste löschen" fragt nach, weil es für alle Mitglieder endgültig ist.
7. **Marke in Momenten, Ehrlichkeit immer.** Das Maskottchen erscheint bei Begrüßung, leeren Zuständen und Erfolgen. Jede Zahl ist belegt. *Beispiel:* Nach dem Einkauf feiert Avo kurz: "Einkauf gespeichert. Ca. 3,20 € durch Angebote gespart, laut Händler." Bei einer Allergie-Warnung erscheint weder Figur noch Witz.

---

## 3. Marke

### 3.1 Umgang mit dem Namen

- **Arbeitsname:** Die App heißt im Konzept "Avo", der Assistent ebenfalls "Avo". Der Name ist nicht final (Owner-Frage F-01).
- **Austauschbar halten:** Es gibt genau eine Quelle für Markennamen: `AppBrand` in `lib/core/constants/app_brand.dart` (Teil A) mit `appName` ("Avo"), `proName` ("Avo Pro") und `assistantName` ("Avo"). Übersetzungen enthalten keine Markennamen, sondern Platzhalter `{app}`, `{pro}`, `{assistant}`.
- **Siri und Kurzbefehle** nutzen `.applicationName` (heute schon so), damit ein Namenswechsel automatisch greift.
- **Abo-Name:** immer `{pro}`, nie "Premium", nie "Shoply Premium". Die Kapsel in der App heißt nur "Pro".
- **Technische Kennungen bleiben unverändert:** Bundle-ID `com.dominik.shoply`, App Group `group.com.shoply.app`, URL-Schema `shoply://`, Domains `shoplyai.app` und `joinavo.app`, Produkt-IDs `shoply_premium_monthly` und `shoply_premium_yearly`, Supabase-Tabellen, Firebase-Projekt. Bestehende geteilte Links müssen weiter öffnen.
- **Avo-Wissen und System-Prompt** (Teil B) beziehen Name, Preise (aus StoreKit, in Euro) und Pro-Umfang aus derselben Konfiguration wie die Paywall. Kein Text nennt "Shoply" oder Dollarpreise.

### 3.2 Tonalität

Grundton: per Du, knapp, freundlich, konkret, ehrlich. Wir beschreiben, was passiert ist oder was man tun kann. Keine Werbesprache, keine Emojis, keine Ausrufezeichen in Systemtexten.

| Situation | Nicht so | Sondern so |
|---|---|---|
| Einkauf abgeschlossen | "(Häkchen-Emoji) 11 Artikel erfolgreich abgeschlossen!" | "Einkauf gespeichert." |
| Liste leer | "Leere Liste. Füge Produkte hinzu, um mit dem Einkaufen zu beginnen" | "Alles erledigt. Schön." (wenn vorher Artikel da waren) bzw. "Noch nichts auf der Liste." |
| Offline | "Fehler beim Laden" | "Offline. Deine Änderungen werden gespeichert, sobald du wieder online bist." |
| Fehler beim Speichern | "Fehler: PostgrestException (…)" | "Das hat nicht geklappt. Erneut versuchen?" |
| Angebot am Artikel | "Spare 0,80 € bei Lidl" | "0,99 € bei Lidl, laut Händler statt 1,79 €" |
| Ersparnis-Zeile | "€ 23,40 günstigster Korb bei Lidl" | "4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region" |
| Ohne echte PLZ | "Spare bis zu 4 €" | keine Ersparnis-Zahl; Zeile "Für Angebote in deiner Region: Postleitzahl festlegen" |
| Allergie | "Achtung!!! Gefahr" | "Enthält Erdnuss. Du hast eine Erdnussallergie eingetragen." |
| Avo nach Aktion | "Super, erledigt! (Konfetti-Emoji)" | "3 Artikel zu Wocheneinkauf hinzugefügt." |
| Nachkauf-Vorschlag | "Wahrscheinlich fast leer!" | "Milch, kaufst du etwa alle 6 Tage" |
| Mitteilung geteilte Liste | "(Avocado-Emoji) Lena checked off „Milch“" | "Lena hat Milch abgehakt." (gebündelt, siehe Kapitel 19) |
| Paywall-Fußnote | "Jetzt zuschlagen!" | "Danach 29,99 € pro Jahr. Jederzeit in den Einstellungen kündbar." |

**Begriffe (verbindlich):** Artikel (nicht Produkt), Liste, Einkauf (ein abgeschlossener Einkauf), Markt (nicht Laden), Kategorie (Anzeige) und "Reihenfolge im Markt" (Einstellung), Mitteilungen (nicht Benachrichtigungen), Pro (nicht Premium), Angebot, "laut Händler", "in deiner Region", Wochenplan, Tagebuch (Kalorien), Mitglieder.

**Format:**
- Zahlen und Währung über `intl` mit Locale: "3,20 €" mit geschütztem Leerzeichen, "1.840 kcal", "0,5 l". Nie fest `'{price} €'` oder `'$2.99'`.
- Einzahl/Mehrzahl über ein Plural-System (ICU-Plural in den Übersetzungen), nicht über Extra-Schlüssel oder "(s)".
- Datum: "Sa., 7. Nov.", "Heute", "Gestern", relative Zeit nur bis 7 Tage.
- Keine harten Zeilenumbrüche `\n` in Überschriften. Umbruch macht das Layout.
- Avo spricht nur im Chat und im Sprachmodus in der ersten Person. Die übrige Oberfläche beschreibt Funktionen ohne Figur: "Zettel importieren" statt "Avo liest deine Liste".

### 3.3 Maskottchen

Das heutige 3D-Avo (4 PNGs, ca. 450 px) wird neu gezeichnet: flach, zwei Tonstufen statt Plastik-Glanz, gleiche Proportionen (Avocado-Hälfte mit Kern, kurze Ärmchen, Gesicht). Format: Vektor (PDF bzw. SVG, oder Rive für die einmalige Bewegung), damit es in jeder Größe scharf ist.

| Pose | Wann | Wo | Größe |
|---|---|---|---|
| winkend | Begrüßung | Willkommen im Onboarding | 160 pt |
| zufrieden | Leerer Zustand nach Erledigung, leere Bereiche | "Alles erledigt. Schön.", leerer Verlauf, keine gespeicherten Rezepte | 96 pt (in Sheets 64 pt) |
| feiernd | Erfolgsmoment | Einkauf gespeichert, Wochenplan auf der Liste, Challenge geschafft, Pro gekauft | 120 pt, 1,5 s |
| suchend | Nichts gefunden | leere Suche, keine Rezepte in der Kategorie | 96 pt |

Regeln:
- **Nie** in Tab-Bar, Toolbars, Listenzeilen, Einkaufsmodus, Rezeptdetail, Paywall, Avo-Antworten, Widgets, Mitteilungs-Bildern.
- **Nie** bei Allergie-Hinweisen, Geld (Ersparnis, Kosten teilen, Kauf), Fehlern, Offline und Löschen.
- Kleiner als 64 pt wird nicht gezeigt (wird zum grünen Fleck).
- Bewegung: höchstens eine einmalige Bewegung bis 1 s beim Erscheinen (winken, kurzer Sprung). Keine Schleifen, kein Blinzeln. Reduce Motion: statisch, nur Einblenden.
- Ab Textgröße AX1 entfällt das Maskottchen in leeren Zuständen; Text und Aktion bleiben.
- VoiceOver: dekorativ, ausgeblendet. Die Aussage steht im Text daneben.
- Teil A liefert die Assets in `assets/avo/` (A-Ordner laut `owner.sh`).

### 3.4 Der Avo-Kern

Der Assistent hat kein Gesicht. Er erscheint als **Kern**: eine Kugel in Kern-Braun mit einem Ring in Fruchtfleisch-Grün. Er ist das wiedererkennbare Zeichen des Assistenten und seine einzige Ladeanzeige.

- **Farben:** Kern `avoKern` (#7A4A24 hell, #8A5A30 dunkel), Ring `avoRing` (#C9DE6E in beiden Modi).
- **Als Symbol** (im Avo-Kreis der Tab-Bar, 22 pt): als Vorlage-Symbol auf dem SF-Symbols-Raster gezeichnet (Ring als Kontur, Kern gefüllt), damit es sich in getönten Darstellungen und im erhöhten Kontrast wie ein Systemsymbol verhält. Name `avo.core`, drei Gewichte.
- **Zustände** (Enum `AvoCoreState`, auch über den nativen Kanal an die Tab-Bar):

| Zustand | Bild | Wann |
|---|---|---|
| `ruhig` | steht still | Standard |
| `hoertZu` | Ring folgt der Mikrofon-Lautstärke, Skalierung bis 8 % | Sprachmodus hört |
| `denkt` | Ring "atmet" langsam (Helligkeit 70 bis 100 %, Feder, keine Größenänderung) | Avo arbeitet; ersetzt jeden Spinner bei Avo |
| `spricht` | Ring folgt der Lautstärke der Sprachausgabe | Avo antwortet mit Stimme |
| `neutral` | statisch, Ring in `labelSecondary` statt Grün | Allergie, Geld, Fehler, Löschen-Rückfrage |

- Reduce Motion: keine Größenänderung, Lautstärke nur über Helligkeit; `denkt` ohne Atmen, stattdessen drei Punkte in `labelSecondary`.
- Antippen des Kerns im Sprachmodus unterbricht Avos Sprachausgabe sofort.

### 3.5 App-Icon "Die Hälfte"

Eine aufgeschnittene Avocado-Hälfte von vorn, mittig, ohne Gesicht und ohne Zettel. Der Kern sitzt etwas unterhalb der Mitte, rund und satt wie ein erledigter Abhak-Kreis. Das Maskottchen steckt nicht im Icon.

Aufbau in der Icon-Composer-App (Xcode 26) in drei Ebenen: Hintergrund, Fruchtfleisch mit Schale, Kern. Daraus rendert iOS 26+ Glas, Spiegelungen und alle Erscheinungen. Für iOS 18 bis 25 zusätzlich das Asset-Katalog-Icon mit drei Varianten (Standard, Dunkel, Getönt) als 1024er PNG.

| Erscheinung | Gestaltung |
|---|---|
| Hell (Standard) | Hintergrund Verlauf #F3F6DF nach #E3ECB8; Schale als Rand #3F7A1F; Fruchtfleisch #D8E77E nach #C3D867 zur Schale hin; Kern #7A4A24 mit weichem Glanz oben links |
| Dunkel | Hintergrund #0E1508 nach #16210D; Schale #5E8F2E; Fruchtfleisch #A9C459; Kern #8A5A30, der Kern bleibt das hellste Glanzlicht |
| Klar hell / klar dunkel (iOS 26) | alle Ebenen werden Glas; die Form liest sich über die Kantenlichter der Schale und den dichteren Kern; Hintergrund transparent |
| Getönt | Ebenen werden Helligkeit: Hintergrund dunkel, Fruchtfleisch mittel, Kern hell. Die Hälfte mit Kern bleibt in jeder Tönung erkennbar |

Prüfen in allen Größen: Home-Bildschirm (60 pt), Spotlight (40 pt), Einstellungen (29 pt), Mitteilungen (20 pt), App Store (1024 px). Bei 20 pt muss der Kern als Punkt erkennbar bleiben; feine Schalen-Details dürfen dort verschwinden. Das Widget-Extension-Icon-Set (heute leer) bekommt dasselbe Icon. Der Startbildschirm (`LaunchScreen.storyboard`) zeigt nur `systemBackground`, ohne Bild, damit kein Farbsprung zum ersten Frame entsteht (erster Frame = `bgGrouped` in Systemfarbe, siehe Kapitel 13).

---

## 4. Farbe

Grundlage sind die iOS-Systemfarben (gruppierte Hintergründe, Label-Stufen). Neu ist nur der Akzent. Alle Werte sind adaptiv (hell, dunkel, jeweils mit erhöhtem Kontrast). Kontraste nach WCAG 2.1, gemessen auf der jeweils genannten Fläche.

### 4.1 Flächen und Text

| Token | Hell | Dunkel | Verwendung |
|---|---|---|---|
| `bgGrouped` | #F2F2F7 | #000000 | Hintergrund jedes Screens mit Sektionen |
| `bgPlain` | #FFFFFF | #000000 | Hintergrund randloser Listen (Einkaufsmodus, AX-Größen) |
| `bgGroupedElevated` | #F2F2F7 | #1C1C1E | Hintergrund in Sheets |
| `surface` | #FFFFFF | #1C1C1E | Sektionen, Zeilen, Karten |
| `surfaceElevated` | #FFFFFF | #2C2C2E | Zeilen in Sheets |
| `fill` | #E9E9EE | #2C2C2E | Eingabefelder im Inhalt, Chips, Stepper, Nutzer-Blase, Markt-Chip |
| `fillPressed` | #DCDCE1 | #3A3A3C | gedrückter Zustand von Zeilen und Chips |
| `separator` | #C6C6C8 | #38383A | Trennlinie zwischen Zeilen einer Sektion, ab der Textkante eingerückt |
| `controlOutline` | #8A8A8E | #7C7C80 | leerer Abhak-Kreis, Rahmen von Steuerelementen (Nicht-Text-Kontrast 3,44:1 bzw. 4,09:1) |
| `label` | #000000 | #FFFFFF | aller Text inklusive Fließtext und Rezeptschritte |
| `labelSecondary` | #636366 | #98989F | nur Metadaten: Menge-Einheit, "von Lena", Uhrzeit, Quellen, Platzhalter |
| `labelTertiary` | #AEAEB2 | #636366 | nur deaktivierte Elemente und dekorative Zeichen, nie für Information |
| `labelOnPhoto` | #FFFFFF | #FFFFFF | Text auf Fotos, nur über Verlauf (siehe 9.6) |
| `scrim` | #000000 mit 20 % | #000000 mit 48 % | Abdunkeln hinter großen Sheets und Dialogen |

Kontraste Text:

| Paar | Hell | Dunkel |
|---|---|---|
| `labelSecondary` auf `surface` | 5,99:1 | 5,94:1 |
| `labelSecondary` auf `bgGrouped` | 5,37:1 | 7,33:1 |
| `labelSecondary` auf `fill` / `surfaceElevated` | 4,95:1 | 4,86:1 |
| `label` auf `fill` | 17,35:1 | über 14:1 |

Regel: Auf `fillPressed` dunkel (#3A3A3C) steht kein `labelSecondary` (nur 3,96:1); dort `label` verwenden.

### 4.2 Akzent und Status

| Token | Hell | Dunkel | Verwendung, Kontrast |
|---|---|---|---|
| `action` | #3F7A1F | #A6D45F | Akzent "Avocado". Antippbares (Text-Buttons, Symbole in Buttons, Links), gefüllte Hauptaktion, erledigtes Häkchen. 5,23:1 auf Weiß, 4,69:1 auf `bgGrouped`; dunkel 9,89:1 auf #1C1C1E |
| `onAction` | #FFFFFF | #0E1A06 | Text und Symbole auf gefülltem `action`. 5,23:1 bzw. 10,44:1 |
| `actionFill` | #EEF5E4 | #25301A | Hinterlegung: gewählter Chip, Pro-Kapsel, hervorgehobene Paywall-Zeile. `action` darauf 4,69:1 bzw. 8,05:1 |
| `success` | = `action` | = `action` | erfolgreich erledigt. Bewusst identisch, ein zweites Grün würde konkurrieren |
| `health` | = `action` | = `action` | Kalorienring, Gesundheitsdiagramme |
| `money` | = `label` | = `label` | Ersparnis-Text steht in voller Textfarbe mit `tag`-Symbol; Geld-Diagramme nutzen `action` |
| `presence` | = `action` | = `action` | Punkt "kauft gerade ein" |
| `warning` | #A85400 | #FF9F0A | Allergie, fehlende PLZ, über Kalorienziel. 5,34:1 bzw. 8,28:1 |
| `danger` | #D70015 | #FF453A | Löschen, Fehler. 5,38:1 bzw. 4,99:1 |
| `dealTag` | #FFD60A | #FFD60A | Füllung des gelben Preisschilds, nie Textfarbe |
| `onDealTag` | #1C1C1E | #1C1C1E | Preis auf dem Schild, 12,05:1 |
| `dealTagStroke` | #000000 mit 14 %, 0,5 pt | keine | Kante des Schilds auf Weiß (Gelb allein hat 1,41:1 zu Weiß) |
| `avoKern` | #7A4A24 | #8A5A30 | siehe 3.4 |
| `avoRing` | #C9DE6E | #C9DE6E | siehe 3.4 |

**Akzent-Regeln (verbindlich, K-09):**
- Code spricht Grün nur über die semantischen Tokens `action`, `success`, `health` an. Es gibt kein freies `green`, kein `Color(0xFF3F7A1F)` außerhalb von `app_colors.dart`.
- Höchstens **eine gefüllte Akzent-Kapsel pro Bildschirm** (die Hauptaktion). Weitere Aktionen sind Glas, grau (`fill`) oder schlicht (Text in `action`).
- Leere Abhak-Kreise sind `controlOutline`. Grün wird ein Häkchen erst im Moment des Abhakens.
- Fortschrittslinien und -zahlen (z. B. "5 von 11") stehen in `label`, nicht in Grün. Ausnahme: Kalorienring und Wasser (`health`).
- Statusfarbe nie allein: Abgehakt = gefüllter Kreis plus Häkchen plus durchgestrichener Text; Angebot = Schild mit Preis; Fehler = Symbol plus Text; Warnung = Symbol plus Text.
- Ein Bildschirm zeigt höchstens drei Farbtöne außer Graustufen gleichzeitig (Akzent, Listenfarbe, Gelb). Inhalte (Fotos) zählen nicht.

### 4.3 Listenfarben (K-08)

Jede Liste hat eine Farbe und ein SF Symbol, wie in Erinnerungen. Die Farbe färbt **nur** den runden Listen-Glyph (Kreis mit weißem Symbol) im Titelmenü und in "Alle Listen" sowie den Titel im Listen-Widget. Häkchen bleiben in allen Listen `action`, damit "erledigt" überall gleich aussieht.

Die Palette sind die iOS-Systemfarben. "Avocado" ist **keine** Listenfarbe, weil sie mit dem Akzent verwechselt würde.

| Name | Hell | Dunkel | Erhöhter Kontrast hell | Erhöhter Kontrast dunkel |
|---|---|---|---|---|
| Blau | #007AFF | #0A84FF | #0040DD | #409CFF |
| Rot | #FF3B30 | #FF453A | #D70015 | #FF6961 |
| Orange | #FF9500 | #FF9F0A | #C93400 | #FFB340 |
| Gelb | #FFCC00 | #FFD60A | #B25000 | #FFD426 |
| Grün | #34C759 | #30D158 | #248A3D | #30DB5B |
| Minze | #00C7BE | #63E6E2 | #0C817B | #66D4CF |
| Indigo | #5856D6 | #5E5CE6 | #3634A3 | #7D7AFF |
| Lila | #AF52DE | #BF5AF2 | #8944AB | #DA8FFF |
| Rosa | #FF2D55 | #FF375F | #D30F45 | #FF6482 |
| Braun | #A2845E | #AC8E68 | #7F6545 | #B59469 |
| Graphit | #8E8E93 | #98989D | #6C6C70 | #AEAEB2 |

- Neue Listen bekommen die nächste noch nicht benutzte Farbe in der Reihenfolge der Tabelle.
- Der Glyph ist dekorativ (VoiceOver ignoriert ihn; der Listenname trägt die Bedeutung). Deshalb gilt für das weiße Symbol auf hellen Farben (Gelb, Minze) keine 3:1-Pflicht; im erhöhten Kontrast werden die dunkleren Varianten verwendet.
- Symbole zur Auswahl (20 Stück): `cart`, `basket`, `bag`, `house`, `building.2`, `person.2`, `fork.knife`, `carrot`, `leaf`, `birthday.cake`, `gift`, `party.popper`, `pawprint`, `cross.case`, `drop`, `flame`, `sun.max`, `moon`, `star`, `heart`.
- Die heutigen Listen-Hintergründe (`background_type`, `background_value`, `background_image_url`) werden nicht mehr angezeigt (K-07). Die Daten in Supabase bleiben unverändert; eine Migration ordnet bestehenden Listen eine Listenfarbe zu (Verlauf: Grundfarbe des Verlaufs, Bild: Blau).

### 4.4 Angebots- und Ersparnisfarbe

- Das **gelbe Preisschild** (`dealTag` mit `onDealTag`) kennt jeder aus deutschen Supermärkten. Es ist das einzige Gelb der Oberfläche und erscheint nur mit dem Modul Angebote.
- Gelb ist nie Textfarbe, nie Flächenfarbe von Karten, nie Hintergrund von Zeilen.
- Die Ersparnis-Zeile ("4 von 11 Artikeln …") steht in `label` mit `tag`-Symbol in `labelSecondary`. Nicht grün, nicht gelb.
- Ist das Modul aus oder der Kill-Switch aktiv, verschwindet Gelb vollständig aus der App, ohne reservierten Platz.

### 4.5 Erhöhter Kontrast

| Token | Hell | Dunkel |
|---|---|---|
| `action` | #2E5C14 (7,90:1 auf Weiß) | #C4E88A (12,36:1 auf #1C1C1E) |
| `onAction` | #FFFFFF | #0E1A06 |
| `actionFill` | #EEF5E4 (`action` darauf 7,08:1) | #25301A (10,06:1) |
| `labelSecondary` | #3C3C43 (10,94:1) | #C7C7CC (10,10:1) |
| `controlOutline` | #6C6C70 | #AEAEB2 |
| `separator` | #8A8A8E | #8D8D93 |
| `warning` | #8A4500 (7,16:1) | #FFB340 (9,54:1) |
| `danger` | #B00012 (7,36:1) | #FF6961 (6,03:1) |
| `dealTagStroke` | #1C1C1E, 1 pt | #1C1C1E, 1 pt |
| Glas | bekommt eine sichtbare 1-pt-Kontur in `separator` | ebenso |

Umschaltung über `MediaQuery.highContrastOf(context)` (iOS "Kontrast erhöhen").

### 4.6 Reduzierte Transparenz und Sonderflächen

| Token | Hell | Dunkel | Verwendung |
|---|---|---|---|
| `glassFallback` | #F9F9F9 plus 0,5 pt `separator` | #1C1C1E plus 0,5 pt `separator` | ersetzt Glas bei "Transparenz reduzieren" und auf Android (Kapitel 8) |
| `cookingBg` | #000000 | #000000 | Kochmodus, immer schwarz (K-25) |
| `cookingLabel` / `cookingSecondary` | #FFFFFF / #98989F | gleich | Text im Kochmodus |

### 4.7 Diagramme

- Eine Frage, eine Datenreihe. Die Reihe steht in `health` (Kalorien, Wasser, Gewicht-Ziel), in `action` (Ersparnis pro Monat) oder sonst in `label`.
- Vergleichswerte (Vorwoche, Vormonat) in `fill`. Zielmarke als gestrichelte Linie in `labelSecondary`.
- Nie mehrere Farben nebeneinander. Makros (Protein, Kohlenhydrate, Fett) sind drei getrennte Zeilen mit je einem Balken in derselben Farbe, kein dreifarbiger Stapel.

### 4.8 Markenfarben der Märkte

Echte Supermarkt-Logos nur mit schriftlicher Erlaubnis. Bis dahin ist der Markt-Chip eine Kapsel mit einem 8-pt-Punkt in der Markenfarbe und dem Namen in Systemschrift. Die Markenfarben sind **Daten, keine Design-Tokens**: Sie stehen im Ketten-Verzeichnis von Teil B (zusammen mit Aliasen und Handelsmarken), nicht in `AppColors`. Startwerte: Lidl #0050AA, REWE #CC071E, Aldi Süd #00005F, Aldi Nord #00549F, Edeka #FFD400, Kaufland #E10915, Netto #FFE500, PENNY #CD1414. Helle Punkte (Edeka, Netto) bekommen eine 0,5-pt-Kontur in `separator`.

---

## 5. Typografie

### 5.1 Schriften

- **SF Pro** ist die einzige Schrift. Unter 20 pt (nach Skalierung) die Textvariante, ab 20 pt die Display-Variante. In Flutter: Schriftfamilie `CupertinoSystemText` bzw. `CupertinoSystemDisplay` je nach Endgröße (im Spike prüfen, siehe 17.5).
- **SF Pro Rounded** nur für Zahlen, die man wie eine Anzeige liest (Mengen, Preise, kcal, Fortschritt, Timer), wie in Health. Nur wenn sie zur Laufzeit als Systemschrift erreichbar ist; die Schriftdatei wird nicht gebündelt (Lizenz). Rückfall: SF Pro mit tabellarischen Ziffern (K-18).
- **Ziffern** sind überall, wo sich Zahlen ändern oder untereinander stehen, tabellarisch (`FontFeature.tabularFigures()`): Mengen, Preise, kcal, Zähler, Timer, Diagrammachsen.
- Keine Serifen, keine eigenen Schriften, keine Großbuchstaben-Zeilen, kein `toUpperCase()` für Anzeige.

### 5.2 Textstile

Größen bei Textgröße L. Gewichte sind die in dieser App verwendeten (nicht zwingend Apples Standardgewicht).

| Stil (`AppTextStyle`) | Apple-Stil | Größe / Zeile | Gewicht | Laufweite | Verwendung |
|---|---|---|---|---|---|
| `largeTitle` | Large Title | 34 / 41 | Bold | +0,40 | Screen-Titel ("Wocheneinkauf", "Rezepte") |
| `title1` | Title 1 | 28 / 34 | Bold | +0,38 | Rezeptname, Paywall-Titel, Kochmodus-Schritt (Regular) |
| `title2` | Title 2 | 22 / 28 | Bold | -0,26 | Sprachmodus-Transkript (Regular), Erfolgsmoment, Artikel im Einkaufsmodus (Semibold) |
| `title3` | Title 3 | 20 / 25 | Semibold | -0,45 | leere Zustände, Abschnittstitel großer Seiten |
| `headline` | Headline | 17 / 22 | Semibold | -0,43 | Sektionstitel (Gänge, "Zutaten"), Zeilentitel mit Gewicht, Buttons |
| `body` | Body | 17 / 22 | Regular | -0,43 | Artikelnamen, Rezeptschritte, Avo-Antworten, Fließtext |
| `callout` | Callout | 16 / 21 | Regular | -0,31 | Hinweis-Zeilen, Ersparnis-Zeile |
| `subheadline` | Subheadline | 15 / 20 | Regular | -0,23 | Metadaten, Markt-Chip, Unterzeilen |
| `footnote` | Footnote | 13 / 18 | Regular | -0,08 | Quellen ("laut Händler", "Foto: Open Food Facts"), Sektionsfuß, Preis auf dem Schild (Semibold) |
| `caption1` | Caption 1 | 12 / 16 | Regular | 0 | Zeitstempel, Achsenbeschriftung |
| `caption2` | Caption 2 | 11 / 13 | Semibold | +0,06 | Pro-Kapsel |
| `numberXL` | wie Large Title | 34 / 41 | Rounded Bold | 0 | "640 kcal übrig", "5 von 11" im Einkaufsmodus |
| `numberL` | wie Title 2 | 22 / 28 | Rounded Semibold | 0 | Mengen im Einkaufsmodus, Nährwertzeile, Timer klein |
| `number` | wie Body | 17 / 22 | Rounded Semibold | 0 | Mengen ("2"), Preise ("0,99 €") in Zeilen |
| `numberS` | wie Footnote | 13 / 18 | Rounded Semibold | 0 | Preis auf dem gelben Schild, Zähler in Sektionsköpfen |

Regeln:
- **Hierarchie aus Gewicht vor Größe.** Ein Screen zeigt höchstens drei Stile gleichzeitig im sichtbaren Bereich (Zahlenstile nicht mitgezählt).
- **Sektionstitel** im iOS-26-Stil: gemischte Schreibweise, `headline`, `label`. Keine kleinen grauen Großbuchstaben.
- **Fließtext** immer in `label`. `labelSecondary` nur für Metadaten.
- **Fetter Text** (Bedienungshilfe, `MediaQuery.boldTextOf`): jedes Gewicht steigt eine Stufe (Regular zu Semibold, Semibold zu Bold, Bold zu Heavy).

### 5.3 Dynamic Type (K-19)

Die App wächst wie iOS: **jeder Stil nach Apples eigener Tabelle**, nicht mit einem linearen Faktor für alle. Große Titel wachsen dadurch weniger stark als Fließtext.

Größen in pt je Textgröße (xS bis xxxL, dann Bedienungshilfen AX1 bis AX5):

| Stil | xS | S | M | **L** | xL | xxL | xxxL | AX1 | AX2 | AX3 | AX4 | AX5 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Large Title | 31 | 32 | 33 | **34** | 36 | 38 | 40 | 44 | 48 | 52 | 56 | 60 |
| Title 1 | 25 | 26 | 27 | **28** | 30 | 32 | 34 | 38 | 43 | 48 | 53 | 58 |
| Title 2 | 19 | 20 | 21 | **22** | 24 | 26 | 28 | 34 | 39 | 44 | 50 | 56 |
| Title 3 | 17 | 18 | 19 | **20** | 22 | 24 | 26 | 31 | 37 | 43 | 49 | 55 |
| Headline, Body | 14 | 15 | 16 | **17** | 19 | 21 | 23 | 28 | 33 | 40 | 47 | 53 |
| Callout | 13 | 14 | 15 | **16** | 18 | 20 | 22 | 26 | 32 | 38 | 44 | 51 |
| Subheadline | 12 | 13 | 14 | **15** | 17 | 19 | 21 | 25 | 30 | 36 | 42 | 49 |
| Footnote | 12 | 12 | 12 | **13** | 15 | 17 | 19 | 23 | 27 | 33 | 38 | 44 |
| Caption 1 | 11 | 11 | 11 | **12** | 14 | 16 | 18 | 22 | 26 | 32 | 37 | 43 |
| Caption 2 | 11 | 11 | 11 | **11** | 13 | 15 | 17 | 20 | 24 | 29 | 34 | 41 |

- Die Werte vor dem Bau mit der aktuellen Tabelle in Apples Human Interface Guidelines ("Typography", "Dynamic Type sizes") abgleichen.
- **Textgröße bestimmen:** Flutter liefert auf iOS einen linearen Faktor = Body-Größe / 17. Aus `MediaQuery.textScalerOf(context).scale(17)` wird die nächstliegende Body-Größe und damit die Kategorie (xS bis AX5) abgeleitet.
- **Zeilenhöhe** = Größe mal Verhältnis des Stils bei L (Large Title 1,21; Title 1 1,21; Title 2 1,27; Title 3 1,25; Headline/Body 1,29; Callout 1,31; Subheadline 1,33; Footnote 1,38; Caption 1 1,33; Caption 2 1,18), gerundet.
- **Zahlenstile** folgen der Zeile ihres Apple-Stils (siehe Tabelle 5.2).
- **Obergrenzen nur dort, wo größer nicht mehr hilft:**
  - Tab-Beschriftungen: werden ab AX1 ausgeblendet; Langdruck zeigt sie im Large Content Viewer.
  - `numberXL`: höchstens 1,5-fach (51 pt), weil sie oben im Screen sonst die Liste unter den Falz schiebt.
  - Pro-Kapsel, Markt-Chip-Punkt, Preisschild: wachsen bis AX2, darüber bleiben sie auf AX2-Größe; der Text daneben wächst weiter.
  - Achsenbeschriftungen in Diagrammen: bis xxxL; darüber entfallen sie, die Werte stehen als Text unter dem Diagramm.
  - Widgets und Systemoberflächen skalieren nach den Regeln des Systems.
- **Umbruch statt Abschneiden.** Ellipsen sind nur erlaubt bei: Listenname im eingeklappten Navigationstitel (eine Zeile), Rezepttitel in kleinen Karten (zwei Zeilen), Widgets. Überall sonst bricht Text um. Großer Titel: bis zwei Zeilen, dann Ellipse; der volle Name steht im Titelmenü und in VoiceOver.

### 5.4 Laufweite

Die Laufweite wird **aus der Endgröße berechnet**, nicht pro Stil fest eingetragen. Grund: Mit Dynamic Type ändert sich die Größe, und eine feste Laufweite passt dann nicht mehr. Flutter übernimmt Apples Laufweiten-Tabelle der Systemschrift nicht automatisch.

Funktion `trackingFor(double pointSize)` in `app_text_styles.dart` (Teil A), Werte aus Apples Tabelle für SF Pro (in pt), dazwischen linear:

| Größe | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 bis 34 | ab 36 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Laufweite | +0,06 | 0 | -0,08 | -0,15 | -0,23 | -0,31 | -0,43 | -0,44 | -0,45 | -0,45 | -0,36 | -0,26 | -0,10 | +0,07 | +0,15 | +0,22 | +0,29 | +0,38 | +0,40 | +0,37 |

Erklärung: Bei Fließtext (17 bis 20 pt) ist die Laufweite am engsten. Ab 20 pt schaltet iOS auf die Display-Variante um, die von sich aus enger gezeichnet ist; deshalb sind die Werte dort wieder positiv. Große Schrift wirkt dadurch insgesamt enger als kleine, genau wie in Apples Apps. Zahlenstile (Rounded, tabellarisch) haben Laufweite 0. Die Werte vor dem Bau mit Apples aktueller Tabelle abgleichen.

---

## 6. Raster und Abstände

### 6.1 Abstands-Skala

Nur diese Werte (Token-Namen nach Wert):

| Token | 2 | 4 | 8 | 12 | 16 | 20 | 24 | 32 | 40 | 48 |
|---|---|---|---|---|---|---|---|---|---|---|
| Name | `space2` | `space4` | `space8` | `space12` | `space16` | `space20` | `space24` | `space32` | `space40` | `space48` |

### 6.2 Feste Maße

| Token | Wert | Bemerkung |
|---|---|---|
| `pageMargin` | 16 (ab 430 pt Breite 20) | Seitenrand und Einzug inset-gruppierter Sektionen |
| `sectionGap` | 32 | Abstand zwischen zwei Sektionen (inklusive Sektionstitel) |
| `sectionHeaderGap` | 8 | Sektionstitel bis Sektion; Sektionsfuß 8 unter der Sektion |
| `rowPaddingH` / `rowPaddingV` | 16 / 11 | Innenabstand einer Zeile |
| `rowMinHeight` | 44 | Mindesthöhe jeder Zeile, nie feste Höhe |
| `rowMinHeightShopping` | 64 | Mindesthöhe im Einkaufsmodus |
| `touchMin` | 44 | Mindest-Trefferfläche jedes Bedienelements |
| `touchShopping` | 56 | Trefferfläche des Abhak-Kreises im Einkaufsmodus |
| `checkSize` / `checkSizeShopping` | 24 / 36 | gezeichneter Abhak-Kreis |
| `listGlyph` | 28 | Listen-Glyph in Zeilen; 36 im Titelmenü |
| `articleImage` / `articleImageShopping` | 28 / 36 | Avo Symbol oder Produktfoto in der Artikelzeile |
| `avatarS / M / L / XL` | 20 / 28 / 36 / 64 | Stapel, Zeilen, Titelzeile, Profil |
| `glassButton` | 44 | runder Glas-Knopf (Symbol 17 pt, Medium) |
| `bottomContentInset` | aus `ShellInsets` | unterer Inhaltsabstand = Höhe der Bodenebene + 16; eine einzige Quelle (heute zwei Wahrheiten: `getNavbarClearance` und `120 + padding`) |

Höhen sind immer Mindestwerte (`ConstrainedBox(minHeight:)`), nie `SizedBox(height:)` um Text.

### 6.3 Verhalten nach Breite

Breitenklassen (aus `MediaQuery.sizeOf(context).width`): **schmal** unter 350 pt, **kompakt** 350 bis 389, **normal** 390 bis 429, **groß** ab 430.

| Breite | Geräte | Seitenrand | Tab-Beschriftungen | "Einkaufen" im Accessory | Rezept-Raster | Metazeile der Liste | Nährwertzeile | Paywall-Pläne |
|---|---|---|---|---|---|---|---|---|
| 320 | iPhone SE und 13 Pro mit Anzeigezoom "Größerer Text" | 16 | aus, Langdruck zeigt sie | nur Symbol `cart` | 1 Spalte | bricht in 2 Zeilen | 2 × 2 | untereinander, Preis unter dem Plan-Namen |
| 375 | SE 3, 13 mini | 16 | an | Symbol + "Einkaufen" bis xxL, darüber nur Symbol | 2 Spalten | eine Zeile bis xL | 4 Spalten bis L, darüber 2 × 2 | nebeneinander in der Zeile bis xL |
| 390 / 393 | 13, 13 Pro, 14, 15, 16 | 16 | an | Symbol + Text bis xxxL | 2 Spalten | eine Zeile bis xxL | 4 Spalten bis xL | nebeneinander bis xxL |
| 402 | 17 Pro | 16 | an | wie 390 | 2 Spalten | wie 390 | wie 390 | wie 390 |
| 440 | 17 Pro Max (430 bei Plus/älteren Max) | 20 | an | wie 390 | 2 Spalten, größere Bilder | eine Zeile | 4 Spalten bis xxL | nebeneinander |

### 6.4 Verhalten nach Textgröße

Unabhängig von der Breite gilt ab **AX1**:
- Zeilen stapeln: Die Menge rutscht unter den Namen; Chips und Markt-Chip brechen um (`Wrap`).
- Artikelbilder werden automatisch ausgeblendet; der Name rückt an den Kreis.
- Inset-gruppierte Sektionen werden randlos ("plain", wie Erinnerungen): Hintergrund `bgPlain`, Zeilen über die volle Breite, Text 16 pt eingerückt. So bekommt der Artikelname die volle Breite.
- Tab-Beschriftungen entfallen (Large Content Viewer).
- Rezept-Raster wird einspaltig, Rezeptkarten zeigen das Foto über dem Titel in voller Breite.
- Maskottchen in leeren Zuständen entfällt.
- Zwei Buttons nebeneinander werden untereinander gestellt (`Flex` mit Umschaltung, nicht `Row`).

Im **Einkaufsmodus** ist die Liste immer randlos, unabhängig von der Textgröße.

### 6.5 Sichere Bereiche

- Oben: Dynamic Island bzw. Notch über `MediaQuery.paddingOf`. Der große Titel beginnt unter der Navigationszeile.
- Unten: Home-Indikator. Die Bodenebene (Tab-Bar, Accessory) steht 8 pt über dem sicheren Bereich, wie die native Tab-Bar.
- Tastatur: Bei offener Tastatur verschwindet die Tab-Bar (mit Feder, nicht hart), das Accessory sitzt direkt auf der Tastatur. Inhalte bekommen den Tastatur-Abstand über `viewInsets`.

---

## 7. Form

### 7.1 Radien-Skala

| Token | Wert | Element |
|---|---|---|
| `radiusSheet` | Geräteradius minus 8 | schwebendes Sheet in Teilhöhe (8 pt Abstand zum Rand) |
| `radiusSheetFull` | Geräteradius | Sheet in voller Höhe, nur oben |
| `radiusSection` | 26 | inset-gruppierte Sektion (iOS-26-Wert) |
| `radiusCard` | 20 | frei stehende Karten in horizontalen Reihen (Rezeptkarte klein, Wochenplan-Tag) |
| `radiusThumb` | 12 | Bild in einer Zeile (Rezept-Thumbnail 56 pt) |
| `radiusPhotoS` | 8 | Produktfoto in der Artikelzeile (28 bis 36 pt) |
| Kapsel | Höhe / 2 | Buttons, Chips, Felder, Markt-Chip, Preisschild, Pro-Kapsel, Accessory, Tab-Bar |
| Kreis | Durchmesser / 2 | Abhak-Kreis, Avatar, Listen-Glyph, Glas-Knopf, Avo-Kreis |

### 7.2 Konzentrische Regeln

- **Innerer Radius = äußerer Radius minus Abstand.** Ein Bild mit 8 pt Abstand in einer Karte mit 20 pt Radius hat 12 pt.
- Ein Rezeptfoto über die volle Breite einer Sektion hat oben `radiusSection` (26) und unten 0; es teilt sich die Ecke mit der Sektion.
- Sheets sind konzentrisch zur Geräteecke. Der Geräteradius kommt aus einer Tabelle pro Gerätemodell in Swift (öffentliche API gibt es nicht; private Schlüssel sind wegen App Review verboten), über den Kanal `shoply/device` (Teil A in eigener Swift-Datei). Fallback: Geräteradius 47 (Sheet 39).
- Native Glas-Formen (`UIGlassEffect`) setzen ihre Ecken über `cornerConfiguration` selbst konzentrisch; Flutter-Formen nutzen die Tabelle.
- Elemente, die in einer Kapsel sitzen (Symbol im Feld), haben ihren Mittelpunkt auf dem Radius-Mittelpunkt der Kapsel-Rundung.

### 7.3 Kapseln

Alles, was man antippt und Text trägt, ist eine Kapsel: Buttons, Chips, Felder, Segmente, Markt-Chip. Ausnahme: Zeilen in Sektionen (rechteckig in der Sektion, die Sektion trägt den Radius).

---

## 8. Material und Tiefe

### 8.1 Liquid Glass: abschließende Liste der erlaubten Stellen

Glas gibt es **nur** hier. Alles andere ist feste Fläche.

| Stelle | Glas | Native Ausführung | Bemerkung |
|---|---|---|---|
| Tab-Bar mit abgesetztem Avo-Kreis | ja | **eine** native Platform View (K-13) | Kreis und Tab-Kapsel in einem `UIGlassContainerEffect` |
| Eingabe-Accessory "Artikel hinzufügen" + "Einkaufen" | ja | eine `LiquidGlassGroup` | nur im Tab Liste, nur an der Wurzel |
| Toolbar-Buttons oben (Zurück, Teilen, Mehr, Schließen, Fertig) | ja | eine Gruppe pro Navigationsleiste | Profil-Avatar ist **kein** Glas (Bild in der Titelzeile, wie App Store) |
| Menüs, Pull-down-Menüs, Kontextmenüs | ja | Glasfläche existiert nur, solange das Menü offen ist | wachsen aus dem Auslöser |
| Sheets in Teilhöhe | ja | Hintergrund des Sheets | bei voller Höhe fest (`bgGroupedElevated`) |
| Avo-Eingabe "Frag Avo" und Sprachmodus-Steuerung | ja | Teil der Tab-Bar-View bzw. Bodenleiste des Sprachmodus | |
| Bodenleiste im Einkaufsmodus ("+", "Einkauf beenden", Avo) | ja | eine Gruppe | "Einkauf beenden" getönt |
| Aktionsleiste im Rezeptdetail ("Zutaten auf Liste", "Kochen") | ja | eine Gruppe | ersetzt dort das Accessory |
| Steuerung im Kochmodus (Timer-Kapsel, Zurück/Weiter) | ja | eine Gruppe | auf Schwarz |
| Rückgängig- und Status-Hinweis (schwebend) | ja | eine Glasfläche, nur solange sichtbar | |

**Nie Glas:** Listen, Zeilen, Karten, Sektionen, Rezeptbilder, Diagramme, Avo-Antworten, Paywall-Pläne, Hinweis-Zeilen, Chips, Felder im Inhalt, Widget-Inhalte.

### 8.2 Regeln

- **Kein Glas auf Glas.** Ein Menü aus der Tab-Bar ersetzt die Tab-Bar optisch, es liegt nicht darauf. Inhalte in einem Glas-Sheet sitzen auf `surfaceElevated`, nicht auf weiterem Glas.
- **Varianten:** `regular` überall; `clear` nur über Fotos (Toolbar im Rezeptdetail über dem Foto), dann mit einem Verlauf von #000000 30 % am oberen Bildrand für die Lesbarkeit.
- **Tönung:** nur die jeweils eine Hauptaktion einer Bedienebene ist in `action` getönt: "Einkaufen" im Accessory, "Einkauf beenden" im Einkaufsmodus, "Zutaten auf Liste" im Rezeptdetail, der Häkchen-Knopf "Fertig" in Sheets. Sonst ungetönt.
- **Scroll-Edge-Effekt statt Trennlinie:** Wo Inhalt unter Glas läuft, blendet ein weicher Farbverlauf aus der Hintergrundfarbe den Inhalt aus: oben 24 pt unter der Navigationsleiste, unten 40 pt hinter der Bodenebene. Ein einfacher `LinearGradient` ohne Unschärfe. Keine Linie unter der Navigationsleiste.
- **Schatten nur für Schwebendes.** Natives Glas bringt seine Tiefe selbst mit. Flutter-gezeichnete schwebende Elemente (Fallback, gezogene Zeile beim Umsortieren) bekommen `shadowFloat`: hell 0/8/24 mit #000000 12 %, dunkel 0/8/24 mit #000000 40 %. Inhalte haben nie Schatten.
- **Tiefe aus drei Ebenen:** Hintergrund (`bgGrouped`), Fläche (`surface`), Glas. Mehr Ebenen gibt es nicht.

### 8.3 Bedienungshilfen

- **Transparenz reduzieren:** Natives `UIGlassEffect` reagiert selbst. Für Flutter-gezeichnete Glas-Fallbacks wird der Zustand über einen nativen Kanal gelesen (`UIAccessibility.isReduceTransparencyEnabled` plus Mitteilung bei Änderung; Flutter liefert ihn nicht). Dann `glassFallback`.
- **Kontrast erhöhen:** Glas bekommt eine 1-pt-Kontur in `separator`; der heutige `AdaptiveGlass` behandelt fälschlich Kontrast statt Transparenz und wird korrigiert.
- **Android und iOS vor 26:** `glassFallback` mit `shadowFloat`, kein `BackdropFilter`.

### 8.4 Umsetzung in Flutter

- **Grundbaustein:** die vorhandenen nativen Views `shoply/liquid_glass` und `shoply/liquid_glass_group` aus `ios/Runner/LiquidGlassViewFactory.swift` (Teil A). Sie bekommen einen Methodenkanal für Updates (Größe, Form, Tönung, sichtbar/unsichtbar), weil Formen heute nur beim Erzeugen gesetzt werden und bei Dynamic Type stehen bleiben. Der Kapselradius vor iOS 26 wird bei jeder Größenänderung neu berechnet (heute bei Größe 0 eckig).
- **Tab-Bar:** eigene native View `shoply/tab_bar` (K-13), Details in 12.1.
- **Menüs und Alerts:** nativ über `adaptive_platform_ui` (`AdaptiveAlertDialog`, `AdaptivePopupMenuButton`), wo der Auslöser ohnehin ein nativer Knopf ist; sonst Flutter-Inhalt auf einer nativen Glasfläche, die nur existiert, solange das Menü offen ist.
- **Kein `BackdropFilter`** in `lib/presentation` auf iOS. Keine Glas-Views in scrollenden Zeilen.
- **Verdeckte Glas-Views werden aus dem Baum genommen:** Liegt ein Sheet in mittlerer oder voller Höhe über der Bodenebene, wird das Accessory entfernt (nicht nur verdeckt).

### 8.5 Performance-Budget

| Regel | Wert |
|---|---|
| Native Glas-Views gleichzeitig pro Screen | höchstens 3 (Beispiel Startseite: Tab-Bar mit Avo-Kreis = 1, Accessory = 2, Toolbar-Gruppe oben = 3) |
| Glas in scrollenden Inhalten | 0 |
| `BackdropFilter` auf iOS | 0 |
| Frame-Zeit Ziel / Grenze | 8,3 ms (120 Hz) / 16 ms, gemessen im Profile-Modus auf iPhone 13 Pro |
| Bild-Dekodierung | immer in Anzeigegröße (`memCacheWidth`/`cacheWidth` = logische Breite × Pixelverhältnis) |
| Platform Views bei Sheet-Animation | Glas-Views unter dem Sheet bleiben stehen (keine Größenänderung während der Animation) |

Wer ein viertes Glas-Element braucht, muss eines zusammenlegen oder als Fläche zeichnen. Das wird in der Status-Datei begründet.

---

## 9. Ikonografie und Bilder

### 9.1 SF Symbols: Grundregeln

- **SF Symbols** für die gesamte Bedienung. Material-Icons, `CupertinoIcons` und Lucide fallen weg (heute ca. 365 / 39 / 5 Stellen).
- **Rendering:** hierarchisch in Bedienelementen; monochrom in Zeilen; mehrfarbig nur in Widgets und im Kalorien-Bereich (`drop.fill` Wasser, `flame.fill`).
- **Frei stehend.** Keine getönten Quadrate oder Kreise hinter Symbolen. Einzige Ausnahme: der Listen-Glyph (Inhalt, Muster aus Erinnerungen).
- **Größe und Gewicht folgen dem Text daneben:** Symbolgröße = Schriftgröße des Stils (Maßstab "medium"), Gewicht = Gewicht des Textes. Damit wachsen Symbole mit Dynamic Type.

| Ort | Größe | Gewicht |
|---|---|---|
| Tab-Bar | System (nativ) | System |
| Glas-Knopf 44 pt | 17 pt | Medium |
| In Zeilen (führend) | 17 pt (`body`) | Regular |
| Hinweis-Zeilen | 16 pt (`callout`) | Regular |
| Metazeilen | 15 pt (`subheadline`) | Regular |
| Leere Zustände ohne Maskottchen | 48 pt | Light |
| Paywall-Vorteile | 22 pt | Medium, `action` |

### 9.2 Symbol pro Funktion

| Funktion | Symbol | Funktion | Symbol |
|---|---|---|---|
| Tab Liste | `checklist` | Tab Rezepte | `fork.knife` |
| Tab Plan | `calendar` | Tab Kalorien | `flame` |
| Avo | `avo.core` (eigenes Symbol, 3.4) | Suche (Avo aus) | `magnifyingglass` |
| Zurück | `chevron.left` | Schließen / Abbrechen | `xmark` |
| Fertig / Übernehmen | `checkmark` | Mehr | `ellipsis` |
| Hinzufügen | `plus` | Liste wechseln (am Titel) | `chevron.down` |
| Liste teilen / einladen | `person.crop.circle.badge.plus` | Teilen (System) | `square.and.arrow.up` |
| Einkaufen starten | `cart` | Einkauf beenden | `checkmark.circle` |
| Einkaufsmodus verlassen | `chevron.down` | Zettel importieren | `text.viewfinder` |
| Kamera | `camera` | Sprachmodus | `waveform` |
| Mikrofon stumm | `mic.slash` | Markt | `storefront` |
| Angebot, Ersparnis | `tag` | Verlauf, Einkäufe | `clock.arrow.circlepath` |
| Kosten teilen | `eurosign.circle` | Mitglieder | `person.2` |
| Bearbeiten, Umbenennen | `pencil` | Löschen | `trash` |
| Reihenfolge im Markt | `arrow.up.arrow.down` | Liste anheften | `pin` |
| Listen-Info | `info.circle` | Alle Listen | `list.bullet` |
| Liste beitreten | `link` | Rezept merken | `bookmark` / `bookmark.fill` |
| Kochen | `frying.pan` | Timer | `timer` |
| Zutat ersetzt | `arrow.left.arrow.right` | Allergie, Warnung | `exclamationmark.triangle.fill` |
| Wasser | `drop` | Gewicht | `scalemass` |
| Workout | `figure.run` | Barcode | `barcode.viewfinder` |
| Lebensmittel suchen | `magnifyingglass` | Manuell eintragen | `square.and.pencil` |
| Ziele | `target` | Challenges | `flag` |
| Woche, Statistik | `chart.bar` | Apple Health | `heart` |
| Mitteilungen | `bell` | Darstellung | `circle.lefthalf.filled` |
| Sprache | `globe` | Module | `switch.2` |
| Preise & Angebote | `tag` | Ernährung & Allergien | `leaf` |
| Siri & Kurzbefehle | `waveform.circle` | Widgets | `rectangle.3.group` |
| Hilfe | `questionmark.circle` | Datenschutz | `hand.raised` |
| Rechtliches | `doc.text` | Offline | `icloud.slash` |
| Ausstehend (Sync) | `arrow.triangle.2.circlepath` | Rückgängig | `arrow.uturn.backward` |
| Fehler | `exclamationmark.circle` | Erledigt, Erfolg | `checkmark.circle.fill` |
| Standort | `location` | Kontext Ernährung angepasst | `leaf` |

Symbole, die erst ab iOS 16 oder 17 existieren (`carrot`, `frying.pan`, `popcorn`, `waterbottle`, `figure.run` u. a.), brauchen einen Rückfall, solange das Deployment-Ziel unter iOS 17 liegt (heute 15.6, Owner-Frage F-12). Der Renderer liefert bei unbekanntem Namen den Rückfall aus der Symbol-Tabelle.

### 9.3 SF Symbols in Flutter (K-16)

- **Weg:** Native Darstellung zur Laufzeit. Ein Kanal `shoply/symbols` (Teil A, eigene Swift-Datei) rendert `UIImage(systemName:withConfiguration:)` in Größe, Gewicht und Bildschirm-Maßstab als Vorlage-Bitmap. Flutter zeigt sie als Bild mit Farbfilter. Cache im Speicher und auf der Festplatte; beim App-Start werden alle Symbole aus einem Manifest (`assets/symbols_manifest.json`) im Hintergrund vorgerendert, damit beim Scrollen nie gewartet wird.
- **Warum nicht gebündelt:** Exportierte SF-Symbol-Dateien im App-Bundle wären auch im Android-Build enthalten; Apples Lizenz erlaubt SF Symbols nur auf Apple-Plattformen. Zur Laufzeit gerenderte Systemsymbole umgehen das und passen sich jeder iOS-Version an.
- **Alternative** (nur nach Lizenzprüfung): Icon-Font aus SF-Symbols-Exporten, ausschließlich im iOS-Build. Vorher klären: Lizenztext der aktuellen SF-Symbols-App, ob Bündeln in einer iOS-App erlaubt ist, und wie der Android-Build sie ausschließt.
- **Android:** Zuordnung jedes Symbols zu einem Material-Symbol in derselben Tabelle.
- **Barrierefreiheit:** Jedes Symbol bekommt entweder ein ausgeschriebenes `semanticLabel` oder wird als dekorativ ausgeblendet (`excludeFromSemantics`), nie beides offen.

### 9.4 Artikel- und Kategoriebilder: "Avo Symbols" (K-17)

- Ein eigenes Set aus etwa 10 Kategorie-Symbolen und 200 Artikel-Symbolen (Milch, Bananen, Brötchen, Eier …), gezeichnet auf dem SF-Symbols-Raster mit denselben Strichstärken in drei Gewichten (Light, Regular, Semibold), exportiert als SF-Symbol-Vorlage. Eigene Zeichnungen, also keine Lizenzfrage.
- In der App als Icon-Font `AvoSymbols` (keine Bild-Dekodierung beim Scrollen), in Widgets und Siri als Symbol-Assets im Asset-Katalog.
- Farbe: in Listen `labelSecondary`, im Einkaufsmodus `label`. In getönten Widgets färben sie sich mit.
- Abschaltbar: Einstellung "Artikelbilder anzeigen" (Standard an); ab AX1 automatisch aus.
- Zuständig: Teil B (`assets/articles/`, `assets/illustrations/`), eine Person zeichnet mit fester Vorlage. Bis das Set fertig ist, gilt **ausschließlich** die Übergangslösung unten; niemand zeichnet eigene Zwischenlösungen.

**Übergang: SF Symbol der Kategorie** (für die 10 Kategorie-IDs aus `categories.dart`):

| Kategorie-ID | Symbol | Rückfall vor iOS 17 |
|---|---|---|
| `fruits_vegetables` | `carrot` | `leaf` |
| `bakery` | `birthday.cake` | `circle.grid.2x2` |
| `meat_fish` | `fish` | `fork.knife` |
| `staples` | `basket` | `bag` |
| `snacks` | `popcorn` | `bag` |
| `beverages` | `waterbottle` | `drop` |
| `household` | `bubbles.and.sparkles` | `sparkles` |
| `dairy` | `drop` | `drop` |
| `frozen` | `snowflake` | `snowflake` |
| `other` | `bag` | `bag` |

Eigene Kategorien der Nutzer bekommen `tag`.

### 9.5 Produktfotos (Open Food Facts)

- Nur, wenn ein Markenprodukt erkannt oder ein Barcode gescannt wurde. Nie aus Händler-Shops oder Prospekten (Urheberrecht, Recherche).
- In der Zeile 28 pt (Einkaufsmodus 36 pt), weiße Unterlage, `radiusPhotoS`, nicht freigestellt (ein Freisteller wäre eine Bearbeitung unter Share-Alike).
- Quellenangabe im Artikel-Sheet als `footnote`: "Foto: Open Food Facts, CC BY-SA" mit Link. Die Seite "Datenquellen" nennt Open Food Facts, Open Prices (ODbL), OpenStreetMap (ODbL) und die Angebotsquelle.
- Angebote ohne Bildlizenz zeigen das Avo Symbol der Kategorie, nicht das Händlerbild (heute Hotlink auf `mg2de.b-cdn.net`).

### 9.6 Rezeptfotos

- Das Bunteste der App, deshalb groß: Detail randlos oben 4:3 bis unter die Statusleiste; Rezept der Woche 16:10; Karten 4:3 (groß) bzw. 1:1 (Thumbnail).
- **`photo_color`:** Jedes Rezeptfoto bekommt beim Hochladen eine gespeicherte Grundfarbe (Supabase-Feld, Teil A; Bestand per einmaligem Job nachrechnen). Sie steht ab dem ersten Frame als Fläche, das Foto blendet in 0,2 s darüber. Kein Schimmer, kein Spinner.
- **Typo-Karte:** Fehlt das Foto oder ist es kleiner als 600 px in der kurzen Seite, wird die Karte zur Typo-Karte: Fläche `fill`, Titel in `title3` bzw. `title2`, darunter bis zu vier Avo Symbols der Hauptzutaten. Nie ein gestrecktes oder unscharfes Bild.
- Text auf Fotos nur mit Verlauf vom Bildrand (#000000 von 0 auf 55 % über das untere Drittel), Schrift `labelOnPhoto`. Kein Glas als Textunterlage.
- Dekodierung in Anzeigegröße, die nächsten zwei Fotos einer Reihe werden vorgeladen.
- Eigene, kuratierte Fotos für Rezept der Woche, Onboarding und Paywall (Lizenz klären, Owner-Frage F-07).

### 9.7 Supermarkt-Logos

Nur mit schriftlicher Erlaubnis der Kette. Bis dahin Markt-Chip mit Markenpunkt und Name in Systemschrift (4.8). Keine nachgezeichneten Logos, keine Markenschriften.

---

## 10. Bewegung

### 10.1 Feder-Tokens (`AppMotion`)

Federn statt fester Dauern. Parameter wie bei Apple: Dämpfung (1,0 = kein Überschwingen) und Antwort (Sekunden bis zum Ziel, keine Dauer). Umrechnung für Flutter (`SpringDescription`, Masse 1): Steifigkeit = (2π / Antwort)², Dämpfung = 4π × Dämpfungsgrad / Antwort.

| Token | Dämpfung | Antwort | Steifigkeit / Dämpfung (Flutter) | Wofür |
|---|---|---|---|---|
| `springStandard` | 1,0 | 0,35 s | 322,3 / 35,90 | Zeilen einfügen und umordnen, Ein- und Ausblenden von Elementen, Tabs ein/aus bei Modulwechsel |
| `springQuick` | 1,0 | 0,25 s | 631,7 / 50,27 | Abhak-Kreis füllt sich, Schalter, Chips, gedrückter Zustand |
| `springMenu` | 1,0 | 0,30 s | 438,6 / 41,89 | Menüs und Kontextmenüs wachsen aus dem Auslöser |
| `springSheet` | 1,0 | 0,40 s | 246,7 / 31,42 | Sheet öffnen und schließen ohne Wurf, Detent-Wechsel per Tippen |
| `springFling` | 0,8 | 0,35 s | 322,3 / 28,72 | nach Wischen oder Wurf: Sheet loslassen, Zeile nach Wischaktion; übernimmt die Fingergeschwindigkeit |
| `springMorph` | 1,0 | 0,40 s | 246,7 / 31,42 | Glas-Morph: Tab-Bar zu "Frag Avo", Bodenebene zum Einkaufsmodus, Paywall aus dem Element, Rezeptkarte zum Detail |
| `springMove` | 1,0 | 0,40 s | 246,7 / 31,42 | abgehakte Zeile wandert nach "Erledigt" bzw. "Im Wagen" |
| `springDigits` | 1,0 | 0,30 s | 438,6 / 41,89 | rollende Ziffern, Fortschrittslinie und Ring folgen der Zahl |
| `springCelebrate` | 0,8 | 0,40 s | 246,7 / 25,13 | Erfolgsmoment (Skalierung aus 0,9) |
| `fadeReduced` | – | 0,2 s, ease-in-out | feste Dauer | einzige erlaubte feste Dauer: Überblendung bei Reduce Motion, Foto über `photo_color`, nachgeladene Inhalte |

Regeln:
- Jede Bewegung ist **unterbrechbar** und startet vom **aktuellen Wert** und mit der aktuellen Geschwindigkeit (`AnimationController.animateWith(SpringSimulation(…, start: controller.value, velocity: controller.velocity))`).
- **Gesten folgen dem Finger 1:1** mit Abstand zum Griffpunkt: Wischaktionen, Sheets, Umsortieren, Wochenplan-Tage, Zurück-Wischen. An Grenzen Gummiband (Apple-Formel: Überstand × Dimension × 0,55 / (Dimension + 0,55 × |Überstand|)).
- Beim Loslassen wird das Ziel aus der Wurfprojektion gewählt (Endpunkt = Position + (Geschwindigkeit / 1000) × 0,998 / 0,002) und die Fingergeschwindigkeit an die Feder übergeben.
- Überschwingen (Dämpfung 0,8) nur nach einer Geste mit Schwung oder im Erfolgsmoment.
- Keine Endlos-Animationen. Ausnahme: der Avo-Kern im Zustand `denkt`, solange Avo wirklich arbeitet.

### 10.2 Übergänge

| Übergang | Verhalten |
|---|---|
| **Push** (Drilldown in einem Tab) | iOS-Push von rechts mit Zurück-Wischen vom Rand, das 1:1 folgt und unterbrechbar ist. In Flutter `CupertinoPageRoute` (systemnah; erlaubte Ausnahme von den Feder-Tokens, weil es das Systemverhalten nachbildet). |
| **Tab-Wechsel** | sofort, ohne Animation und ohne Haptik (wie iOS). Das heutige seitliche Durchschieben (`SlidingTabsContainer`) entfällt. Erneutes Tippen auf den aktiven Tab: zurück zur Wurzel, dann nach oben scrollen. |
| **Sheet** | fährt von unten mit `springSheet`, Detents mittel und groß, Ziehen folgt 1:1, Loslassen mit `springFling`. Der Bildschirm dahinter wird bei großem Detent um 0,96 skaliert und mit `scrim` abgedunkelt; bei mittlerem Detent bleibt er bedienbar. |
| **Vollbild-Cover** (Einkaufsmodus, Kochmodus, Onboarding, Rezept-Editor, Kamera) | fährt von unten, schließt nach unten; Einkaufsmodus siehe Morph. |
| **Morph aus dem Auslöser** | Menü wächst aus dem Knopf (Skalierung 0,6 auf 1 plus Deckkraft, Ursprung am Knopf); "Frag Avo" entsteht aus dem Avo-Kreis; die Paywall wächst als Sheet aus dem angetippten gesperrten Element; der Listen-Titel wird zum Wechsel-Menü; Zurück geht denselben Weg. |
| **Zoom Rezeptkarte zu Detail** | Das Foto wächst von der Karte ins Detail (`springMorph`); Zurück-Wischen schrumpft es unterbrechbar zur Karte zurück. |
| **Einkaufsmodus starten** | Die Tab-Bar zieht sich in den Knopf "Einkaufen" zurück, das Accessory schrumpft zum "+"-Glasknopf unten links, der Avo-Kreis bleibt an seiner Stelle; die Liste wird randlos und die Zeilen wachsen auf Einkaufsmodus-Maße (`springMorph`). Rückfall, wenn der native Morph im Spike nicht gelingt: Überblendung beider Bodenebenen in 0,25 s, die genauso ruhig aussehen muss. |

### 10.3 Listen-Animationen

- **Abhaken:** Kreis füllt sich vom Mittelpunkt (`springQuick`), das Häkchen zeichnet sich, der Text wird durchgestrichen und `labelSecondary`. Nach 0,6 s wandert die Zeile mit `springMove` in die eingeklappte Sektion "Erledigt (n)" (normal) bzw. "Im Wagen (n)" (Einkaufsmodus); die Zeilen darunter rücken nach. In den 0,6 s und danach über die Rückgängig-Leiste widerrufbar.
- **Hinzufügen:** Die neue Zeile entsteht in ihrer Kategorie: Höhe wächst von 0 (`springStandard`), Inhalt blendet ein. Ist die Kategorie nicht sichtbar, scrollt die Liste nicht; stattdessen erscheint im Accessory kurz "Milch → Milch & Käse". Ändert die KI später die Kategorie, wandert die Zeile mit `springStandard`, ohne Sprung.
- **Umsortieren:** Langdruck hebt die Zeile an (Skalierung 1,03, `shadowFloat`), sie folgt dem Finger 1:1; Nachbarn machen mit `springStandard` Platz; Einrasten mit Auswahl-Haptik; Auto-Scroll am Rand mit Gummiband-Geschwindigkeit.
- **Gang wechseln (Einkaufsmodus):** Gang-Titel haften oben; ist der letzte Artikel eines Gangs abgehakt, klappt der Gang mit `springStandard` zusammen und der nächste Titel rückt nach. Die Liste springt nie automatisch.
- **Änderungen anderer (geteilt):** Neue Artikel blenden an ihrem Platz ein; von anderen abgehakte Zeilen zeigen 2 s den Avatar der Person (16 pt) am Kreis und wandern dann wie eigene.
- **Rollende Ziffern:** Ändert sich eine Zahl ("5 von 11", kcal, Portionen, Mengen, gespart), rollen nur die geänderten Ziffern vertikal in Richtung der Änderung (abwärts beim Weniger-Werden), `springDigits`, tabellarisch, damit nichts seitlich springt.

### 10.4 Reduce Motion

- Alle Verschiebungen, Morphs und Skalierungen werden Überblendungen (`fadeReduced`).
- Rollende Ziffern: Überblenden der ganzen Zahl.
- Abgehakte Zeilen bleiben stehen (durchgestrichen) und wandern erst, wenn der Nutzer 1 s nicht scrollt und nicht tippt, oder beim Beenden des Einkaufs. Kein Wegspringen unter dem Finger.
- Avo-Kern: nur Helligkeit, keine Größe. Präsenz-Punkt: statisch.
- Erfolgsmoment: nur Einblenden, keine Skalierung.
- Zoom-Übergang: Überblendung.
- In Flutter: `MediaQuery.disableAnimationsOf(context)` (iOS "Bewegung reduzieren").

---

## 11. Haptik

Nur bei bedeutsamen Momenten, immer im selben Frame wie das Bild. Eine zentrale Klasse `AppHaptics` (Teil A); `HapticFeedback.` wird sonst nirgends aufgerufen (heute 118 Stellen). Erfolg, Warnung und Fehler brauchen `UINotificationFeedbackGenerator`, den Flutter nicht anbietet: über einen kleinen nativen Kanal (Teil A, eigene Swift-Datei; Registrierung in `AppDelegate.swift` als Anfrage an Teil B) oder ein geprüftes Paket.

| Ereignis | Haptik | Bemerkung |
|---|---|---|
| Artikel abhaken (auch rückgängig abhaken) | leichter Impuls | im Moment, in dem der Kreis sich füllt |
| Letzten offenen Artikel abhaken | Erfolg | statt des leichten Impulses |
| Einkauf gespeichert, Wochenplan auf der Liste, Kauf erfolgreich, Challenge geschafft | Erfolg | gleichzeitig mit dem Erfolgsmoment |
| Fehler: nicht gespeichert, Kauf fehlgeschlagen, ungültige Eingabe | Fehler | mit sichtbarer Meldung |
| Warnung: Allergen in Rezept erkannt | Warnung | einmal beim Erscheinen |
| Zeile rastet beim Umsortieren ein | Auswahl | |
| Stepper-Schritt (Portionen, Menge) | Auswahl | |
| Sheet rastet auf einem Detent ein (nach Ziehen) | Auswahl | nicht beim programmatischen Öffnen |
| Segment- und Wochentag-Wechsel per Wischen | Auswahl | nicht bei Tippen |
| Sprachmodus beginnt zuzuhören | leichter Impuls | |
| Wischaktion überschreitet die Auslöse-Schwelle | leichter Impuls | |
| Langdruck öffnet Kontextmenü | systemseitig | nicht selbst auslösen |

Keine Haptik: Tab-Wechsel, Zurück, Scrollen, normale Buttons, Chips, Tippen in Felder, Öffnen von Sheets, Avo sendet eine Nachricht.

---

## 12. Komponenten-Bibliothek

Teil A baut alle Komponenten bis Meilenstein S2 in `lib/presentation/widgets/design/` (Ausnahmen mit "Teil B" markiert: B baut sie im eigenen Ordner nach diesen Vorgaben). Jede Komponente liest nur Tokens aus Kapitel 4 bis 11. Klassennamen ohne Markennamen.

Schema je Komponente: **Zweck · Anatomie · Varianten · Zustände · Maße/Tokens · Barrierefreiheit · Flutter (ersetzt)**.

### 12.1 Tab-Bar mit Avo-Einstieg (`AppTabBar`)

- **Zweck:** Bereich wechseln; der einzige In-App-Einstieg zu Avo.
- **Anatomie:** Schwebende Glas-Kapsel mit 2 bis 4 Tabs (Symbol und Beschriftung), rechts davon abgesetzt ein runder Glas-Kreis gleicher Höhe mit dem Avo-Kern-Symbol. Kapsel und Kreis bilden eine native Glasgruppe. Abstand zum Home-Indikator wie die System-Tab-Bar.
- **Varianten:**
  - Tabs nach Modulen: Liste und Rezepte immer; Plan (Modul Wochenplan); Kalorien (Modul Kalorien). Reihenfolge fest: Liste, Rezepte, Plan, Kalorien.
  - Kreis: `avo.core` (Modul Avo an) oder `magnifyingglass` (Modul Avo aus, dann reine App-Suche). Die Form der Leiste ändert sich dadurch nicht.
- **Zustände:**
  - normal; Tab ausgewählt (Symbol gefüllt, Tönung `action`).
  - **"Frag Avo"** (nach Tippen auf den Kreis): Der Kreis dehnt sich nach links zum Feld "Frag Avo oder suche" mit `camera` links und `waveform` rechts; die Tab-Kapsel schrumpft zu einem kleinen Kreis links mit dem Symbol des aktiven Tabs (Tippen kehrt zurück). Muster des Such-Tabs in iOS 26. Die Tastatur öffnet sich, das Feld sitzt auf der Tastatur. `waveform` startet den Sprachmodus und darf nie entfallen (Langdruck allein ist nicht auffindbar).
  - Avo-Kern-Zustände aus 3.4 (`denkt`, während eine Antwort läuft, auch wenn das Sheet geschlossen ist).
  - ausgeblendet: bei offener Tastatur (außer im Zustand "Frag Avo"), in Vollbild-Covern außer Einkaufs- und Kochmodus.
  - Einkaufsmodus: Tab-Kapsel zieht sich in den Knopf "Einkaufen" zurück, der Kreis bleibt an seiner Stelle (10.2).
  - Modul ein/aus: Tab blendet mit `springStandard` ein bzw. aus, Nachbarn rücken nach. Steht man auf einem ausgeschalteten Tab, landet man auf Liste.
  - Minimieren beim Scrollen: aus (K-14).
- **Maße/Tokens:** Höhe und Symbolgröße wie die System-Tab-Bar; Kreis-Durchmesser = Höhe der Kapsel; 8 pt Abstand zwischen Kapsel und Kreis. Beschriftungen entfallen unter 350 pt Breite und ab AX1.
- **Barrierefreiheit:** Tabs haben die Tab-Rolle ("Rezepte, Tab, 2 von 3, ausgewählt"). Kreis: "Avo", Hinweis "Doppeltippen zum Fragen", eigene Aktion "Sprechen"; bei Suche "Suchen". Large Content Viewer bei Langdruck ab AX1. Kein Haptik beim Tab-Wechsel. Erneutes Tippen auf den aktiven Tab: zur Wurzel, dann nach oben scrollen.
- **Flutter (ersetzt `main_scaffold.dart`: `_NavIcon`, `_AvoOrb`, `SlidingTabsContainer`):**
  - Eigene native View `shoply/tab_bar` in `LiquidGlassViewFactory.swift` (Teil A): echte `UITabBar`-Elemente plus Kreis in einem `UIGlassContainerEffect`, Eingabefeld "Frag Avo" als natives `UITextField` in derselben View, damit der Morph nativ läuft.
  - Kanal `shoply/tab_bar`: `setItems(tabs)`, `select(index)`, `setAvoState(state)`, `setMode(normal | askAvo | hidden | shopping)`, `setAvoIsSearch(bool)`; Ereignisse `onTabTap(index)`, `onAvoTap`, `onAvoLongPress`, `onAskText(text)`, `onAskSubmit`, `onVoiceTap`, `onCameraTap`.
  - Die Tab-Inhalte liegen in einem Container ohne Animation; jeder Tab behält seinen Navigator und Zustand (heute: `StatefulShellRoute`).
  - **Spike in Woche 1 (höchstens 2 Tage, Teil A):** native View mit Morph und Textfeld. Gelingt der Morph nicht sauber, sofort Rückfall: Flutter-gezeichnete Tabs auf einer `LiquidGlassGroup` mit eigener `Semantics(selected:, button:)`, Morph als Überblendung (`fadeReduced`-Kurve, 0,25 s). Keine weitere Zeit in Glas-Effekte stecken. Prüfen als Alternative: die native iOS-26-Tab-Bar von `adaptive_platform_ui` mit Such-Tab (`isSearch`), sie lädt aber nur Systemsymbole und kennt keinen Langdruck (müsste gepatcht werden).

### 12.2 Navigationsleiste mit großem Titel und Listen-Umschalter (`LargeTitleNavBar`)

- **Zweck:** Wo bin ich, was kann ich hier tun, wie komme ich zurück.
- **Anatomie:** obere Zeile 44 pt: links Zurück (Glas, nur bei Push) bzw. Schließen (Sheet); rechts Toolbar-Gruppe (12.3). Darunter großer Titel (`largeTitle`, linksbündig, bis 2 Zeilen). An Tab-Wurzeln rechts in der Titelzeile der Profil-Avatar (36 pt, kein Glas). Beim Scrollen klappt der Titel in die obere Zeile ein (`headline`, eine Zeile, Ellipse) mit Scroll-Edge-Verlauf.
- **Varianten:**
  - Tab-Wurzel: großer Titel plus Avatar.
  - Push erste Ebene: großer Titel; tiefere Ebenen: nur Inline-Titel.
  - Sheet: Inline-Titel mittig, `xmark` links, `checkmark` rechts (getönt), wenn es etwas zu übernehmen gibt (K-30).
  - Foto-Kopf (Rezeptdetail): Leiste transparent über dem Foto, Glas-Variante `clear`, Titel erscheint erst beim Einklappen.
  - **Listen-Umschalter (Tab Liste):** Der Titel ist der Listenname mit `chevron.down` (13 pt Semibold, `labelSecondary`) direkt hinter dem letzten Wort. Tippen: Menü wächst aus dem Titel (12.24) mit allen Listen (Glyph, Name, offene Anzahl rechts, aktuelle Liste mit Häkchen), Trenner, "Neue Liste", "Liste beitreten", "Alle Listen".
- **Zustände:** groß, eingeklappt; mit Status-Zeile unter dem Titel (offline, ausstehende Änderungen, 12.27).
- **Maße/Tokens:** Titel beginnt bei `pageMargin`; 8 pt zwischen Titel und Metazeile; Avatar `avatarL`.
- **Barrierefreiheit:** Titel hat die Überschriften-Rolle. Umschalter: "Liste wechseln, Wocheneinkauf, 9 offen", Taste. Avatar: "Profil und Einstellungen". Zurück: "Zurück zu Rezepte".
- **Flutter (ersetzt `PaperSettingsAppBar`, `GreetingHeader`, 33 Material-`AppBar`):** eigener Sliver `LargeTitleSliver` in einem `CustomScrollView` (Flutters `CupertinoSliverNavigationBar` nutzt feste Größen und keine Tokens).

### 12.3 Toolbar (`GlassToolbar`)

- **Zweck:** Aktionen eines Screens als schwebende Glas-Knöpfe.
- **Anatomie:** Gruppe aus 1 bis 3 Knöpfen (`glassButton` 44 pt, Symbol 17 pt Medium) oder Text-Kapseln; eine gemeinsame Glasform.
- **Varianten:** oben rechts (Navigationsleiste); oben links (Zurück, Schließen); unten schwebend (Einkaufsmodus, Rezeptdetail, Kochmodus), dort mit höchstens einer getönten Hauptaktion.
- **Zustände:** normal, gedrückt (Skalierung 0,97, `springQuick`), deaktiviert (Symbol `labelTertiary`), ausgeblendet bei Tastatur (untere Varianten).
- **Barrierefreiheit:** Jeder Symbol-Knopf hat ein Label ("Teilen", "Mehr"). Large Content Viewer ab AX1.
- **Flutter (ersetzt `PaperCircleIconButton`, `ListDetailShareButton`, Zurück-Kreise):** eine `LiquidGlassGroup` pro Gruppe, Symbole aus `shoply/symbols`.

### 12.4 Eingabe-Accessory "Artikel hinzufügen" (`AddItemAccessory`)

- **Zweck:** Hinzufügen mit einem Feld, Einkaufsmodus starten. Muster: Mini-Player in Musik.
- **Anatomie (links nach rechts):** Glas-Kapsel mit `plus` (17 pt, `labelSecondary`), Textfeld (`body`, Platzhalter "Artikel hinzufügen"), `text.viewfinder` (44-pt-Ziel, Zettel importieren). 8 pt Abstand. Getönte Glas-Kapsel `cart` plus "Einkaufen" (Hauptaktion der Bodenebene). Sitzt 8 pt über der Tab-Bar, nur auf der Wurzel des Tabs Liste.
- **Bei Fokus:** Tab-Bar verschwindet, das Accessory sitzt auf der Tastatur, "Einkaufen" blendet aus. Darüber ein Vorschlags-Panel (Fläche `surfaceElevated`, `radiusCard`, `shadowFloat`, kein Glas), bis 5 Zeilen:
  1. Vorschau des Getippten: "Milch · Menge 2 · Milch & Käse" (lokal geparst, sofort).
  2. Treffer aus dem eigenen Verlauf (häufig und zuletzt gekauft, die schon offenen ausgenommen).
  3. Mit Modul Angebote: bis 3 Angebote des Markts dieser Liste (Slot `OfferSuggestionsBar`, Teil B), je eine Zeile mit gelbem Schild.
- **Verhalten:** Return fügt hinzu und behält den Fokus; Tippen auf eine Vorschlagszeile fügt hinzu. Lokales Parsen: "2 Milch", "Milch 2", "2x Milch", "500 g Mehl", "1,5 l Wasser" ergeben Menge, Einheit und Name; Kategorie lokal sofort (Schlüsselwörter, gelernte Zuordnung), KI bestätigt im Hintergrund. `text.viewfinder` öffnet ein Menü: Kamera, Fotos, Dateien.
- **Zustände:** leer, mit Text, mehrzeilig (bis 3 Zeilen, dann scrollt das Feld), fokussiert, offline (gleich; die neue Zeile trägt das Sync-Zeichen), Liste ohne offene Artikel ("Einkaufen" ausgeblendet).
- **Maße/Tokens:** Mindesthöhe 48. Höhe = max(48, Zeilenhöhe von `body` bei aktueller Textgröße × Zeilen + 2 × 13). Feld mindestens 160 pt breit. "Einkaufen" nur als Symbol-Kreis 44 pt bei schmal oder ab xxxL (Tabelle 6.3).
- **Barrierefreiheit:** Feld "Artikel hinzufügen", Hinweis "Zum Beispiel 2 Milch". Vorschläge sind Tasten mit vollem Text. "Einkaufen": "Einkaufsmodus starten". Nach dem Hinzufügen Ansage "Milch hinzugefügt, Milch und Käse".
- **Flutter (ersetzt `add_item_composer.dart`, Auslöser von `attachment_sheet.dart`):**
  - Behebt den Bug der abgeschnittenen Eingabe: kein `SizedBox(height:)`, keine Messung nach dem Frame (heute `_height`), Höhe aus Textmetrik berechnet; die native Glasform wird per Kanal aktualisiert, wenn sich die Höhe ändert.
  - `TextField(minLines: 1, maxLines: 3)` mit `textScaler` aus dem `DesignScope` (keine doppelte Skalierung, 17.2).
  - Abnahme auf echtem Gerät: iPhone 13 Pro mit Anzeigezoom "Größerer Text", AX5, fetter Text; dazu iPhone SE.

### 12.5 Inset-Sektion (`InsetSection`)

- **Zweck:** Grundbaustein für fast alle Inhalte (Listen, Einstellungen, Avo-Ergebnisse, Hinweise).
- **Anatomie:** optionaler Sektionstitel (`headline`, `label`, rechts optional Zähler in `numberS` `labelSecondary` oder schlichte Aktion), Zeilen auf `surface` mit `radiusSection`, Trennlinien in `separator` ab der Textkante, optionaler Sektionsfuß (`footnote`, `labelSecondary`).
- **Varianten:** inset (Standard); plain (randlos: Einkaufsmodus, ab AX1); einklappbar ("Erledigt (7)", "Im Wagen (5)" mit `chevron.down`/`chevron.right`, Zustand pro Liste gemerkt).
- **Zustände:** normal; Zeile gedrückt (`fillPressed`); leer (Sektion entfällt komplett, kein leerer Rahmen).
- **Barrierefreiheit:** Sektionstitel als Überschrift; einklappbare Titel sind Tasten mit Zustand "eingeklappt/ausgeklappt".
- **Flutter (ersetzt `CupertinoListSection` mit iOS-15-Radien, `_buildSettingsGroup`, `AppListTile`, `NudgeCardShell`, `AppCard`):** Sliver-Variante für lange Listen (`SliverList` mit Sektionen), keine `Column` mit allen Zeilen.

### 12.6 Listen-Zeile (`ListRow`)

- **Zweck:** eine Liste zeigen und öffnen.
- **Anatomie:** Listen-Glyph 28 pt (Kreis in Listenfarbe, weißes Symbol 15 pt), Name (`body`), Unterzeile (`subheadline`, `labelSecondary`): "9 offen · Lidl" bzw. bei Präsenz "Lena kauft gerade ein" mit `presence`-Punkt. Rechts: Avatar-Stapel 20 pt (höchstens 3 und "+n") bei geteilten Listen, `chevron.right`.
- **Varianten:** Zeile in "Alle Listen"; Menüzeile im Listen-Umschalter (ohne Chevron, offene Anzahl rechts); Zeile in Avo-Rückfragen.
- **Zustände:** normal, angeheftet (`pin` 13 pt hinter dem Namen), geteilt, jemand kauft ein, offline ausstehend.
- **Aktionen:** Tippen wählt die Liste (Tab Liste zeigt sie); Wischen nach links: "Teilen", "Löschen" bzw. "Verlassen" (mit Bestätigung, weil endgültig); Kontextmenü: Anheften, Umbenennen, Teilen, Farbe und Symbol, Löschen.
- **Barrierefreiheit:** ein Element: "Wocheneinkauf, 9 offen, Markt Lidl, geteilt mit Lena, Lena kauft gerade ein"; Wisch- und Menüaktionen als eigene Aktionen.
- **Flutter (ersetzt `_PaperListRow` in `home_screen.dart`).**

### 12.7 Abhak-Kreis (`CheckCircle`)

- **Anatomie:** leer: Ring 1,5 pt in `controlOutline`; erledigt: Füllung `action`, Häkchen 2 pt in `onAction`.
- **Varianten:** normal 24 pt in 44-pt-Ziel; Einkaufsmodus 36 pt in 56-pt-Ziel; Vorschlag ("Vielleicht auch"): gestrichelter Ring mit `plus`.
- **Zustände:** leer, erledigt, von anderen erledigt (Avatar 16 pt unten rechts am Kreis, 2 s sichtbar), ausstehend (offline: kleines `arrow.triangle.2.circlepath` 10 pt unten rechts), deaktiviert.
- **Bewegung und Haptik:** Füllen mit `springQuick` vom Mittelpunkt, leichter Impuls im selben Frame (Kapitel 10, 11).
- **Barrierefreiheit:** Teil des Zeilen-Elements; Zustand "erledigt" bzw. "nicht erledigt"; Doppeltippen hakt ab.

### 12.8 Artikel-Zeile mit Abhaken (`ItemRow`)

- **Zweck:** ein Artikel: sehen, abhaken, ändern.
- **Anatomie:** `CheckCircle`, Artikelbild 28 pt (Slot `ArticleImage`, Teil B; abschaltbar), Name (`body`, bricht um), darunter optional (`subheadline`, `labelSecondary`): Notiz und/oder "von Lena" (nur, wenn nicht man selbst). Rechts: Menge (`number`, mit Einheit "500 g", bei Menge 1 ohne Zahl) und darunter bzw. daneben das gelbe Schild (Slot `ItemOfferBadge`, Teil B).
- **Varianten:**
  - normal (in Sektion): Tippen auf den Kreis-Bereich (die vorderen 56 pt) hakt ab; Tippen auf den Rest öffnet das Artikel-Sheet (Name, Menge, Einheit, Notiz, Kategorie, Foto/Quelle, Löschen).
  - Einkaufsmodus (randlos): die ganze Zeile hakt ab; Bearbeiten über Langdruck. Kreis 36 pt in 56-pt-Ziel, Name 22 pt Semibold (wächst wie Title 2), Menge in `numberL`, Bild 36 pt, Mindesthöhe 64.
  - Vorschlag ("Vielleicht auch"): Name in `label`, Unterzeile "kaufst du etwa alle 6 Tage", Tippen setzt den Artikel auf die Liste.
  - erledigt: Name durchgestrichen in `labelSecondary`.
- **Zustände:** offen, erledigt, von anderen geändert (2 s Avatar), ausstehend (offline), Fehler ("Nicht gespeichert" mit `exclamationmark.circle` in `danger`, Tippen wiederholt), neu (wächst ein).
- **Gesten:** Wischen nach links: "Löschen" (volles Wischen löscht sofort, Rückgängig-Hinweis) und "Bearbeiten"; Langdruck: Kontextmenü (Bearbeiten, Menge ändern, Kategorie ändern, Löschen) und danach Ziehen zum Umsortieren, auch in eine andere Kategorie. Im Einkaufsmodus in "Im Wagen" Wischen nach rechts: zurückholen.
- **AX-Layout (ab AX1):** Menge und Schild unter dem Namen, Bild entfällt, Kreis oben bündig zur ersten Textzeile.
- **Barrierefreiheit:** ein Element: "Milch, Menge 2, im Angebot 0,99 Euro laut Händler, von Lena, nicht erledigt"; eigene Aktionen: Bearbeiten, Menge ändern, Verschieben, Löschen.
- **Flutter (ersetzt `list_item_tile.dart`; das Artikel-Sheet ersetzt `item_form_dialog.dart`):** `select` auf den einzelnen Artikel, `RepaintBoundary` pro Zeile, keine Netzaufrufe beim Bauen.

### 12.9 Kategorie- bzw. Gang-Abschnitt (`AisleSection`)

- **Anatomie:** Titel = Kategoriename (`headline`), rechts Anzahl offen (`numberS`, `labelSecondary`); darunter `ItemRow`s.
- **Varianten:** normal (inset); Einkaufsmodus: Titel haftet oben auf `bgPlain` mit Scroll-Edge-Verlauf ("Kühlregal 3").
- **Regeln:** Reihenfolge nach "Reihenfolge im Markt" der Liste (pro Markt gelernt bzw. eingestellt); leere Kategorien entfallen; ein Gang ohne offene Artikel klappt im Einkaufsmodus zusammen.
- **Barrierefreiheit:** Titel als Überschrift mit Anzahl ("Kühlregal, 3 offen").
- **Flutter (ersetzt `list_category_section.dart`, Drop-Zonen über das neue Umsortieren).**

### 12.10 Markt-Chip (`StoreChip`, Teil B)

- **Zweck:** Für welchen Markt ist diese Liste; Grundlage für Angebote und Gang-Reihenfolge.
- **Anatomie:** Kapsel `fill`, 8-pt-Punkt in Markenfarbe (helle Farben mit 0,5-pt-Kontur), Name (`subheadline`, `label`), optional `chevron.down` 11 pt, wenn änderbar.
- **Varianten und Zustände:** gesetzt ("Lidl"); vorgeschlagen ("Lidl?" mit gestricheltem Rand in `controlOutline`; Tippen fragt "Ist das deine Lidl-Liste?" mit "Ja" / "Anderer Markt"); kein Markt ("Markt wählen" in `labelSecondary` mit `storefront`); Markt ohne Angebote (Modul aus: Chip bleibt, nur ohne Angebote).
- **Maße:** Mindesthöhe 32 (Trefferfläche 44), Innenabstand 10 horizontal; bricht ab AX1 um.
- **Barrierefreiheit:** "Markt: Lidl, ändern".
- **Flutter:** Slot im Listenkopf (A), Inhalt von B (`store_chip*`). Ein eigener Markt-Wechsel des Nutzers schlägt jedes erkannte Signal; Standort und Lernen schlagen nur vor (nie automatisch setzen).

### 12.11 Angebots-Hinweis am Artikel (`ItemOfferBadge`, Teil B)

- **Anatomie:** gelbe Kapsel (`dealTag`, `dealTagStroke`), Preis in `numberS` `onDealTag` ("0,99 €").
- **Verhalten:** Tippen öffnet das Angebots-Sheet: Produktname, Preis, "laut Händler statt 1,79 €" (nur wenn der Händler den Vergleichspreis nennt), Grundpreis ("1,98 €/l"), "gültig bis Sa., 14. Nov.", Markt, "in deiner Region", Knopf "Preis übernehmen", Quellen-Fußnote. Keine eigene Prozentrechnung hervorheben.
- **Zustände:** sichtbar; entfällt ohne Platzreservierung, wenn das Modul aus, der Kill-Switch aktiv, die Liste ausgeblendet oder kein Angebot des Listen-Markts da ist.
- **Barrierefreiheit:** im Zeilen-Element enthalten ("im Angebot 0,99 Euro laut Händler").
- **Flutter (ersetzt `ItemOfferChip`, `item_offer_sheet.dart`).**

### 12.12 Hinweis-Zeile (`HintRow`), ersetzt alle Hinweis-Karten

- **Zweck:** ein bis zwei tagesaktuelle Hinweise auf der Startseite, ohne Banner-Lärm.
- **Anatomie:** Zeile in der Sektion "Für heute" ganz oben: Symbol (16 pt, `labelSecondary`, oder semantisch: `warning` bei Hinweis auf fehlende PLZ), Text (`callout`, `label`, bis 3 Zeilen), rechts eine schlichte Aktion ("Hinzufügen", "Öffnen") oder `chevron.right`.
- **Inhalte** (je ein Widget von Teil B, Anordnung durch Teil A, höchstens 2 sichtbar, nach Relevanz):
  - Ersparnis der Liste ("4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 € gespart, in deiner Region"), nur Modul Angebote und echte PLZ;
  - Markt-Vorschlag ("Du bist bei Lidl. Lidl-Liste öffnen?"), nie automatisch umschalten;
  - Wochenplan heute ("Heute im Plan: Ofengemüse mit Feta");
  - Kalorien ("Noch 640 kcal heute · Ideen fürs Abendessen");
  - Kosten teilen ("Lena schuldet dir 4,20 € · Erledigt?");
  - Einkauf teilen ("Wocheneinkauf mit Lena teilen? Ca. 42 €");
  - persönlicher Prospekt ("5 Sachen, die du oft kaufst, sind im Angebot");
  - einmalige Tipps und das Pro-Angebot nach dem ersten Aha-Moment (Kapitel 16).
- **Zustände:** sichtbar; ausgeblendet für heute bzw. dauerhaft (Wischen nach links "Ausblenden", Kontextmenü "Heute ausblenden" / "Nicht mehr zeigen"); nach Erledigen verschwindet die Zeile mit `springStandard`.
- **Regel gegen Layout-Sprünge:** Welche Hinweise erscheinen, steht beim ersten Frame aus dem Cache fest. Neu berechnete Hinweise erscheinen erst beim nächsten Öffnen des Tabs, nie während man liest.
- **Barrierefreiheit:** ein Element mit Aktion; Ausblenden als eigene Aktion.
- **Flutter (ersetzt `nudge_card.dart`, Avo-Hinweisstreifen, die sechs Karten der Startseite; Inhalte bleiben B-Widgets, nur ihre Form ändert sich).**

### 12.13 Rezept-Karte groß und klein (`RecipeCard`)

- **Anatomie groß:** Foto 4:3 (frei stehend `radiusCard`, in einer Sektion oben `radiusSection`), darunter auf `surface`: Titel (`title3`, bis 2 Zeilen), Metazeile (`subheadline`, `labelSecondary`: "35 Min · 2 Portionen · 520 kcal", kcal nur mit Modul Kalorien), optional Hinweis "Für dich angepasst" bzw. Allergie (`warning` mit Symbol), rechts `bookmark` als schlichter Knopf.
- **Varianten:** Hero "Rezept der Woche" (16:10, randlos, Titel auf Verlauf im Foto); klein als Kachel (160 pt breit, Foto 4:3, Titel `subheadline` Semibold, 2 Zeilen, Meta `caption1`); Zeile (Thumbnail 56 pt mit `radiusThumb`, Titel `headline`, Meta `subheadline`); Typo-Karte (9.6).
- **Zustände:** Foto lädt (`photo_color`-Fläche), kein bzw. schlechtes Foto (Typo-Karte), gemerkt (`bookmark.fill` in `action`), angepasst, Allergen.
- **Bewegung:** Zoom-Übergang ins Detail (10.2).
- **Barrierefreiheit:** ein Element: "Ofengemüse mit Feta, 35 Minuten, 2 Portionen, gemerkt"; Aktion "Merken"/"Nicht mehr merken".
- **Flutter (ersetzt `FeaturedRecipeCard`, `RecipeImageCard`, `DietAwareRecipeCard`, `RecipeGridCard`, `RecipeActionCard`):** `CachedNetworkImage` mit `memCacheWidth`; Teil B nutzt dieselbe Komponente im Wochenplan.

### 12.14 Fortschrittsring (`ProgressRing`)

- **Anatomie:** Ring mit Spur in `fill` und Wert in `health` (Kalorien, Wasser) oder `label` (sonst); Strichstärke 10 % des Durchmessers (mindestens 3 pt); in der Mitte optional `numberXL` und Einheit.
- **Varianten:** 24 pt (Sperrbildschirm, Widget), 44 pt (Zeilen), 120 pt (Kalorien-Tab), 160 pt (Kalorien bei groß).
- **Zustände:** 0 bis 100 %; über 100 %: Ring voll, Text "120 kcal drüber" in `warning` mit `exclamationmark.triangle.fill` (nie nur Farbe).
- **Bewegung:** folgt der Zahl mit `springDigits`.
- **Barrierefreiheit:** ein Element "Kalorien heute, 640 von 2.000 übrig"; Änderungen höflich angesagt.
- **Flutter (ersetzt `CalorieRing`, `StepProgressRing`).**

### 12.15 Rollende Zahl (`RollingNumber`)

- **Zweck:** Markenmoment für jede sich ändernde Zahl ("5 von 11", kcal, Portionen, Mengen, gespart).
- **Anatomie:** jede Ziffer in eigenem `ClipRect` mit `Transform.translate`; das Ganze in einer `RepaintBoundary`; tabellarische Ziffern.
- **Verhalten:** nur geänderte Ziffern rollen, Richtung nach Änderung, `springDigits`. Sekundentakte (Timer) rollen nicht, sie wechseln.
- **Reduce Motion:** Überblendung der ganzen Zahl.
- **Barrierefreiheit:** liest nur den Endwert; im Einkaufsmodus als Live-Region ("5 von 11 erledigt").

### 12.16 Diagramm (`BarChart`, `LineChart`)

- **Regeln:** eine Frage, eine Datenreihe (4.7). Balken mit 4 pt Radius oben; Linie 2 pt; Zielmarke gestrichelt in `labelSecondary`; Vergleichsperiode in `fill`; Achsen in `caption1` `labelSecondary`; der heutige Tag wird über die fette Achsenbeschriftung markiert, nicht über eine zweite Farbe.
- **Interaktion:** Ziehen über das Diagramm zeigt den Wert des Punkts in einer Zeile über dem Diagramm (Auswahl-Haptik pro Punkt).
- **Zustände:** keine Daten (ein Satz statt Nullen: "Noch keine Woche erfasst."), Teil-Daten (ungeloggte Tage leer, nicht 0).
- **Barrierefreiheit:** Zusammenfassung als Satz ("Diese Woche im Schnitt 1.840 kcal, Ziel 2.000") plus Werte pro Balken als eigene Elemente.
- **Flutter (ersetzt `WeeklyCaloriesStrip`, `_WeekBars`, `WeightChart`, Wochentags-Diagramm im Verlauf):** `CustomPainter`, kein Diagramm-Paket nötig.

### 12.17 Nährwertzeile (`NutritionRow`)

- **Anatomie:** vier Spalten wie in Health: Wert (`numberL`), Einheit (`footnote`, `labelSecondary`), Bezeichnung (`caption1`, `labelSecondary`): "540 kcal", "32 g Protein", "48 g Kohlenhydrate", "21 g Fett".
- **Varianten:** 2 × 2 bei schmal oder ab xxxL; mit Fußnote "pro Portion, geschätzt", wenn KI-geschätzt.
- **Flutter (ersetzt `NutritionInfoWidget` und die `MacroBar`-Zeile im Detail).**

### 12.18 Segment-Steuerung (`SegmentedControl`)

- **Anatomie:** Kapsel-Spur `fill`, Daumen `surface` (hell) bzw. #636366 (dunkel), Beschriftung `subheadline` Semibold; 2 bis 4 Segmente; Mindesthöhe 36 (Trefferfläche 44).
- **Verhalten:** Daumen gleitet mit `springQuick`; Wischen über die Segmente folgt dem Finger, Auswahl-Haptik beim Wechsel per Wischen.
- **AX:** passen die Beschriftungen nicht in eine Zeile, wird daraus ein Pull-down-Menü.
- **Flutter:** Flutter-gezeichnet, keine native View (K-31).

### 12.19 Chips und Filter (`FilterChip`)

- **Anatomie:** Kapsel `fill`, Text `subheadline` `label`; gewählt: `actionFill`, Text `action`, führendes `checkmark` 13 pt.
- **Regeln:** eine waagerecht scrollende Zeile bis xxL, darüber `Wrap`; keine Emojis, keine Farbe pro Kategorie; Mehrfachauswahl mit UND-Verknüpfung, "Zurücksetzen" als schlichte Aktion am Ende.
- **Maße:** Mindesthöhe 32, Trefferfläche 44.
- **Barrierefreiheit:** Taste mit Zustand "ausgewählt".
- **Flutter (ersetzt Emoji-Kategorie-Kacheln, Filter-Chips in Rezepten, Chips im Essen-Sheet).**

### 12.20 Buttons (`AppButton`)

| Variante | Aussehen | Wann |
|---|---|---|
| Prominent | Kapsel `action`, Text `headline` in `onAction`, Mindesthöhe 50, 20 pt Innenabstand | eine Hauptaktion pro Screen ("14 Tage gratis testen", "Zutaten auf Liste") |
| Grau | Kapsel `fill`, Text `headline` in `label` | Nebenaktion neben der Hauptaktion ("Kochen") |
| Glas | native Glas-Kapsel oder -Kreis (12.3), getönt nur für die Hauptaktion einer Bedienebene | schwebende Bedienebene |
| Schlicht | Text in `action` (`body` bzw. `headline`), ohne Fläche, Trefferfläche 44 | Aktionen in Zeilen und Fußnoten ("Widerrufen", "Alle anzeigen") |
| Destruktiv | Text in `danger`; gefüllt `danger` nur in Löschen-Rückfragen | Löschen, Verlassen, Abmelden |

- **Größen:** groß 50, mittel 44, klein 34 sichtbar mit 44 Trefferfläche.
- **Zustände:** normal, gedrückt (Skalierung 0,97 und 90 % Deckkraft, beim Berühren, nicht beim Loslassen), deaktiviert (Fläche `fill`, Text `labelTertiary`), arbeitet (Beschriftung bleibt, kleiner Fortschrittsindikator ersetzt das Symbol, Breite bleibt gleich).
- **AX:** Text bricht um, Höhe wächst; zwei Buttons nebeneinander werden untereinander gestellt.
- **Flutter (ersetzt `AppButton`, `AppOutlineButton`, `PaperPrimaryButton`, `PaperOutlineButton`, `PaperSaveButton`, `LiquidGlassFilledButton`, `LiquidGlassOutlinedButton`, Material `ElevatedButton`).**

### 12.21 Stepper (`ValueStepper`)

- **Anatomie:** Kapsel `fill`: `minus`, Wert (`RollingNumber` in `number`), `plus`; Knöpfe je 44 pt.
- **Zustände:** an den Grenzen deaktiviert (`labelTertiary`); Langdruck wiederholt.
- **Haptik:** Auswahl pro Schritt.
- **Barrierefreiheit:** einstellbares Element ("Portionen, 2"), Wischen hoch/runter ändert.
- **Flutter (ersetzt `ServingsStepper`, Portionen-Dialog, Portionen-Raster im Kochmodus).**

### 12.22 Zeilen für Einstellungen (`ToggleRow`, `NavRow`, `ValueRow`)

- **Anatomie:** optional führendes Symbol (frei, 17 pt, `labelSecondary`), Titel (`body`), optional Unterzeile (`subheadline`, `labelSecondary`); rechts Schalter (`ToggleRow`), Wert und `chevron.right` (`NavRow`) oder nur Wert (`ValueRow`).
- **Schalter:** Flutter-gezeichnet (`CupertinoSwitch` mit Spur `action`), die ganze Zeile schaltet. Keine nativen Schalter in Listen (K-31).
- **Varianten:** destruktive Zeile (Text `danger`, eigene Sektion, z. B. "Abmelden", "Konto löschen"); Pro-Zeile (mit `ProBadge`).
- **Barrierefreiheit:** Schalter-Zeile ist ein Element mit Zustand "Ein/Aus".
- **Flutter (ersetzt `_buildSettingsGroup`, `Switch.adaptive`, `AdaptiveSwitch` in Listen).**

### 12.23 Sheet mit Detents (`AppSheet`)

- **Anatomie:** Griff (36 × 5, `labelTertiary`), Kopf (12.2, Variante Sheet), Inhalt auf `bgGroupedElevated`.
- **Detents:** mittel (etwa halbe Höhe, mindestens so hoch wie der Inhalt ohne Scrollen) und groß; Sheets für kurze Aufgaben nur mittel.
- **Material:** in Teilhöhe schwebend mit 8 pt Abstand zum Rand, `radiusSheet`, Glas-Hintergrund; bei groß fest, `radiusSheetFull` oben, Bildschirm dahinter 0,96 und `scrim`.
- **Verhalten:** Ziehen 1:1, Loslassen mit Wurfprojektion und `springFling`; Wischen nach unten schließt; mit ungespeicherten Änderungen fragt ein Aktionsblatt "Änderungen verwerfen?"; Tastatur hebt das Sheet auf groß.
- **Barrierefreiheit:** modal, Fokus springt hinein; Zwei-Finger-Z-Geste schließt; Griff ist eine Taste "Größe ändern".
- **Flutter (ersetzt `showAppBottomSheet`, alle Material-`showModalBottomSheet`, die zentrierten Dialoge `SelectListBottomSheet`, `item_form_dialog.dart`, Teilen-Dialog).**

### 12.24 Menü und Kontextmenü (`AppMenu`)

- **Anatomie:** Glasfläche (`radiusCard`), Zeilen mindestens 44 pt: Titel (`body`) links, Symbol rechts (iOS-Muster), Gruppen durch 8-pt-Bänder getrennt, aktuelle Auswahl mit `checkmark` links, destruktive Einträge in `danger` am Ende.
- **Verhalten:** wächst aus dem Auslöser (`springMenu`, Ursprung am Knopf); Kontextmenü per Langdruck auf Zeilen (die Zeile wird hervorgehoben, das Menü erscheint darunter bzw. darüber); Tippen daneben schließt.
- **Barrierefreiheit:** jeder Kontextmenü-Eintrag zusätzlich als eigene VoiceOver-Aktion der Zeile.
- **Flutter (ersetzt `CupertinoActionSheet`-Menüs, `list_detail_menu.dart`, Anhang-Menü):** Flutter-Inhalt auf nativer Glasfläche, die nur existiert, solange das Menü offen ist; native Menüs über `adaptive_platform_ui` nur, wo der Auslöser selbst nativ ist.

### 12.25 Suche (`SearchField`)

- **Anatomie:** Kapsel `fill`, `magnifyingglass` 15 pt `labelSecondary`, Feld `body`, Löschen `xmark.circle.fill`; bei Fokus rechts "Abbrechen" (schlicht).
- **Varianten:** im Inhalt unter dem großen Titel (Rezepte, Einstellungen, Alle Listen, Angebote der Woche), scrollt mit; globale Suche im Feld "Frag Avo" bzw. hinter dem Lupen-Kreis (12.1, Kapitel 01).
- **Verhalten:** lokale Ergebnisse ohne Verzögerung, Netzsuche entprellt 300 ms; Ergebnisse ersetzen den Inhalt darunter, gruppiert in Sektionen.
- **Zustände:** leer, Treffer, keine Treffer (leerer Zustand "suchend"), offline (nur lokale Treffer, Hinweiszeile).
- **Flutter (ersetzt Glas-Suchkapsel im Rezepte-Tab, eigene Suchfelder in Angebote, Ersteller):** kein Glas im Inhalt.

### 12.26 Leerer Zustand (`EmptyState`)

- **Anatomie:** Maskottchen-Pose (96 pt) oder Symbol (48 pt Light), Titel (`title3`), ein Satz (`body`, `label`), eine Aktion (prominent oder schlicht).
- **Regeln:** steht dort, wo der Inhalt stünde (nicht zwingend bildschirmmittig); konkrete Sätze ("Noch keine gespeicherten Rezepte. Tippe auf das Lesezeichen bei einem Rezept."); ab AX1 ohne Maskottchen.
- **Flutter (ersetzt `EmptyState`, `AppEmptyState`, 140-pt-Leerboxen).**

### 12.27 Fehler- und Offline-Hinweis (`StatusRow`)

- **Anatomie:** Zeile unter dem Titel bzw. am Anfang der betroffenen Sektion: Symbol (`icloud.slash` in `labelSecondary`, `exclamationmark.circle` in `danger`), Text (`subheadline`, `label`), optional schlichte Aktion "Erneut versuchen".
- **Varianten:** offline ("Offline. Änderungen werden gespeichert, sobald du wieder online bist."), ausstehend ("3 Änderungen warten"), Fehler einer Sektion, fehlende Berechtigung ("Standort ist aus. In Einstellungen erlauben").
- **Regeln:** überall sichtbar, wo es zählt, auch in der Liste und im Einkaufsmodus (heute fehlt der Hinweis dort); nie über Titel gelegt; nie rohe Fehlermeldungen; nur bei echtem Fehlschlag ohne lokalen Stand ein Vollflächen-Fehler im Layout des leeren Zustands.
- **Flutter (ersetzt `_OfflineBanner`, "Fehler beim Laden"-Boxen, rote Snackbars).**

### 12.28 Rückgängig-Hinweis (`UndoToast`)

- **Anatomie:** schwebende Glas-Kapsel 8 pt über der Bodenebene: Text (`subheadline`, `label`: "Milch gelöscht"), schlichte Aktion "Widerrufen".
- **Verhalten:** 4 s sichtbar (mit aktivem VoiceOver 10 s und Ansage); ein neuer Hinweis ersetzt den alten; Wischen nach unten schließt; Reduce Motion: Überblendung.
- **Varianten:** mit Aktion (Rückgängig); reiner Status nur, wenn das Ergebnis sonst nicht sichtbar ist ("Liste geteilt").
- **Flutter (ersetzt 131 `SnackBar(`):** ein globaler Host im `builder` (K-20); der `ScaffoldMessenger` bleibt technisch bestehen, wird aber nicht mehr benutzt.

### 12.29 Avatar und Präsenz (`Avatar`, `PresenceLine`)

- **Avatar:** Bild (gecacht, in Anzeigegröße dekodiert) oder Initialen (`headline`-Gewicht, `label` auf `fill`); Größen 20, 28, 36, 64; Stapel überlappt 6 pt mit 2-pt-Ring in Flächenfarbe.
- **Präsenz:** Avatar mit 8-pt-Punkt `presence` unten rechts und Text "Lena kauft gerade ein" (`subheadline`). Der Punkt pulsiert beim Erscheinen einmal, danach statisch.
- **Barrierefreiheit:** "Lena kauft gerade ein"; Live-Abhaken anderer wird höflich angesagt ("Lena hat Milch abgehakt").
- **Flutter (ersetzt `CircleAvatar`/`NetworkImage`-Stellen, `AuthorAvatar`).**

### 12.30 Pro-Kennzeichnung (`ProBadge`)

- **Anatomie:** Kapsel "Pro" (`caption2` Semibold), Text `action` auf `actionFill`, 6 pt horizontal, Mindesthöhe 18; wächst bis AX2.
- **Ort:** hinter dem Namen des Features in Zeilen und Titeln. Nie bei Angeboten.
- **Verhalten:** Tippen öffnet die Paywall, die aus der Kapsel bzw. dem Element wächst, mit diesem Feature oben.
- **Barrierefreiheit:** "Pro-Funktion" wird an das Label der Zeile angehängt.

### 12.31 Paywall-Bausteine

Aufbau von oben (Sheet groß, Hintergrund `bgGrouped`):

1. **Schließen:** Glas-Knopf `xmark` oben links, sofort sichtbar (K-23). "Käufe wiederherstellen" steht in den Links unten.
2. **`PaywallHero`:** eigenes, kuratiertes Essensfoto 16:10 randlos (mit `photo_color`), unten weicher Verlauf in den Hintergrund.
3. **Titel:** "{pro}" in `title1`, ein Satz Nutzen in `body` (Text legt der Owner fest).
4. **`ProFeatureRow`s** in einer Sektion: Symbol 22 pt in `action` (frei), Titel `headline`, ein Satz `subheadline` `labelSecondary`. Kommt man über ein gesperrtes Feature, steht es oben mit `actionFill` hinterlegt. Inhalt aus der Konfiguration `pro_features` (Kapitel 16).
5. **`PlanRow`s** (Auswahl, eine Sektion): "Jährlich", "29,99 € pro Jahr · 2,50 € im Monat", rechts kleine Kapsel "16 % günstiger" (aus den StoreKit-Preisen berechnet, nicht fest); "Monatlich", "2,99 € im Monat". Gewählt: `checkmark.circle.fill` in `action`, sonst Ring in `controlOutline`. Jährlich vorausgewählt.
6. **`TrialTimeline`:** drei Punkte auf einer 2-pt-Linie in `fill`: "Heute: alles freigeschaltet", "Tag 12: Erinnerung per Mitteilung", "Tag 14: Abo beginnt, 29,99 €".
7. **Hauptaktion** (prominent): "14 Tage gratis testen" bzw. "Abonnieren", wenn die Testphase schon genutzt wurde (StoreKit-Berechtigung).
8. **Fußnote** (`footnote`, `labelSecondary`): "Danach 29,99 € pro Jahr. Jederzeit in den iPhone-Einstellungen kündbar."
9. **Links** (schlicht, `footnote`): "Käufe wiederherstellen · Nutzungsbedingungen · Datenschutz" (Pflicht für App Review 3.1.2).

- **Zustände:** Produkte laden (Preise als "…" im reservierten Platz, Hauptaktion deaktiviert, kein Spinner); Fehler ("Der App Store ist gerade nicht erreichbar. Erneut versuchen"); Kauf läuft (Fortschritt im Button, Rest deaktiviert); Erfolg (Erfolgsmoment, dann schließen); schon Pro ("Du hast {pro}" plus "Abo verwalten"); Testphase genutzt.
- **Verboten:** Countdown, durchgestrichene Fantasiepreise, verzögertes Schließen, Maskottchen, Angebote als Vorteil.
- **Barrierefreiheit:** Pläne als Auswahlgruppe; Zeitleiste als Liste.
- **Flutter (ersetzt `subscription_screen.dart`).** Preise immer aus StoreKit.

### 12.32 Chat-Blase und Avo-Antwort (`UserBubble`, `AvoMessage`, `AvoResultRow`, `AvoConfirmCard`)

- **`UserBubble`:** rechts, `fill`, `radiusCard` (einzeilig Kapsel), `body` `label`, höchstens 80 % Breite.
- **`AvoMessage`:** links, ohne Blase, `body` in `label`, markierbar; erscheint Wort für Wort (Streaming, je Wort `fadeReduced`). VoiceOver liest "Avo:" voran.
- **`AvoResultRow`** (Ergebniszeile wie eine Wallet-Transaktion, in einer `InsetSection`): Symbol der Aktion (20 pt, frei: `plus`, `checkmark`, `trash`, `flame`, `calendar`), Titel (`body`: "3 Artikel zu Wocheneinkauf hinzugefügt"), Unterzeile ("Milch, Eier, Gurken"), rechts schlicht "Widerrufen" oder "Ansehen". Nach Widerrufen: "Rückgängig gemacht" in `labelSecondary`.
- **Rückfragen:** Auswahl als `ListRow`s bzw. Zeilen ("Welche Liste?").
- **Rezepte:** als Rezept-Zeile (12.13).
- **Schätzungen** (Essen, Nährwerte): Zeile mit "geschätzt" und Bearbeiten vor dem Speichern; nie direkt gespeichert.
- **`AvoConfirmCard`** (nur für Löschen): neutral, ohne Figur, Kern im Zustand `neutral`; Text "Liste "Party" mit 14 Artikeln löschen? Das lässt sich nicht rückgängig machen."; Knöpfe gefüllt `danger` "Löschen" und grau "Abbrechen". Per Stimme reicht "Ja" nicht; es braucht den Tipp.
- **Leer:** drei Vorschläge als Zeilen passend zum Kontext ("Zutaten für Ofengemüse auf Wocheneinkauf", "Was koche ich heute?", "Trag mein Mittagessen per Foto ein").
- **Flutter (ersetzt `avo_chat_widgets.dart`, `avo_payload_cards.dart`; Teil B).**

### 12.33 Sprachmodus-Visual (`AvoVoiceStage`, Teil B)

- **Anatomie:** Sheet groß in Systemdarstellung (K-37); Mitte Avo-Kern 120 pt; darüber das Live-Transkript (`title2` Regular, höchstens 4 Zeilen, ältere Zeilen blenden nach oben aus); darunter Avos Antwort (`title2`), Wort für Wort, gesprochen; Ergebniszeilen (12.32) erscheinen über der Steuerung; unten Glas-Gruppe: `mic.slash` (stumm), `camera` (Essen fotografieren, Zettel), `xmark` (Beenden).
- **Zustände:** hört zu, denkt, spricht, stumm, Rückfrage Löschen (wartet auf Tipp), Fehler ("Ich höre dich gerade nicht. Prüfe deine Verbindung."), Berechtigung fehlt (Erklärung vor der Systemabfrage, Kapitel 13).
- **Verhalten:** Antippen des Kerns unterbricht die Sprachausgabe sofort; Halten des Avo-Kreises startet ihn direkt (Loslassen sendet nicht automatisch; Beenden über `xmark` oder Pause).
- **Reduce Motion:** Kern nur über Helligkeit.
- **Barrierefreiheit:** Ansage "Avo hört zu"; Transkript als Live-Region; mit VoiceOver alternativ "Zum Senden doppeltippen".

### 12.34 Bestätigungsdialog (`confirmDestructive`)

- **Nur für endgültiges Löschen und Gleichwertiges:** Liste löschen, Liste verlassen, Mitglied entfernen, Rezept löschen, Entwurf verwerfen, Kategorie löschen, Einkauf aus dem Verlauf löschen, Challenge abbrechen, Konto löschen, Abmelden mit noch nicht gesendeten Änderungen.
- **Nie für:** Artikel löschen, abhaken, Einkaufsmodus oder Kochmodus verlassen (Fortschritt bleibt erhalten), Sheet schließen ohne Änderungen.
- **Muster:** nativer Alert; Titel als Frage mit Objekt ("„Party“ löschen?"), Nachricht mit Folge ("Die Liste und 14 Artikel werden für alle Mitglieder gelöscht. Das lässt sich nicht rückgängig machen."), Knöpfe "Abbrechen" und rot das Verb ("Löschen").
- **Flutter:** `confirm_dialog.dart` bleibt (erfüllt die Regel schon), Texte nach diesem Muster.

### 12.35 Erfolgsmoment (`SuccessMoment`)

- **Anatomie:** Überlagerung in der Mitte: Maskottchen feiernd 120 pt, `title2` ("Einkauf gespeichert."), Unterzeile `subheadline` `labelSecondary` ("11 Artikel · ca. 3,20 € durch Angebote gespart, laut Händler"; Ersparnis nur mit Modul Angebote).
- **Verhalten:** erscheint erst, nachdem ein Sheet geschlossen ist, nie darüber; Skalierung aus 0,9 mit `springCelebrate`, Erfolgs-Haptik im selben Frame; nach 1,5 s ausblenden; Tippen schließt sofort; einmal pro Ereignis.
- **Reduce Motion:** nur Einblenden. **VoiceOver:** Ansage statt visueller Zeit.

### 12.36 Maskottchen (`Mascot`)

`Mascot(pose:, size:)` mit Posen aus 3.3, Vektor, dekorativ für VoiceOver. Ersetzt `lib/core/mascot/avo_mascot.dart` (PNG, quadratische Box, Sprechblase mit fester Schrift).

---

## 13. Zustands-Regeln

| Zustand | Regel |
|---|---|
| **Start** | Erster Flutter-Frame in `bgGrouped` der Systemdarstellung. Theme, Sprache, Module, Pro-Status (zuletzt bekannt), Listen und Artikel der Liste von heute kommen aus dem lokalen Stand, der vor `runApp` geladen ist (SharedPreferences einmal vorladen, Provider-Overrides; Teil B in `main.dart`). Kein Neuaufbau der App nach dem ersten Frame (`ValueKey('$themeMode-$languageCode')` entfällt). |
| **Laden mit lokalem Stand** | Inhalt sofort aus dem lokalen Stand; Abgleich im Hintergrund; neue Werte ersetzen alte ohne Layout-Sprung (Zahlen rollen, Zeilen wachsen ein). Kein Indikator. |
| **Allererstes Laden ohne lokalen Stand** | Nur dann: Skelett in Form des Inhalts als ruhige Tonflächen (`fill`) ohne Schimmer, höchstens bis zur ersten Antwort. Nie Vollbild-Spinner. |
| **Nachladende Inhalte** | Was oberhalb der Leseposition erschiene, erscheint erst beim nächsten Öffnen (Hinweis-Zeilen) oder in vorab reservierter Fläche. Nachgeladenes unterhalb blendet ein (`fadeReduced`). |
| **Nutzer-Aktionen** | optimistisch: sofort sichtbar, Abgleich im Hintergrund, bei Fehler zurückrollen mit Hinweis (`StatusRow` an der Zeile oder Rückgängig-Leiste) und Fehler-Haptik. Länger dauernde, vom Nutzer gestartete Aufgaben (Kauf, Foto-Import, Avo) zeigen Fortschritt am Auslöser bzw. im Avo-Kern, nie bildschirmfüllend. |
| **Leer** | `EmptyState` mit einem Satz und einer Aktion. Statt "0" ein Satz ("Alles erledigt. Schön."). |
| **Fehler** | ein Satz in Alltagssprache, "Erneut versuchen"; nie rohe Ausnahmen; gecachter Inhalt bleibt sichtbar. |
| **Offline** | `StatusRow` unter dem Titel in jedem betroffenen Screen (auch Liste und Einkaufsmodus); Schreiben geht in eine dauerhafte Warteschlange (Abhaken im Laden ohne Netz geht nicht verloren); ausstehende Zeilen tragen das Sync-Zeichen; Netz-only-Funktionen (Avo, Angebote, Rezeptsuche online) zeigen an ihrem Ort "Braucht eine Verbindung". |
| **Modul aus** | Alle Elemente des Moduls verschwinden ohne Lücke (Kapitel 15). Ein direkter Aufruf einer Modul-Route (Deep Link, Widget, Mitteilung) öffnet ein Sheet "Kalorien ist ausgeschaltet" mit "Einschalten" und "Nicht jetzt". |
| **Kill-Switch Angebote** | wie Modul aus, zusätzlich ohne Hinweis und ohne Schalter (15.3). |
| **Pro gesperrt** | echte Vorschau mit eigenen Daten statt Schloss-Bildschirm; die Pro-Aktion trägt `ProBadge` und öffnet die Paywall aus dem Element. |
| **Pro-Status unbekannt** | gilt als der zuletzt bekannte Status; bis zur Klärung werden keine Pro-Hinweise gezeigt (heute flackern Sperren beim Start). |
| **Berechtigung nötig** (Standort, Kamera, Mikrofon, Spracherkennung, Health, Mitteilungen) | erst im Moment des Nutzens; vorher ein kurzes Sheet mit einem Satz Nutzen und "Weiter" / "Nicht jetzt"; danach die Systemabfrage. Abgelehnt: `StatusRow` mit "In Einstellungen erlauben". Mitteilungen erst beim ersten Teilen einer Liste oder beim Einschalten einer Erinnerung. |
| **Geteilte Änderungen** | live per Realtime; nach Rückkehr aus dem Hintergrund (über 2 s) einmal nachladen, weil Realtime verpasste Ereignisse nicht nachliefert. Ein von anderen gelöschter Artikel verschwindet ohne Fehlermeldung. |

---

## 14. Barrierefreiheit

### 14.1 Verbindliche Regeln

1. **Dynamic Type bis AX5** in jedem Screen; Layout fließt mit (5.3, 6.4); Umbruch statt Abschneiden.
2. **Anzeigezoom (320 pt Breite)** wird wie jede andere Breite behandelt (6.3).
3. **Trefferflächen** mindestens 44 × 44 pt, im Einkaufsmodus 56.
4. **Kontrast** mindestens WCAG AA (Text 4,5:1, große Schrift und Bedienelemente 3:1); Werte in Kapitel 4; erhöhter Kontrast hat eigene Werte (4.5).
5. **Farbe nie allein** (4.2).
6. **VoiceOver:** jede Zeile ein Element mit vollständigem Satz; Symbole beschriftet oder ausgeblendet; Tabs mit Tab-Rolle; Überschriften als Überschriften; Kontextmenü- und Wischaktionen zusätzlich als eigene Aktionen; sinnvolle Reihenfolge (oben nach unten, Bodenebene zuletzt); Ansagen für Live-Änderungen (abgehakt von anderen, hinzugefügt, Fehler); Zwei-Finger-Z schließt Sheets und Cover.
7. **Sprachsteuerung:** sichtbarer Text = Label (Knopf "Einkaufen" heißt auch für Sprachsteuerung "Einkaufen").
8. **Reduce Motion** (10.4), **Transparenz reduzieren** (8.3), **Kontrast erhöhen** (4.5), **Fetter Text** (5.2).
9. **Large Content Viewer** für Tab-Bar und Glas-Knöpfe ab AX1.
10. **Intelligente Umkehrung:** Flutter kann Fotos und Maskottchen nicht ausnehmen; bekannte Einschränkung, dokumentiert.
11. **Keine Zeitlimits** außer Rückgängig-Hinweis (mit VoiceOver verlängert) und Erfolgsmoment (dekorativ).

### 14.2 Umsetzung in Flutter

- `DesignScope` stellt bereit: Textgrößen-Kategorie, `boldText`, `highContrast`, `disableAnimations`, `reduceTransparency` (nativer Kanal), Breitenklasse.
- Semantik mit `Semantics`/`MergeSemantics`, eigene Aktionen über `CustomSemanticsAction`, Ansagen über `SemanticsService.announce` (heute nur 2 `Semantics(`-Stellen).
- Large Content Viewer für native Tab-Bar nativ; für Flutter-Glas-Knöpfe über den nativen Kanal oder `Tooltip`-Ersatz ab AX1.

### 14.3 Prüfmatrix

Jeder Screen aus Kapitel 01 (Screen-Karte) läuft durch diese Matrix. Teil A baut das Gerüst in `test/layout/` (Helfer rendert einen Screen in allen Kombinationen), Teil B nutzt es für seine Screens.

| Dimension | Werte | Kriterium | Wie geprüft |
|---|---|---|---|
| Breite | 320, 375, 390, 402, 440 pt | kein Überlauf, kein horizontales Scrollen, kein abgeschnittener Text | Widget-Test: `FlutterError` bei Überlauf schlägt fehl; Golden-Bilder zur Sichtprüfung |
| Textgröße | L, xxxL, AX3, AX5 | Text bricht um, Zeilen stapeln, Trefferflächen bleiben | Widget-Test mit gesetzter Kategorie; Golden-Bilder |
| Fetter Text | an, aus | keine Überläufe | Widget-Test (`MediaQueryData(boldText: true)`) |
| Darstellung | hell, dunkel; je mit erhöhtem Kontrast | Kontrast AA | `expectLater(tester, meetsGuideline(textContrastGuideline))` |
| Trefferflächen | alle | mindestens 44 pt, beschriftet | `meetsGuideline(iOSTapTargetGuideline)`, `meetsGuideline(labeledTapTargetGuideline)` |
| Reduce Motion | an | keine Verschiebungen, Zeilen springen nicht weg | Widget-Test mit `disableAnimations: true` |
| Transparenz reduzieren | an | Glas wird fest | Gerät (Stichprobe) |
| VoiceOver | an | Reihenfolge, Labels, Aktionen, Ansagen | Gerät: Startseite, Liste, Einkaufsmodus, Rezeptdetail, Avo, Paywall, Onboarding |
| Geräte-Abnahme | iPhone 13 Pro mit Anzeigezoom "Größerer Text" + AX3 + fetter Text; iPhone SE | Bug der Mutter behoben; Hauptabläufe bedienbar | echtes Gerät, Screenshots in die Status-Datei |
| Leistung | iPhone 13 Pro, Profile-Modus | 8,3 ms Ziel, nie über 16 ms | DevTools-Zeitleiste: Scrollen Liste mit 60 Artikeln, Abhaken in Serie, Tab-Wechsel, Rezepte-Tab |

---

## 15. Modulsystem

### 15.1 Kern und Module

**Kern (immer an, nicht abschaltbar):** Listen (inklusive Teilen, Präsenz, Einkaufsmodus, Foto-Import, Vorschläge "Vielleicht auch"), Rezepte (inklusive Community, Kochmodus, Erstellen), Verlauf der Einkäufe (inklusive Monatsrückblick ohne Ersparnis), Märkte pro Liste (Markt-Chip, Reihenfolge im Markt).

| Modul | Standard (Vorschlag, Owner entscheidet: F-04) | Bringt | Verschwindet beim Ausschalten |
|---|---|---|---|
| **Preise & Angebote** | an | gelbe Schilder, Angebote beim Tippen, Ersparnis-Zeile, Angebots-Sheet, Angebote der Woche, persönlicher Prospekt, Rezept-Angebote, Ersparnis im Verlauf und Erfolgsmoment, PLZ und Lieblingsmärkte | alles links; Abschnitt "Angebote der Woche" in Alle Listen; Hinweis-Zeilen Ersparnis und Prospekt; Avo-Werkzeuge für Angebote; Ersparnis-Zeile im großen Listen-Widget. Der Markt-Chip bleibt. |
| **Wochenplan** | an | Tab Plan, "Heute im Plan", "Zum Wochenplan" im Rezept, Plan-Widget, Siri "Was gibt's heute?", Avo-Werkzeuge Plan | Tab, Hinweis-Zeile, Menüeintrag im Rezept, Widget-Inhalt ("Wochenplan ist ausgeschaltet"), Siri-Satz antwortet entsprechend, Avo-Werkzeuge |
| **Kalorien & Gesundheit** | aus | Tab Kalorien, kcal in Rezept-Metazeilen und Wochenplan, "Ins Tagebuch eintragen", Hinweis "Noch 640 kcal", Kalorien-Widget, Apple Health, Erinnerung "Ideen fürs Abendessen", Avo-Werkzeuge | alles links; Health-Synchronisation pausiert (Daten bleiben) |
| **Avo (KI-Assistent)** | an | Avo-Kreis, Chat, Sprachmodus, Siri "Frag Avo", Widget "Avo fragen", Avo-Einstellungen | Kreis wird Suche; Chat, Sprachmodus, Siri-Satz, Widget-Inhalt, Einstellungen. KI im Hintergrund (Kategorien, Foto-Import) gehört zum Kern und bleibt. |
| **Kosten teilen** | aus, mit einmaligem Vorschlag beim ersten Teilen einer Liste (F-15) | "Betrag" und "Kosten teilen" im Abschluss-Sheet, "Offene Beträge" in Alle Listen, Hinweis-Zeilen, Abschnitte im Verlauf, Mitteilungen zu Beträgen, Avo-Werkzeug | alles links; offene Beträge bleiben gespeichert |

### 15.2 Regeln

- **Sofort wirksam,** ohne Neustart, über `moduleEnabledProvider(AppModule)` (Teil A, `lib/core/modules/app_modules.dart`). Teil B fragt nur ab und rendert `SizedBox.shrink()`, wenn aus.
- **Gespeichert** lokal und im Konto (synchron über Geräte); Ausschalten löscht keine Daten.
- **Orte zum Schalten:** Onboarding (Modulwahl), Einstellungen > Module (alle Schalter an einem Ort), der leere Zustand eines Modul-Tabs ("Tab ausblenden"), Avo (`update_setting` mit Ergebniszeile und Widerrufen).
- **Tab-Bar:** Ein Modul-Tab erscheint bzw. verschwindet mit `springStandard`; steht man darauf, landet man auf Liste.
- **Widgets:** Widget-Arten sind fest registriert und lassen sich nicht ausblenden; ein Widget eines ausgeschalteten Moduls zeigt einen ruhigen Satz und öffnet beim Tippen das Modul-Sheet. Deshalb gibt es **kein eigenes Angebots-Widget**, solange keine Lizenz besteht (K-27).
- **Halbfertiges:** Module und Funktionen mit Status `hidden` erscheinen nirgends (nicht im Onboarding, nicht in den Einstellungen, nicht in Avo). Nur in Debug-Builds lassen sie sich über ein Entwicklermenü einschalten (Langdruck auf die Versionsnummer in Hilfe).

### 15.3 Remote-Kill-Switch für Angebote

- Quelle: Supabase-Tabelle `app_flags` (Teil B), Feld `offers_enabled`, beim Start aus dem Cache gelesen und im Hintergrund aktualisiert.
- Ist das Flag aus:
  - Alles aus "Preise & Angebote" verschwindet wie bei "Modul aus".
  - Zusätzlich verschwindet der Modul-Schalter selbst aus Onboarding und Einstellungen; es gibt keinen Hinweis "nicht verfügbar". Gelb kommt in der App nicht mehr vor.
  - Der Einstellungs-Abschnitt "Preise & Angebote" heißt dann "Märkte" und enthält nur noch Markt-Erkennung, Standort/PLZ und Lieblingsmärkte (K-27).
  - Avo hat keine Angebots-Werkzeuge mehr; fragt jemand danach, antwortet Avo sachlich, dass er dazu gerade nichts sagen kann.
  - Gespeicherte Angebotspreise an Artikeln werden nicht mehr angezeigt.
- Wird das Flag wieder an, erscheint alles beim nächsten Öffnen eines Screens, ohne Neustart.

### 15.4 Einzel-Schalter "Preise & Angebote"

Alle standardmäßig an, jeder einzeln abschaltbar, jeder Schalter wirkt sofort und übersteht einen Neustart:
- Angebote in Listen (gelbe Schilder)
- Vorschläge beim Tippen
- "X von Y im Angebot · gespart"-Zeile
- Spar-Hinweise auf der Startseite (Prospekt)
- Ersparnis im Verlauf und nach dem Einkauf
- Automatische Markt-Erkennung (Listenname, gelernt aus Einkäufen, Standort als Vorschlag)
- Standort bzw. Postleitzahl, Lieblingsmärkte
- Pro Liste im Listenmenü: "Angebote für diese Liste ausblenden"

---

## 16. Pro-Flächen

Der Owner entscheidet später, was Pro wird (F-05). Die Flächen funktionieren für jedes Feature. **Angebote sind nie Pro.** Der Kern (Listen, Teilen, Rezepte, Einkaufsmodus, Verlauf) bleibt frei und muss allein überzeugen.

### 16.1 Kennzeichnung

- `ProBadge` hinter dem Feature-Namen (12.30), in Zeilen, Titeln, Menüeinträgen.
- In Avo: Fragt man nach einer Pro-Funktion, führt Avo sie nicht aus, sondern zeigt eine Ergebniszeile "Mit {pro} verfügbar" mit "Ansehen". Keine Pro-Werbung in Avo-Antworten ohne Anlass.
- Im Profil: Zeile "{pro}" mit Status ("14 Tage gratis testen" bzw. "Aktiv bis …").

### 16.2 Gesperrte Funktionen

- **Echte Vorschau statt Schloss-Bildschirm:** Der Wochenplan zeigt den Plan mit eigenen Rezepten; erst "Auf die Liste" öffnet die Paywall. Der Sprachmodus zeigt die Bühne; erst das Sprechen öffnet die Paywall.
- Die Paywall wächst als Sheet aus dem angetippten Element (`springMorph`) und zeigt dieses Feature oben.

### 16.3 Paywall

Aufbau in 12.31. Inhalte aus der Konfiguration `pro_features` (Supabase, gecacht; je Eintrag `id`, `symbol`, `title_key`, `body_key`, `order`, `is_pro`), damit der Owner den Umfang ohne App-Update ändert. Dieselbe Konfiguration speist das Avo-Wissen.

### 16.4 Kontextuelle Hinweise

- Eine Fußzeile unter der betroffenen Sektion ("Mit {pro} plant Avo die ganze Woche. Ansehen") oder eine Hinweis-Zeile auf der Startseite.
- **Das erste Pro-Angebot** erscheint nach einem Aha-Moment: nach dem ersten abgeschlossenen Einkauf oder nach dem ersten Wochenplan auf der Liste, als Hinweis-Zeile "14 Tage {pro} gratis testen", nicht als Pop-up.

### 16.5 Regeln gegen Nerven

- Höchstens ein kontextueller Hinweis pro Feature und Woche (lokaler Zähler), höchstens einer pro Tag insgesamt.
- Nie beim App-Start, nie im Onboarding vor dem Aha-Moment, nie im Einkaufsmodus, nie im Kochmodus, nie als ungefragtes Modal.
- Schließen immer sofort sichtbar; kein Countdown; keine Fantasiepreise; Preise und Rabatt aus StoreKit.
- Abgelehnte Hinweise ("Nicht mehr zeigen") gelten dauerhaft für dieses Feature.
- Bei unbekanntem Pro-Status keine Hinweise (Kapitel 13).

---

## 17. Umsetzung in Flutter

### 17.1 Token-Dateien (Teil A, `lib/core/constants/`)

| Datei | Inhalt |
|---|---|
| `app_colors.dart` | `AppColorTokens` mit allen Tokens aus Kapitel 4 als Instanzen für hell, dunkel, hell-hochkontrast, dunkel-hochkontrast; Zugriff `AppColors.of(context)`; `ListColor`-Enum mit Varianten; keine Markenfarben der Märkte (die sind Daten, Teil B) |
| `app_dimensions.dart` | Abstands-Skala, feste Maße (6.2), Radien (7.1), Breitenklassen (6.3), Geräteradius-Zugriff |
| `app_text_styles.dart` | `AppTextStyle`-Enum, Dynamic-Type-Tabelle (5.3), Zeilenhöhen-Verhältnisse, `trackingFor()` (5.4), Schriftfamilie nach Endgröße, Rounded-Erkennung, fetter Text; Zugriff `AppText.of(context, AppTextStyle.body)` |
| `app_motion.dart` (neu) | Feder-Tokens (10.1) als `SpringDescription`, Helfer für unterbrechbare Animation, `fadeReduced`, Reduce-Motion-Weiche |
| `app_brand.dart` (neu) | `appName`, `proName`, `assistantName` (3.1) |

Die heutigen Werte in diesen Dateien (Paper-Creme, Terrakotta, "Satoshi", Radien 28/24/36) werden ersetzt, nicht ergänzt. `AppColors.surface(context)`-Helfer und Legacy-Aliase entfallen nach der Umstellung.

### 17.2 Theme auf iOS wirklich anwenden

- `AdaptiveApp` nutzt auf iOS nur die Primärfarbe des Material-Themes; `app_theme.dart` ist dort wirkungslos. Deshalb legt der `builder` in `app.dart` einen `DesignScope` (InheritedWidget, `lib/core/design/design_scope.dart`) und zusätzlich ein Material-`Theme` aus denselben Tokens um die App, damit auch Material-Bausteine stimmen.
- `DesignScope` liest die ursprüngliche Textgröße aus `MediaQuery`, leitet die Kategorie ab und setzt darunter `MediaQuery.textScaler` auf `TextScaler.noScaling`. Alle Stile tragen ihre Endgröße; nichts wird doppelt skaliert. Native Views skalieren selbst.
- Der Remount-Schlüssel `ValueKey('$themeMode-$languageCode')` entfällt; Theme-Wechsel läuft über den `DesignScope` mit Überblendung.
- Standard-Darstellung "System" (K-32), heute "Hell".

### 17.3 Umgang mit den Paper-Dateien

| Datei | Schicksal |
|---|---|
| `lib/core/constants/paper_colors.dart` (`PaperColors`, `PaperTextStyles`) | entfällt |
| `lib/core/widgets/paper/paper_widgets.dart` | entfällt |
| `lib/presentation/widgets/common/paper_settings.dart` | entfällt (ersetzt durch 12.2, 12.22) |
| `lib/core/widgets/design_system.dart` (`AppRadius`, `AppCard`, `AppButton` …) | entfällt |
| `lib/presentation/widgets/common/liquid_glass_button.dart` | entfällt |
| `lib/core/constants/list_background_gradients.dart` | entfällt (toter Code) |
| `lib/core/theme/app_theme.dart` | wird aus Tokens neu gebaut (nur noch Material-Bausteine und Android) |
| `lib/core/constants/recipe_categories.dart` | IDs bleiben, Emojis und Farben entfallen (SF Symbols) |
| `lib/core/constants/categories.dart` | IDs bleiben, Material-Farben und -Icons entfallen |
| `lib/presentation/widgets/common/empty_state.dart`, `loading_indicator.dart` | durch 12.26 ersetzt bzw. entfällt |
| `lib/core/mascot/avo_mascot.dart` | durch `Mascot` ersetzt |

Vorgehen: Die Dateien werden mit S2 als `@Deprecated` markiert. Jeder Screen, der umgebaut wird, entfernt seine Paper-Nutzung vollständig. Gelöscht wird eine Datei, sobald `grep` auf ihre Bausteine 0 Treffer ergibt. Übersetzungsschlüssel mit `_kicker` und `_paper` werden mit dem letzten Nutzer gelöscht.

### 17.4 Ordner

| Ordner | Inhalt | Besitz |
|---|---|---|
| `lib/core/constants/` | Tokens (17.1) | A |
| `lib/core/design/` | `DesignScope`, Breiten- und Textgrößen-Klassen, nativer Glas-Kanal, Symbol-Kanal, Haptik | A |
| `lib/presentation/widgets/design/` | Komponenten aus Kapitel 12 (eine Datei pro Komponente) und `design_gallery_screen.dart` (Debug-Route `/debug/components`, zeigt jede Komponente in allen Zuständen) | A |
| B-Ordner (`widgets/deals`, Screens `avo`, `calories`, `plan`, `offers`, `history`) | B-Komponenten nach Kapitel 12 (`StoreChip`, `ItemOfferBadge`, `AvoVoiceStage` …) | B |
| `test/layout/` | Prüfgerüst (14.3) | A |

Die Komponenten-Basis (Tokens, `InsetSection` mit 26 pt, `CheckCircle`, `ItemRow`, Buttons, `AppSheet`, `StoreChip`-Slot, `ProBadge`, Accessory, Tab-Bar) muss gemergt sein, **bevor** Screens auf beiden Macs umgebaut werden (Meilenstein S2). Sonst baut jeder eigene Varianten.

### 17.5 Schrift

- Familie nach Endgröße: `CupertinoSystemText` unter 20 pt, `CupertinoSystemDisplay` ab 20 pt. Im Spike prüfen, ob Flutter auf iOS so die richtige optische Größe wählt; sonst die Familie `.SF UI Text` / `.SF UI Display` testen.
- SF Pro Rounded: im Spike `fontFamily: '.SF Pro Rounded'` bzw. die Rounded-Variante der Systemschrift über einen nativen Kanal (Schriftbeschreibung mit Design "rounded") prüfen. Gelingt es nicht: SF Pro mit tabellarischen Ziffern. Keine Schriftdatei bündeln (Lizenz).
- Laufweite nur über `trackingFor()`, nie als feste `letterSpacing`-Werte in Screens.

### 17.6 Regeln, die ein Skript prüft

`tool/design_check.sh` (Teil A) läuft vor jedem Commit beider Teile und schlägt fehl, wenn in `lib/presentation` oder `lib/core/widgets` gefunden wird:
- `Color(0x`, `Colors.` (außer `Colors.transparent`)
- `fontSize:`, `letterSpacing:`, `FontWeight.` außerhalb der Token-Dateien
- `Duration(milliseconds` in Animationen (außer über `AppMotion`)
- `Icons.`, `CupertinoIcons.`, `LucideIcons.`
- `HapticFeedback.`
- `SnackBar(`, `CircularProgressIndicator`, `BackdropFilter`
- `PaperColors`, `PaperTextStyles`, `PaperKicker`, `toUpperCase()` in Anzeigetexten
- `SizedBox(height:` direkt um ein `Text`- oder `TextField`-Widget (Heuristik)

### 17.7 Nativer Glas-Anteil

| Baustein | Datei | Besitz |
|---|---|---|
| `shoply/liquid_glass`, `shoply/liquid_glass_group` mit neuem Update-Kanal | `ios/Runner/LiquidGlassViewFactory.swift` | A |
| `shoply/tab_bar` (12.1) | `ios/Runner/LiquidGlassViewFactory.swift` bzw. neue A-Datei daneben | A |
| `shoply/symbols` (9.3), `shoply/device` (7.2), `shoply/haptics` (11), Reduce-Transparency-Signal (8.3) | neue Swift-Datei von Teil A; die Registrierung in `AppDelegate.swift` ist eine Anfrage an Teil B | A, Registrierung B |

### 17.8 Leistung im Code

- Riverpod `select` auf einzelne Artikel; keine Provider, die bei jedem Abhaken die ganze Startseite neu rechnen (heute ca. 10 Netzaufrufe pro Häkchen).
- `RepaintBoundary` um Zeilen, Ringe und rollende Zahlen; Listen nur als Slivers mit Builder.
- Bilder über `CachedNetworkImage` mit `memCacheWidth`, nie `Image.network` in scrollenden Listen.
- Tab-Inhalte, die nicht sichtbar sind, beobachten keine teuren Provider (`TickerMode` und pausierte Abfragen).
- Kein `BackdropFilter`, keine Platform Views in Zeilen, höchstens drei Glas-Views (8.5).

---

## 18. Entscheidungen dieses Konzepts und offene Fragen

### 18.1 Konzept-Entscheidungen

| Nr. | Entscheidung | Grund |
|---|---|---|
| K-01 | Designsprache "Vorinstalliert" mit den Jury-Übernahmen aus 1.2 | Jury-Sieger in allen drei Blickwinkeln |
| K-02 | Der erste Tab heißt **"Liste"** und zeigt die Liste von heute; der Titel ist der Listenname mit Umschalter; es gibt keinen eigenen Tab "Listen", "Alle Listen" ist eine Seite aus dem Titelmenü | Jury-Warnung: "Heute" plus Titel "Wocheneinkauf" plus Tab "Listen" ist doppeldeutig; spezifische Namen nach Inhalt (Apple); Platz in der Tab-Bar bei 320 pt |
| K-03 | Wochenplan als eigener Tab **"Plan"** (Modul), nicht als Segment in Rezepte | tägliche Nutzung ("Heute kochen"), Vorschlag des Owner-Assistenten, Jury-Hinweis auf frei werdenden Platz |
| K-04 | Der Avo-Kreis rechts neben der Tab-Bar ist der einzige In-App-Einstieg; "Frag Avo" ist zugleich die App-Suche; ist Avo aus, wird der Kreis zur Lupe | Plan 1; iOS-26-Muster des abgesetzten Suchknopfs; eine Form der Tab-Bar in allen Zuständen |
| K-05 | Profil als Avatar in der Titelzeile jeder Tab-Wurzel; Einstellungen als Sheet, jede Seite mit eigener Route | Muster aus App Store und Health; heute sind 24 Screens ohne Route nicht verlinkbar |
| K-06 | Feste Akzentfarbe; die Einstellung "Akzentfarbe wählen" entfällt (heute ohnehin ohne Wirkung) | eine Handlungsfarbe, prüfbare Kontraste; Owner bestätigt (F-02) |
| K-07 | Listen-Hintergründe (Verläufe, Bilder) werden nicht mehr angezeigt; Listenfarbe und Symbol ersetzen sie; Daten bleiben | Inventar: heute faktisch unsichtbar; Ruhe; Owner bestätigt (F-03) |
| K-08 | Listenfarben = iOS-Systemfarben ohne "Avocado" | Verwechslung mit dem Akzent (Jury) |
| K-09 | Grün-Disziplin: semantische Tokens, eine gefüllte Akzent-Kapsel pro Screen, Fortschritt in `label` | Jury-Warnung "Grün-Inflation" |
| K-10 | "Einkaufen" sitzt unten im Accessory, keine Kapsel oben im Inhalt | Daumenreichweite (Jury); Herkunft des Morphs am Auslöser |
| K-11 | Einkaufsmodus-Bodenleiste: "+" links, "Einkauf beenden" getönt, Avo-Kreis rechts an derselben Stelle; Präsenz oben; Rückgängig-Leiste 4 s | Nachtragen im Laden, eine Hand, Fehltipps im Gehen |
| K-12 | Erledigtes sammelt sich in "Erledigt (n)" bzw. "Im Wagen (n)"; unter Reduce Motion bleiben Zeilen stehen, bis man nicht mehr scrollt | Jury-Warnung zum 0,6-s-Wegspringen |
| K-13 | Tab-Bar und Avo-Kreis als eine eigene native View (`shoply/tab_bar`); Spike höchstens 2 Tage, dann Rückfall | Glas-Budget, nativer Morph, eigenes Symbol und Langdruck |
| K-14 | Die Tab-Bar minimiert sich in Version 1 nicht beim Scrollen | stabiles Layout mit Accessory; zwei Platform Views können nicht gemeinsam morphen |
| K-15 | Höchstens drei native Glas-Views pro Screen; Toolbar-Knöpfe als eine Gruppe; Profil-Avatar ohne Glas | Leistung iPhone 13 Pro (Jury-Warnung) |
| K-16 | SF Symbols zur Laufzeit nativ gerendert und gecacht; keine SF-Symbol-Dateien im Bundle | Lizenz (Android-Build), aktuelle Symbole |
| K-17 | Artikelbilder als monochrome "Avo Symbols"; bis dahin ausschließlich Kategorie-Symbole | Recherche (Illustrationen bauen), Umsetzbarkeit für zwei Personen, getönte Widgets |
| K-18 | SF Pro Rounded nur, wenn systemseitig erreichbar; keine Schriftdatei | Lizenz; Rückfall tabellarische Ziffern |
| K-19 | Dynamic Type nach Apples Tabelle pro Stil, Laufweite aus der Endgröße berechnet, `textScaler` im Baum neutralisiert | Jury-Warnung zur Laufweite in Flutter; große Titel wachsen wie in iOS |
| K-20 | Rückgängig-Hinweis statt Material-Snackbars | iOS-Muster, Agency |
| K-21 | Das Coach-Mark-Tutorial entfällt; Ersatz: einmalige Tipp-Zeilen am Ort (eine pro Funktion, wegwischbar) | blockiert die App, Texte nur Deutsch, Apple-Muster TipKit |
| K-22 | Die Onboarding-Frage "Was bringt dich zu uns?" entfällt; die Modulwahl ersetzt sie | Plan 1; Prioritäten steuerten nur die Reihenfolge der Startseiten-Karten |
| K-23 | Paywall mit eigenem Foto-Kopf; Schließen sofort sichtbar oben links | Business-Jury (Pro unter Wert), Jury-Warnung zum Schließen-Knopf |
| K-24 | Pro-Hinweise höchstens einmal pro Feature und Woche; gesperrt heißt echte Vorschau | Übernahme aus 3 und 5 |
| K-25 | Kochmodus immer schwarz, Schritttext 28 pt | Küche, Übernahme aus 4 |
| K-26 | Verlauf ist Kern; Monatsrückblick gehört zum Verlauf; Ersparnis nur mit dem Angebots-Modul | Plan nennt Verlauf nicht als Modul; Abschluss speist Nachkauf und Markt-Lernen |
| K-27 | Bei Kill-Switch heißt der Abschnitt "Märkte"; kein eigenes Angebots-Widget, solange keine Lizenz besteht | Widgets lassen sich nicht spurlos entfernen |
| K-28 | Die Liste von heute schaltet nie automatisch um; Standort, Präsenz und Wochenplan erzeugen nur einen Vorschlag | Ortsgefühl und Vertrauen (Jury) |
| K-29 | Maskottchen neu, flach, vier Posen (winkend, zufrieden, feiernd, suchend); "schlafend" entfällt | Mehrdeutigkeit "schläft" (Jury) |
| K-30 | Sheets: `xmark` links schließt, `checkmark` rechts (getönt) übernimmt | iOS-26-Muster |
| K-31 | Schalter, Segmente und Menüinhalte werden in Flutter gezeichnet | keine Platform Views in Zeilen |
| K-32 | Darstellung standardmäßig "System" | heute "Hell", ignoriert den Dunkelmodus |
| K-33 | Der verwaiste Screen "Listenaktivitäten" wird zum Abschnitt "Zuletzt geändert" im Sheet "Listen-Info", gespeist aus echten Daten | heute immer leer (`logActivity` wird nie aufgerufen) |
| K-34 | Rollende Ziffern sind ein Systembaustein für alle sich ändernden Zahlen | Markenmoment ohne Farbe, Übernahme aus 4 |
| K-35 | Tab-Wechsel ohne Animation | iOS-Verhalten; behebt das Durchschieben leerer Tabs |
| K-36 | Normale Liste: Kreis hakt ab, Name öffnet das Artikel-Sheet; Einkaufsmodus: ganze Zeile hakt ab | Erinnerungen-Muster; im Laden zählt nur Abhaken |
| K-37 | Der Sprachmodus folgt der Systemdarstellung (kein erzwungenes Dunkel) | Ruhe, Familiarität |
| K-38 | Startseite zeigt höchstens zwei Hinweis-Zeilen; welche, steht beim ersten Frame fest | Liste muss auf iPhone SE mit AX-Schrift sichtbar beginnen; keine Layout-Sprünge |
| K-39 | Mitteilungen geteilter Listen werden gebündelt ("Lena hat 5 Artikel abgehakt", "Lena kauft gerade bei Lidl ein") statt eine pro Häkchen | Plan: kein Benachrichtigungs-Spam |

### 18.2 Offene Fragen an den Owner

| Nr. | Frage | Vorschlag des Konzepts |
|---|---|---|
| F-01 | Heißt die App "Avo" oder "Shoply"? Heißt das Abo "{App} Pro"? Bleibt der Assistent "Avo", auch wenn die App anders heißt? | App "Avo", Abo "Avo Pro", Assistent "Avo" |
| F-02 | Einverstanden, dass die Akzentfarbe fest ist und die Wahl entfällt (K-06)? | ja |
| F-03 | Einverstanden, dass Listen-Hintergründe als sichtbare Funktion entfallen (K-07)? | ja |
| F-04 | Welche Module sind beim ersten Start vorausgewählt? | Angebote, Wochenplan, Avo an; Kalorien und Kosten teilen aus |
| F-05 | Was wird Pro? | Kandidaten: Wochenplan, Avo-Sprachmodus, Kalorien mit Apple Health, Statistiken; nie Angebote; Kern frei |
| F-06 | Tab-Name "Liste" in Ordnung (Alternativen "Einkauf", "Heute")? | "Liste" |
| F-07 | Eigene Fotos für Paywall, Onboarding und Rezept der Woche: selbst fotografieren oder Lizenz kaufen? | selbst fotografieren, 5 bis 8 Motive |
| F-08 | Wer zeichnet das neue Maskottchen (4 Posen) und die Avo Symbols (ca. 210 Symbole, 3 Gewichte), mit welchem Budget? | eine Person mit fester Vorlage; Übergang mit Kategorie-Symbolen |
| F-09 | Sollen wir bei Ketten um Logo-Erlaubnis anfragen? | erst nach der Angebots-Partnerschaft; bis dahin Name und Punkt |
| F-10 | Bleibt der Kochmodus bis zur Pro-Entscheidung gesperrt (heute die einzige Sperre)? | freigeben, bis der Pro-Umfang feststeht |
| F-11 | Soll das Abo Familienfreigabe unterstützen? | ja, passt zu geteilten Listen |
| F-12 | Mindest-iOS von 15.6 auf 17 anheben? (interaktive Widgets, neuere Symbole, weniger Rückfälle) | ja, iOS 17 |
| F-13 | Wird Android weiter ausgeliefert (ohne eigene Gestaltung, ohne Abo)? | ja, mit Fallbacks; Gestaltung später |
| F-14 | Dürfen die Onboarding-Prioritäten (`users.app_priorities`) als Daten entfallen? | ja, Feld bleibt ungenutzt in der Datenbank |
| F-15 | Kosten teilen standardmäßig aus, mit einmaligem Vorschlag beim ersten Teilen einer Liste? | ja |
