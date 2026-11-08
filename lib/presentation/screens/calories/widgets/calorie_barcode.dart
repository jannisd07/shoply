import 'package:flutter/cupertino.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/native/barcode_scanner_channel.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_fields.dart';

/// "4 056489 123457" for EAN-13, "9638 5074" for EAN-8, as printed on packs.
String formatGtin(String code) {
  if (code.length == 13) return '${code[0]} ${code.substring(1, 7)} ${code.substring(7)}';
  if (code.length == 8) return '${code.substring(0, 4)} ${code.substring(4)}';
  return code;
}

/// "Nummer eingeben" (S3 Barcode, S6): the digits under the barcode, number
/// pad, return key "Suchen". A number that is no valid EAN-13, EAN-8 or
/// UPC-A gets a line under the field instead of a search.
class CalorieBarcodeField extends StatefulWidget {
  const CalorieBarcodeField({super.key, required this.onSubmit, this.autofocus = false, this.enabled = true});

  /// Called with the checked digits.
  final ValueChanged<String> onSubmit;
  final bool autofocus;
  final bool enabled;

  @override
  State<CalorieBarcodeField> createState() => _CalorieBarcodeFieldState();
}

class _CalorieBarcodeFieldState extends State<CalorieBarcodeField> {
  final _controller = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String text) {
    final code = BarcodeScannerChannel.normalizeGtin(text);
    setState(() => _invalid = code == null);
    if (code != null) widget.onSubmit(code);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final error = _invalid ? context.tr('cal_barcode_invalid') : null;
    return MergeSemantics(
      child: Semantics(
        label: context.tr('cal_barcode_enter'),
        hint: error,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget + AvoSpacing.s),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l, vertical: AvoSpacing.s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: Text(context.tr('cal_barcode_enter'), style: context.text(AvoTextStyle.subhead, color: colors.secondaryLabel)),
                ),
                const SizedBox(height: AvoSpacing.xxs),
                CupertinoTextField(
                  key: const ValueKey('cal-barcode-field'),
                  controller: _controller,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  decoration: null,
                  padding: const EdgeInsets.symmetric(vertical: AvoSpacing.xs),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  inputFormatters: [calorieDigitsFormatter],
                  placeholder: context.tr('cal_barcode_placeholder'),
                  placeholderStyle: context.text(AvoTextStyle.body, color: colors.placeholder),
                  style: context.text(AvoTextStyle.body, tabular: true),
                  onChanged: (_) {
                    if (_invalid) setState(() => _invalid = false);
                  },
                  onSubmitted: _submit,
                ),
                if (error != null)
                  ExcludeSemantics(
                    child: Text(error, style: context.text(AvoTextStyle.footnote, color: colors.destructive)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
