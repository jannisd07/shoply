# Partneranfrage Angebote (Entwurf)

Stand 07.11.2026. Entwurf für den Owner, der die Anfrage selbst verschickt. Alles in eckigen Klammern wird vor dem
Versand ersetzt oder gestrichen. Fakten stammen aus der Recherche
[Preise, Angebote und Artikelbilder](../research/Preise%20Angebote%20und%20Artikelbilder.md) und aus Kapitel 12 des
Konzepts (Regeln für Angebote).

## Vor dem Versand

Der Brief beschreibt die Angebote so, wie Teil B sie gerade umbaut: an einer Liste mit Markt nur dessen Angebote, „in
deiner Region“, kein Preisvergleich zwischen Märkten, nie Teil von Pro. Die Version im App Store weicht davon noch ab.
Sie hat den „günstigsten Korb“, und ihre Paywall führt „Angebote deiner Märkte“ als Pro-Funktion (`premium_feat_deals`
in `lib/presentation/screens/subscription/subscription_screen.dart`; im Code hat Teil A das am 07.11.2026 gestrichen,
`10f30c6`, die App-Store-Version zeigt es aber noch). Deshalb stehen im Brief die Beschreibung und der Satz zu Pro unter „in der
Version, die wir gerade fertigstellen“.

Verschick den Brief erst, wenn eine Version im App Store ist, deren Paywall keine Angebote mehr nennt. Die Recherche
nennt das Pro-Abo als den Punkt, der jedem Argument der privaten Nutzung die Grundlage nimmt. Wer bei marktguru
nachsieht und Angebote in der Paywall findet, liest dort das Gegenteil des Briefs. Ist der ganze Umbau erschienen, kann
der Halbsatz „in der Version, die wir gerade fertigstellen“ weg, und aus „In der neuen Version sind die Angebote“ wird
„Bei Avo sind die Angebote“.

Heute liest die App die Angebote ohne Vereinbarung. Für das Gespräch mit einem Anwalt ist das der vollständige Stand der
Arbeitskopie vom 07.11.2026:

- Die Abfragen gehen direkt vom iPhone der Person an die interne Schnittstelle `api.marktguru.de/api/v1/offers/search`.
- Die Zugangsschlüssel liest die App zur Laufzeit aus dem Quelltext der marktguru-Startseite, hält sie bis zu sieben
  Tage vor und holt sie nach Fehler 401 oder 403 neu. Ein fest eingebautes Ersatzpaar gibt es nicht mehr.
- Beide Anfragen geben sich als Browser aus (`user-agent: Mozilla/5.0 …` in
  `lib/data/services/offer_price_service.dart:281` und `:326`). Für die Linie des BGH (I ZR 224/12: Scraping ist
  hinnehmbar, solange keine technischen Sperren umgangen werden) zählt das zusammen mit dem Nachladen der Schlüssel.
- Produktbilder lädt die App direkt vom marktguru-CDN (`mg2de.b-cdn.net`, `lib/data/models/store_offer.dart:115`).
  Plan B2.2 streicht das.
- Die Paywall im App Store führt Angebote als Pro (siehe oben).
- Avo gibt Angebote aus seinen Werkzeugen heute an Gemini (Google) weiter, nach dem Umbau B1 an Claude (Anthropic).

Die AGB von marktguru verbieten das automatische Auslesen und jede geschäftliche Nutzung (Ziffer 4e) und die
kommerzielle Nutzung gegenüber Dritten (Ziffer 4d). Ohne den optionalen Absatz sagt der Brief nicht, woher die Angebote
in Avo heute kommen. Er behauptet nicht, dass Avo marktguru nicht nutzt, schweigt aber dazu, und wer bei marktguru die
App öffnet, erkennt die eigenen Daten. Der optionale Absatz spricht die heutige Nutzung offen an. Das kann Vertrauen
schaffen, ist aber ein Eingeständnis. Was davon in den Brief kommt, entscheidest du, am besten nach einem kurzen
Gespräch mit einem Anwalt. Ob die App bis zu einer Lizenz eine ehrliche Kennung wie `Avo/<Version>` statt eines Browsers
sendet, ist eine Frage für B2.1. Bei Bonial und Shopfully stellt sich die Frage nach der heutigen Nutzung nicht, deren
Daten nutzt Avo nicht.

Weitere Punkte:

