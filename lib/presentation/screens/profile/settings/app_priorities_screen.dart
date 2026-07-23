import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/app_priorities.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/widgets/common/paper_settings.dart';
import 'package:shoply/presentation/state/auth_provider.dart';

/// Profile → "What matters to you" — lets a user change the priorities
/// they picked (or skipped) during onboarding at any time, per the
/// brief's "let users change these preferences later" autonomy bullet.
/// Only ever reorders home-screen nudge cards; nothing here gates a
/// feature, so there's no risky state to get wrong.
class AppPrioritiesScreen extends ConsumerStatefulWidget {
  const AppPrioritiesScreen({super.key});

  @override
  ConsumerState<AppPrioritiesScreen> createState() =>
      _AppPrioritiesScreenState();
}

class _AppPrioritiesScreenState extends ConsumerState<AppPrioritiesScreen> {
  Set<String> _selected = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserPriorities();
  }

  Future<void> _loadUserPriorities() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    try {
      final response = await SupabaseService.instance
          .from('users')
          .select('app_priorities')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _selected = Set.from(
            (response['app_priorities'] as List?)?.cast<String>() ?? [],
          );
        });
      }
    } catch (e) {
      // Handle error silently — same pattern as DietPreferencesScreen.
    }
  }

  Future<void> _save() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseService.instance.from('users').update({
        'app_priorities': _selected.toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      ref.invalidate(currentUserProvider);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
      appBar: PaperSettingsAppBar(
        title: context.tr('app_priorities'),
        actions: [
          PaperSaveButton(
            label: context.tr('save'),
            loading: _isLoading,
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 8,
          bottom: 60 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 4),
            child: Text(
              context.tr('app_priorities_hint'),
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ),
          PaperSectionHeader(context.tr('app_priorities')),
          ...List.generate(kAppPriorities.length, (index) {
            final priority = kAppPriorities[index];
            return Column(
              children: [
                _buildPriorityRow(
                  priority: priority,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                if (index < kAppPriorities.length - 1)
                  Container(height: 0.5, color: separatorColor),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPriorityRow({
    required AppPriority priority,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final isSelected = _selected.contains(priority.id);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          if (isSelected) {
            _selected.remove(priority.id);
          } else {
            _selected.add(priority.id);
          }
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(priority.icon, size: 20, color: textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                context.tr('priority_${priority.id}'),
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected
                  ? AppColors.accentColor(context)
                  : textSecondary.withValues(alpha: 0.4),
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}
