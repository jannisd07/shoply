> **Hinweis (07.11.2026):** Für die Konzeptbilder gilt jetzt [`chatgpt-bilder-prompt.md`](chatgpt-bilder-prompt.md), das unser eigenes Konzept zeichnen lässt. Diese Datei bleibt nur noch als vollständige Funktionsliste der App (Abschnitt 3) bestehen. Einzelne Aussagen hier (Preisvergleich-Sheet, Angebote als Pro-Vorteil, ein einziges Konzept statt fünf Richtungen) sind durch Jannis' Plan überholt.

Ich habe dir ein Video geschickt. Das ist unsere iPhone-App **Avo**. Schau dir das komplette Video genau an: jeden Screen, jedes Sheet, jede Liste, jeden Button, jeden Text. Unten erkläre ich dir zusätzlich, was die App alles kann. Manche Funktionen sieht man im Video nur kurz oder gar nicht, sie gehören trotzdem ins neue Design.

Unser aktuelles Design finden wir komplett schlecht. Wir wollen ein vollständiges Redesign: neue Optik, neue Struktur, neue Navigation, wo es sinnvoll ist. Behalte nichts, nur weil es schon da ist. Die **Funktionen** bleiben alle erhalten, das **Design** wird komplett neu.

Das Ziel: Avo soll aussehen, als hätte Apple die App selbst gebaut. Ausgerichtet an **iOS 27 und Liquid Glass**, professionell, ruhig, hochwertig und bis ins Detail stimmig. Wir wollen mit der App richtig Geld verdienen (Abo-Modell). Sie muss also auf den ersten Blick so gut aussehen, dass Leute ihr vertrauen und dafür bezahlen.

---

## 1. Was Avo ist

Avo ist eine Einkaufslisten-App mit eingebautem KI-Assistenten für den deutschen Markt. Der Kern ist die gemeinsame Einkaufsliste. Darum herum gibt es:
- Live-Angebote und Preisvergleich der Supermärkte in deiner Nähe
- Rezepte und eine Rezept-Community
- optionales Kalorien-Tracking
- einen KI-Assistenten, der fast alles in der App per Chat erledigen kann

**Zielgruppe:** Paare, WGs und Familien, die zusammen einkaufen; Leute, die beim Einkauf Geld sparen wollen; Leute, die gesünder essen und kochen wollen.

**Sprache:** Deutsch (Englisch gibt es auch). Bitte alle Mockups mit deutschen Texten und echten Inhalten, also keine Platzhalter wie „Lorem ipsum“. Beispiel-Supermärkte: REWE, Lidl, Aldi, Edeka, Kaufland, Netto, PENNY.

**Maskottchen:** „Avo“, eine niedliche Avocado mit Gesicht, Ärmchen und Beinchen. Sie gibt es in mehreren Stimmungen (fröhlich, winkend, denkend, feiernd, überrascht). Avo ist gleichzeitig der Name der App und des KI-Assistenten. Du darfst das Maskottchen modernisieren oder sparsamer einsetzen, wenn das hochwertiger wirkt. Die Avocado sollte aber erkennbar bleiben.

**App-Icon:** Das jetzige Icon ist ein generisches grünes Quadrat mit einem weißen Zettel. Bitte schlag auch ein neues App-Icon vor.

**Technik (wichtig für realistische Entwürfe):** Die App ist in Flutter gebaut, primär für iOS. Echte Liquid-Glass-Effekte sind möglich, z. B. für Tab-Bar, Buttons und Sheets. Entwirf also nichts, was nur als statisches Bild funktioniert. Alles muss als echte, scrollbare App umsetzbar sein.

---

## 2. Aktueller Stand (das, was du im Video siehst)

- Warmer „Papier“-Look: cremefarbener Hintergrund, Serifenschrift (Georgia) für Überschriften, terrakotta-farbene Akzente, kleine Großbuchstaben-Kicker über Überschriften.
- Unten eine schwarze Pillen-Navigationsleiste mit den Tabs **Listen, Rezepte, (Kalorien, nur wenn aktiviert), Profil**. Daneben eine separate runde Avo-Schaltfläche, die den KI-Chat im Vollbild öffnet.
- Die Detailansicht einer Liste öffnet sich im Vollbild ohne Navigationsleiste. Unten hängt eine schwebende Eingabeleiste zum Hinzufügen von Artikeln.

