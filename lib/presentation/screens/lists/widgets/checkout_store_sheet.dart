import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/constants/paper_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/nearby_store.dart';
import 'package:shoply/data/services/checkout_store_resolver.dart';

/// Asks which shop the trip happened in, when GPS could not say so on its own.
///
/// Only shown when [CheckoutStoreResolver] is genuinely unsure — standing in a
/// lone REWE never interrupts the checkout. Returns the chosen retailer name,
/// or null when the user skips (skipping is always allowed; the trip is
/// recorded either way, just without a shop).
Future<String?> showCheckoutStoreSheet(
  BuildContext context, {
  required StoreResolution resolution,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _CheckoutStoreSheet(resolution: resolution),
  );
}

class _CheckoutStoreSheet extends StatefulWidget {
  final StoreResolution resolution;
  const _CheckoutStoreSheet({required this.resolution});

  @override
  State<_CheckoutStoreSheet> createState() => _CheckoutStoreSheetState();
}

class _CheckoutStoreSheetState extends State<_CheckoutStoreSheet> {
  final _manualController = TextEditingController();
  bool _typingManually = false;

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  List<NearbyStore> get _candidates => switch (widget.resolution) {
        StoreAmbiguous(:final candidates) => candidates,
        _ => const <NearbyStore>[],
      };

  bool get _locationDenied => switch (widget.resolution) {
        StoreUnknown(:final locationDenied) => locationDenied,
        _ => false,
      };

  void _pick(String retailer) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(retailer);
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final candidates = _candidates;

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
              context.tr('checkout_store_title'),
              style: PaperTextStyles.serif(20, color: textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              _locationDenied
                  // Location was refused: name what that costs, once, without
                  // nagging — then still let them answer by hand.
                  ? context.tr('checkout_store_location_off_body')
                  : context.tr('checkout_store_body'),
              style: TextStyle(fontSize: 12.5, color: textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),

            if (candidates.isNotEmpty && !_typingManually) ...[
              // Constrained so a retail park with a dozen shops scrolls
              // instead of pushing the buttons off screen.
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _StoreTile(
                    store: candidates[i],
                    onTap: () => _pick(
                      candidates[i].retailerUniqueName != null
                          ? candidates[i].displayName
                          : candidates[i].displayName,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _TextButtonRow(
                label: context.tr('checkout_store_other'),
                onTap: () => setState(() => _typingManually = true),
              ),
            ] else ...[
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: TextField(
                  controller: _manualController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(fontSize: 15, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: context.tr('checkout_store_hint'),
                    hintStyle: TextStyle(color: textSecondary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  onSubmitted: (value) {
                    final name = value.trim();
                    if (name.isNotEmpty) _pick(name);
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    final name = _manualController.text.trim();
                    if (name.isNotEmpty) _pick(name);
                  },
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accentColor(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      context.tr('save'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 8),
            // Never a dead end: the trip is saved with or without a shop.
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  context.tr('checkout_store_skip'),
                  style: TextStyle(fontSize: 13, color: textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  final NearbyStore store;
  final VoidCallback onTap;

  const _StoreTile({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final distance = store.distanceMeters < 1000
        ? '${store.distanceMeters.round()} m'
        : '${store.distanceKm.toStringAsFixed(1)} km';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 20,
              color: AppColors.accentColor(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  if (store.address != null)
                    Text(
                      store.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              distance,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextButtonRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TextButtonRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.accentColor(context),
          ),
        ),
      ),
    );
  }
}
