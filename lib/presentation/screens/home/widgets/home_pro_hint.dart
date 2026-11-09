import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/subscription/paywall_screen.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/hint_row.dart';
import 'package:shoply/presentation/widgets/design/pro_badge.dart';
import 'package:shoply/presentation/widgets/design/pro_gate.dart';
import 'package:shoply/presentation/widgets/design/swipe_actions.dart';

/// "14 Tage Avo Pro gratis testen" on Home after the first finished trip
/// (Konzept 18 §9.3, §11.11): `ProBadge` instead of a symbol, "Ansehen"
/// opens the paywall out of this row; swiping or the menu hides it for good.
/// Home decides with `ProHintVisit` whether it appears.
class HomeProHint extends StatelessWidget {
  const HomeProHint({super.key, required this.onNever});

  /// "Nicht mehr zeigen".
  final VoidCallback onNever;

  @override
  Widget build(BuildContext context) {
    final never = context.tr('pro_hint_never');
    return Builder(
      builder: (rowContext) => HintRow(
        leading: const ProBadge(),
        text: context.tr(
          'pro_hint_trial',
          params: {'pro': AppBrand.proName, 'days': '$kProTrialDays'},
        ),
        actionLabel: context.tr('pro_hint_view'),
        onTap: () =>
            unawaited(ProGate.openPaywall(rowContext, origin: rowContext)),
        swipeActions: [SwipeAction(label: never, onPressed: onNever)],
        contextMenuItems: [AvoMenuItem(label: never, onSelected: onNever)],
      ),
    );
  }
}
