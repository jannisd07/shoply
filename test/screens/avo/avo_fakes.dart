// Fakes and sample data for the Avo tab tests (Teil B, W1).
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/models/shopping_item_model.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/models/store_info.dart';
import 'package:shoply/data/repositories/item_repository.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/list_import_service.dart';
import 'package:shoply/data/services/meal_photo_analysis_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/providers/avo_screen_context_provider.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_backend.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_photo_source.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_turn_view.dart';
import 'package:shoply/presentation/screens/lists/widgets/offer_suggestions_bar.dart';
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

  /// What the card actions did, in order ("food:Spaghetti:lunch:2").
  final List<String> cardWrites = [];

  /// Undo calls of the records the fake handed out.
  int recordUndos = 0;

  /// The answer of a photo read; a [MealPhotoException] or
  /// [ListImportException] to fail.
  Object? mealPhoto;
  Object? listPhoto;
  final List<String?> photoNotes = [];

  /// Holds a photo read until [releasePhoto].
  bool holdPhoto = false;
  Completer<void>? _photoGate;
  void releasePhoto() {
    final g = _photoGate;
    _photoGate = null;
    g?.complete();
  }

  Future<AvoUndoResult> _undo() async {
    recordUndos++;
    return AvoUndoResult.undone;
  }

  @override
  Future<AvoItemsRecord> addItems(
    WidgetRef ref, {
    required String tool,
    required AvoItemsSource source,
    required String listId,
    required List<NewItem> items,
  }) async {
    cardWrites.add('items:$listId:${items.map((i) => i.name).join(',')}');
    return AvoItemsRecord(
      tool: tool,
      source: source,
      listId: listId,
      listName: sampleLists.firstWhere((l) => l.id == listId).name,
      added: items.length,
      undo: _undo,
    );
  }

  @override
  Future<AvoFoodRecord> logEstimate(
    WidgetRef ref,
    AvoEstimateCard estimate, {
    required MealType meal,
    double factor = 1,
  }) async {
    cardWrites.add('food:${estimate.name}:${meal.name}:${factor.round()}');
    return AvoFoodRecord(
      tool: 'log_food',
      name: estimate.name,
      meal: meal,
      kcal: (estimate.kcal * factor).round(),
      leftKcal: 640,
      undo: _undo,
    );
  }

  @override
  Future<AvoGoalRecord> applyGoal(
    WidgetRef ref,
    AvoGoalPreviewCard preview,
  ) async {
    cardWrites.add('goal:${preview.goal.dailyCalorieTarget}');
    return AvoGoalRecord(
      tool: 'setup_nutrition_goal',
      kcal: preview.goal.dailyCalorieTarget ?? 0,
      previousKcal: preview.previous?.dailyCalorieTarget,
      undo: _undo,
    );
  }

  /// [splitTrip] answers null (the card is out of date).
  bool splitStale = false;

  @override
  Future<AvoSplitRecord?> splitTrip(
    WidgetRef ref,
    AvoSplitPreviewCard card,
  ) async {
    cardWrites.add('split:${card.historyId}:${card.total}');
    if (splitStale) return null;
    return AvoSplitRecord(
      tool: 'split_trip_cost',
      tripDate: card.tripDate,
      shares: card.shares,
    );
  }

  @override
  Future<AvoSettingRecord> removeEntry(
    WidgetRef ref,
    AvoRemovalCard card,
  ) async {
    cardWrites.add('${card.diet ? 'diet' : 'allergy'}:${card.entry}');
    return AvoSettingRecord(
      tool: 'update_setting',
      key: card.diet ? 'diet_remove' : 'allergies_remove',
      value: card.entry,
      undo: _undo,
    );
  }

  @override
  Future<AvoPlanRecord?> planRecipe(
    WidgetRef ref,
    AvoPlanTakenCard card, {
    required bool replace,
  }) async {
    cardWrites.add('plan:${card.recipeName}:${replace ? 'replace' : 'add'}');
    return AvoPlanRecord(
      tool: 'add_to_plan',
      recipeName: card.recipeName,
      day: card.day,
      servings: card.servings,
      undo: _undo,
    );
  }

  @override
  Future<MealPhotoEstimate> readMealPhoto(
    Uint8List photo, {
    String? note,
  }) async {
    photoNotes.add(note);
    if (holdPhoto) {
      _photoGate = Completer<void>();
      await _photoGate!.future;
    }
    final answer = mealPhoto;
    if (answer is MealPhotoEstimate) return answer;
    throw answer ?? const MealPhotoException('provider_error');
  }

  @override
  Future<ListImportResult> readListPhoto(
    Uint8List photo,
    CancelToken cancel,
  ) async {
    final answer = listPhoto;
    if (answer is ListImportResult) return answer;
    throw answer ?? const ListImportException('provider_error');
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
  Override? offlineOverride,
}) => [
  avoBackendProvider.overrideWithValue(backend),
  avoChatProvider.overrideWith(
    (ref) =>
        chat ?? AvoChat(backend, proHints: FakeProHints(allow: allowProHint)),
  ),
  offlineOverride ?? isOfflineProvider.overrideWithValue(offline),
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

// ------------------------------------------------- W1b: cards and photos

/// A photo source without the camera: whether the camera was explained,
/// what the next pick brings ([photo], or [denied] like image_picker's
/// `camera_access_denied`).
class FakePhotoSource implements AvoPhotoSource {
  FakePhotoSource({this.photo, this.denied = false, this.explained = true});

  Uint8List? photo;
  bool denied;
  bool explained;
  int takes = 0;
  int chooses = 0;
  int settings = 0;

  AvoPick get _next => denied
      ? (outcome: AvoPickOutcome.denied, photo: null)
      : photo == null
      ? (outcome: AvoPickOutcome.cancelled, photo: null)
      : (outcome: AvoPickOutcome.photo, photo: photo);

  @override
  Future<bool> cameraExplained() async => explained;

  @override
  Future<void> markCameraExplained() async => explained = true;

  @override
  Future<void> openSettings() async => settings++;

  @override
  Future<AvoPick> take() async {
    takes++;
    return _next;
  }

  @override
  Future<AvoPick> choose() async {
    chooses++;
    return photo == null
        ? (outcome: AvoPickOutcome.cancelled, photo: null)
        : (outcome: AvoPickOutcome.photo, photo: photo);
  }
}

/// A 1×1 PNG, enough for `Image.memory`.
final Uint8List kTinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// The overrides of the card tests: modules, offers, the photo source.
List<Override> avoCardOverrides({
  required FakeAvoBackend backend,
  bool offline = false,
  Set<AppModule> modules = const {
    AppModule.offers,
    AppModule.calories,
    AppModule.mealPlan,
    AppModule.costSplit,
    AppModule.avo,
  },
  bool offers = true,
  AvoScreenContext? screen,
  FakePhotoSource? photos,
  AvoChat? chat,
  List<ShoppingListModel>? lists,
  Override? offlineOverride,
}) => [
  ...avoOverrides(
    backend: backend,
    offline: offline,
    chat: chat,
    lists: lists,
    offlineOverride: offlineOverride,
  ),
  moduleEnabledProvider.overrideWith((ref, m) => modules.contains(m)),
  offersAvailableProvider.overrideWithValue(offers),
  offerCategoryOfProvider.overrideWithValue((_) => 'dairy'),
  avoScreenContextProvider.overrideWith((ref) => screen),
  avoPhotoSourceProvider.overrideWithValue(photos ?? FakePhotoSource()),
];

/// The rounds of a conversation on their own, as the tab draws them: each
/// of [questions] is asked once after the first frame (or [photo] is sent).
class AvoRounds extends ConsumerStatefulWidget {
  const AvoRounds({super.key, this.questions = const ['Frage'], this.photo});

  final List<String> questions;
  final Uint8List? photo;

  @override
  ConsumerState<AvoRounds> createState() => _AvoRoundsState();
}

class _AvoRoundsState extends ConsumerState<AvoRounds> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chat = ref.read(avoChatProvider)..attach(ref);
      final photo = widget.photo;
      if (photo != null) {
        chat.sendPhoto(photo);
        return;
      }
      for (final q in widget.questions) {
        chat.send(q);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(avoChatProvider)..attach(ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in chat.turns)
          Padding(
            padding: const EdgeInsets.all(16),
            child: AvoTurnView(
              key: ValueKey(t.id),
              chat: chat,
              turn: t,
              offline: ref.watch(isOfflineProvider),
              aiEnabled: true,
              onSend: (_) {},
              onEdit: (_) {},
            ),
          ),
      ],
    );
  }
}