- Avo und KI: Für Antworten zu Angeboten schickt Avo Produktname, Preis und Gültigkeit einzelner Angebote an Claude
  (Plan B1.6). Der Brief fragt danach (Punkt 2 der Aufzählung). Bis eine Antwort da ist, kann Avo ohne
  Angebots-Werkzeuge laufen (`tools_variant: "no_offers"`).
- Suche: Unter „Angebote der Woche“ zeigt die Suche Treffer mehrerer Märkte, nach Markt gruppiert und nie nach Preis
  sortiert. Ob sie standardmäßig nur die Märkte der eigenen Listen zeigt, ist offen (F12-10). Fällt die Entscheidung
  anders aus, den Satz dazu im Brief anpassen.
- Zahlen nur mit Beleg, etwa aktive Nutzer pro Monat aus App Store Connect. Ohne belegte Zahl fällt der Satz weg; der
  Brief trägt auch ohne.
- Anhang: zwei oder drei Bilder (Liste mit der Angebotszeile, Angebot am Artikel, Einstellungen „Preise & Angebote“).
  Diese und die im Brief angebotenen Screenshots nur mit erfundenen Beispieldaten, etwa „Milch, 0,99 € bei Lidl, laut
  Händler statt 1,19 €“ aus Kapitel 12, und mit dem Platzhalter in der Quellen-Fußnote. Echte Treffer aus der heutigen
  Anbindung zeigen die heutige Nutzung, auch ohne den optionalen Absatz. An Bonial oder Shopfully geschickt, gäben sie
  marktguru-Daten an einen direkten Wettbewerber weiter, und genau diese Nutzung gegenüber Dritten verbietet Ziffer 4d.
- Händler erscheinen auf den Bildern mit Markenpunkt und Name wie im Konzept (00 4.8), Logos nur, wenn sie in der App
  erlaubt sind. Die Buchstaben-Kacheln aus D2 („L“ auf Lidl-Blau) sind wegen ihrer Nähe zum Logo eine offene
  Owner-Frage und gehören nicht in den Anhang.
- Empfänger: marktguru gehört seit Januar 2025 zum Vermarktungsportfolio von Seven.One (ProSiebenSat.1). Einen Kontakt
  für Partner oder Vermarktung gibt es über info.marktguru.de oder über Seven.One. Bonial führt kaufDA und MeinProspekt
  (bonial.com, Bereich Unternehmen). Publitas hat einen Entwicklerbereich unter developers.publitas.com. Geprüfte
  Adressen enthält dieses Dokument keine.
- Reihenfolge: marktguru zuerst. Bonial und Shopfully oder Publitas parallel oder nach etwa zwei Wochen ohne Antwort.
- Danach: Ergebnis in [`status-B.md`](status-B.md) und [`docs/OPEN-ISSUES.md`](../OPEN-ISSUES.md) eintragen. Mit
  Lizenz bekommt die Quellen-Fußnote in der App den Namen des Partners statt des Platzhalters. Angebotsbilder kämen dann
  wieder in Frage; dafür müssten Regel 7 aus Kapitel 12 („nie das Bild der Angebotsquelle“) und die Global Constraints
  des Plans per Owner-Entscheidung geändert werden.

## Anfrage an marktguru

**Betreff:** Partneranfrage: marktguru-Angebote in der Einkaufslisten-App Avo

Guten Tag [Frau/Herr Nachname],

ich bin [Vorname Nachname], [Rolle] von Avo, einer Einkaufslisten-App für das iPhone ([App-Store-Link]). In Avo
schreiben Menschen ihre Liste für den nächsten Einkauf, oft zu zweit oder mit der Familie, und haken sie im Markt ab.
Für die Angebote in Avo suchen wir eine lizenzierte Quelle und fragen deshalb bei Ihnen nach Zugang und Lizenz.

Für Händler ist das ein guter Moment. Wer „Milch“ auf die Liste setzt, plant genau diesen Kauf, und Avo hängt das
passende Angebot an diesen Eintrag. Ein Händler erreicht so Leute, die ohnehin bei ihm einkaufen wollen. [Optional, nur
mit belegter Zahl: Avo nutzen derzeit [Zahl] Menschen im Monat.]

