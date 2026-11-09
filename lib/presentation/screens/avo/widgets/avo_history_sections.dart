import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_history.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/presentation/screens/avo/avo_card_format.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/avo_l10n.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_card_scope.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_record_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/routes/app_destinations.dart';

// Kap. 5.2: history, restocking.
const double _circle = 22; // D2 check circle size, here dashed
const double _dash = 3; // D2
const double _dashStroke = 1.5; // D2
const double _plusGlyph = 13; // D2
const double _rowMinHeight = 56; // D2 detail row

/// `get_shopping_history`: the trips, a tap on one unfolds its items, and
/// "Alle wieder auf {Liste}" for the newest; its result follows as a row.
List<Widget> avoTripsSections(
  BuildContext context,
  AvoCardScope s,
  AvoWidgetPayload p,
  AvoTripsCard card,
) {
  final trips = card.trips;
  if (trips.isEmpty) {
    return [
      AvoResultSection(
        title: context.tr('avo_card_trips_empty'),
        leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.clock)),
      ),
    ];
  }
  final record = s.chat.recordOf(p);
  final listName = card.listName;
  final newest = trips.first;
  return [
    AvoResultSection(
      title: context.tr('avo_card_trips'),
      leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.clock)),
      onOpen: () => openAppDestination(context, AppDestinations.history),
      details: [
        for (var i = 0; i < trips.length && i < 8; i++)
          _TripRow(
            trip: trips[i],
            open: s.chat.isTripOpen(p, i),
            onToggle: () => s.chat.toggleTrip(p, i),
          ),
      ],
      actions: [
        if (card.listId != null &&
            listName != null &&
            newest.items.isNotEmpty &&
            record == null)
          AvoCardAction(
            label: context.tr(
              'avo_card_history_add_all',
              params: {'list': listName},
            ),
            working: s.chat.isCardWorking(p),
            onPressed: s.offline || s.chat.isCardWorking(p)
                ? null
                : () => s.chat.addTripAgain(p),
          ),
      ],
    ),
    if (record != null) AvoRecordSection(payload: p, scope: s, record: record),
  ];
}

/// One trip: list, "Sa., 31. Okt. · 14 Artikel · 42,80 €" (the amount only
/// when it was recorded); a tap shows its items. Unfolded is kept in the
/// conversation.
class _TripRow extends StatelessWidget {
  const _TripRow({
    required this.trip,
    required this.open,
    required this.onToggle,
  });

  final ShoppingHistory trip;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final open = this.open;
    final colors = context.colors;
    final cost = t.totalCost;
    final meta = [
      avoDay(context, t.completedAt),
      avoTrCount(context, 'avo_card_items', t.items.length),
      if (cost != null && cost > 0) avoEuro(context, cost),
    ].join(' · ');
    final secondary = context.text(
      AvoTextStyle.subhead,
      color: colors.secondaryLabel,
      tabular: true,
    );
    final items = t.items.map((i) => i.name).join(', ');
    return Semantics(
      container: true,
      button: t.items.isNotEmpty,
      expanded: t.items.isEmpty ? null : open,
      label: open ? '${t.listName}, $meta. $items' : '${t.listName}, $meta',
      onTap: t.items.isEmpty ? null : onToggle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: t.items.isEmpty ? null : onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.s,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.listName, style: context.text(AvoTextStyle.body)),
                Text(meta, style: secondary),
                if (open)
                  Padding(
                    padding: const EdgeInsets.only(top: AvoSpacing.xs),
                    child: Text(items, style: secondary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `split_trip_cost` (Kap. 5.2): the split before anything is saved, with
/// what it replaces; only "Teilen" saves it, then its result row.
List<Widget> avoSplitPreviewSections(
  BuildContext context,
  AvoCardScope s,
  AvoWidgetPayload p,
  AvoSplitPreviewCard card,
) {
  if (s.chat.recordOf(p) != null) {
    return [AvoRecordSection(payload: p, scope: s)];
  }
  final shares = [
    for (final sh in card.shares)
      '${sh.isYou ? context.tr('avo_you') : sh.name} ${avoEuro(context, sh.amount)}',
  ].join(' · ');
  final total = avoEuro(context, card.total);
  final payer = card.payerIsYou
      ? context.tr('avo_split_paid_you')
      : card.payerName == null
      ? context.tr('avo_split_paid_other')
      : context.tr('avo_split_paid_by', params: {'name': card.payerName!});
  final stale = s.chat.isSplitStale(p);
  final working = s.chat.isCardWorking(p);
  // Everything "Teilen" changes besides the shares: the split it replaces,
  // whose "bezahlt" is reset, a payer set for the first time.
  final notes = [
    if (card.replaces.isNotEmpty)
      card.paidReset.isEmpty
          ? context.tr('avo_split_replaces')
          : context.tr(
              'avo_split_replaces_paid',
              params: {'names': avoAnd(context, card.paidReset)},
            ),
    if (card.payerIsNew) context.tr('avo_split_payer_new'),
  ];
  return [
    AvoResultSection(
      title: context.tr(
        'avo_rec_split_title',
        params: {'date': avoDay(context, card.tripDate)},
      ),
      subtitle: [
        context.tr(
          card.totalFromTrip ? 'avo_split_preview' : 'avo_split_preview_said',
          params: {'shares': shares, 'total': total},
        ),
        payer,
      ].join(' · '),
      leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.people)),
      footnote: stale
          ? context.tr('avo_confirm_expired')
          : notes.isEmpty
          ? null
          : notes.join(' '),
      actions: [
        if (!stale)
          AvoCardAction(
            label: context.tr('avo_split_action'),
            working: working,
            onPressed: working || s.offline ? null : () => s.chat.splitTrip(p),
          ),
      ],
    ),
  ];
}

/// `get_restock_suggestions`: "Vielleicht auch", each row with a dashed
/// circle; a tap puts it on the list and the row becomes its result.
AvoResultSection avoRestockSection(
  BuildContext context,
  AvoCardScope s,
  AvoWidgetPayload p,
  AvoRestockCard card,
) => AvoResultSection(
  title: context.tr('avo_card_maybe_also'),
  leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.clock)),
  detailIndent: AvoSpacing.l + AvoSizes.hitTarget + AvoSpacing.s,
  details: [
    for (var i = 0; i < card.lines.length; i++)
      _RestockRow(scope: s, payload: p, card: card, row: i),
  ],
);

