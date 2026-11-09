import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/avo_assistant_service.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_card_scope.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_confirm_card.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_record_sections.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/routes/route_paths.dart';

// Kap. 5.7: settings, modules, the app.

/// Removing an allergy (Kap. 6.5): the safety variant of the confirm card;
/// only "Entfernen" removes it, then the result with "Widerrufen".
class AvoAllergySection extends StatelessWidget {
  const AvoAllergySection({
    super.key,
    required this.payload,
    required this.scope,
    required this.card,
  });

  final AvoWidgetPayload payload;
  final AvoCardScope scope;
  final AvoAllergyCard card;

  @override
  Widget build(BuildContext context) {
    final chat = scope.chat;
    final phase = chat.confirmPhaseOf(payload);
    if (phase == AvoConfirmPhase.deleted && chat.recordOf(payload) != null) {
      return AvoRecordSection(payload: payload, scope: scope);
    }
    final allergen = {'allergen': card.allergen};
    return AvoConfirmCard(
      safety: true,
      title: context.tr('avo_confirm_allergy_title', params: allergen),
      body: context.tr('avo_confirm_allergy_body', params: allergen),
      confirmLabel: context.tr('avo_remove'),
      doneText: context.tr('avo_rec_allergy_removed', params: allergen),
      cancelledText: context.tr('avo_not_removed'),
      phase: phase,
      offline: scope.offline,
      firstShow: chat.firstShowOf(payload),
      onConfirm: () => chat.removeAllergy(payload),
      onCancel: () => chat.cancelDelete(payload),
    );
  }
}

/// `update_setting` that did not work.
AvoResultSection avoSettingFailedSection(
  BuildContext context,
  AvoSettingFailedCard card,
) => AvoResultSection(
  title: context.tr(
    'avo_setting_failed',
    params: {'setting': avoSettingName(context, card.key)},
  ),
  leading: AvoSymbolTile(
    neutral: true,
    icon: Icon(
      CupertinoIcons.exclamationmark_circle,
      color: context.colors.destructive,
    ),
  ),
);

/// The name of a setting key ("Darstellung", "Allergien").
String avoSettingName(BuildContext context, String key) => context.tr(
  switch (key) {
    'theme_mode' => 'avo_set_appearance',
    'accent_color' => 'avo_set_accent',
    'language' => 'avo_set_language',
    'notifications' => 'avo_set_notifications',
    'zip_code' => 'avo_set_region',
    'age' => 'avo_set_age',
    'gender' => 'avo_set_gender',
    'height_cm' => 'avo_set_height',
    'allergies_add' || 'allergies_remove' => 'avo_set_allergies',
    'diet_add' || 'diet_remove' => 'avo_set_diet',
    'display_name' || 'name' => 'avo_set_name',
    _ => 'avo_set_generic',
  },
);

/// `get_app_info`: a row to the Pro page (Avo's text says the rest; prices
/// come from the App Store). No Pro hint beyond what was asked.
AvoResultSection avoAppInfoSection(BuildContext context, AvoAppInfoCard card) {
  void open() => context.push(RoutePaths.pro);
  return AvoResultSection(
    title: AppBrand.proName,
    subtitle: card.isPro ? context.tr('avo_app_info_have') : null,
    leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.sparkle)),
    onOpen: open,
    actions: [AvoCardAction(label: context.tr('avo_view'), onPressed: open)],
  );
}