All das darf komplett weg. Wenn du eine bessere Navigation hast (anderer Tab-Aufbau, Avo anders eingebunden, Suche als eigener Tab o. Ä.), schlag sie vor und begründe sie kurz.

---

## 3. Alle Funktionen der App

### Einkaufslisten (Kernfunktion)
- Beliebig viele Listen, jede mit eigenem Namen und eigenem Hintergrund (Farben, Verläufe, Bilder).
- **Gemeinsame Listen in Echtzeit:** per Einladungslink oder Code teilen. Mitglieder sehen Änderungen sofort, bei jedem Artikel steht, wer ihn hinzugefügt hat. Es gibt einen Aktivitäten-Verlauf pro Liste.
- **Automatische KI-Sortierung:** Jeder Artikel wird automatisch einer von 29 Kategorien zugeordnet (Obst & Gemüse, Milchprodukte, Backwaren usw.). Die Liste ist dadurch nach Supermarkt-Gängen gruppiert. Die Reihenfolge der Kategorien lässt sich anpassen, Artikel lassen sich per Drag & Drop verschieben.
- Artikel mit Menge und Einheit, abhaken, bearbeiten, löschen.
- **Liste per Foto importieren:** einen handgeschriebenen Zettel, einen Screenshot oder eine Datei fotografieren bzw. auswählen. Avo liest die Artikel aus und zeigt sie in einem Prüf-Sheet an. Dort kann man sie bearbeiten und dann alle importieren.
- **Live-Angebote beim Tippen:** Während man einen Artikel eingibt, erscheinen die drei besten aktuellen Angebote aus Märkten in der Nähe (Preis, Markt, Produktbild).
- **Preisvergleich der ganzen Liste:** eine Leiste zeigt den günstigsten Gesamtkorb, z. B. „€ 23,40 günstigster Korb bei Lidl“. Antippen öffnet einen Vergleich aller Märkte. Der Standort kommt per GPS oder Postleitzahl.
- Smarte Vorschläge: Artikel, die man wahrscheinlich noch braucht (basierend auf dem eigenen Kaufverhalten).
- **Einkauf abschließen:** Die App fragt, in welchem Markt man war (lernt daraus), und speichert den Einkauf im Verlauf.

### Preise, Angebote und Sparen
- **Angebote der Woche:** Seite zum Durchsuchen aktueller Supermarkt-Angebote, standardmäßig gefiltert auf Artikel, die auf den eigenen Listen stehen.
- **Persönlicher Prospekt:** „5 Sachen, die du regelmäßig kaufst, sind gerade im Angebot – spart 4,80 €“.
- **Preis-Highlight:** „Wocheneinkauf ist bei Lidl 3,20 € günstiger als bei REWE“.
- **Ersparnis-Tracking:** „Du hast diesen Monat 18,60 € durch Angebote gespart.“
- Rezepte zeigen an, welche Zutaten gerade im Angebot sind.

### Avo, der KI-Assistent (Chat)
- Vollbild-Chat. Eingabe per Text, Kamera oder Mikrofon. Schnellaktionen als Chips, wenn der Chat leer ist.
- Avo kann rund 35 Aktionen direkt ausführen. Ergebnisse erscheinen als Karten im Chat. Beispiele:
  - Listen anlegen, umbenennen, löschen; Artikel hinzufügen, abhaken, verschieben, löschen; Einkauf abschließen
  - Rezepte suchen, gespeicherte Rezepte zeigen, Nährwerte schätzen, alle Zutaten eines Rezepts auf eine Liste setzen
  - Angebote suchen, Listenpreise zwischen Märkten vergleichen, persönliche Angebote zeigen, Ersparnisse zusammenfassen
  - Einkaufsverlauf zeigen, Artikel aus alten Einkäufen erneut hinzufügen, „Was geht mir bald aus?“-Vorschläge
  - Kosten eines Einkaufs mit anderen teilen
  - Essen, Wasser und Gewicht eintragen; Kalorienziel einrichten; Tagesstatus, Wochenrückblick und Challenge-Stand zeigen
  - Einstellungen ändern (Sprache, Benachrichtigungen usw.) und Fragen zur App beantworten
