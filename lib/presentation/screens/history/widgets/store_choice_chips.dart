import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/store_chain_directory.dart';
import 'package:shoply/presentation/widgets/design/filter_chip.dart';

// D2 V1 "Wo warst du?": 8-pt brand dot; light brands get a 0.5-pt outline,
// a selected chip a 1-pt white ring so dark brands stay visible on dark.
const double _kDot = 8; // D2
const double _kOutline = 0.5; // D2
const double _kSelectedRing = 1; // D2

/// One market chip of [StoreChoiceChips].
@immutable
class StoreChoiceEntry {
  const StoreChoiceEntry(this.chainId, {this.here = false});

  /// `StoreChainDirectory` id.
  final String chainId;

  /// Found from the location: "REWE (hier)".
  final bool here;
}

/// "Wo warst du?" (V1): one market at most, tapping the chosen one again
/// clears it, then "Anderer Markt …" opens the store picker. VoiceOver reads
/// the market chips as one radio group named "Wo warst du?"; the source of
/// the preselection ("Markt dieser Liste") is read after the chosen chip.
class StoreChoiceChips extends StatelessWidget {
  const StoreChoiceChips({
    super.key,
    required this.entries,
    required this.selected,
    required this.onChanged,
    required this.onOther,
    this.selectedHint,
  });

  final List<StoreChoiceEntry> entries;

  /// The chosen chain id, or null.
  final String? selected;

  final ValueChanged<String?> onChanged;

  /// "Anderer Markt …".
  final VoidCallback onOther;

  /// Read after the chosen chip ("Markt dieser Liste").
  final String? selectedHint;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final name = StoreChainDirectory.byId(entry.chainId)?.displayName ??
          entry.chainId;
      final isSelected = entry.chainId == selected;
      final label = entry.here
          ? context.tr('hist_checkout_store_here', params: {'store': name})
          : name;
      Widget chip = AppFilterChip(
        label: label,
        selected: isSelected,
        leading: BrandDot(chainId: entry.chainId, selected: isSelected),
        radioIndex: i,
        radioCount: entries.length,
        onSelected: (on) => onChanged(on ? entry.chainId : null),
      );
      if (isSelected && selectedHint != null) {
        chip = Semantics(hint: selectedHint, child: chip);
      }
      chips.add(KeyedSubtree(key: ValueKey(entry.chainId), child: chip));
    }
    chips.add(
      Semantics(
        hint: context.tr('hist_checkout_other_store_hint'),
        child: AppFilterChip(
          key: const ValueKey('other'),
          label: context.tr('hist_checkout_other_store'),
          selected: false,
          onSelected: (_) => onOther(),
        ),
      ),
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: context.tr('hist_checkout_where'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AvoSpacing.m),
        child: ChipRow(
          wrap: true,
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
          chips: chips,
        ),
      ),
    );
  }
}

/// The 8-pt brand dot of a market (decorative). A chain without an agreed
/// colour, or a market of the person's own, is a ring in `uncheckedRing`.
class BrandDot extends StatelessWidget {
  const BrandDot({super.key, required this.chainId, this.selected = false});

  final String chainId;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final chain = StoreChainDirectory.byId(chainId);
    final brand = chain?.brandColor;
    final outline = chain?.needsOutlineOn(Theme.of(context).brightness) ?? false;
    final Border? border;
    if (brand == null) {
      border = Border.all(color: colors.uncheckedRing, width: _kSelectedRing);
    } else if (selected) {
      border = Border.all(color: colors.onChipSelected, width: _kSelectedRing);
    } else if (outline) {
      border = Border.all(color: colors.uncheckedRing, width: _kOutline);
    } else {
      border = null;
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _kDot,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: brand,
            border: border,
          ),
        ),
      ),
    );
  }
}
