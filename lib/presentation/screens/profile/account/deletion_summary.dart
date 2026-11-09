import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/subscription_service.dart';
import 'package:shoply/presentation/providers/subscription_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/share_members.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';
import 'package:shoply/presentation/screens/profile/account/profile_edit_controller.dart';
import 'package:shoply/presentation/state/shopping_history_provider.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart'
    show
        openSplitBalancesCountProvider,
        subscriptionFamilySharedProvider,
        subscriptionRenewsOnProvider;

/// A shared list the person created, and who gets it (Konzept 18 §7.3,
/// F18-08: the member who joined first). [memberName] is null while the
/// members are unknown or have no name.
@immutable
class ListHandover {
  const ListHandover({required this.listName, this.memberName});

  final String listName;
  final String? memberName;

  @override
  bool operator ==(Object other) =>
      other is ListHandover &&
      other.listName == listName &&
      other.memberName == memberName;

  @override
  int get hashCode => Object.hash(listName, memberName);
}

/// The calorie diary in the summary: none, the module is on, or it is off
/// but data exists ("Kalorien-Tagebuch (ausgeschaltet)").
enum CalorieDiary { none, on, off }

/// What deleting the account does, from the local state (Konzept 18 §7.3).
/// Null counts are unknown (never loaded); the row then has no number.
@immutable
class DeletionSummary {
  const DeletionSummary({
    this.name,
    this.ownLists = 0,
    this.handovers = const [],
    this.leftLists = 0,
    this.ownRecipes,
    this.trips,
    this.calories = CalorieDiary.none,
    this.pro = false,
    this.proRenewsOn,
    this.openBalances,
  });

  /// Display name for the alert ("Jannis, dein Konto …").
  final String? name;

  /// Lists without other members; deleted.
  final int ownLists;

  /// Shared lists the person created; they change hands.
  final List<ListHandover> handovers;

  /// Shared lists of others the person leaves.
  final int leftLists;

  /// Own published recipes.
  final int? ownRecipes;

  /// Shopping trips in the history.
  final int? trips;
  final CalorieDiary calories;

  /// An own Avo Pro subscription (not through Family Sharing) keeps running
  /// at Apple.
  final bool pro;
  final DateTime? proRenewsOn;

  /// Open amounts of Kosten teilen; null without the module or data.
  final int? openBalances;
}

/// Sorts [lists] into deleted, handed over and left (Konzept 18 §7.3,
/// F18-08). [membersOf] gives the known members of a list or null.
({int own, List<ListHandover> handovers, int left}) sortListsForDeletion({
  required String? userId,
  required List<ShoppingListModel> lists,
  required List<ListMember>? Function(ShoppingListModel list) membersOf,
}) {
  var own = 0;
  var left = 0;
  final handovers = <ListHandover>[];
  for (final list in lists) {
    if (list.ownerId != userId) {
      left++;
      continue;
    }
    final members = list.isShared ? membersOf(list) : const <ListMember>[];
    if (members == null) {
      handovers.add(ListHandover(listName: list.name));
      continue;
    }
    final others = otherMembers(members, userId);
    if (others.isEmpty) {
      own++;
      continue;
    }
    final heir = firstJoined(others);
    handovers.add(
      ListHandover(
        listName: list.name,
        memberName: heir.name.isEmpty ? null : heir.name,
      ),
    );
  }
  return (own: own, handovers: handovers, left: left);
}

/// The member who joined first (unknown dates last, then the given order).
ListMember firstJoined(List<ListMember> members) {
  var best = members.first;
  for (final m in members.skip(1)) {
    final a = m.joinedAt;
    final b = best.joinedAt;
    if (a != null && (b == null || a.isBefore(b))) best = m;
  }
  return best;
}

/// How many recipes the person published; null when unknown. Asked once
/// per account when Konto löschen opens.
final ownRecipeCountProvider = FutureProvider<int?>((ref) async {
  final userId = ref.watch(accountIdentityProvider.select((i) => i?.userId));
  if (userId == null) return null;
  try {
    return (await RecipeService().getMyRecipes()).length;
  } catch (e) {
    debugPrint('[ACCOUNT] own recipes unknown: ${e.runtimeType}');
    return null;
  }
});

/// The summary of Konto löschen from the providers of the lists, the
/// history, the recipes, the modules and Pro. Overridden in tests.
final deletionSummaryProvider = Provider<DeletionSummary>((ref) {
  final userId = ref.watch(accountIdentityProvider)?.userId;
  final lists = ref.watch(allListsSourceProvider).valueOrNull ?? const [];
  final sorted = sortListsForDeletion(
    userId: userId,
    lists: lists,
    membersOf: (list) => ref.watch(listMembersProvider(list.id)).valueOrNull,
  );
  final trips = ref.watch(shoppingHistoryProvider).valueOrNull?.length;
  final recipes = ref.watch(ownRecipeCountProvider).valueOrNull;
  final caloriesOn = ref.watch(moduleEnabledProvider(AppModule.calories));
  final status = ref.watch(subscriptionStatusProvider).valueOrNull;
  // Through Family Sharing the subscription is not the person's own.
  final familyShared = ref.watch(subscriptionFamilySharedProvider) == true;
  return DeletionSummary(
    name: ref.watch(accountDisplayNameProvider),
    ownLists: sorted.own,
    handovers: sorted.handovers,
    leftLists: sorted.left,
    ownRecipes: recipes,
    trips: trips,
    calories: caloriesOn ? CalorieDiary.on : CalorieDiary.none,
    pro: status == SubscriptionStatus.subscribed && !familyShared,
    proRenewsOn: ref.watch(subscriptionRenewsOnProvider),
    openBalances: ref.watch(openSplitBalancesCountProvider).valueOrNull,
  );
});
