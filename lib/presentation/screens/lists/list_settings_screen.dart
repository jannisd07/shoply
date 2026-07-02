import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/common/paper_settings.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/state/lists_provider.dart';

class ListSettingsScreen extends ConsumerStatefulWidget {
  final String listId;
  final String listName;
  final String ownerId;

  const ListSettingsScreen({
    super.key,
    required this.listId,
    required this.listName,
    required this.ownerId,
  });

  @override
  ConsumerState<ListSettingsScreen> createState() => _ListSettingsScreenState();
}

class _ListSettingsScreenState extends ConsumerState<ListSettingsScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String? _currentUserId;
  bool _isCreator = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = SupabaseService.instance.currentUser?.id;
    _isCreator = _currentUserId == widget.ownerId;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final membersResponse = await SupabaseService.instance
          .from('list_members')
          .select('user_id, role')
          .eq('list_id', widget.listId);

      final List<Map<String, dynamic>> members = [];
      for (final member in (membersResponse as List)) {
        final userId = member['user_id'] as String;
        final role = member['role'] as String? ?? 'member';
        final userResponse = await SupabaseService.instance
            .from('users')
            .select('display_name, avatar_url, email')
            .eq('id', userId)
            .maybeSingle();
        members.add({
          'user_id': userId,
          'role': role,
          'display_name': userResponse?['display_name'] as String? ?? 'Unknown',
          'avatar_url': userResponse?['avatar_url'] as String?,
          'email': userResponse?['email'] as String?,
          'is_owner': role == 'owner',
        });
      }
      members.sort((a, b) {
        if (a['is_owner'] == true && b['is_owner'] != true) return -1;
        if (b['is_owner'] == true && a['is_owner'] != true) return 1;
        return (a['display_name'] as String).compareTo(
          b['display_name'] as String,
        );
      });
      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load members: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeMember(String userId, String displayName) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.tr('remove_member')),
        content: Text(
          context.tr('remove_member_confirm', params: {'name': displayName}),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('cancel')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('remove')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.instance
            .from('list_members')
            .delete()
            .eq('list_id', widget.listId)
            .eq('user_id', userId);
        HapticFeedback.mediumImpact();
        await _loadMembers();
      } catch (e) {
        debugPrint('❌ Failed to remove member: $e');
      }
    }
  }

  Future<void> _leaveList() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.tr('leave_list')),
        content: Text(
          context.tr('leave_list_confirm', params: {'name': widget.listName}),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('cancel')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('leave')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.instance
            .from('list_members')
            .delete()
            .eq('list_id', widget.listId)
            .eq('user_id', _currentUserId!);
        HapticFeedback.heavyImpact();
        ref.invalidate(listsNotifierProvider);
        if (mounted) context.go('/home');
      } catch (e) {
        debugPrint('❌ Failed to leave list: $e');
      }
    }
  }

  Future<void> _deleteList() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.tr('delete_list_question')),
        content: Text(
          context.tr(
            'delete_list_message',
            params: {'listName': widget.listName},
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('cancel')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(listsNotifierProvider.notifier)
            .deleteList(widget.listId);
        HapticFeedback.heavyImpact();
        if (mounted) context.go('/home');
      } catch (e) {
        debugPrint('❌ Failed to delete list: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final separatorColor = AppColors.divider(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PaperSettingsAppBar(title: context.tr('list_settings')),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 8,
                bottom: 60 + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                // List name
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 2),
                  child: Text(
                    widget.listName,
                    style: PaperTextStyles.serif(15, color: textSecondary),
                  ),
                ),

                const SizedBox(height: 24),

                // Members section
                PaperSectionHeader(context.tr('members')),
                ...List.generate(_members.length, (index) {
                  final member = _members[index];
                  final isOwner = member['is_owner'] == true;
                  final isCurrentUser = member['user_id'] == _currentUserId;
                  final displayName = member['display_name'] as String;
                  final avatarUrl = member['avatar_url'] as String?;
                  final userId = member['user_id'] as String;

                  return Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.push(
                            '/author/$userId',
                            extra: {'authorName': displayName},
                          );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: ClipOval(
                                  child:
                                      avatarUrl != null && avatarUrl.isNotEmpty
                                      ? Image.network(
                                          avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _buildAvatarFallback(
                                                displayName,
                                                textPrimary,
                                                textSecondary,
                                              ),
                                        )
                                      : _buildAvatarFallback(
                                          displayName,
                                          textPrimary,
                                          textSecondary,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName +
                                          (isCurrentUser
                                              ? ' (${context.tr('you')})'
                                              : ''),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                        color: textPrimary,
                                      ),
                                    ),
                                    if (isOwner)
                                      Text(
                                        context.tr('creator'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (_isCreator && !isOwner)
                                GestureDetector(
                                  onTap: () => _removeMember(
                                    member['user_id'] as String,
                                    displayName,
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.minus_circle_fill,
                                    color: PaperColors.danger,
                                    size: 20,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: textSecondary.withValues(alpha: 0.4),
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (index < _members.length - 1)
                        Container(height: 0.5, color: separatorColor),
                    ],
                  );
                }),

                const SizedBox(height: 32),

                // Actions section
                PaperSectionHeader(context.tr('actions')),
                if (!_isCreator)
                  _buildActionRow(
                    label: context.tr('leave_list'),
                    textPrimary: textPrimary,
                    isDestructive: true,
                    onTap: _leaveList,
                  ),
                if (_isCreator)
                  _buildActionRow(
                    label: context.tr('delete_list'),
                    textPrimary: textPrimary,
                    isDestructive: true,
                    onTap: _deleteList,
                  ),

                if (_isCreator)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 12),
                    child: Text(
                      context.tr('delete_list_hint'),
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildAvatarFallback(
    String name,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF2C2C2E) : PaperColors.cream,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: PaperTextStyles.serif(
            15,
            color: isDark ? textSecondary : PaperColors.creamInk,
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow({
    required String label,
    required Color textPrimary,
    required bool isDestructive,
    required VoidCallback onTap,
  }) {
    final color = isDestructive ? PaperColors.danger : textPrimary;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: color,
          ),
        ),
      ),
    );
  }
}
