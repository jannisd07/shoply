import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:shoply/data/services/tip_service.dart';
import 'package:shoply/presentation/widgets/tips/tip_slot.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/lists/item_editor_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_detail_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_aisles.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_header.dart';
import 'package:shoply/presentation/screens/lists/widgets/shopping_mode_view.dart';
import 'package:shoply/presentation/screens/profile/settings/data/list_preferences.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/widgets/design/success_moment.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

/// Keeps the screen on while the shopping mode is open (Konzept 11 §5.1)
/// and "Bildschirm anlassen" is on (Einstellungen › Listen).
abstract interface class ShoppingKeepAwake {
  Future<void> enable();
  Future<void> disable();
}

/// [ShoppingKeepAwake] through `wakelock_plus`; failures are logged, never
/// shown.
class WakelockKeepAwake implements ShoppingKeepAwake {
  const WakelockKeepAwake();

  @override
  Future<void> enable() => _guard(WakelockPlus.enable, 'on');

  @override
  Future<void> disable() => _guard(WakelockPlus.disable, 'off');

  static Future<void> _guard(Future<void> Function() call, String what) async {
    try {
      await call();
    } catch (e) {
      debugPrint('⚠️ [SHOPPING] Screen could not be kept $what: $e');
    }
  }
}

/// How the shopping mode keeps the screen on; overridden in tests.
final shoppingKeepAwakeProvider = Provider<ShoppingKeepAwake>(
  (ref) => const WakelockKeepAwake(),
);

final _fetchedListNameProvider = FutureProvider.autoDispose
    .family<String?, String>(
      (ref, listId) => ref.read(itemRepositoryProvider).getListName(listId),
    );

/// The name of [listId]: from the loaded lists at once, otherwise asked
/// once from the server; null while unknown.
final shoppingListNameProvider = Provider.autoDispose.family<String?, String>((
  ref,
  listId,
) {
  final lists = ref.watch(listsNotifierProvider).valueOrNull;
  final known = lists?.where((l) => l.id == listId).firstOrNull;
  if (known != null) return known.name;
  return ref.watch(_fetchedListNameProvider(listId)).valueOrNull;
});

/// The shopping mode of one list (`/lists/:listId/shopping`, D2
/// X-Einkaufsmodus, Konzept 11 §5–6), full screen above the tab bar.
///
/// Opens from the local state of the list, keeps the screen on while it is
/// open and in the foreground, tells Avo where the person is, checks items
/// off through the list's notifier and finishes through Teil B's
/// [openCheckoutFlow]: when the trip is saved it shows the success moment
/// and closes. Leaving keeps every check (Konzept 11 §5.4); opening again
/// continues where it stopped.
class ShoppingModeScreen extends ConsumerStatefulWidget {
  /// Creates the shopping mode for [listId].
  const ShoppingModeScreen({super.key, required this.listId, this.listName});

  /// The list.
  final String listId;

  /// Name to show until the lists are loaded.
  final String? listName;

  @override
  ConsumerState<ShoppingModeScreen> createState() => _ShoppingModeScreenState();
}

