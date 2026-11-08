import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/presentation/screens/lists/shopping_trip_completion.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

/// Runs the checkout of [listId] on [context]. True when the trip was saved,
/// false when it was cancelled, failed or had nothing checked.
typedef CheckoutRunner =
    Future<bool> Function(BuildContext context, WidgetRef ref, String listId);

/// The checkout behind [openCheckoutFlow]: for now the existing flow of the
/// list screen ([completeShoppingTrip]); B8 replaces it with the full-screen
/// steps. Override in tests.
final checkoutRunnerProvider = Provider<CheckoutRunner>(
  (ref) => _runExistingCheckout,
);

/// "Einkauf abschließen" for [listId] on its own full-screen route, pushed
/// like any screen (contract `b_slots.dart`). True when the trip was saved,
/// false when it was cancelled, failed or had nothing checked. Shows no
/// confirmation of its own: the host shows the success moment.
Future<bool> openCheckoutFlow(BuildContext context, String listId) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => CheckoutFlowScreen(listId: listId)),
  );
  return saved ?? false;
}

/// Stub of the checkout screen until B8: runs the checkout right away and
/// closes with its result.
class CheckoutFlowScreen extends ConsumerStatefulWidget {
  const CheckoutFlowScreen({super.key, required this.listId});

  final String listId;

  @override
  ConsumerState<CheckoutFlowScreen> createState() => _CheckoutFlowScreenState();
}

class _CheckoutFlowScreenState extends ConsumerState<CheckoutFlowScreen> {
  bool _running = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    var saved = false;
    try {
      saved = await ref.read(checkoutRunnerProvider)(
        context,
        ref,
        widget.listId,
      );
    } catch (e) {
      debugPrint('❌ [CHECKOUT] Checkout failed: $e');
    }
    if (!mounted) return;
    setState(() => _running = false);
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Leaving mid-checkout would skip the rest of it (push to the members).
      canPop: !_running,
      child: Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          backgroundColor: AppColors.background(context),
          elevation: 0,
          automaticallyImplyLeading: !_running,
          title: Text(
            context.tr('complete_shopping'),
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: const SafeArea(
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
    );
  }
}

/// [completeShoppingTrip] only starts a reload of the list, so the items are
/// reloaded here to tell a saved trip (checked items gone) from a cancelled
/// one.
Future<bool> _runExistingCheckout(
  BuildContext context,
  WidgetRef ref,
  String listId,
) async {
  final items =
      ref.read(itemsNotifierProvider(listId)).valueOrNull ??
      const <ShoppingItemModel>[];
  final checkedIds = {
    for (final item in items)
      if (item.isChecked) item.id,
  };
  final listName = await _listName(ref, listId);
  if (!context.mounted) return false;

  await completeShoppingTrip(
    context,
    ref,
    listId: listId,
    listName: listName,
    items: items,
  );
  if (checkedIds.isEmpty || !context.mounted) return false;

  await ref.read(itemsNotifierProvider(listId).notifier).loadItems();
  if (!context.mounted) return false;
  final left =
      ref.read(itemsNotifierProvider(listId)).valueOrNull ??
      const <ShoppingItemModel>[];
  return !left.any((item) => checkedIds.contains(item.id));
}

Future<String> _listName(WidgetRef ref, String listId) async {
  final lists = ref.read(listsNotifierProvider).valueOrNull;
  final known = lists?.where((list) => list.id == listId).firstOrNull;
  if (known != null) return known.name;
  return await ref.read(itemRepositoryProvider).getListName(listId) ?? '';
}
