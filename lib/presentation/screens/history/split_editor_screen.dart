import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/expense_split.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/expense_split_service.dart';
import 'package:shoply/data/services/trip_money_format.dart';
import 'package:shoply/data/services/trip_split_math.dart';
import 'package:shoply/presentation/screens/history/history_actions.dart'
    show leaveGoneTrip, tripLookupProvider;
import 'package:shoply/presentation/screens/history/trip_amount_screen.dart'
    show tripContextLine;
import 'package:shoply/presentation/screens/history/widgets/amount_field.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/state/expense_split_provider.dart';
import 'package:shoply/presentation/state/trip_history_provider.dart';
import 'package:shoply/presentation/widgets/design/avatar.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';
import 'package:shoply/presentation/widgets/design/select_circle.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/swipe_actions.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/app_branch.dart';

const double _kRowMin = 60; // D2 participant row
const double _kNameMinWidth = 100; // V7: the name keeps 100 pt beside the field
const double _kFieldMinWidth = 88; // D2 compact amount capsule

/// One person in "Wer teilt?".
class _Person {
  _Person({
    required this.name,
    this.userId,
    this.selected = true,
    this.wasPaid = false,
    this.oldCents,
  });

  final String? userId;
  final String name;
  bool selected;

  /// Custom share as typed; null = not typed.
  AmountInput? custom;

  /// Paid before, with [oldCents] (paid stays when the share stays).
  final bool wasPaid;
  final int? oldCents;

  bool get nameOnly => userId == null;
}

/// The rest-cent sentence and the reason the save is off (§V7 7).
@immutable
class SplitCheck {
  const SplitCheck({required this.text, required this.ok, this.warn = false});

  final String text;
  final bool ok;

  /// Shown with `exclamationmark.circle`.
  final bool warn;
}

/// V7 "Kosten teilen" (`/history/:tripId/split?amount=&from=checkout`):
/// who gets how much of this trip, equal or custom, with members and people
/// without an account. Saves optimistically and closes at once.
class SplitEditorScreen extends ConsumerStatefulWidget {
  const SplitEditorScreen({
    super.key,
    required this.tripId,
    this.amountCents,
    this.fromCheckout = false,
  });

  final String tripId;

  /// `amount=` from V1.
  final int? amountCents;

  /// `from=checkout`: no own toast, V3's undo takes everything back.
  final bool fromCheckout;

  @override
  ConsumerState<SplitEditorScreen> createState() => _SplitEditorScreenState();
}