In der Version, die wir gerade fertigstellen, sieht man ein Angebot vor allem am Artikel auf der Liste, als Vorschlag
beim Eintippen und in einer Zeile über der Liste, etwa „4 von 11 Artikeln diese Woche bei Lidl im Angebot, ca. 3,20 €
gespart, in deiner Region“. Außerdem erscheinen Angebote auf einer Detailseite zum Angebot, auf einer Seite mit allen
Angeboten zu einer Liste und unter „Angebote der Woche“, mit eigener Suche und mit Angeboten für Artikel, die jemand oft
kauft. Dazu kommen Hinweise auf der Startseite, Erinnerungen zum Nachkaufen, Angebote an den Zutaten von Rezepten und
die Antworten des Assistenten Avo, wenn jemand nach Angeboten fragt. Die Ersparnis steht auch nach dem Einkauf, im Verlauf und im
großen iOS-Widget einer Liste.

Welche Angebote Avo zeigt, hängt am Markt der Liste. Hat eine Liste einen Markt, zum Beispiel „Wocheneinkauf · Lidl“,
zeigt Avo dort nur dessen Angebote. Hat sie keinen, zeigt Avo je Artikel höchstens ein Angebot aus den Lieblingsmärkten
der Person, in der Reihenfolge, die sie selbst festgelegt hat. Die Suche unter „Angebote der Woche“ listet Treffer
mehrerer Märkte, nach Markt gruppiert. Avo rechnet nie aus, welcher Markt günstiger ist, und sortiert nie nach Preis.
Eine aus Angebotspreisen errechnete Summe für den ganzen Einkauf zeigt Avo auch nicht. Zu jedem Angebot nennen wir
Preis, Grundpreis und Gültigkeit. Einen Vergleichspreis nennen wir nur als „laut Händler statt 1,19 €“ und rechnen
keine eigenen Prozent-Rabatte aus; die Ersparnis ergibt sich aus diesem Vergleichspreis und den Mengen auf der Liste.
„In deiner Region“ steht dabei, weil die Angebote nach Postleitzahl gelten und nicht für eine bestimmte Filiale.

In der neuen Version sind die Angebote für alle kostenlos. Avo hat ein optionales Pro-Abo für andere Funktionen,
Angebote gehören ausdrücklich nicht dazu. Ich erwähne das, weil es für die Lizenz eine Rolle spielen dürfte.

[Optionaler Absatz, siehe Hinweise oben, Wortlaut am besten mit dem Anwalt abstimmen: Offen gesagt zeigt Avo Ihre
Angebote heute schon an. Die App fragt dafür ohne Vereinbarung die Schnittstelle hinter Ihrer Web-Suche ab, mit
Zugangsschlüsseln aus dem Quelltext Ihrer Webseite. Das möchten wir auf eine saubere Grundlage stellen. Kommen wir nicht
zusammen, schalten wir die Anbindung ab.]

Von Ihnen bräuchten wir:

1. Zugang zu einer offiziellen Schnittstelle: Suche nach Produktbegriff und Postleitzahl, Filter nach Händler, mit
   Produktname, Preis, Grundpreis, Vergleichspreis des Händlers, Menge und Gültigkeit.
2. Eine Lizenz, diese Daten und die Produktbilder in Avo zu zeigen: in der App, in ihren iOS-Widgets und Mitteilungen
   und in den Antworten des Assistenten. Für diese Antworten gehen Produktname, Preis, Menge und Gültigkeit der
   passenden Angebote an einen externen KI-Dienst (Anthropic), der daraus den Antworttext formuliert. Bitte sagen Sie
   uns, ob eine Lizenz das abdecken kann.
3. Ihre Vorgaben zur Quellenangabe: Logo, Wortlaut, Platzierung und Linkziel.
4. Ihre Konditionen und einen Testzugang.

