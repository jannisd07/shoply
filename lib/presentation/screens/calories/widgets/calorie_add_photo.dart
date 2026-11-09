import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_add_parts.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// S3 "Foto": the card with "Foto aufnehmen" and "Aus Fotos wählen", offline
/// off with the reason, the daily limit (Free with "Avo Pro ansehen").
class CalorieAddPhoto extends ConsumerStatefulWidget {
  const CalorieAddPhoto({super.key, required this.actions});

  final CalorieAddActions actions;

  @override
  ConsumerState<CalorieAddPhoto> createState() => _CalorieAddPhotoState();
}

class _CalorieAddPhotoState extends ConsumerState<CalorieAddPhoto> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final offline = ref.watch(isOfflineProvider);
    final limit = ref.watch(caloriePhotoLimitReachedProvider);
    final offerPro = ref.watch(caloriePhotoLimitOffersProProvider);
    final Widget card;
    if (limit) {
      card = CalorieSegmentCard(
        glyph: const AvoIcon(AvoIcons.camera),
        text: !offerPro
            ? context.tr('cal_photo_limit_pro')
            : context.tr('cal_photo_limit_free', params: {'pro': AppBrand.proName, 'n': '${ref.watch(caloriePhotosPerDayProProvider)}'}),
        children: [
          AppButton.primary(label: context.tr('cal_manual_row'), onPressed: () => widget.actions.openManual()),
          if (offerPro) const CalorieSeeProButton(),
        ],
      );
    } else {
      card = CalorieSegmentCard(
        glyph: const AvoIcon(AvoIcons.camera),
        text: context.tr('cal_photo_prompt'),
        children: [
          Semantics(
            hint: offline ? context.tr('cal_photo_offline') : null,
            child: AppButton.primary(
              label: context.tr('cal_photo_take'),
              icon: const Icon(CupertinoIcons.camera_fill),
              onPressed: offline ? null : widget.actions.takePhoto,
            ),
          ),
          AppButton.plain(label: context.tr('cal_photo_pick'), onPressed: offline ? null : widget.actions.pickPhoto),
          if (offline)
            Text(
              context.tr('cal_photo_offline'),
              textAlign: TextAlign.center,
              style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      card,
      Padding(
        padding: const EdgeInsets.fromLTRB(AvoSpacing.screen + AvoSpacing.l, AvoSpacing.s, AvoSpacing.screen + AvoSpacing.l, 0),
        child: Text(context.tr('cal_photo_note'), style: context.text(AvoTextStyle.footnote, color: colors.secondaryLabel)),
      ),
    ]);
  }

}