class _ShoppingModeScreenState extends ConsumerState<ShoppingModeScreen>
    with WidgetsBindingObserver {
  late final ShoppingKeepAwake _keepAwake;
  late final StateController<AvoScreenContext?> _avoContext;
  late final StateController<ShoppingModeSession?> _session;
  late final ShoppingModeSession _ownSession;
  ShoppingModeSession? _previousSession;
  AvoScreenContext? _previousContext;
  AvoScreenContext? _ownContext;
  bool _awake = false;
  bool _foreground = true;

  /// "Bildschirm anlassen" in Einstellungen › Listen.
  bool get _keepOn => ref.read(listPreferencesProvider).keepScreenOn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _keepAwake = ref.read(shoppingKeepAwakeProvider);
    _avoContext = ref.read(avoScreenContextProvider.notifier);
    _previousContext = _avoContext.state;
    _session = ref.read(shoppingModeSessionProvider.notifier);
    _previousSession = _session.state;
    _ownSession = ShoppingModeSession(
      listId: widget.listId,
      startedAt: DateTime.now(),
    );
    // Providers may not change while the tree builds: set after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _session.state = _ownSession;
    });
    _setAwake(_keepOn);
    // Tip T2 is done however the shopping mode was opened.
    ref.read(tipServiceProvider).note(TipEvent.shoppingStarted);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _setAwake(_foreground && _keepOn);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setAwake(false);
    // Hand back the session of a shopping mode below (stacked), else clear
    // it, unless another shopping mode replaced ours.
    final session = _session;
    final ownSession = _ownSession;
    final previousSession = _previousSession;
    scheduleMicrotask(() {
      if (session.mounted && session.state == ownSession) {
        session.state = previousSession;
      }
    });
    // Hand Avo back the screen below, unless someone set a newer context.
    final own = _ownContext;
    final previous = _previousContext;
    final controller = _avoContext;
    if (own != null) {
      scheduleMicrotask(() {
        if (controller.mounted && controller.state == own) {
          controller.state = previous;
        }
      });
    }
    super.dispose();
  }

  void _setAwake(bool on) {
    if (on == _awake) return;
    _awake = on;
    unawaited(on ? _keepAwake.enable() : _keepAwake.disable());
  }

  /// Avo starts with this list while the shopping mode is open. Providers
  /// may not change while the tree builds, so it is set after the frame.
  void _tellAvo(String name) {
    final next = AvoScreenContext(
      screen: 'shopping',
      listId: widget.listId,
      listName: name.isEmpty ? null : name,
    );
    if (next == _ownContext) return;
    _ownContext = next;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ownContext == next) _avoContext.state = next;
    });
  }

  Future<void> _finish() async {
    final items =
        ref.read(itemsNotifierProvider(widget.listId)).valueOrNull ??
        const <ShoppingItemModel>[];
    final count = items.where((i) => i.isChecked).length;
    final saved = await openCheckoutFlow(context, widget.listId);
    if (!saved || !mounted) return;
    ref.read(tipServiceProvider).note(TipEvent.tripCompleted);
    unawaited(
      showSuccessMoment(
        context,
        title: context.tr('list_shop_saved_title'),
        subtitle: count == 1
            ? context.tr('list_shop_saved_one')
            : context.tr('list_shop_saved_many', params: {'count': '$count'}),
      ),
    );
    _close();
  }

  void _close() => unawaited(Navigator.of(context).maybePop());

  @override
  Widget build(BuildContext context) {
    final listId = widget.listId;
    final itemsState = ref.watch(itemsNotifierProvider(listId));
    // Read once here: an undo from the toast may run after this screen is
    // gone, when `ref` can no longer be used. The notifier stays alive.
    final notifier = ref.read(itemsNotifierProvider(listId).notifier);
    final name =
        ref.watch(shoppingListNameProvider(listId)) ?? widget.listName ?? '';
    _tellAvo(name);
    final items = itemsState.valueOrNull;
    // The switch can change while the shopping mode is open (Avo).
    ref.listen<bool>(
      listPreferencesProvider.select((p) => p.keepScreenOn),
      (_, on) => _setAwake(_foreground && on),
    );

    return ShoppingModeView(
      listId: listId,
      title: name.isEmpty ? context.tr('list_shop_title') : name,
      items: items,
      loadFailed: items == null && itemsState.hasError,
      order:
          ref.watch(shoppingAisleOrderProvider(listId)).valueOrNull ??
          const ShoppingAisleOrder(),
      companions: ref.watch(shoppingCompanionsProvider(listId)),
      offline: ref.watch(isOfflineProvider),
      showImages: listImagesShown(context, ref),
      onToggle: (item, checked) => notifier.toggleItemChecked(item.id, checked),
      onAdd: () =>
          unawaited(openItemEditor(context, listId: listId, prefill: '')),
      onEdit: (item) =>
          unawaited(openItemEditor(context, listId: listId, item: item)),
      onFinish: _finish,
      onClose: _close,
      onRetry: notifier.loadItems,
    );
  }
}