Im Gegenzug nennen wir marktguru überall, wo ein Angebot erscheint, auf Wunsch mit Logo, und verlinken auf das Angebot
oder den Prospekt bei marktguru. Daten holen wir ausschließlich über die Schnittstelle, die Sie freigeben, und nur, wenn
jemand seine Postleitzahl hinterlegt oder den Standort freigegeben hat. Abfragen entstehen beim Eintippen ab zwei
Zeichen, bei der Suche unter „Angebote der Woche“, für die offenen Artikel einer Liste höchstens alle sechs Stunden, für
oft gekaufte Artikel höchstens sechs Suchen in sechs Stunden, für höchstens zehn Zutaten eines Rezepts und wenn jemand
Avo nach Angeboten fragt. Pro Abfrage übermitteln wir nur Suchbegriff, Postleitzahl und gegebenenfalls den Händler,
keine Konto- oder Gerätekennungen. Die Abfragen gehen direkt vom iPhone der Person an die Schnittstelle; möchten Sie
keine IP-Adressen von Endnutzern sehen, leiten wir sie über unseren Server. Kataloge laden wir nicht auf Vorrat. Stört
Sie etwas an der Darstellung, können wir die Angebote zentral abschalten, ohne App-Update.
[Optional, nur wenn wir es messen: Auf Wunsch schicken wir monatlich zusammengefasste Zahlen zu Einblendungen und
Klicks, ohne Bezug zu einzelnen Personen.]

Ist so eine Zusammenarbeit für Sie denkbar? Über ein kurzes Gespräch würde ich mich freuen. Screenshots der
Angebotsansichten schicke ich gern vorab.

Viele Grüße
[Vorname Nachname]
[Rolle], Avo
[Firma, Rechtsform, Anschrift; bei GmbH oder UG auch Sitz, Registergericht, Registernummer und Geschäftsführung
(§ 35a GmbHG), bei eingetragenen Kaufleuten die Angaben nach § 37a HGB]
[E-Mail] · [Telefon]

## Variante Bonial (kaufDA, MeinProspekt)

Der Brief bleibt gleich, bis auf diese Stellen. Den optionalen Absatz zur heutigen Nutzung lässt du weg, und
Screenshots gibt es auch hier nur mit Beispieldaten (siehe „Vor dem Versand“).

**Betreff:** Partneranfrage: Angebote von kaufDA in der Einkaufslisten-App Avo

Erster Absatz, letzter Satz:

> Für die Angebote in Avo suchen wir eine lizenzierte Quelle und fragen deshalb, ob wir die Angebote zeigen dürfen, die
> Händler über kaufDA und MeinProspekt verbreiten.

Vor der Aufzählung „Von Ihnen bräuchten wir“ zusätzlich:

> Für eine Einkaufsliste brauchen wir einzelne Angebote mit Preis, die sich einem Eintrag wie „Milch“ zuordnen lassen.
> Ganze Prospekte helfen uns dafür wenig. Gibt es bei Bonial einen Weg zu solchen Daten, etwa über Tjek?

Im Absatz „Im Gegenzug“ steht statt marktguru: „nennen wir kaufDA (oder die Marke, die Sie vorgeben) … und verlinken
auf das Angebot oder den Prospekt bei kaufDA“.

## Variante Shopfully oder Publitas

Auch hier bleibt der Brief gleich, ohne den optionalen Absatz und mit Screenshots nur aus Beispieldaten. Shopfully hieß
im deutschsprachigen Raum früher Offerista; dazu gehören wogibtswas und Tiendeo. Publitas spielt Prospekte über eine
Kooperation mit Offerista in über 1.400 Plattformen und Apps aus. Publitas antwortet vermutlich lieber auf Englisch;
dann den Brief übersetzen.

**Betreff:** Partneranfrage: Angebote auf Produktebene für die Einkaufslisten-App Avo

Erster Absatz, letzter Satz:

> Für die Angebote in Avo suchen wir eine lizenzierte Quelle und fragen deshalb, ob wir die Angebote deutscher
> Lebensmittelhändler zeigen dürfen, die über [Shopfully | Publitas] erscheinen.

Vor der Aufzählung zusätzlich, für Shopfully:

> Das Prospekt-Widget, das Shopfully über Awin anbietet, kennen wir. Für eine Einkaufsliste brauchen wir aber einzelne
> Angebote mit Preis, Menge und Gültigkeit, die Avo einem Eintrag wie „Milch“ zuordnen kann. Können Sie solche Daten
> liefern, und für welche deutschen Lebensmittelhändler?

Für Publitas:

> Ihre GraphQL-Schnittstelle für Partner haben wir gesehen. Liefert sie einzelne Angebote mit Preis, Menge und
> Gültigkeit, die Avo einem Eintrag wie „Milch“ zuordnen kann? Und welche deutschen Lebensmittelhändler sind dabei?

Im Absatz „Im Gegenzug“ steht statt marktguru der Name des Empfängers oder die Marke, die er vorgibt.
