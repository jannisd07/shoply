# A5 Stand je Teil (Unterbrechung 08.11.2026, Mac-Neustart)

Berichte der vier A5-Agenten beim Anhalten. Nichts davon ist committet; die Dateien liegen im Arbeitsordner.
Auftrag: [`a5-auftrag.md`](a5-auftrag.md). Dateizuordnung: `status-A.md`, Abschnitt „Unterbrechung“.

## item (Artikel-Vollbild, Import)

| Datei | Stand |
|---|---|
| `translations/lists_item.dart` | fertig (Präfixe `list_item_`, `list_item_unit_`, `list_item_import_`, keine Doppelungen) |
| `widgets/item_editor_parts.dart` (neu) | halb: Fehler `:584` `kTouchSlop` unbekannt (`import 'package:flutter/gestures.dart';` fehlt), Info `:148` `library_private_types_in_public_api` (`covariant RenderObject` + Cast); kein Test |
| `item_editor_screen.dart` | halb: Code vollständig (`ItemEditorScreen` für Bearbeiten/Hinzufügen/Entwurf, `openItemDraftEditor`/`ItemDraft`, Löschen mit Rückgängig, offline/Fehler); kein Test. `openItemEditor` öffnet schon das D2-Vollbild |
| `widgets/item_form_dialog.dart` | nicht begonnen: zur Weiterleitung kürzen (`showItemFormDialog` → `openItemEditor`), `PaperPrimaryButton` vorerst behalten (Importe in `share_list_dialog.dart`, `list_detail_screen.dart`) |
| `widgets/attachment_sheet.dart`, `import_review_sheet.dart` | nicht begonnen (alte Bottom-Sheets) |
| Tests `test/screens/lists/item_editor_*`, `import_*` | nicht begonnen; `test/attachment_sheet_test.dart` erwartet alte Texte „Kamera / Fotos / Dateien“ |

Abweichung: „Artikel löschen“ ohne Rückfrage, mit Rückgängig (Konzept 11 §4). Für B: `ArticleImageCredit` und
`articleImagesShown` sind nicht über `b_slots.dart` exportiert.

Nächste Schritte: (1) Analyse-Meldungen beheben, `item_form_dialog.dart` zur Weiterleitung. (2)
`item_editor_screen_test.dart` (layoutMatrix + Verhalten mit ersetzten Providern). (3) Import: `showAttachmentSheet` →
`AvoMenu` am Plus mit „Foto aufnehmen / Foto wählen / Datei wählen / Text einfügen“ + Status-Kapsel;
`showImportReviewSheet` → Vollbild „14 Artikel erkannt“ mit Häkchen, Hinzufügen über `addItems` mit Rückgängig; neu
`openListImport(context, listId:, anchorKey:)` für „detail“; Tests.

## detail (Liste)

offen (Bericht ausstehend)

## shopping (Einkaufsmodus)

offen (Bericht ausstehend)

## overview (Listen-Übersicht, Teilen, Listen-Info)

offen (Bericht ausstehend)
