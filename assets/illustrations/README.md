# Artikelbilder (eigene Illustrationen)

Ordner für die eigenen Artikelbilder, die `ArticleImage`
(`lib/presentation/widgets/article_image.dart`) neben Listenartikeln zeigt. Stil, Technik und die Bild-Prompts stehen in
[`docs/redesign/artikelbilder-prompts.md`](../../docs/redesign/artikelbilder-prompts.md). Der Owner erzeugt die Bilder.

## Dateien

- Name: `<key>.webp`, nur `a` bis `z`, `0` bis `9` und `_` (zum Beispiel `milk.webp`, `green_beans.webp`).
- Der Schlüssel ist englisch (britisch, wie die Spalte „English“ der Prompt-Tabelle) und wird nach dem ersten Bild nie
  mehr umbenannt.
- 512 × 512 px, WebP mit Alpha, sRGB, höchstens 60 KB, ohne EXIF.

## Zuordnung Artikelname → Schlüssel

Die App sucht nie nach dem Dateinamen. Sie ordnet einen Listeneintrag über die Tabelle `articleIllustrationKeys` in
`lib/data/services/article_image_resolver.dart` einem Bild zu:

- Schlüssel der Tabelle sind Artikelnamen in der Form von `normalizeProductName`: klein, ä → ae, ö → oe, ü → ue,
  ß → ss, nur Buchstaben, Ziffern und Leerzeichen („gruene bohnen“, nicht „Grüne Bohnen“).
- Mehrere Namen dürfen auf denselben Schlüssel zeigen: Deutsch und Englisch, Plural, Synonyme und regionale Wörter
  (Möhren/Karotten, Semmel/Brötchen) sowie amerikanisches Englisch (zucchini, eggplant, yogurt, cookies, chips für
  `crisps` …, Liste in der Prompt-Datei).
- Gesucht wird in dieser Reihenfolge: der ganze Name, der Name ohne Zahlen („Milch 1,5 %“ → „milch“), das letzte Wort
  („Frische Milch“ → „milch“). Teile eines Wortes zählen nie („Milchreis“ ist keine Milch).

Reihenfolge der Bildquellen: eigene Illustration, sonst Foto von Open Food Facts (nur mit Barcode, weißer Grund, nicht
freigestellt, mit Quellenzeile „Foto: Open Food Facts, CC BY-SA“), sonst Kategorie-Symbol, sonst eine neutrale Fläche.
Ab Textgröße AX1 und mit ausgeschalteter Einstellung „Artikelbilder anzeigen“ zeigt die App gar kein Bild.

## Bilder einbauen

1. Datei hier ablegen und ihre Namen in `articleIllustrationKeys` eintragen.
2. Einmalig in `pubspec.yaml` unter `flutter: assets:` den Ordner `assets/illustrations/` eintragen (geteilte Datei,
   eigener kleiner Commit). Diese README landet dann mit im App-Bundle (wenige KB); wer das nicht will, verschiebt sie
   nach `docs/`.
3. `flutter test test/article_image_test.dart`: Der Test schlägt fehl, wenn ein Schlüssel nicht normalisiert ist, eine
   Datei fehlt oder `pubspec.yaml` den Ordner nicht nennt.

Keine Bilder aus Händler-Shops, Prospekten oder von Angebotsquellen (Urheberrecht, § 72 UrhG).