class _SplitEditorScreenState extends ConsumerState<SplitEditorScreen> {
  bool _gone = false;
  List<_Person>? _people;
  int _payer = 0;
  bool _equal = true;
  AmountInput _total = const AmountInput.empty();
  bool _dirty = false;
  bool _membersFailed = false;
  bool _adding = false;
  String? _nameTaken;
  final TextEditingController _name = TextEditingController();
  final FocusNode _nameFocus = FocusNode(debugLabel: 'SplitName');
  final FocusNode _totalFocus = FocusNode(debugLabel: 'SplitTotal');
  List<ExpenseSplit> _before = const [];

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _totalFocus.dispose();
    super.dispose();
  }

  String get _lang => Localizations.localeOf(context).languageCode;

  void _init(ShoppingHistory trip, List<ExpenseSplit> splits, List<SplitMember>? members) {
    final me = ref.read(authUserIdProvider);
    final cents = widget.amountCents ?? trip.totalCostCents;
    _total = cents == null ? const AmountInput.empty() : AmountInput.valid(cents);
    _before = splits;
    if (splits.isNotEmpty) {
      final sorted = [...splits]..sort((a, b) => a.position.compareTo(b.position));
      _equal = sorted.every((s) => s.splitMode == 'equal');
      final people = [
        for (final s in sorted)
          _Person(
            userId: s.userId,
            name: s.participantName,
            wasPaid: s.isPaid,
            oldCents: s.amountCents,
          )..custom = AmountInput.valid(s.amountCents),
      ];
      // The payer stays in the list even when their share was left out.
      final payerId = trip.paidByUserId;
      var payer = people.indexWhere(
        (p) => payerId != null ? p.userId == payerId : p.name == trip.paidByName,
      );
      if (payer < 0) {
        people.insert(
          0,
          _Person(
            userId: payerId,
            name: trip.paidByName ?? '',
            selected: false,
          ),
        );
        payer = 0;
      }
      _people = people;
      _payer = payer;
      if (cents == null) {
        _total = AmountInput.valid(
          sorted.fold<int>(0, (a, s) => a + s.amountCents),
        );
      }
      return;
    }
    final list = members ?? const <SplitMember>[];
    final people = [
      for (final m in list) _Person(userId: m.userId, name: m.name),
    ];
    if (!people.any((p) => p.userId == me) && me != null) {
      people.insert(0, _Person(userId: me, name: ''));
    }
    _people = people;
    final shopper = trip.completedBy ?? trip.userId;
    _payer = people.indexWhere((p) => p.userId == shopper).clamp(0, people.length - 1);
    if (cents == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _totalFocus.requestFocus();
      });
    }
  }

  String _display(_Person p) {
    final me = ref.read(authUserIdProvider);
    if (p.userId != null && p.userId == me) return context.tr('hist_split_you');
    return p.name.trim().isEmpty ? context.tr('hist_member_unknown') : p.name;
  }

  List<_Person> get _chosen => [
    for (final p in _people ?? const <_Person>[])
      if (p.selected) p,
  ];

  /// Shares in cents of the chosen people, in order; null while invalid.
  List<int>? _shares() {
    final total = _total.cents;
    final chosen = _chosen;
    if (total == null || total <= 0 || chosen.length < 2) return null;
    if (_equal) return equalShareCents(total, chosen.length);
    final shares = [for (final p in chosen) p.custom?.cents ?? 0];
    return sharesAddUp(total, shares) ? shares : null;
  }

  SplitCheck _check() {
    final total = _total.cents;
    if (total == null || total <= 0) {
      return SplitCheck(text: context.tr('hist_split_need_amount'), ok: false, warn: true);
    }
    final chosen = _chosen;
    if (chosen.length < 2) {
      return SplitCheck(text: context.tr('hist_split_need_two'), ok: false);
    }
    if (_equal) {
      final shares = equalShareCents(total, chosen.length);
      if (shares.toSet().length == 1) {
        return SplitCheck(
          text: context.tr('hist_split_each', params: {'amount': formatEuroCents(shares.first, _lang)}),
          ok: true,
        );
      }
      final rest = shares.last;
      final firsts = shares.where((s) => s != rest).toList();
      if (firsts.length > 1) {
        // Two or more rest cents (W11 M2): they go to the first k people.
        return SplitCheck(
          text: context.tr(
            'hist_split_remainder_many',
            params: {
              'k': '${firsts.length}',
              'first': formatEuroCents(firsts.first, _lang),
              'n': '${shares.length - firsts.length}',
              'rest': formatEuroCents(rest, _lang),
            },
          ),
          ok: true,
        );
      }
      return SplitCheck(
        text: context.tr(
          'hist_split_remainder',
          params: {
            'first': firsts.map((c) => formatEuroCents(c, _lang)).join(', '),
            'n': '${shares.length - firsts.length}',
            'rest': formatEuroCents(rest, _lang),
          },
        ),
        ok: true,
      );
    }
    final assigned = [for (final p in chosen) p.custom?.cents ?? 0].fold<int>(0, (a, b) => a + b);
    if (assigned == total) {
      return SplitCheck(
        text: context.tr(
          'hist_split_assigned',
          params: {
            'assigned': formatEuroCents(assigned, _lang),
            'total': formatEuroCents(total, _lang),
          },
        ),
        ok: true,
      );
    }
    return SplitCheck(
      text: assigned < total
          ? context.tr('hist_split_left', params: {'amount': formatEuroCents(total - assigned, _lang)})
          : context.tr('hist_split_over', params: {'amount': formatEuroCents(assigned - total, _lang)}),
      ok: false,
      warn: true,
    );
  }

  /// People who paid before and whose share changes (K12-10).
  List<String> _reopened() {
    final shares = _shares();
    if (shares == null) return const [];
    final chosen = _chosen;
    return [
      for (var i = 0; i < chosen.length; i++)
        if (chosen[i].wasPaid &&
            chosen[i].oldCents != shares[i] &&
            !identical(chosen[i], _payerPerson))
          _display(chosen[i]),
    ];
  }

  _Person? get _payerPerson {
    final people = _people;
    if (people == null || people.isEmpty) return null;
    return people[_payer.clamp(0, people.length - 1)];
  }

  void _change(VoidCallback fn) => setState(() {
    fn();
    _dirty = true;
  });

  void _setMode(bool equal) => _change(() {
    if (!equal && _equal) {
      // Start the custom shares from the equal ones.
      final total = _total.cents;
      final chosen = _chosen;
      if (total != null && chosen.length >= 2) {
        final shares = equalShareCents(total, chosen.length);
        for (var i = 0; i < chosen.length; i++) {
          chosen[i].custom = AmountInput.valid(shares[i]);
        }
      }
    }
    _equal = equal;
  });

  void _addName() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() {
        _adding = false;
        _nameTaken = null;
      });
      return;
    }
    final taken = (_people ?? const <_Person>[]).any(
      (p) => _display(p).toLowerCase() == name.toLowerCase(),
    );
    if (taken) {
      setState(() => _nameTaken = name);
      _nameFocus.requestFocus();
      return;
    }
    _change(() {
      _people = [...?_people, _Person(name: name)];
      _adding = false;
      _nameTaken = null;
      _name.clear();
    });
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        name,
        Directionality.of(context),
      ),
    );
  }

  void _removeName(_Person p) {
    final people = _people;
    if (people == null) return;
    final at = people.indexOf(p);
    _change(() {
      people.remove(p);
      if (_payer >= people.length) _payer = 0;
    });
    AvoToast.show(
      context,
      message: _display(p),
      actionLabel: context.tr('common_undo'),
      onAction: () => _change(() => people.insert(at.clamp(0, people.length), p)),
    );
  }

  void _save(ShoppingHistory trip) {
    final shares = _shares();
    final total = _total.cents;
    final payer = _payerPerson;
    if (shares == null || total == null || payer == null) return;
    final chosen = _chosen;
    final container = ProviderScope.containerOf(context, listen: false);
    final before = _before;
    final fromCheckout = widget.fromCheckout;
    final controller = container.read(tripHistoryProvider.notifier);
    controller.upsert(
      trip.copyWith(
        totalCost: centsToEuros(total),
        paidByUserId: payer.userId,
        paidByName: payer.name,
      ),
    );
    Navigator.of(context).pop(true);
    unawaited(
      saveTripSplit(
        container,
        trip: trip,
        totalCents: total,
        participants: [
          for (final p in chosen)
            SplitShare(userId: p.userId, participantName: p.name, amount: 0),
        ],
        shareCents: shares,
        equal: _equal,
        payerUserId: payer.userId,
        payerName: payer.userId == null ? payer.name : null,
        before: before,
        showToast: !fromCheckout,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(historyTripProvider(widget.tripId));
    final title = context.tr('hist_split_title');
    if (trip == null) {
      // Not in the local history: read it once; gone → the history (§1.2).
      final lookup = ref.watch(tripLookupProvider(widget.tripId));
      if (!_gone && !lookup.isLoading && lookup.valueOrNull == null) {
        _gone = true;
        leaveGoneTrip(context);
      }
      return FullScreenEditor(title: title, child: const SkeletonSection(rows: 3, withImage: false));
    }
    final splitsAsync = ref.watch(tripSplitsProvider(trip.id));
    final members = trip.listId == null
        ? const <SplitMember>[]
        : ref.watch(splitMembersProvider(trip.listId!));
    if (_people == null) {
      final splits = splitsAsync.valueOrNull;
      if (splits == null && splitsAsync.isLoading) {
        return FullScreenEditor(title: title, child: const SkeletonSection(rows: 3, withImage: false));
      }
      if (splits != null && splits.isNotEmpty) {
        _init(trip, splits, members);
      } else if (members != null) {
        _membersFailed = members.isEmpty && trip.listId != null;
        _init(trip, splits ?? const [], members);
      } else {
        return FullScreenEditor(title: title, child: const SkeletonSection(rows: 3, withImage: false));
      }
    }
    final people = _people!;
    final colors = context.colors;
    final now = ref.watch(historyClockProvider)();
    final check = _check();
    final reopened = _reopened();
    final shares = _shares();
    final chosen = _chosen;
    final equalShares = _equal && _total.cents != null && chosen.length >= 2
        ? equalShareCents(_total.cents!, chosen.length)
        : null;

    final rows = <Widget>[
      for (final p in people)
        _ParticipantRow(
          name: _display(p),
          sub: identical(p, _payerPerson)
              ? context.tr('hist_split_has_paid')
              : (p.nameOnly ? context.tr('hist_split_no_account') : null),
          selected: p.selected,
          onToggle: () => _change(() => p.selected = !p.selected),
          shareCents: p.selected && equalShares != null
              ? equalShares[chosen.indexOf(p)]
              : null,
          custom: !_equal && p.selected,
          customInitial: p.custom?.cents,
          onCustom: (v) => _change(() => p.custom = v),
          onRemove: p.nameOnly ? () => _removeName(p) : null,
          lang: _lang,
        ),
      if (_adding)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: context.tr('hist_split_add_person'),
                textField: true,
                child: CupertinoTextField(
                  controller: _name,
                  focusNode: _nameFocus,
                  autofocus: true,
                  placeholder: context.tr('hist_split_name_placeholder'),
                  textCapitalization: TextCapitalization.words,
                  style: context.text(AvoTextStyle.body),
                  placeholderStyle: context.text(AvoTextStyle.body, color: colors.placeholder),
                  decoration: null,
                  padding: const EdgeInsets.symmetric(vertical: AvoSpacing.m - AvoSpacing.xxs),
                  onSubmitted: (_) => _addName(),
                ),
              ),
              if (_nameTaken != null)
                // Said by VoiceOver as soon as it appears (3.3.1).
                Semantics(
                  liveRegion: true,
                  container: true,
                  child: Row(
                    children: [
                      ExcludeSemantics(
                        child: AvoIcon(AvoIcons.exclamationmarkCircle, size: 15, color: colors.destructive), // D2
                      ),
                      const SizedBox(width: AvoSpacing.xs),
                      Expanded(
                        child: Text(
                          context.tr('hist_split_name_taken', params: {'name': _nameTaken!}),
                          style: context.text(AvoTextStyle.footnote),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        )
      else
        Semantics(
          button: true,
          label: context.tr('hist_split_add_person'),
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _adding = true),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.s),
                child: Row(
                  children: [
                    AvoIcon(AvoIcons.personBadgePlus, size: 20, color: colors.tint), // D2
                    const SizedBox(width: AvoSpacing.m),
                    Expanded(
                      child: Text(
                        context.tr('hist_split_add_person'),
                        style: context.text(AvoTextStyle.body, color: colors.tint),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];

    final payer = _payerPerson;
    return FullScreenEditor(
      title: title,
      dirty: _dirty,
      doneLabel: context.tr('hist_split_save'),
      doneEnabled: shares != null,
      onDone: () => _save(trip),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          InsetSection(
            footer: tripContextLine(context, trip, now),
            children: [
              HistoryAmountField(
                title: context.tr('hist_split_total'),
                placeholder: '',
                languageCode: _lang,
                initialCents: _total.cents,
                focusNode: _totalFocus,
                onChanged: (v) => _change(() => _total = v),
              ),
            ],
          ),
          if (_total.isInvalid)
            AmountNote(text: context.tr('hist_amount_invalid'), error: true),
          const SizedBox(height: AvoSpacing.section),
          if (payer != null)
            InsetSection(
              children: [
                Builder(
                  builder: (anchor) => _PaidByRow(
                    value: _display(payer),
                    onTap: () => unawaited(
                      showAvoMenu(
                        anchor,
                        items: [
                          for (var i = 0; i < people.length; i++)
                            AvoMenuItem(
                              label: _display(people[i]),
                              checked: i == _payer,
                              onSelected: () => _change(() => _payer = i),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AvoSpacing.screen, AvoSpacing.section, AvoSpacing.screen, AvoSpacing.section),
            child: AppSegmentedControl<bool>(
              semanticLabel: context.tr('hist_split_mode'),
              segments: [
                SegmentItem(value: true, label: context.tr('hist_split_equal')),
                SegmentItem(value: false, label: context.tr('hist_split_custom')),
              ],
              selected: _equal,
              onChanged: _setMode,
            ),
          ),
          if (_membersFailed)
            Padding(
              padding: const EdgeInsets.fromLTRB(AvoSpacing.screen, 0, AvoSpacing.screen, AvoSpacing.m),
              child: StatusRow(
                kind: StatusKind.failed,
                text: context.tr('hist_split_members_failed'),
                actionLabel: context.tr('common_try_again'),
                onAction: () {
                  ref.invalidate(splitCandidateMembersProvider(trip.listId!));
                  setState(() {
                    _people = null;
                    _membersFailed = false;
                  });
                },
              ),
            ),
          InsetSection(
            header: context.tr('hist_split_who'),
            headerTrailing: Text(
              '${chosen.length}',
              style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel, tabular: true),
            ),
            children: rows,
          ),
          Semantics(
            liveRegion: true,
            container: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AvoSpacing.xxxl, AvoSpacing.s, AvoSpacing.xxxl, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (check.warn) ...[
                        AvoIcon(AvoIcons.exclamationmarkCircle, size: 15, color: colors.secondaryLabel), // D2
                        const SizedBox(width: AvoSpacing.xs),
                      ],
                      Expanded(
                        child: Text(
                          check.text,
                          style: context.text(
                            AvoTextStyle.footnote,
                            color: check.ok ? colors.label : colors.secondaryLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (final name in reopened)
                    Padding(
                      padding: const EdgeInsets.only(top: AvoSpacing.xs),
                      child: Text(
                        context.tr('hist_split_paid_changes', params: {'name': name}),
                        style: context.text(AvoTextStyle.footnote),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AvoSpacing.xxl),
        ],
      ),
    );
  }
}

/// Saves a split (V7) after the editor closed: "Aufteilung gespeichert ·
/// Widerrufen" (restores [before] incl. paid states), or "Aufteilung nicht
/// gespeichert · Erneut versuchen" with the error haptic.
Future<void> saveTripSplit(
  ProviderContainer container, {
  required ShoppingHistory trip,
  required int totalCents,
  required List<SplitShare> participants,
  required List<int> shareCents,
  required bool equal,
  required String? payerUserId,
  required String? payerName,
  required List<ExpenseSplit> before,
  bool showToast = true,
}) async {
  final service = container.read(expenseSplitServiceProvider);
  final controller = container.read(tripHistoryProvider.notifier);
  BuildContext? host() => rootNavigatorKey.currentContext;
  try {
    await service.saveSplit(
      historyId: trip.id,
      totalCents: totalCents,
      participants: participants,
      shareCents: shareCents,
      equal: equal,
      paidByUserId: payerUserId,
      paidByName: payerName,
    );
    container.invalidate(tripSplitsProvider(trip.id));
    unawaited(container.read(openSharesProvider.notifier).refresh());
    final c = host();
    if (!showToast || c == null || !c.mounted) return;
    AvoToast.show(
      c,
      message: c.tr('hist_split_saved'),
      actionLabel: c.tr('common_undo'),
      onAction: () => unawaited(_restore(container, trip, before)),
    );
  } catch (e) {
    debugPrint('❌ [SPLIT] Split not saved: ${e.runtimeType}');
    controller.upsert(trip);
    unawaited(AvoHaptics.error());
    final c = host();
    if (c == null || !c.mounted) return;
    AvoToast.show(
      c,
      message: c.tr('hist_split_save_failed'),
      actionLabel: c.tr('common_try_again'),
      onAction: () => unawaited(
        saveTripSplit(
          container,
          trip: trip,
          totalCents: totalCents,
          participants: participants,
          shareCents: shareCents,
          equal: equal,
          payerUserId: payerUserId,
          payerName: payerName,
          before: before,
          showToast: showToast,
        ),
      ),
    );
  }
}

Future<void> _restore(
  ProviderContainer container,
  ShoppingHistory trip,
  List<ExpenseSplit> before,
) async {
  final service = container.read(expenseSplitServiceProvider);
  try {
    if (before.isEmpty) {
      // A first split also wrote the amount and payer (save_trip_split):
      // put them back with the shares (I3).
      await service.clearSplit(
        trip.id,
        totalCents: trip.totalCostCents,
        paidByUserId: trip.paidByUserId,
        paidByName: trip.paidByName,
      );
    } else {
      final total = before.fold<int>(0, (a, s) => a + s.amountCents);
      await service.saveSplit(
        historyId: trip.id,
        totalCents: total,
        participants: [
          for (final s in before)
            SplitShare(userId: s.userId, participantName: s.participantName, amount: 0),
        ],
        shareCents: [for (final s in before) s.amountCents],
        equal: before.every((s) => s.splitMode == 'equal'),
        paidByUserId: trip.paidByUserId,
        paidByName: trip.paidByName,
      );
      // Paid states that the server did not keep come back one by one.
      final now = await service.getSplitsForHistory(trip.id);
      for (final old in before.where((s) => s.isPaid)) {
        final match = now.where(
          (n) => n.userId == old.userId && n.participantName == old.participantName && !n.isPaid,
        );
        for (final m in match) {
          await service.setPaid(m.id, true);
        }
      }
    }
    container.read(tripHistoryProvider.notifier).upsert(trip);
  } catch (e) {
    debugPrint('❌ [SPLIT] Undo failed: ${e.runtimeType}');
    unawaited(AvoHaptics.error());
    final c = rootNavigatorKey.currentContext;
    if (c != null && c.mounted) {
      AvoToast.show(
        c,
        message: c.tr('hist_split_undo_failed'),
        actionLabel: c.tr('common_try_again'),
        onAction: () => unawaited(_restore(container, trip, before)),
      );
    }
  } finally {
    container.invalidate(tripSplitsProvider(trip.id));
    unawaited(container.read(openSharesProvider.notifier).refresh());
  }
}

/// "Bezahlt von · Du ⌃⌄" (A-V6 until A ships the row with a pull-down).
class _PaidByRow extends StatelessWidget {
  const _PaidByRow({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = context.tr('hist_split_paid_by');
    return Semantics(
      button: true,
      label: title,
      value: value,
      hint: context.tr('hist_opens_menu'),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.s),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AvoSpacing.s,
              children: [
                Text(title, style: context.text(AvoTextStyle.body)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(value, style: context.text(AvoTextStyle.body, color: colors.secondaryLabel)),
                    const SizedBox(width: AvoSpacing.xs),
                    AvoIcon(AvoIcons.chevronUpChevronDown, size: 13, color: colors.secondaryLabel), // D2
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A person in "Wer teilt?": the selection circle, avatar, name, and the
/// share (equal) or a compact amount field (custom).
class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.name,
    required this.sub,
    required this.selected,
    required this.onToggle,
    required this.shareCents,
    required this.custom,
    required this.customInitial,
    required this.onCustom,
    required this.onRemove,
    required this.lang,
  });

  final String name;
  final String? sub;
  final bool selected;
  final VoidCallback onToggle;
  final int? shareCents;
  final bool custom;
  final int? customInitial;
  final ValueChanged<AmountInput> onCustom;
  final VoidCallback? onRemove;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stacked = context.isAccessibilityText;
    final state = context.tr(selected ? 'hist_split_sharing' : 'hist_split_not_sharing');
    final spoken = [
      name,
      ?sub,
      state,
      if (shareCents != null) spokenEuroCents(shareCents!, lang),
    ].join(', ');
    final field = custom
        ? ConstrainedBox(
            constraints: const BoxConstraints(minWidth: _kFieldMinWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.fill, borderRadius: BorderRadius.circular(AvoSizes.hitTarget / 2)),
              child: IntrinsicWidth(
                child: HistoryAmountField(
                  key: ValueKey('share-$name'),
                  title: '',
                  placeholder: '0',
                  languageCode: lang,
                  initialCents: customInitial,
                  semanticLabel: context.tr('hist_split_share_of_a11y', params: {'name': name}),
                  onChanged: onCustom,
                ),
              ),
            ),
          )
        : (shareCents == null
              ? null
              : Text(
                  formatEuroCents(shareCents!, lang),
                  style: context.text(AvoTextStyle.body, tabular: true),
                ));
    final head = Semantics(
      button: true,
      toggled: selected,
      label: spoken,
      onTap: onToggle,
      customSemanticsActions: onRemove == null
          ? null
          : {CustomSemanticsAction(label: context.tr('hist_split_remove')): onRemove!},
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: Row(
          children: [
            SelectCircle(selected: selected, onChanged: (_) => onToggle(), semanticLabel: name),
            if (!stacked) ...[
              const SizedBox(width: AvoSpacing.xs),
              ExcludeSemantics(child: Avatar(name: name, size: AvatarSize.size28)),
            ],
            const SizedBox(width: AvoSpacing.m),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: _kNameMinWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: context.text(AvoTextStyle.body)),
                    if (sub != null)
                      Text(sub!, style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kRowMin),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AvoSpacing.s, AvoSpacing.xs, AvoSpacing.l, AvoSpacing.xs),
        child: stacked || (custom && MediaQuery.sizeOf(context).width < 360)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [head, ?field],
              )
            : Row(
                children: [
                  Expanded(child: head),
                  if (field != null) ...[const SizedBox(width: AvoSpacing.s), field],
                ],
              ),
      ),
    );
    if (onRemove != null) {
      row = SwipeActions(
        exposeSemantics: false,
        trailingActions: [
          SwipeAction(label: context.tr('hist_split_remove'), icon: AvoIcons.trash, destructive: true, onPressed: onRemove!),
        ],
        child: row,
      );
    }
    return row;
  }
}
