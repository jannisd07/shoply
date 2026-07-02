import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/expense_split_service.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/expense_split_provider.dart';

/// Opens the split-cost sheet for [entry]. Refreshes [tripSplitsProvider]
/// and the relevant home-banner providers on save.
Future<void> showSplitCostSheet(
  BuildContext context,
  WidgetRef ref, {
  required ShoppingHistory entry,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SplitCostSheet(entry: entry),
  );
  ref.invalidate(tripSplitsProvider(entry.id));
  ref.invalidate(tripsAwaitingPaymentToMeProvider);
  ref.invalidate(tripsIOweProvider);
}

class _Participant {
  final String? userId;
  String name;
  bool included;
  double amount;

  _Participant({
    this.userId,
    required this.name,
    this.included = true,
    this.amount = 0,
  });
}

class _SplitCostSheet extends ConsumerStatefulWidget {
  final ShoppingHistory entry;

  const _SplitCostSheet({required this.entry});

  @override
  ConsumerState<_SplitCostSheet> createState() => _SplitCostSheetState();
}

class _SplitCostSheetState extends ConsumerState<_SplitCostSheet> {
  final _totalController = TextEditingController();
  final List<_Participant> _participants = [];
  final _newNameController = TextEditingController();
  bool _customAmounts = false;
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _totalController.dispose();
    _newNameController.dispose();
    super.dispose();
  }

  void _initFromData(String? currentUserId, String currentUserName) {
    if (_initialized) return;
    _initialized = true;
    _totalController.text = widget.entry.totalCost != null
        ? widget.entry.totalCost!.toStringAsFixed(2)
        : '';
    _participants.add(_Participant(userId: currentUserId, name: currentUserName));
    _recalcEqualSplit();
  }

  void _mergeMembers(List<Map<String, dynamic>> members, String? currentUserId) {
    for (final m in members) {
      final user = m['user'] as Map<String, dynamic>?;
      final id = user?['id'] as String?;
      if (id == null || id == currentUserId) continue;
      if (_participants.any((p) => p.userId == id)) continue;
      final name = (user?['display_name'] as String?) ?? context.tr('member');
      _participants.add(_Participant(userId: id, name: name));
    }
  }

  double get _total => double.tryParse(_totalController.text.replaceAll(',', '.')) ?? 0;

  List<_Participant> get _includedParticipants =>
      _participants.where((p) => p.included).toList();

  void _recalcEqualSplit() {
    if (_customAmounts) return;
    final included = _includedParticipants;
    if (included.isEmpty) return;
    final share = _total / included.length;
    for (final p in included) {
      p.amount = share;
    }
  }

  Future<void> _save() async {
    if (_total <= 0) {
      HapticFeedback.heavyImpact();
      return;
    }
    final included = _includedParticipants;
    if (included.isEmpty) return;

    setState(() => _saving = true);
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      await ref.read(expenseSplitServiceProvider).createSplits(
            historyId: widget.entry.id,
            totalCost: _total,
            shares: included
                .map((p) => SplitShare(
                      userId: p.userId,
                      participantName: p.name,
                      amount: double.parse(p.amount.toStringAsFixed(2)),
                    ))
                .toList(),
            paidByUserId: currentUser?.id,
            paidByName: currentUser?.displayName,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('split_save_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final accent = AppColors.accentColor(context);

    return currentUserAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (currentUser) {
        _initFromData(currentUser?.id, currentUser?.displayName ?? context.tr('you'));

        final membersAsync = widget.entry.listId != null
            ? ref.watch(splitCandidateMembersProvider(widget.entry.listId!))
            : null;
        membersAsync?.whenData((members) => _mergeMembers(members, currentUser?.id));

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.divider(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      context.tr('split_trip_cost'),
                      style: PaperTextStyles.serif(22, color: textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.entry.listName,
                      style: TextStyle(fontSize: 13, color: textSecondary),
                    ),
                    const SizedBox(height: 18),

                    // Total cost input
                    TextField(
                      controller: _totalController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: PaperTextStyles.serif(20, color: textPrimary),
                      decoration: InputDecoration(
                        prefixText: '€ ',
                        prefixStyle: PaperTextStyles.serif(20, color: textSecondary),
                        labelText: context.tr('total_cost'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setSheetState(_recalcEqualSplit),
                    ),
                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('split_between').toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setSheetState(() {
                            _customAmounts = !_customAmounts;
                            if (!_customAmounts) _recalcEqualSplit();
                          }),
                          child: Text(
                            _customAmounts
                                ? context.tr('split_equal')
                                : context.tr('split_custom'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    for (final p in _participants)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Checkbox(
                              value: p.included,
                              activeColor: accent,
                              onChanged: (v) => setSheetState(() {
                                p.included = v ?? false;
                                _recalcEqualSplit();
                              }),
                            ),
                            Expanded(
                              child: Text(
                                p.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: p.included ? textPrimary : textSecondary,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 84,
                              child: TextField(
                                enabled: p.included && _customAmounts,
                                textAlign: TextAlign.end,
                                keyboardType:
                                    const TextInputType.numberWithOptions(decimal: true),
                                controller: TextEditingController(
                                  text: p.amount > 0 ? p.amount.toStringAsFixed(2) : '',
                                )..selection = TextSelection.collapsed(
                                    offset: p.amount > 0
                                        ? p.amount.toStringAsFixed(2).length
                                        : 0,
                                  ),
                                decoration: const InputDecoration(
                                  suffixText: ' €',
                                  isDense: true,
                                  border: UnderlineInputBorder(),
                                ),
                                onChanged: (v) => p.amount =
                                    double.tryParse(v.replaceAll(',', '.')) ?? 0,
                              ),
                            ),
                          ],
                        ),
                      ),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newNameController,
                            decoration: InputDecoration(
                              hintText: context.tr('add_person_hint'),
                              isDense: true,
                              border: const UnderlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle, color: accent),
                          onPressed: () {
                            final name = _newNameController.text.trim();
                            if (name.isEmpty) return;
                            setSheetState(() {
                              _participants.add(_Participant(name: name));
                              _newNameController.clear();
                              _recalcEqualSplit();
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.tr('split_sum_check'),
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                        Text(
                          '${_includedParticipants.fold<double>(0, (s, p) => s + p.amount).toStringAsFixed(2)} € / ${_total.toStringAsFixed(2)} €',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: PaperColors.paper,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: PaperColors.paper,
                                ),
                              )
                            : Text(context.tr('save_split')),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