- Wenn Avo nicht weiß, welche Liste gemeint ist, fragt er nach und zeigt eine Auswahl.

### Startseite (Home)
- Persönliche Begrüßung, abhängig von der Tageszeit, mit dem Avo-Maskottchen.
- Übersicht aller Listen mit Anzahl offener Artikel und der letzten Aktivität („Lena hat Milch hinzugefügt“).
- **Intelligente Hinweis-Karten.** Sie werden danach sortiert, was dem Nutzer im Onboarding wichtig war:
  - „Milch geht dir wohl bald aus“ (aus dem eigenen Kaufrhythmus berechnet)
  - Persönlicher Prospekt (Angebote zu Dingen, die man oft kauft)
  - Preisvergleich-Highlight
  - „Einkauf mit deiner Gruppe teilen? ≈ 42 € gesamt“
  - Rezeptvorschlag passend zu den restlichen Kalorien des Tages
- Einstieg zu den Angeboten der Woche, z. B. „12 Angebote passend zu deinen Listen“.
- Banner bei offenen Kostenaufteilungen.

### Verlauf, Statistiken und Kosten teilen
- Monatsrückblick („Dein November.“) mit Statistiken, einem Diagramm, an welchen Wochentagen man einkauft, und allen vergangenen Einkäufen.
- Ersparnis pro Einkauf und pro Monat, mit Vergleich zum Vormonat.
- **Kosten teilen:** einen Einkauf gleichmäßig oder individuell auf Mitglieder aufteilen. Die App kopiert eine fertige Zahlungserinnerung zum Verschicken per Messenger.

### Rezepte und Community
- Rezept-Tab mit Suche, „Rezept der Woche“ als großer Hero, Kategorien und Filter-Chips (vegan, vegetarisch, schnell, proteinreich usw.).
- Bereiche: Rezepte, Ersteller, Gespeichert, Meine Rezepte, Entwürfe.
- **Ersteller/Creator:** Autorenseiten, Nutzern folgen, Likes und Kommentare.
- **Rezeptdetail:** großes Foto, Zeit, Portionen, Kalorien und Makros, Zutatenliste, Schritte. Mit einem Tipp kommen alle Zutaten auf eine Einkaufsliste. Rezept teilen per Link. „Ins Tagebuch eintragen“ für das Kalorien-Tracking.
- **Rezept personalisieren:** Zutaten werden automatisch passend zur Ernährungsweise und zu Allergien ersetzt (z. B. vegane Alternative).
- **Varianten:** Nutzer reichen eigene Abwandlungen eines Rezepts ein, andere stimmen darüber ab.
- **Kochmodus** (Vollbild, Schritt für Schritt): zuerst Zutaten zusammensuchen und abhaken, dann „Schritt 3 von 7“ mit großem Text, Portionen umrechnen und eingebaute Timer („12 Min Timer starten“).
- **Eigenes Rezept erstellen** in vier Schritten: 1) Foto und Name, 2) Zeiten und Portionen, 3) Zutaten, 4) Anleitung. Mit Entwurfs-Speicherung.

