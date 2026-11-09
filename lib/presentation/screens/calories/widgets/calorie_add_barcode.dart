import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/open_food_facts_service.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_add_parts.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_amount_food.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_barcode.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

enum _BarcodeOutcome { searching, notFound, offline, failed }

/// S3 "Barcode": "Kamera öffnen" (when the iPhone reads barcodes), the
/// number field with "Suchen", the lookup's outcome and "Zuletzt gescannt".
class CalorieAddBarcode extends ConsumerStatefulWidget {
  const CalorieAddBarcode({super.key, required this.actions});

  final CalorieAddActions actions;

  @override
  ConsumerState<CalorieAddBarcode> createState() => _CalorieAddBarcodeState();
}

class _CalorieAddBarcodeState extends ConsumerState<CalorieAddBarcode> {
  _BarcodeOutcome? _barcodeOutcome;
  String? _typedCode;

  Future<void> _lookupTyped(String code) async {
    setState(() {
      _typedCode = code;
      _barcodeOutcome = _BarcodeOutcome.searching;
    });
    try {
      final product = await ref.read(calorieBarcodeLookupProvider)(code);
      if (!mounted) return;
      if (product == null) {
        setState(() => _barcodeOutcome = _BarcodeOutcome.notFound);
        return;
      }
      setState(() => _barcodeOutcome = null);
      widget.actions.openAmount(CalorieAmountFood.fromProduct(product, origin: FoodEntryOrigin.barcode));
    } on OffRequestFailed catch (e) {
      if (mounted) setState(() => _barcodeOutcome = e.reason == 'offline' ? _BarcodeOutcome.offline : _BarcodeOutcome.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final supported = ref.watch(calorieScannerSupportedProvider).valueOrNull ?? true;
    final scans = ref.watch(calorieProductCacheProvider).recentScans;
    final code = _typedCode;
    final outcome = _barcodeOutcome;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      if (supported)
        CalorieSegmentCard(
          glyph: CupertinoIcons.barcode_viewfinder,
          text: context.tr('cal_barcode_prompt'),
          children: [
            AppButton.primary(
              label: context.tr('cal_barcode_open'),
              onPressed: () => widget.actions.openScanner(),
            ),
          ],
        ),
      InsetSection(
        footer: supported ? null : context.tr('cal_barcode_unsupported'),
        children: [CalorieBarcodeField(onSubmit: _lookupTyped)],
      ),
      if (outcome != null && code != null) ...[
        const SizedBox(height: AvoSpacing.s),
        switch (outcome) {
          _BarcodeOutcome.searching => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen + AvoSpacing.l),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  context.tr('cal_scan_searching', params: {'code': formatGtin(code)}),
                  style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel, tabular: true),
                ),
              ),
            ),
          _BarcodeOutcome.notFound => StatusRow(kind: StatusKind.sectionError, text: context.tr('cal_scan_not_found')),
          _BarcodeOutcome.offline => StatusRow(kind: StatusKind.offline, text: context.tr('cal_scan_offline')),
          _BarcodeOutcome.failed => StatusRow(
              kind: StatusKind.sectionError,
              text: context.tr('cal_search_error'),
              actionLabel: context.tr('retry'),
              onAction: () => _lookupTyped(code),
            ),
        },
        if (outcome == _BarcodeOutcome.notFound || outcome == _BarcodeOutcome.offline)
          Padding(
            padding: const EdgeInsets.fromLTRB(AvoSpacing.screen, AvoSpacing.s, AvoSpacing.screen, 0),
            child: AppButton.secondary(
              label: context.tr('cal_manual_row'),
              expand: true,
              onPressed: () => widget.actions.openManual(barcode: code),
            ),
          ),
      ],
      if (scans.isNotEmpty)
        InsetSection(
          header: context.tr('cal_sec_recent_scans'),
          separatorIndent: context.isAccessibilityText ? AvoSpacing.l : AvoSpacing.l + AvoSizes.thumbSmall + AvoSpacing.m,
          children: [
            for (final p in scans)
              CalorieFoodRow(
                key: ValueKey('cal-scan-${p.barcode}'),
                name: p.name,
                imageUrl: p.imageUrl,
                reserveImage: true,
                subtitle: calorieProductLine(context, p),
                onTap: () => widget.actions.openAmount(CalorieAmountFood.fromProduct(p, origin: FoodEntryOrigin.barcode)),
              ),
          ],
        ),
    ]);
  }
}
