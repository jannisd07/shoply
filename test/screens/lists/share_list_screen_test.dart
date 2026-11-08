import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_actions.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_join_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_list_screen.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_members.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';

import '../../layout/layout_matrix.dart';
import 'all_lists_fakes.dart';

ShoppingListModel _list({
  String id = 'w',
  String owner = 'u1',
  String? code,
  String name = 'Wocheneinkauf',
}) => ShoppingListModel(
  id: id,
  name: name,
  ownerId: owner,
  shareCode: code,
  isShared: code != null,
  createdAt: DateTime(2026, 10, 12),
  updatedAt: DateTime(2026, 11, 7),
  itemCount: 12,
  uncheckedCount: 11,
  backgroundType: 'color',
  backgroundValue: '#007AFF',
);

const _members = [
  ListMember(userId: 'u1', name: 'Jannis', isOwner: true),
  ListMember(userId: 'lena', name: 'Lena'),
];

class _ShareCalls {
  final List<String> texts = [];
  int notificationRequests = 0;
}

List<Override> _overrides({
  ShoppingListModel? list,
  String userId = 'u1',
  bool offline = false,
  FakeListActions? actions,
  _ShareCalls? calls,
  bool membersFail = false,
}) {
  final c = calls ?? _ShareCalls();
  return [
    allListsSourceProvider.overrideWithValue(AsyncData([list ?? _list()])),
    authUserIdProvider.overrideWithValue(userId),
    isOfflineProvider.overrideWithValue(offline),
    listMembersProvider.overrideWith((ref, id) async {
      if (membersFail) throw Exception('offline');
      return _members;
    }),
    listActionsProvider.overrideWithValue(actions ?? FakeListActions()),
    shareSheetProvider.overrideWithValue((text, subject, origin) async {
      c.texts.add(text);
    }),
    shareNotificationRequestProvider.overrideWithValue(() async {
      c.notificationRequests++;
      return true;
    }),
  ];
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  List<Override> overrides,
) async {
  await loadLayoutFonts();
  tester.view.physicalSize = const Size(390 * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: layoutHarness(
        const LayoutCase(width: 390, scale: 1),
        AvoToastHost(child: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('codes: normalised and grouped', () {
    expect(normalizeShareCode('ab3 x9k'), 'AB3X9K');
    expect(normalizeShareCode('482-913-77'), '482913');
    expect(groupShareCode('482913'), '482 913');
    expect(groupShareCode('ABC'), 'ABC');
  });

  group('share', () {
    testWidgets('without a code, "Invite people" makes one and shares link '
        'and code', (tester) async {
      final actions = FakeListActions();
      final calls = _ShareCalls();
      await _pump(
        tester,
        const ShareListScreen(listId: 'w', listName: 'Wocheneinkauf'),
        _overrides(actions: actions, calls: calls),
      );
      expect(find.text('Members (2)'.toUpperCase()), findsOneWidget);
      expect(find.text('You · Creator'), findsOneWidget);
      await tester.tap(find.text('Invite people'));
      await tester.pump();
      await tester.pump();
      expect(actions.codes, ['w']);
      expect(calls.texts, hasLength(1));
      expect(calls.texts.single, contains('Join my list “Wocheneinkauf” in Avo.'));
      expect(calls.texts.single, contains('/join/AB3X9K'));
      expect(calls.texts.single, contains('code AB3X9K'));
      expect(calls.texts.single, isNot(contains('🛒')));
    });

    testWidgets('an existing code is kept', (tester) async {
      final actions = FakeListActions();
      final calls = _ShareCalls();
      await _pump(
        tester,
        const ShareListScreen(listId: 'w', listName: 'Wocheneinkauf'),
        _overrides(list: _list(code: 'Q7P2ZK'), actions: actions, calls: calls),
      );
      await tester.tap(find.text('Invite people'));
      await tester.pump();
      expect(actions.codes, isEmpty);
      expect(calls.texts.single, contains('Q7P2ZK'));

      await tester.tap(find.text('Show code'));
      await tester.pumpAndSettle();
      expect(find.text('Q7P'), findsOneWidget);
      expect(find.text('2ZK'), findsOneWidget);
      expect(find.text('Create new code'), findsOneWidget);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.ensureVisible(find.text('Q7P'));
      await tester.pump();
      await tester.tap(find.text('Q7P'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Code copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('members do not get "Create new code"', (tester) async {
      await _pump(
        tester,
        const ShareListScreen(listId: 'w', listName: 'Wocheneinkauf'),
        _overrides(list: _list(code: 'Q7P2ZK', owner: 'lena')),
      );
      await tester.tap(find.text('Show code'));
      await tester.pumpAndSettle();
      expect(find.text('Create new code'), findsNothing);
    });

    testWidgets('offline without a code: invite needs a connection', (
      tester,
    ) async {
      final actions = FakeListActions();
      await _pump(
        tester,
        const ShareListScreen(listId: 'w', listName: 'Wocheneinkauf'),
        _overrides(offline: true, actions: actions),
      );
      expect(find.text('Needs a connection'), findsOneWidget);
      await tester.tap(find.text('Invite people'), warnIfMissed: false);
      await tester.pump();
      expect(actions.codes, isEmpty);
    });

    testWidgets('members that fail to load say so', (tester) async {
      await _pump(
        tester,
        const ShareListScreen(listId: 'w', listName: 'Wocheneinkauf'),
        _overrides(membersFail: true),
      );
      expect(find.text('Members couldn’t be updated.'), findsOneWidget);
    });

    testWidgets('the notification explanation comes first, once', (
      tester,
    ) async {
      final calls = _ShareCalls();
      await _pump(
        tester,
        const ShareListScreen(
          listId: 'w',
          listName: 'Wocheneinkauf',
          showIntro: true,
        ),
        _overrides(calls: calls),
      );
      expect(
        find.text('Find out when someone adds something or goes shopping'),
        findsOneWidget,
      );
      expect(find.text('Invite people'), findsNothing);
      await tester.tap(find.text('Allow notifications'));
      await tester.pump();
      await tester.pump();
      expect(calls.notificationRequests, 1);
      expect(find.text('Invite people'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('list_share_notif_intro_seen_v1'), isTrue);
    });
  });

  group('join', () {
    testWidgets('a code nobody has says so', (tester) async {
      final actions = FakeListActions();
      await _pump(tester, const JoinListScreen(), _overrides(actions: actions));
      await tester.enterText(find.byType(EditableText), 'ab3 x9k');
      await tester.pump();
      expect(find.text('AB3X9K'), findsOneWidget);
      await tester.tap(find.text('Join'));
      await tester.pump();
      await tester.pump();
      expect(actions.joined, ['AB3X9K']);
      expect(
        find.text('No list found with this code. Check the characters.'),
        findsOneWidget,
      );
    });

    testWidgets('a code of an own list offers to open it', (tester) async {
      final actions = FakeListActions();
      await _pump(
        tester,
        const JoinListScreen(),
        _overrides(list: _list(code: 'Q7P2ZK'), actions: actions),
      );
      await tester.enterText(find.byType(EditableText), 'Q7P2ZK');
      await tester.pump();
      await tester.tap(find.text('Join'));
      await tester.pump();
      expect(actions.joined, isEmpty);
      expect(find.text('You’re already on this list.'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('joining returns the list', (tester) async {
      final joined = _list(id: 'wg', name: 'WG-Vorrat', owner: 'tom');
      ShoppingListModel? result;
      await _pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: GestureDetector(
              onTap: () async =>
                  result = await openJoinListScreen(context, initialCode: 'X'),
              child: const Text('start'),
            ),
          ),
        ),
        _overrides(actions: FakeListActions(joinResult: joined)),
      );
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'WG1234');
      await tester.pump();
      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      expect(result?.id, 'wg');
    });

    testWidgets('offline: joining needs a connection', (tester) async {
      final actions = FakeListActions();
      await _pump(
        tester,
        const JoinListScreen(initialCode: 'AB3X9K'),
        _overrides(offline: true, actions: actions),
      );
      expect(find.text('Joining needs a connection.'), findsOneWidget);
      await tester.tap(find.text('Join'), warnIfMissed: false);
      await tester.pump();
      expect(actions.joined, isEmpty);
    });
  });

  layoutMatrix(
    'ShareListScreen',
    (context) => ProviderScope(
      overrides: _overrides(list: _list(code: 'Q7P2ZK')),
      child: const ShareListScreen(
        listId: 'w',
        listName: 'Wocheneinkauf fürs lange Wochenende',
      ),
    ),
    afterPump: (tester) async {
      await tester.ensureVisible(find.text('Show code'));
      await tester.pump();
      await tester.tap(find.text('Show code'));
      await tester.pumpAndSettle();
      expect(find.text('Q7P'), findsOneWidget);
    },
  );
  layoutMatrix(
    'ShareListScreen (notification explanation)',
    (context) => ProviderScope(
      overrides: _overrides(),
      child: const ShareListScreen(
        listId: 'w',
        listName: 'Wocheneinkauf',
        showIntro: true,
      ),
    ),
  );
  layoutMatrix(
    'JoinListScreen',
    (context) => ProviderScope(
      overrides: _overrides(offline: true),
      child: const JoinListScreen(initialCode: 'AB3X9K'),
    ),
  );
}
