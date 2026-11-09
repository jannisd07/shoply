import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/modules/module_labels.dart';
import 'package:shoply/data/services/app_flags_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/pro_badge.dart';
import 'package:shoply/presentation/widgets/design/pro_gate.dart';

/// The Pro feature id of "more Avo questions a day" (`/pro?feature=`).
const String avoQuestionsProFeature = ProFeatures.avoQuestions;

/// Avo Pro's daily limit of an `ai` task from `app_flags.ai_limits`
/// (`pro.<task>`); null while unknown.
final avoProTaskLimitProvider = Provider.family<int?, String>((ref, task) {
  final limits = ref.watch(
    appFlagsProvider.select((f) => f.values[AppFlagKeys.aiLimits]),
  );
  if (limits is! Map) return null;
  final pro = limits['pro'];
  if (pro is! Map) return null;
  final value = pro[task];
  return value is num ? value.toInt() : null;
});

/// Avo Pro's daily Avo questions (`pro.avo_chat`); null while unknown.
final avoProQuestionLimitProvider = Provider<int?>(
  (ref) => ref.watch(avoProTaskLimitProvider('avo_chat')),
);

/// The Pro row after the daily photo limit (A9-3): meal photos or shopping
/// notes, with Avo Pro's limit of that task. Nothing while it is unknown.
class AvoPhotoProRow extends ConsumerWidget {
  const AvoPhotoProRow({super.key, required this.meal});

  /// A meal photo (`meal_photo`), else a shopping note (`list_import`).
  final bool meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(
      avoProTaskLimitProvider(meal ? 'meal_photo' : 'list_import'),
    );
    if (limit == null) return const SizedBox.shrink();
    return AvoProRow(
      title: context.tr('avo_pro_more_photos_title'),
      subtitle: context.tr(
        'avo_pro_more_photos_sub',
        params: {'pro': AppBrand.proName, 'limit': '$limit'},
      ),
      feature: avoQuestionsProFeature,
      icon: const AvoIcon(AvoIcons.camera),
    );
  }
}

/// The Pro row (Kap. 2.7): a section with the feature, the Pro badge, what
/// Pro adds and "Ansehen" to the paywall. Here only for the daily limit.
class AvoProRow extends StatelessWidget {
  const AvoProRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.feature,
    this.icon,
  });

  final String title;
  final String subtitle;
  final String feature;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return AvoResultSection(
      title: title,
      subtitle: subtitle,
      leading: AvoSymbolTile(icon: icon ?? const AvoIcon(AvoIcons.sparkle)),
      trailingTitle: const ProBadge(),
      semanticLabel: '$title, ${AppBrand.proName}. $subtitle',
      actions: [
        AvoCardAction(
          label: context.tr('avo_view'),
          // The paywall grows out of this row (A9b-2).
          onPressed: () => unawaited(
            ProGate.openPaywall(context, feature: feature, origin: context),
          ),
        ),
      ],
    );
  }
}

/// A module that is switched off (Kap. 2.8): "Kalorien & Gesundheit ist
/// ausgeschaltet" with "Einschalten"; once on "… eingeschaltet" with
/// "Widerrufen".
class AvoModuleOffRow extends StatelessWidget {
  const AvoModuleOffRow({
    super.key,
    required this.module,
    required this.phase,
    required this.onTurnOn,
    required this.onUndo,
  });

  final AppModule module;
  final AvoModulePhase phase;
  final VoidCallback onTurnOn;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final name = module.label(context);
    final on = phase == AvoModulePhase.on;
    final undone = phase == AvoModulePhase.undone;
    return AvoResultSection(
      title: context.tr(
        on || undone ? 'avo_module_on' : 'avo_module_off',
        params: {'module': name},
      ),
      leading: const AvoSymbolTile(icon: AvoIcon(AvoIcons.switch2)),
      state: undone ? AvoSectionState.undone : AvoSectionState.done,
      actions: [
        if (on)
          AvoCardAction(
            label: context.tr('avo_undo'),
            isUndo: true,
            onPressed: onUndo,
          )
        else if (!undone)
          AvoCardAction(
            label: context.tr('avo_turn_on'),
            working: phase == AvoModulePhase.working,
            onPressed: phase == AvoModulePhase.off ? onTurnOn : null,
          ),
      ],
    );
  }
}

