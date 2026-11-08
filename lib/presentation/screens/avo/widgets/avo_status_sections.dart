import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/constants/app_brand.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/modules/module_labels.dart';
import 'package:shoply/data/services/app_flags_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';
import 'package:shoply/presentation/screens/avo/avo_chat.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_glyphs.dart';
import 'package:shoply/presentation/screens/avo/widgets/avo_result_card.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/pro_badge.dart';
import 'package:shoply/routes/route_paths.dart';

/// The Pro feature id of "more Avo questions a day" (`/pro?feature=`).
const String avoQuestionsProFeature = 'avo_questions';

/// Avo Pro's daily Avo questions from `app_flags.ai_limits` (`pro.avo_chat`);
/// null while unknown. Never a number in a text.
final avoProQuestionLimitProvider = Provider<int?>((ref) {
  final limits = ref.watch(
    appFlagsProvider.select((f) => f.values[AppFlagKeys.aiLimits]),
  );
  if (limits is! Map) return null;
  final pro = limits['pro'];
  if (pro is! Map) return null;
  final value = pro['avo_chat'];
  return value is num ? value.toInt() : null;
});

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
          onPressed: () => context.push(RoutePaths.proFor(feature)),
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
      leading: const AvoSymbolTile(icon: AvoIcon(avoTogglesIcon)),
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
  });

  final String code;
  final VoidCallback onRetry;
  final VoidCallback onSignIn;
  final DateTime? retryAt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final error = AvoSymbolTile(
      neutral: true,
      icon: Icon(
        CupertinoIcons.exclamationmark_circle,
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
          subtitle: context.tr('avo_err_unreachable'),
        );
    }
  }

  Widget _retry(
    BuildContext context,
    Widget leading,
    String title, {
    String? subtitle,
  }) {
    return _RetryLater(
      retryAt: retryAt,
      builder: (ready) => AvoResultSection(
        title: title,
        subtitle: subtitle,
        leading: leading,
        actions: [
          AvoCardAction(
            label: context.tr('avo_retry'),
            onPressed: ready ? onRetry : null,
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
