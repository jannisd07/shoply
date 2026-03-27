import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/localization/localization_helper.dart';
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
        return (a['display_name'] as String).compareTo(b['display_name'] as String);
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
        content: Text(context.tr('remove_member_confirm', params: {'name': displayName})),
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
        content: Text(context.tr('leave_list_confirm', params: {'name': widget.listName})),
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
        content: Text(context.tr('delete_list_confirm_message', params: {'name': widget.listName})),
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
        await ref.read(listsNotifierProvider.notifier).deleteList(widget.listId);
        HapticFeedback.heavyImpact();
        if (mounted) context.go('/home');
      } catch (e) {
        debugPrint('❌ Failed to delete list: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final secondaryText = isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          context.tr('list_settings'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 8),

                // List info header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          CupertinoIcons.cart_fill,
                          color: CupertinoColors.systemBlue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.listName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_members.length} ${context.tr('members')}',
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Members section header
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text(
                    context.tr('members').toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: secondaryText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Members list
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: List.generate(_members.length, (index) {
                      final member = _members[index];
                      final isOwner = member['is_owner'] == true;
                      final isCurrentUser = member['user_id'] == _currentUserId;
                      final displayName = member['display_name'] as String;
                      final avatarUrl = member['avatar_url'] as String?;
                      final userId = member['user_id'] as String;

                      return Column(
                        children: [
                          if (index > 0)
                            Divider(
                              height: 0.5,
                              indent: 68,
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                            ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              context.push('/author/$userId', extra: {'authorName': displayName});
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // Avatar
                                  SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: ClipOval(
                                      child: avatarUrl != null && avatarUrl.isNotEmpty
                                          ? Image.network(
                                              avatarUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => _buildAvatarFallback(displayName, isDark),
                                            )
                                          : _buildAvatarFallback(displayName, isDark),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Name + role
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName + (isCurrentUser ? ' (${context.tr('you')})' : ''),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                          ),
                                        ),
                                        if (isOwner)
                                          Text(
                                            context.tr('creator'),
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: secondaryText,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Remove button
                                  if (_isCreator && !isOwner)
                                    CupertinoButton(
                                      padding: EdgeInsets.zero,
                                      minSize: 32,
                                      onPressed: () => _removeMember(member['user_id'] as String, displayName),
                                      child: Icon(
                                        CupertinoIcons.minus_circle_fill,
                                        color: CupertinoColors.systemRed,
                                        size: 22,
                                      ),
                                    )
                                  else
                                    Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 14,
                                      color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 28),

                // Danger zone
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text(
                    context.tr('actions').toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: secondaryText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      if (!_isCreator)
                        _buildActionRow(
                          icon: CupertinoIcons.arrow_right_square,
                          label: context.tr('leave_list'),
                          isDestructive: true,
                          onTap: _leaveList,
                          isDark: isDark,
                        ),
                      if (_isCreator) ...[
                        _buildActionRow(
                          icon: CupertinoIcons.trash,
                          label: context.tr('delete_list'),
                          isDestructive: true,
                          onTap: _deleteList,
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),

                if (_isCreator)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: Text(
                      context.tr('delete_list_hint'),
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
                      ),
                    ),
                  ),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
              ],
            ),
    );
  }

  Widget _buildAvatarFallback(String name, bool isDark) {
    return Container(
      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E5EA),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white60 : const Color(0xFF8E8E93),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    required bool isDestructive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final color = isDestructive ? CupertinoColors.systemRed : (isDark ? Colors.white : const Color(0xFF1A1A1A));

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