class _RestockRow extends StatelessWidget {
  const _RestockRow({
    required this.scope,
    required this.payload,
    required this.card,
    required this.row,
  });

  final AvoCardScope scope;
  final AvoWidgetPayload payload;
  final AvoRestockCard card;
  final int row;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final line = card.lines[row];
    final chat = scope.chat;
    final change = chat.rowChangeOf(payload, row);
    final key = (payload, row);
    final phase = chat.undoPhaseOf(key);
    final listName = card.listName;
    final working = chat.isCardWorking(key);
    final canAdd =
        card.listId != null && change == null && !working && !scope.offline;
    final sub = change == null
        ? context.tr('avo_card_every_days', params: {'n': '${line.everyDays}'})
        : phase == AvoUndoPhase.undone
        ? context.tr('avo_row_undone')
        : [
            context.tr('avo_card_added', params: {'n': '1'}),
            ?listName,
            if (phase == AvoUndoPhase.changedSince)
              context.tr('avo_row_changed_since'),
          ].join(' · ');
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          line.name,
          style: context.text(
            AvoTextStyle.body,
            color: phase == AvoUndoPhase.undone
                ? colors.secondaryLabel
                : colors.label,
          ),
        ),
        Text(
          sub,
          style: context.text(
            AvoTextStyle.subhead,
            color: colors.secondaryLabel,
          ),
        ),
      ],
    );
    final circle = SizedBox.square(
      dimension: AvoSizes.hitTarget,
      child: Center(
        child: working
            ? const CupertinoActivityIndicator()
            : change != null
            ? AvoIcon(AvoIcons.check, size: _circle, color: colors.tint)
            : CustomPaint(
                size: const Size.square(_circle),
                painter: _DashedCircle(color: colors.tint),
                child: SizedBox.square(
                  dimension: _circle,
                  child: Center(
                    child: AvoIcon(
                      AvoIcons.plus,
                      size: _plusGlyph,
                      color: colors.tint,
                    ),
                  ),
                ),
              ),
      ),
    );
    void add() => chat.addRestock(payload, row);
    // One VoiceOver element per row: the name, its state, and (while it is
    // not on the list) the tap that puts it there.
    final main = Semantics(
      container: true,
      button: canAdd,
      label: '${line.name}, $sub',
      hint: canAdd && listName != null
          ? context.tr(
              'avo_card_add_to',
              params: {'item': line.name, 'list': listName},
            )
          : null,
      onTap: canAdd ? add : null,
      excludeSemantics: true,
      child: PressableScale(
        onPressed: canAdd ? add : null,
        child: Row(
          children: [
            circle,
            const SizedBox(width: AvoSpacing.s),
            Expanded(child: text),
          ],
        ),
      ),
    );
    final undoable =
        change?.undo != null &&
        phase != AvoUndoPhase.undone &&
        phase != AvoUndoPhase.changedSince;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AvoSpacing.l - (AvoSizes.hitTarget - _circle) / 2,
          AvoSpacing.xs,
          AvoSpacing.l,
          AvoSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(child: main),
            if (undoable)
              AppButton.plain(
                label: context.tr('avo_undo'),
                working: phase == AvoUndoPhase.working,
                onPressed: phase == AvoUndoPhase.idle
                    ? () => chat.undoKey(key, change!.undo)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// The dashed "not on the list yet" circle (D2 Kap. 5.2).
class _DashedCircle extends CustomPainter {
  const _DashedCircle({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _dashStroke;
    final radius = (size.shortestSide - _dashStroke) / 2;
    final center = size.center(Offset.zero);
    final circumference = 2 * math.pi * radius;
    final count = (circumference / (2 * _dash)).floor();
    final step = 2 * math.pi / count;
    for (var i = 0; i < count; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * step,
        step / 2,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCircle old) => old.color != color;
}