/// What a failed answer shows in its card (table 3.3).
class AvoErrorSection extends StatelessWidget {
  const AvoErrorSection({
    super.key,
    required this.code,
    required this.onRetry,
    required this.onSignIn,
    this.retryAt,
    this.partlyDone = false,
    this.partlyDoneHidden = false,
  });

  final String code;

  /// Null hides "Erneut versuchen" (the question was asked again already).
  final VoidCallback? onRetry;

  /// Changes of this answer are done and keep their cards: says so.
  final bool partlyDone;

  /// Something without a card of its own is done (recipe to list, a log):
  /// says that part is done, without pointing at cards.
  final bool partlyDoneHidden;
  final VoidCallback onSignIn;
  final DateTime? retryAt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final error = AvoSymbolTile(
      neutral: true,
      icon: AvoIcon(
        AvoIcons.exclamationmarkCircle,
        color: colors.destructive,
      ),
    );
    switch (code) {
      case 'quota_exceeded':
        return AvoResultSection(
          title: context.tr('avo_limit_reached'),
          leading: const AvoSymbolTile(
            neutral: true,
            icon: AvoIcon(AvoIcons.clock),
          ),
        );
      case 'unauthorized':
        return AvoResultSection(
          title: context.tr('avo_err_session'),
          leading: error,
          actions: [
            AvoCardAction(
              label: context.tr('avo_sign_in_again'),
              onPressed: onSignIn,
            ),
          ],
        );
      case 'ai_disabled':
        return AvoResultSection(
          title: context.tr('avo_unavailable'),
          leading: const AvoSymbolTile(
            neutral: true,
            icon: Icon(CupertinoIcons.exclamationmark_triangle),
          ),
        );
      case 'network_error':
        return _retry(context, error, context.tr('avo_offline'));
      case 'timeout':
        return _retry(context, error, context.tr('avo_err_timeout'));
      case 'rate_limited':
        return _retry(context, error, context.tr('avo_err_busy'));
      default:
        return _retry(
          context,
          error,
          context.tr('avo_err_title'),
          subtitle: partlyDone || partlyDoneHidden
              ? null
              : context.tr('avo_err_unreachable'),
        );
    }
  }

  Widget _retry(
    BuildContext context,
    Widget leading,
    String title, {
    String? subtitle,
  }) {
    final sub = partlyDone
        ? context.tr('avo_err_partly_done')
        : partlyDoneHidden
        ? context.tr('avo_err_partly_done_hidden')
        : subtitle;
    final retry = onRetry;
    return _RetryLater(
      retryAt: retryAt,
      builder: (ready) => AvoResultSection(
        title: title,
        subtitle: sub,
        leading: leading,
        actions: [
          if (retry != null)
            AvoCardAction(
              label: context.tr('avo_retry'),
              onPressed: ready ? retry : null,
            ),
        ],
      ),
    );
  }
}

/// Rebuilds once when [retryAt] has passed ("Erneut versuchen" turns active
/// after `retry_after_s`).
class _RetryLater extends StatefulWidget {
  const _RetryLater({required this.retryAt, required this.builder});

  final DateTime? retryAt;
  final Widget Function(bool ready) builder;

  @override
  State<_RetryLater> createState() => _RetryLaterState();
}

class _RetryLaterState extends State<_RetryLater> {
  bool _ready = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final at = widget.retryAt;
    if (at == null) return;
    final left = at.difference(DateTime.now());
    if (left > Duration.zero) {
      _ready = false;
      _timer = Timer(left, () {
        if (mounted) setState(() => _ready = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_ready);
}
