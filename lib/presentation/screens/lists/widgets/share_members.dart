import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/state/lists_provider.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';

/// One member of a list (`list_members` with the joined `users` row).
@immutable
class ListMember {
  const ListMember({
    required this.userId,
    required this.name,
    this.isOwner = false,
    this.joinedAt,
  });

  /// Reads a row of `ListRepository.getListMembers`.
  factory ListMember.fromRow(Map<String, dynamic> row) {
    final user = row['user'];
    final name = user is Map ? user['display_name'] as String? : null;
    final joined = row['joined_at'] ?? row['created_at'];
    return ListMember(
      userId: row['user_id'] as String,
      name: name?.trim() ?? '',
      isOwner: row['role'] == 'owner',
      joinedAt: joined is String ? DateTime.tryParse(joined) : null,
    );
  }

  final String userId;

  /// Display name; empty when the person has none.
  final String name;
  final bool isOwner;

  /// When the person joined, if the table reports it.
  final DateTime? joinedAt;

  @override
  bool operator ==(Object other) =>
      other is ListMember &&
      other.userId == userId &&
      other.name == name &&
      other.isOwner == isOwner &&
      other.joinedAt == joinedAt;

  @override
  int get hashCode => Object.hash(userId, name, isOwner, joinedAt);
}

/// The members of a list, owner first, then by name. Kept for the session
/// (not auto-disposed), so a second visit shows the known members at once
/// while [ref.invalidate] refreshes them. Overridden in tests.
final listMembersProvider = FutureProvider.family<List<ListMember>, String>((
  ref,
  listId,
) async {
  final rows = await ref.watch(listRepositoryProvider).getListMembers(listId);
  return sortMembers([for (final row in rows) ListMember.fromRow(row)]);
});

/// Owner first, then alphabetically (case-insensitive).
List<ListMember> sortMembers(List<ListMember> members) =>
    [...members]..sort((a, b) {
      if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

/// The members except [currentUserId].
List<ListMember> otherMembers(
  List<ListMember> members,
  String? currentUserId,
) => [
  for (final m in members)
    if (m.userId != currentUserId) m,
];

/// A member's name for display; "Jemand" when there is none.
String memberName(BuildContext context, ListMember member) =>
    member.name.isEmpty ? context.tr('someone') : member.name;

/// "mit Lena", "mit Lena und Max", "mit Lena und 2 weiteren"; null without
/// other members.
String? withMembersLabel(BuildContext context, List<ListMember> others) {
  if (others.isEmpty) return null;
  final first = memberName(context, others.first);
  if (others.length == 1) {
    return context.tr('common_with_name', params: {'name': first});
  }
  if (others.length == 2) {
    return context.tr(
      'list_ov_with_two',
      params: {'a': first, 'b': memberName(context, others[1])},
    );
  }
  return context.tr(
    'list_ov_with_more',
    params: {'name': first, 'n': '${others.length - 1}'},
  );
}

/// The second line of a member row: "Du · Ersteller", "Du", "Ersteller",
/// "beigetreten am 14. Okt." or nothing.
String? memberSubtitle(
  BuildContext context,
  ListMember member, {
  required String? currentUserId,
}) {
  final you = member.userId == currentUserId;
  if (you && member.isOwner) return context.tr('list_ov_you_creator');
  if (you) return context.tr('list_ov_you');
  if (member.isOwner) return context.tr('list_ov_creator');
  final joined = member.joinedAt;
  if (joined == null) return null;
  return context.tr(
    'list_ov_joined_on',
    params: {'date': listDate(context, joined)},
  );
}

/// A member row (Konzept 11 §9.1/§10.1): avatar, name, the second line.
/// At least 44 pt high; from AX1 the text wraps freely. One VoiceOver element
/// with [semanticActions] (for example "Entfernen").
class MemberRow extends StatelessWidget {
  const MemberRow({
    super.key,
    required this.member,
    required this.currentUserId,
    this.onLongPress,
    this.semanticActions = const {},
  });

  final ListMember member;
  final String? currentUserId;

  /// Opens the member's menu (the creator removing someone).
  final VoidCallback? onLongPress;

  final Map<String, VoidCallback> semanticActions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = memberName(context, member);
    final subtitle = memberSubtitle(
      context,
      member,
      currentUserId: currentUserId,
    );
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: AvoSpacing.s,
        ),
        child: Row(
          children: [
            Avatar(
              name: name,
              size: AvatarSize.large,
              neutral: member.userId == currentUserId,
            ),
            const SizedBox(width: AvoSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: context.text(AvoTextStyle.body)),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: context.text(
                        AvoTextStyle.subhead,
                        color: colors.secondaryLabel,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      label: [name, ?subtitle].join(', '),
      customSemanticsActions: semanticActions.isEmpty
          ? null
          : {
              for (final e in semanticActions.entries)
                CustomSemanticsAction(label: e.key): e.value,
            },
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: row,
      ),
    );
  }
}