### Kalorien und Gesundheit (optionaler Tab, im Onboarding oder Profil aktivierbar)
- **Ziel-Einrichtung:** Ziel (abnehmen, Muskeln aufbauen, Gewicht halten, individuell), Geschlecht, Alter, Größe, Gewicht, Zielgewicht, Aktivitätslevel und Zeitraum. Daraus werden das tägliche Kalorienziel und die Makros berechnet.
- **Tages-Dashboard:** Kalorienring („640 kcal übrig“), Makro-Balken (Protein, Kohlenhydrate, Fett), Mahlzeiten (Frühstück, Mittag, Abend, Snack), Wasser-Tracker, Wochenleiste.
- **Essen hinzufügen** über vier Wege: Suche in einer Lebensmitteldatenbank, Barcode, **Foto** (die KI schätzt die Nährwerte und zeigt an, wie sicher sie ist) oder manuell.
- **Gewichtsverlauf** mit Diagramm und Zielmarke.
- **Wochenrückblick:** Serie („5 Tage in Folge geloggt“), Makro-Durchschnitt, an wie vielen Tagen das Proteinziel erreicht wurde, gekochte Mahlzeiten, Wasser, Gewichtsveränderung.
- **„Was kann ich heute noch essen?“:** Rezepte, die in die restlichen Kalorien passen.
- **Challenges:** 16:8 Intervallfasten, 30 Tage ohne Zucker oder eine eigene Challenge. Täglicher Check-in („Heute geschafft“ / „Heute nicht“), Serien, Fortschritt in Prozent, abgeschlossene Challenges.

### Onboarding und Login
- Willkommens-Screen (aktuell „Einkaufen, schön sortiert.“) mit „Mit Apple fortfahren“, „Mit Google fortfahren“ und E-Mail-Registrierung. Außerdem Passwort zurücksetzen und eine Abfrage des Namens.
- Drei Intro-Seiten: Listen sortieren sich selbst, Listen gemeinsam nutzen, Rezepte passen sich an.
- Personalisierung:
  - „Was bringt dich zu uns?“ (Geld sparen, Listen teilen, gesünder essen, Rezepte entdecken, organisiert bleiben)
  - Ernährungsweise
  - Körperdaten für das Ziel
  - „Auch Kalorien tracken?“ (ja / nur Einkaufen & Rezepte)
- Interaktives Tutorial mit Hinweisen beim ersten Start.

### Profil und Einstellungen
- Profilkarte mit Avatar, Name und Statistiken, darunter ein Banner für Premium.
- Einstellungen:
  - Persönliche Daten und Anzeigename
  - Ernährungsweise und Allergien
  - App-Prioritäten
  - Sprache (Deutsch/Englisch)
  - Benachrichtigungen: jemand fügt etwas hinzu, Einkauf abgeschlossen, Einladungen, Likes, Kommentare, neue Rezepte von Leuten, denen man folgt, Wochenzusammenfassung
  - Design: hell/dunkel und Akzentfarbe
  - Hilfe & Support, Datenschutz, AGB, Abmelden

### iOS-Extras
- Home-Screen-Widget in drei Größen, das eine gewählte Liste zeigt.
- Siri: „Hey Siri, füge Milch zu meiner Avo-Liste hinzu.“
- Push-Benachrichtigungen, Offline-Modus mit automatischer Synchronisierung.
- Deep Links für geteilte Rezepte, Listen und Einladungen.

### Premium (Abo, hier verdienen wir Geld)
- **2,99 € pro Monat** oder **29,99 € pro Jahr**, jeweils mit **14 Tagen gratis**. Zwei Pläne, Jahresabo mit Ersparnis hervorgehoben. „Käufe wiederherstellen“ und „Jederzeit kündbar“.
- Premium-Vorteile auf der Paywall: unbegrenzt geteilte Listen, Avo plant Rezepte und ganze Wochen, Angebote deiner Märkte, Einkaufs-Statistiken.
- Aktuell ist die Benennung uneinheitlich: mal „Shoply Premium“, mal „Avo Pro“. Bitte gib dem Abo einen einheitlichen Namen (z. B. „Avo Pro“).
- Gesperrte Funktionen zeigen einen Hinweis „Mit Pro freischalten“.
- Die Paywall muss die hochwertigste Seite der App werden: klarer Nutzen, Vertrauen, kein billiger Druck. Denk auch daran, wo in der App Premium sinnvoll und unaufdringlich auftauchen kann (z. B. die Ersparnis zeigen, die man mit Pro hätte).

---

## 4. Designrichtung

- **iOS 27 und Liquid Glass**, nativ wie eine Apple-App (z. B. Erinnerungen, Fitness, Wallet, Apple Music):
  - schwebende Liquid-Glass-Tab-Bar, Glas-Buttons und Glas-Sheets
  - große Titel, die beim Scrollen kleiner werden
  - SF Pro und SF Symbols
  - echte Tiefe durch Materialien statt durch dicke Rahmen
