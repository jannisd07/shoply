# A6 Rezepte: Ergebnis und offene Punkte (08.11.2026)

A6 ist auf `main`: Bibliothek `b435582`, Rezepte-Tab `f2f0c0c`, Kochmodus und Editor `7ce2a24`, Rezeptdetail `f8d80d9`,
dazu Editor als Vollbild `86cc1de`, Abschnittskopf-Link 44 pt `de52181`, „Weiter“ im Kochmodus rechtsbündig. Auftrag:
[`a6-auftrag.md`](a6-auftrag.md). Jeder Teil auf sauberem `main` geprüft (bis 2.370 Tests grün, `dart analyze` ohne
Errors/Warnings). Im Simulator (iPhone 17) angesehen: Tab, Detail, Kochmodus.

## Fehlende Daten und Server (A)

- `RecipeService.getRecipes`/`getMyRecipes`/`getSavedRecipes`/`getRecipesByAuthor` liefern bei Fehlern `[]` statt zu
  werfen; `[]` überschreibt den Rezept-Cache. Richtig: werfen, `[]` nicht cachen.
- Allergien/Ernährung kommen nur über `currentUserProvider` aus dem Netz; offline keine Allergie-Warnungen. Gehören in
  den Profil-Cache (`OfflineCacheService`).
- `creator_follows` in Supabase prüfen (Unique, RLS); ohne Tabelle bleibt Folgen nur lokal.
- Sichtbarkeit „Nur ich“: Spalte `recipes.is_public` und Parameter in `createRecipe`/`updateRecipe` fehlen;
  `createRecipe` darf nie die E-Mail als Autorname nehmen.
- `RecipeDraft`: Felder `recipeId`, `difficulty`, `isPublic` fehlen (Entwürfe beim Bearbeiten, Schwierigkeit).
- `RecipeService.updateRecipe(…, labels:)` fehlt (Schwierigkeit geht beim Bearbeiten verloren).
- Meldungen: keine Server-Tabelle (E-09); „Melden“ öffnet eine Mail an support@shoplyai.app.
- `getPopularRecipes` sagt nicht, ob Wochen- oder Gesamtrangfolge.
- Server-Suche (RPC) und Nachladen beim Scrollen fehlen; die Suche läuft lokal über den Katalog.
- Schalter „Rezepte automatisch anpassen“ fehlt im Profil (heute immer angepasst).

## Komponenten (A)

- `AvoColors.warning` fehlt (Allergie-Hinweise nutzen `destructive`).
- `AvoSearchField`: Mikrofon (`onDictate`) und D2-Kapselform (40 pt); `AppFilterChip`: Symbol vor dem Text.
- `AvoToast` mit Ziel („Zur Liste“, E-16); `AvatarSize` 36/64 mit Foto; `AvoIcons` personBadgePlus, bookmarkSlash.
- `showAvoMenu`/`showAvoConfirm` nehmen das App-Thema, im (immer dunklen) Kochmodus erscheinen sie hell.
- Zwei Allergie-Logiken: `RecipeDietProfile` in `recipes_home_data.dart` (browse) und
  `widgets/recipe_detail_adaptation.dart` (detail); zusammenführen zu `lib/data/services/recipe_adaptation.dart`.
- Die Texte liegen in vier Dateien `recipes_{browse,library,detail,cook}.dart`; nach A6 in `recipes.dart`
  zusammenführen, alte Schlüssel (`cooking_mode_*`, `save_draft_question*` …) entfernen.

## Bewusst abgewichen

- Kochmodus fragt beim Schließen nur mitten im Kochen nach (Konzept: keine Rückfrage).
- Editor: „Weiter“ oben als Kapsel; Zeiten per Stepper in Minuten; kein Umsortieren, kein Bildausschnitt.
- Detail: Reihenfolge Zutaten → Angebote → Zubereitung → Nährwerte; Nährwerte als Balken gegen EU-Referenz.
- Nicht gebaut: Varianten, Kommentare (keine Daten), „Zum Wochenplan“ (B), „Weiter kochen“ im Tab.

## Für Teil B

- Slots `RecipeOfferSummary(recipe:, listId:)`, `IngredientOfferBadge(listId:, ingredient:)` (kommen mit Angebote S15);
  `addRecipeToPlan` (kommt mit B7). Käse im `allergen_matcher.dart` ist erledigt (`0e1d0e8`, `88f558e`).
