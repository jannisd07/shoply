import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/presentation/providers/price_comparison_provider.dart';

/// Bottom sheet to set (or clear) a manual zip code for local offer lookups.
/// Used when GPS is unavailable/denied — without this, pricing has no way
/// to know which region's offers to show. Returns `true` if the zip code
/// changed and was saved.
Future<bool> showZipCodeSheet(BuildContext context, {String? initialZip}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ZipCodeSheet(initialZip: initialZip),
  );
  return saved ?? false;
}

class _ZipCodeSheet extends ConsumerStatefulWidget {
  final String? initialZip;
  const _ZipCodeSheet({this.initialZip});

  @override
  ConsumerState<_ZipCodeSheet> createState() => _ZipCodeSheetState();
}

class _ZipCodeSheetState extends ConsumerState<_ZipCodeSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialZip ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final zip = _controller.text.trim();
    if (zip.length < 4) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    await UserLocationService.instance.setManualZipCode(zip);
    ref.invalidate(userZipCodeProvider);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
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
              context.tr('set_zip_code_title'),
              style: PaperTextStyles.serif(20, color: textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('set_zip_code_body'),
              style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                style: TextStyle(fontSize: 15, color: textPrimary),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                decoration: InputDecoration(
                  hintText: context.tr('zip_code_hint'),
                  hintStyle: TextStyle(color: textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentColor(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(PaperColors.paper),
                          ),
                        )
                      : Text(
                          context.tr('save'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: PaperColors.paper,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
