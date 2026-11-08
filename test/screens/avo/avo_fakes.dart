// Fakes and sample data for the Avo tab tests (Teil B, W1).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/store_info.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_backend.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_status_sections.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/items_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_tab_screen.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

import '../../layout/layout_matrix.dart';

final DateTime kNow = DateTime(2026, 11, 8, 10, 30);

ShoppingListModel sampleList(
  String id, {
  String name = 'Wocheneinkauf',
  int items = 12,
  int open = 9,
  DateTime? updated,
}) => ShoppingListModel(
  id: id,
  name: name,
  ownerId: 'u1',
  createdAt: DateTime(2026, 10, 1),
  updatedAt: updated ?? kNow,
  itemCount: items,
  uncheckedCount: open,
  backgroundType: 'color',
  backgroundValue: '#34C759',
);

ShoppingItemModel sampleItem(
  String id,
  String name, {
  String listId = 'w',
  double quantity = 1,
  String? unit,
  bool checked = false,
}) => ShoppingItemModel(
  id: id,
  listId: listId,
  name: name,
  quantity: quantity,
  unit: unit,
  isChecked: checked,
  createdAt: kNow,
  updatedAt: kNow,
);

final sampleLists = [
  sampleList('w'),
  sampleList('d', name: 'Drogerie', items: 3, open: 2),
];

/// What the fake answers to one question.
class AvoScript {
  const AvoScript({
    this.tools = const [],
    this.payloads = const [],
    this.deltas = const [],
    this.message = '',
    this.errorCode,
    this.retryAfterS,
    this.hold = false,
  });

  /// "Okay." as a plain answer.
  const AvoScript.text(this.message)
    : tools = const [],
      payloads = const [],
      deltas = const [],
      errorCode = null,
      retryAfterS = null,
      hold = false;

  const AvoScript.error(this.errorCode, {this.retryAfterS})
    : tools = const [],
      payloads = const [],
      deltas = const [],
      message = '',
      hold = false;

  final List<(String, Map<String, Object?>)> tools;
  final List<AvoWidgetPayload> payloads;
  final List<String> deltas;
  final String message;
  final String? errorCode;
  final int? retryAfterS;

  /// Keeps the answer open until [FakeAvoBackend.release].
  final bool hold;

  AvoResponse get response => AvoResponse(
    message: message,
    payloads: payloads,
    errorCode: errorCode,
    retryAfterS: retryAfterS,
  );
}

class FakeAvoBackend implements AvoBackend {
  FakeAvoBackend([List<AvoScript>? scripts]) : scripts = [...?scripts];

  final List<AvoScript> scripts;
  final List<String> asked = [];
  final List<String> deleted = [];
  final List<String> added = [];
  int stops = 0;
  int resets = 0;

  /// False: "Stopp" does not end a held answer (it is still finishing).
  bool releaseOnStop = true;
  AvoDeleteOutcome deleteOutcome = AvoDeleteOutcome.deleted;
  Completer<AvoResponse>? _pending;
  AvoResponse? _held;

  bool get isHolding => _pending != null;

  /// Ends a held answer with its scripted response.
  void release() {
    final p = _pending;
    _pending = null;
    p?.complete(_held);
  }

  @override
  Future<AvoResponse> ask(
    String question,
    WidgetRef ref, {
    required void Function(String delta) onText,
    required void Function(String name, Map<String, Object?> input) onTool,
    required void Function(AvoWidgetPayload payload) onPayload,
  }) async {
    asked.add(question);
    final script = scripts.isEmpty
        ? const AvoScript.text('Okay.')
        : scripts.removeAt(0);
    for (final (name, input) in script.tools) {
      onTool(name, input);
    }
    for (final p in script.payloads) {
      onPayload(p);
    }
    for (final d in script.deltas) {
      onText(d);
    }
    if (script.hold) {
      _held = script.response;
      _pending = Completer<AvoResponse>();
      return _pending!.future;
    }
    return script.response;
  }

  @override
  void stop() {
    stops++;
    if (releaseOnStop) release();
  }

  @override
  void reset() => resets++;

