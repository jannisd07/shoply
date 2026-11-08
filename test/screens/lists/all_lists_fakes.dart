// Test doubles for the A5 overview, share and list info tests.
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_actions.dart';

/// Records every write instead of calling Supabase.
class FakeListActions implements ListActions {
  FakeListActions({
    this.failAdd = false,
    this.joinResult,
    this.joinFails = false,
    this.code = 'AB3X9K',
  });

  final bool failAdd;
  final ShoppingListModel? joinResult;
  final bool joinFails;
  final String code;

  final List<String> added = [];
  final List<String> undone = [];
  final List<String> created = [];
  final List<String> renamed = [];
  final List<String> colors = [];
  final List<String> deleted = [];
  final List<String> left = [];
  final List<String> removed = [];
  final List<String> codes = [];
  final List<String> joined = [];
  int refreshed = 0;

  @override
  Future<void> refreshLists() async => refreshed++;

  @override
  Future<ShoppingListModel> createList(String name, {String? colorHex}) async {
    created.add('$name:$colorHex');
    return ShoppingListModel(
      id: 'new',
      name: name,
      ownerId: 'u1',
      createdAt: DateTime(2026, 11, 7),
      updatedAt: DateTime(2026, 11, 7),
    );
  }

  @override
  Future<void> rename(String listId, String name) async =>
      renamed.add('$listId:$name');

  @override
  Future<void> setColor(String listId, String colorHex) async =>
      colors.add('$listId:$colorHex');

  @override
  Future<void> deleteList(String listId) async => deleted.add(listId);

  @override
  Future<void> leaveList(String listId) async => left.add(listId);

  @override
  Future<void> removeMember(String listId, String userId) async =>
      removed.add('$listId:$userId');

  @override
  Future<String> generateShareCode(String listId) async {
    codes.add(listId);
    return code;
  }

  @override
  Future<ShoppingListModel?> joinWithCode(String code) async {
    joined.add(code);
    if (joinFails) throw Exception('offline');
    return joinResult;
  }

  @override
  Future<String> addItem(String listId, QuickAddSuggestion suggestion) async {
    if (failAdd) throw Exception('offline');
    added.add('$listId:${suggestion.name}');
    return 'token-${added.length}';
  }

  @override
  Future<void> undoAdd(String token) async => undone.add(token);
}
