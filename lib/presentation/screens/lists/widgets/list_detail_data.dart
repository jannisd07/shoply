import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/screens/lists/category_order_screen.dart';
import 'package:shoply/presentation/screens/lists/item_editor_screen.dart';
import 'package:shoply/presentation/screens/lists/list_settings_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/attachment_sheet.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_list_dialog.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/routes/route_paths.dart';

// Data and actions of the list screen (Konzept 11 §1), kept apart from the
// widgets so tests can replace them.

/// The list [listId] from the loaded lists; null until they are loaded or
/// when the list is gone.
final listDetailListProvider = Provider.family<ShoppingListModel?, String>(
  (ref, listId) => ref.watch(
    listsNotifierProvider.select(
      (lists) => lists.valueOrNull?.where((l) => l.id == listId).firstOrNull,
    ),
  ),
);

/// Names of the other members of [listId] for the avatar stack in the
/// header (without the signed-in person). Kept for the session, so the
/// second visit shows them at once.
final listDetailMembersProvider = FutureProvider.family<List<String>, String>((
  ref,
  listId,
) async {
  final me = ref.watch(authUserIdProvider);
  final rows = await ref.watch(listRepositoryProvider).getListMembers(listId);
  return [
    for (final row in rows)
      if (row['user_id'] != me)
        if (_displayName(row) case final name?) name,
  ];
});

String? _displayName(Map<String, dynamic> row) {
  final user = row['user'];
  final name = user is Map ? user['display_name'] : null;
  if (name is! String || name.trim().isEmpty) return null;
  return name.trim();
}

/// Whether the signed-in person created [listId]: true, false, or null while
/// the list or the account is unknown.
final listDetailIsOwnerProvider = Provider.family<bool?, String>((ref, listId) {
  final list = ref.watch(listDetailListProvider(listId));
  final me = ref.watch(authUserIdProvider);
  if (list == null || me == null) return null;
  return list.ownerId == me;
});

/// Sum of the saved prices of the open [items] (price × count for piece
/// items), or null when none of them has a price. Owner rule 07.11.2026:
/// only saved prices of this list, never a market comparison.
double? listOpenPriceTotal(Iterable<ShoppingItemModel> items) {
  double? total;
  for (final item in items) {
    final price = item.price;
    if (item.isChecked || price == null) continue;
    total = (total ?? 0) + price * item.pricingQuantity;
  }
  return total;
}

/// "≈ 23,80 €" (de) or "≈ €23.80" (en).
String formatListTotal(double total, String languageCode) {
  final money = NumberFormat.currency(
    locale: languageCode,
    symbol: '€',
    decimalDigits: 2,
  ).format(total);
  return '≈ $money';
}

/// Everything the list screen opens or changes outside its own items. The
/// targets are the public entry points of the other A5 parts; tests override
/// [listDetailActionsProvider] with a recorder.
class ListDetailActions {
  const ListDetailActions();

  /// The item full screen (Teil "item").
  Future<void> openItem(
    BuildContext context, {
    required String listId,
    required ShoppingItemModel item,
  }) => openItemEditor(context, listId: listId, item: item);

  /// Shopping mode (Teil "shopping").
  Future<void> openShopping(BuildContext context, String listId) async {
    await GoRouter.of(context).push<void>(RoutePaths.shopping(listId));
  }

  /// "Liste teilen".
  Future<void> share(
    BuildContext context,
    WidgetRef ref, {
    required String listId,
    required String listName,
  }) => showShareListDialog(context, ref, listId: listId, listName: listName);

  /// Listen-Info (members, leave or delete).
  Future<void> openInfo(
    BuildContext context, {
    required String listId,
    required String listName,
    String? ownerId,
  }) => Navigator.of(context).push<void>(
    CupertinoPageRoute(
      builder: (_) => ListSettingsScreen(
        listId: listId,
        listName: listName,
        ownerId: ownerId,
      ),
    ),
  );

  /// "Reihenfolge im Markt"; true when the order or the own categories
  /// changed.
  Future<bool> openStoreOrder(
    BuildContext context, {
    required String listId,
    required String listName,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      CupertinoPageRoute(
        builder: (_) => CategoryOrderScreen(listId: listId, listName: listName),
      ),
    );
    return changed ?? false;
  }

  /// "Zettel importieren" (Teil "item"): menu from [anchorKey], reading,
  /// review full screen and adding in one batch with "Widerrufen".
  Future<void> importNote(
    BuildContext context, {
    required String listId,
    required GlobalKey anchorKey,
  }) => openListImport(context, listId: listId, anchorKey: anchorKey);

  /// "Einkauf abschließen" (Teil B); true when the trip was saved.
  Future<bool> checkout(BuildContext context, String listId) =>
      openCheckoutFlow(context, listId);

  Future<void> renameList(WidgetRef ref, String listId, String name) => ref
      .read(listsNotifierProvider.notifier)
      .updateList(listId, {'name': name});

  Future<void> deleteList(WidgetRef ref, String listId) =>
      ref.read(listsNotifierProvider.notifier).deleteList(listId);

  Future<void> leaveList(WidgetRef ref, String listId) async {
    await ref.read(listRepositoryProvider).leaveList(listId);
    await ref.read(listsNotifierProvider.notifier).loadLists();
  }

  Future<void> refreshLists(WidgetRef ref) =>
      ref.read(listsNotifierProvider.notifier).loadLists();

  /// Back to where the list was opened from, else to all lists.
  void back(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go(RoutePaths.lists);
    }
  }

  /// After the list was deleted or left.
  void openAllLists(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else {
      router.go(RoutePaths.lists);
    }
  }
}

/// The actions of the list screen; replaced in tests.
final listDetailActionsProvider = Provider<ListDetailActions>(
  (ref) => const ListDetailActions(),
);