  @override
  Future<AvoDeleteOutcome> confirmDelete(String token, WidgetRef ref) async {
    deleted.add(token);
    return deleteOutcome;
  }

  @override
  Future<AvoListChange> addItem(
    WidgetRef ref, {
    required String listId,
    required String name,
    double quantity = 1,
    String? unit,
  }) async {
    added.add('$listId:$name');
    return AvoListChange(
      kind: AvoListChangeKind.added,
      listId: listId,
      listName: sampleLists.firstWhere((l) => l.id == listId).name,
      count: 1,
      items: [sampleItem('new', name, listId: listId, quantity: quantity)],
      // Uses the ref it was given, like the real undo closures do: it must
      // still work after the round's widget is gone.
      undo: () async {
        ref.read(avoListsProvider);
        return AvoUndoResult.undone;
      },
    );
  }
}

/// Records check-offs instead of writing to Supabase.
class FakeItemRepository extends Fake implements ItemRepository {
  final List<String> toggled = [];

  @override
  Future<ShoppingItemModel> toggleItemChecked(
    String itemId,
    bool isChecked,
  ) async {
    toggled.add('$itemId:$isChecked');
    return sampleItem(itemId, itemId, checked: isChecked);
  }
}

/// A pro hint gate that always allows (or never).
class FakeProHints implements AvoProHintGate {
  FakeProHints({this.allow = true});

  final bool allow;

  @override
  Future<bool> take() async => allow;
}

List<Override> avoOverrides({
  required FakeAvoBackend backend,
  bool offline = false,
  bool aiOn = true,
  bool subscribed = false,
  List<ShoppingListModel>? lists,
  int? proLimit = 60,
  FakeItemRepository? items,
  bool allowProHint = true,
  Map<String, StoreInfo> stores = const {},
  AvoChat? chat,
}) => [
  avoBackendProvider.overrideWithValue(backend),
  avoChatProvider.overrideWith(
    (ref) =>
        chat ?? AvoChat(backend, proHints: FakeProHints(allow: allowProHint)),
  ),
  isOfflineProvider.overrideWithValue(offline),
  aiRemoteEnabledProvider.overrideWithValue(aiOn),
  isSubscribedProvider.overrideWithValue(subscribed),
  authUserIdProvider.overrideWithValue('u1'),
  avoListsProvider.overrideWithValue(lists ?? sampleLists),
  storeForListProvider.overrideWith((ref, id) => stores[id]),
  avoProQuestionLimitProvider.overrideWithValue(proLimit),
  itemRepositoryProvider.overrideWithValue(items ?? FakeItemRepository()),
];

/// The tab as the app shows it: design scope, toast host, providers.
Widget avoHarness(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: ThemeData(platform: TargetPlatform.iOS),
    home: AvoDesignScope(child: AvoToastHost(child: child)),
  ),
);

/// Pumps a few frames without waiting for endless animations (the
/// activity dots repeat while Avo works).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The tab at a given phone size and text scale (layout checks).
Future<void> pumpAvoAt(
  WidgetTester tester, {
  required double width,
  required double height,
  required double scale,
  bool offline = false,
  bool aiOn = true,
  FakeAvoBackend? backend,
  List<Override> extra = const [],
  Widget? screen,
}) async {
  await loadLayoutFonts();
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
        devicePixelRatio: 3,
        textScaler: TextScaler.linear(scale),
        padding: const EdgeInsets.only(top: 20),
        viewPadding: const EdgeInsets.only(top: 20),
      ),
      child: ProviderScope(
        overrides: [
          ...avoOverrides(
            backend: backend ?? FakeAvoBackend(),
            offline: offline,
            aiOn: aiOn,
          ),
          ...extra,
        ],
        child: MaterialApp(
          theme: ThemeData(
            platform: TargetPlatform.iOS,
            fontFamily: 'CupertinoSystemText',
          ),
          home: AvoDesignScope(
            child: AvoToastHost(child: screen ?? const AvoTabScreen()),
          ),
        ),
      ),
    ),
  );
  await settle(tester);
}

/// The status row sits in the conversation (not pinned under the head).
bool avoStatusInConversation(WidgetTester tester) => find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(StatusRow),
    )
    .evaluate()
    .isNotEmpty;
