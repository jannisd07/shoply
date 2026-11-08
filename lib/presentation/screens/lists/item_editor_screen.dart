import 'package:flutter/widgets.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/item_form_dialog.dart';

/// Opens one item full screen to edit it (D2-Artikel), or to add one with
/// [prefill] when [item] is null. The one entry point for every screen.
///
/// A5 replaces the old dialog behind it with the D2 full-screen editor; the
/// signature stays.
Future<void> openItemEditor(
  BuildContext context, {
  required String listId,
  ShoppingItemModel? item,
  String prefill = '',
}) => showItemFormDialog(context, listId: listId, item: item, prefill: prefill);
