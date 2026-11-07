import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/user_model.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/presentation/screens/main_scaffold.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/common/paper_settings.dart';

/// One selectable row in a [MultiSelectSettingsScreen].
class MultiSelectOption {
  final String id;
  final String title;
  final String? subtitle;
  final IconData? icon;

  const MultiSelectOption({
    required this.id,
    required this.title,
    this.subtitle,
    this.icon,
  });
}

/// Settings subpage that edits one string-array column of `users`
/// (e.g. `diet_preferences`, `app_priorities`) as a checklist.
///
/// Initial values come from [currentUserProvider] via [initialValues]; Save
/// writes only [column] and refreshes the cached user.
class MultiSelectSettingsScreen extends ConsumerStatefulWidget {
  final String title;
  final String? hint;
  final String sectionTitle;
  final String column;
  final List<String> Function(UserModel user) initialValues;
  final List<MultiSelectOption> options;

  /// Optional extra row that clears the selection (e.g. "No restrictions").
  final MultiSelectOption? noneOption;
  final String? noneSectionTitle;

  /// Shows "N selected" above the list when something is selected.
  final bool showSelectedCount;

  const MultiSelectSettingsScreen({
    super.key,
    required this.title,
    required this.sectionTitle,
    required this.column,
    required this.initialValues,
    required this.options,
    this.hint,
    this.noneOption,
    this.noneSectionTitle,
    this.showSelectedCount = false,
  });

  @override
  ConsumerState<MultiSelectSettingsScreen> createState() =>
      _MultiSelectSettingsScreenState();
}

class _MultiSelectSettingsScreenState
    extends ConsumerState<MultiSelectSettingsScreen> {
  final Set<String> _selected = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final user = await ref.read(currentUserProvider.future);
      if (user != null && mounted) {
        setState(() => _selected.addAll(widget.initialValues(user)));
      }
    } catch (e) {
      debugPrint('❌ [SETTINGS] Failed to load ${widget.column}: $e');
    }
  }

  Future<void> _save() async {
    final user = SupabaseService.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await SupabaseService.instance.from('users').update({
        widget.column: _selected.toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      ref.invalidate(currentUserProvider);

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ [SETTINGS] Failed to save ${widget.column}: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('generic_error'))),
        );
      }
    }
  }

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondary(context);
    final separatorColor = AppColors.divider(context);
    final options = widget.options;
    final noneOption = widget.noneOption;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: PaperSettingsAppBar(
        title: widget.title,
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
          bottom: MainScaffold.getNavbarClearance(context) + 16,
        ),
        children: [
          if (widget.hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 4),
              child: Text(
                widget.hint!,
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
            ),
          if (widget.showSelectedCount && _selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 4),
              child: Text(
                '${_selected.length} ${context.tr('selected')}',
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
            ),
          PaperSectionHeader(widget.sectionTitle),
          for (int i = 0; i < options.length; i++) ...[
            _OptionRow(
              option: options[i],
              selected: _selected.contains(options[i].id),
              onTap: () => _toggle(options[i].id),
            ),
            if (i < options.length - 1)
              Container(height: 0.5, color: separatorColor),
          ],
          if (noneOption != null) ...[
            const SizedBox(height: 32),
            PaperSectionHeader(widget.noneSectionTitle ?? ''),
            _OptionRow(
              option: noneOption,
              selected: _selected.isEmpty,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selected.clear());
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final MultiSelectOption option;
  final bool selected;
  final VoidCallback onTap;

  const _OptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            if (option.icon != null) ...[
              Icon(option.icon, size: 20, color: textSecondary),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (option.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle!,
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected
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
