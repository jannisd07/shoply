import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/services/shared_preferences_provider.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_rows.dart';
import 'package:shoply/presentation/screens/profile/settings/data/list_preferences.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/swipe_actions.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

/// "Vielleicht auch" shows at most this many rows (Konzept 11 §1.1 item 9).
const int kMaybeAlsoMaxRows = 3;

/// A row hidden with "Ausblenden" stays away this long.
const Duration kMaybeAlsoHideFor = Duration(days: 30);

const String _hiddenKeyPrefix = 'list_maybe_also_hidden_';

/// One "Vielleicht auch" row: an item the person buys in a rhythm that is
/// due and not open on the list.
@immutable
class MaybeAlsoSuggestion {
  const MaybeAlsoSuggestion({
    required this.name,
    this.everyDays,
    this.quantity = 1,
    this.categoryId,
  });

  final String name;

  /// "Kaufst du etwa alle 8 Tage"; null shows no reason.
  final int? everyDays;
  final double quantity;
  final String? categoryId;

  @override
  bool operator ==(Object other) =>
      other is MaybeAlsoSuggestion &&
      other.name == name &&
      other.everyDays == everyDays &&
      other.quantity == quantity &&
      other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(name, everyDays, quantity, categoryId);
}

/// The source of "Vielleicht auch": Teil B's rhythm items (the same as
/// Avo's "Nachkauf", only from the person's own purchases, never made-up
/// reasons). Empty while loading or on errors. Overridden in tests.
final maybeAlsoSourceProvider = Provider<List<MaybeAlsoSuggestion>>((ref) {
  final restock = ref.watch(restockSuggestionsProvider).valueOrNull;
  if (restock == null) return const [];
  return [
    for (final s in restock)
      MaybeAlsoSuggestion(
        name: s.displayName,
        everyDays: s.averageDays > 0 ? s.averageDays : null,
        quantity: (s.preferredQuantity ?? 1) <= 0 ? 1 : s.preferredQuantity!,
        categoryId: s.preferredCategory,
      ),
  ];
});

/// Names hidden with "Ausblenden" and until when, per account on the
/// device.
class MaybeAlsoHiddenNotifier extends StateNotifier<Map<String, DateTime>> {
  MaybeAlsoHiddenNotifier(this._ref, this._userId) : super(const {}) {
    state = _read();
  }

  final Ref _ref;
  final String? _userId;

  String get _key => '$_hiddenKeyPrefix$_userId';

  Map<String, DateTime> _read() {
    if (_userId == null) return const {};
    try {
      final raw = _ref
          .read(sharedPreferencesProvider)
          .valueOrNull
          ?.getString(_key);
      if (raw == null) return const {};
      final json = jsonDecode(raw);
      if (json is! Map) return const {};
      final now = DateTime.now();
      return {
        for (final e in json.entries)
          if (e.value is int)
            if (DateTime.fromMillisecondsSinceEpoch(e.value as int)
                case final until when until.isAfter(now))
              '${e.key}': until,
      };
    } catch (e) {
      debugPrint('⚠️ [MAYBE_ALSO] Hidden rows not read: $e');
      return const {};
    }
  }

  /// Hides [name] for [kMaybeAlsoHideFor].
  void hide(String name) {
    final next = {
      ...state,
      name.trim().toLowerCase(): DateTime.now().add(kMaybeAlsoHideFor),
    };
    state = next;
    if (_userId == null) return;
    try {
      final prefs = _ref.read(sharedPreferencesProvider).valueOrNull;
      prefs?.setString(
        _key,
        jsonEncode({
          for (final e in next.entries) e.key: e.value.millisecondsSinceEpoch,
        }),
      );
    } catch (e) {
      debugPrint('⚠️ [MAYBE_ALSO] Hidden row not stored: $e');
    }
  }
}

final maybeAlsoHiddenProvider =
    StateNotifierProvider<MaybeAlsoHiddenNotifier, Map<String, DateTime>>(
      (ref) => MaybeAlsoHiddenNotifier(ref, ref.watch(authUserIdProvider)),
    );

/// The rows of "Vielleicht auch" on [listId]: nothing while the setting
/// "Vielleicht auch" is off (Einstellungen › Listen), else up to
/// [kMaybeAlsoMaxRows] rhythm items that are neither open on the list nor
/// hidden.
final listMaybeAlsoProvider =
    Provider.family<List<MaybeAlsoSuggestion>, String>((ref, listId) {
      if (!ref.watch(listPreferencesProvider.select((p) => p.suggestions))) {
        return const [];
      }
      final source = ref.watch(maybeAlsoSourceProvider);
      if (source.isEmpty) return const [];
      final hidden = ref.watch(maybeAlsoHiddenProvider);
      final open = {
        for (final i
            in ref.watch(itemsNotifierProvider(listId)).valueOrNull ?? const [])
          if (!i.isChecked) i.name.trim().toLowerCase(),
      };
      return [
        for (final s in source)
          if (!open.contains(s.name.trim().toLowerCase()) &&
              !hidden.containsKey(s.name.trim().toLowerCase()))
            s,
      ].take(kMaybeAlsoMaxRows).toList();
    });

/// "Vielleicht auch" (Konzept 11 §1.1 item 9): up to three items the person
/// buys in a rhythm, each with its reason; a tap puts it on the list, a
/// swipe hides it for 30 days. Renders nothing without rows.
class ListMaybeAlsoSection extends ConsumerWidget {
  const ListMaybeAlsoSection({
    super.key,
    required this.listId,
    required this.onAdd,
  });

  final String listId;
  final ValueChanged<MaybeAlsoSuggestion> onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(listMaybeAlsoProvider(listId));
    if (rows.isEmpty) return const SizedBox.shrink();
    final hide = context.tr('list_detail_maybe_also_hide');
    return InsetSection(
      header: context.tr('list_detail_maybe_also'),
      children: [
        for (final s in rows)
          SwipeActions(
            key: ValueKey<String>('maybe-${s.name}'),
            trailingActions: [
              SwipeAction(
                label: hide,
                onPressed: () =>
                    ref.read(maybeAlsoHiddenProvider.notifier).hide(s.name),
              ),
            ],
            child: ListInfoActionRow(
              label: s.name,
              icon: AvoIcons.plusCircle,
              subtitle: s.everyDays == null
                  ? null
                  : context.tr(
                      'list_detail_maybe_also_rhythm',
                      params: {'n': '${s.everyDays}'},
                    ),
              onTap: () => onAdd(s),
            ),
          ),
      ],
    );
  }
}