- Ruhig, aufgeräumt und viel Weißraum. Eine klare Hierarchie pro Screen: Was ist das Wichtigste, was sieht man zuerst?
- Eine eigene Markenfarbe (ausgehend vom Avocado-Grün, aber hochwertig und nicht Standard-Grün) plus eine sorgfältige neutrale Palette. Hell **und** dunkel müssen funktionieren.
- Gerne Produktfotos, Rezeptfotos und Marken-Logos von Supermärkten, damit es lebendig und echt wirkt.
- Gamification und Maskottchen sparsam und erwachsen einsetzen: Belohnungsmomente (Einkauf abgeschlossen, Geld gespart, Challenge geschafft) dürfen Freude machen, ohne kindisch zu wirken.
- Eine einheitliche Designsprache über alle Bereiche (Listen, Angebote, Rezepte, Kalorien, Chat), damit sich die App wie ein Produkt anfühlt und nicht wie fünf zusammengeklebte Apps.

---

## 5. So möchte ich, dass du vorgehst

**Schritt 1: Analyse (nur Text).** Schau dir das Video an und sag mir kurz und ehrlich, was am aktuellen Design die größten Probleme sind. Gemeint sind Struktur, Hierarchie, Navigation, Konsistenz und Wirkung, nicht nur Farben.

**Schritt 2: Designkonzept und Designsystem (Text + 1–2 Bilder).**
- Name/Idee des Konzepts in einem Satz.
- Neue Navigationsstruktur (Tabs, wo Avo sitzt, wie man zwischen Bereichen wechselt).
- Farben (mit Hex-Codes, hell und dunkel), Typografie (Größen und Gewichte), Abstände, Eckenradien, Glas-Materialien, Schatten, Icons.
- Die wichtigsten Komponenten: Listen-Zeile, Artikel-Zeile, Angebots-Karte, Rezept-Karte, Hinweis-Karte, Chat-Blase, Buttons, Chips, Eingabeleiste, Sheets.
- Neues App-Icon und Maskottchen-Stil.

**Schritt 3: Screens als iPhone-Mockups (Bilder).** Danach bitte für jeden Screen ein eigenes Konzeptbild:
- Hochformat in einem iPhone-17-Pro-Rahmen, deutsche Texte, realistische Beispieldaten.
- Alle Bilder im exakt gleichen Stil, also gleiche Farben, Schriften, Komponenten und gleiche Tab-Bar.
- Mach maximal 2–3 Screens pro Antwort und frag mich dann, ob du weitermachen sollst.

In dieser Reihenfolge:
1. Startseite (Home) mit Listen und Hinweis-Karten
2. Listen-Detail (gemeinsame Liste, nach Kategorien sortiert, mit Angebots-Vorschlägen beim Tippen und Preisvergleichsleiste)
3. Preisvergleich-Sheet (alle Märkte)
4. Avo-Chat (mit Antwort-Karten, z. B. Rezept- oder Angebots-Karten)
5. Paywall / Avo Pro
6. Rezepte-Tab
7. Rezeptdetail
8. Kochmodus
9. Kalorien-Dashboard
10. Essen hinzufügen (Foto-Analyse)
11. Angebote der Woche
12. Verlauf / Monatsrückblick mit Ersparnis
13. Kosten teilen
14. Onboarding: Willkommen und Personalisierung
15. Profil und Einstellungen
16. Liste per Foto importieren (Prüf-Sheet)
17. Leere Zustände und Erfolgsmomente (z. B. Einkauf abgeschlossen, Geld gespart)
18. Home-Screen-Widget
19. Dunkelmodus-Versionen von Home, Listen-Detail und Avo-Chat

Zum Schluss erwarte ich eine kurze Liste der wichtigsten Designregeln, damit wir das Konzept 1:1 in der App umsetzen können.

Zauber uns etwas richtig Gutes. Das soll eine App werden, die man im App Store sieht und sofort laden will.
