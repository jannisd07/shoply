import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/routes/route_paths.dart';

/// D2 X-Essen: the xmark is drawn at 18 pt.
const double _kCloseGlyph = 18; // D2

/// Space under the header before the content starts.
const double _kHeaderBottom = AvoSpacing.m;

/// The pinned primary action ends 34 pt above the bottom edge (D2 X-Essen)
/// or 8 pt above the keyboard.
const double _kBottomGapKeyboard = AvoSpacing.s;

/// `RouteSettings.name` of the pages of one logging flow (S3 to S8, S10):
/// after "Eintragen" the whole flow closes and the person is back where it
/// started (Owner-Frage 5).
const String kCalorieFlowPageName = 'calorie-flow';

/// Closes the logging flow this screen belongs to: every flow page on top
/// of the navigator, so S7 opened from S3 lands where S3 was opened.
void popCalorieFlow(BuildContext context) {
  final navigator = Navigator.of(context);
  if (!navigator.canPop()) {
    GoRouter.maybeOf(context)?.go(RoutePaths.home);
    return;
  }
  var first = true;
  navigator.popUntil((route) {
    if (first) {
      first = false;
      return false;
    }
    return route.settings.name != kCalorieFlowPageName || route.isFirst;
  });
}

/// The leading glass button: `xmark` at the start of a flow, `chevron.left`
/// in a follow-up step or when editing (`kalorien.md` K7).
enum CalorieFlowLeading { close, back }

/// The texts of the "verwerfen?" alert of one screen (S5, S8, S14).
class CalorieDiscardTexts {
  const CalorieDiscardTexts({
    required this.title,
    this.message,
    required this.confirm,
    required this.cancel,
  });

  final String title;
  final String? message;

  /// "Verwerfen" (destructive).
  final String confirm;

  /// "Weiter bearbeiten" (the bold default).
  final String cancel;
}

/// The frame of the logging screens S5 and S7 to S10 and of S14 (A-C2
/// `EditorScaffold` is not built; this is B's version from A's tokens).
///
/// - Header: glass button 44 at the start, [title] centred between it and
///   [trailing] (a 44 pt placeholder keeps it centred), growing with large
///   text instead of clipping. The header does not lie over the content.
/// - Content scrolls under a short scroll edge fade; the keyboard shrinks
///   the frame, so the focused field stays visible.
/// - [bottom] (the tinted capsule "Eintragen") is pinned under the content,
///   34 pt above the bottom edge or 8 pt above the keyboard.
/// - With [discard], leaving (button, swipe back, Escape) asks first;
///   without changes the screen closes at once. [onLeave] runs on every way
///   out (S9 saves there).
/// - Pushed from the right like every route (never sliding up).
class CalorieFlowScaffold extends StatelessWidget {
  const CalorieFlowScaffold({
    super.key,
    required this.leading,
    required this.title,
    required this.children,
    this.trailing,
    this.bottom,
    this.discard,
    this.onLeave,
    this.leadingLabel,
    this.scrollController,
    this.canLeave = true,
    this.beforeLeave,
  });

  final CalorieFlowLeading leading;

  /// The inline title: a [CalorieFlowTitle] or a menu button.
  final Widget title;

  /// The content, top to bottom; bring your own 16 pt margins (inset groups
  /// have them).
  final List<Widget> children;

  /// A glass button at the end ("Mehr"); null keeps the space empty.
  final Widget? trailing;

  final Widget? bottom;

  /// Non-null: leaving asks with these texts.
  final CalorieDiscardTexts? discard;

  /// Called once when the screen is left for good (not when the person
  /// chose "Weiter bearbeiten").
  final VoidCallback? onLeave;

  /// VoiceOver label of the leading button; "Schließen" / "Zurück" by
  /// default.
  final String? leadingLabel;

  final ScrollController? scrollController;

  /// False keeps the screen open (an invalid field the screen saves on
  /// leaving): leaving plays the error haptic and does nothing else, the
  /// field already says what is wrong.
  final bool canLeave;

  /// Runs before the screen is left (S9 saves here); false keeps it open.
  /// While set, the pop scope holds every pop (Escape, Android back) for
  /// it; on iOS that also turns off the swipe back, so the back button
  /// leaves.
  final Future<bool> Function()? beforeLeave;

  /// Leaves the screen: back to where it was opened, or Home when it was the
  /// first route (deep link). A pop reports itself to [onLeave] through the
  /// pop scope; going Home calls it here.
  static void leave(BuildContext context, {VoidCallback? onLeave}) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      onLeave?.call();
      GoRouter.maybeOf(context)?.go(RoutePaths.home);
    }
  }

  Future<void> _attemptLeave(BuildContext context) async {
    if (!canLeave) {
      unawaited(AvoHaptics.error());
      return;
    }
    final before = beforeLeave;
    if (before != null && !await before()) return;
    if (!context.mounted) return;
    final texts = discard;
    if (texts != null) {
      final ok = await showAvoConfirm(
        context,
        title: texts.title,
        message: texts.message,
        confirmLabel: texts.confirm,
        cancelLabel: texts.cancel,
      );
      if (!ok || !context.mounted) return;
    }
    if (context.mounted) leave(context, onLeave: onLeave);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final close = leading == CalorieFlowLeading.close;
    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        AvoSpacing.screen,
        GlassToolbar.topOffset(context),
        AvoSpacing.screen,
        _kHeaderBottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassIconButton(
            icon: close
                ? const AvoIcon(AvoIcons.xmark, size: _kCloseGlyph)
                : const AvoIcon(AvoIcons.chevronBack),
            semanticLabel: leadingLabel ?? context.tr(close ? 'common_close' : 'back'),
            onPressed: () => unawaited(_attemptLeave(context)),
          ),
          const SizedBox(width: AvoSpacing.s),
          Expanded(child: title),
          const SizedBox(width: AvoSpacing.s),
          trailing ?? const SizedBox.square(dimension: AvoSizes.toolbarButton),
        ],
      ),
    );

    final bottomWidget = bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return PopScope<Object?>(
      canPop: discard == null && canLeave && beforeLeave == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          onLeave?.call();
        } else {
          unawaited(_attemptLeave(context));
        }
      },
      child: ColoredBox(
        color: colors.background,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: Column(
            children: [
              Semantics(container: true, explicitChildNodes: true, sortKey: const OrdinalSortKey(0), child: header),
              Expanded(
                child: Semantics(
                  container: true,
                  sortKey: const OrdinalSortKey(1),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.only(
                            top: AvoSpacing.xs,
                            bottom: bottomWidget == null && keyboard == 0
                                ? safeBottom + AvoSpacing.xxl
                                : AvoSpacing.xxl,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: children,
                          ),
                        ),
                      ),
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: ScrollEdgeFade(height: AvoSpacing.l),
                      ),
                    ],
                  ),
                ),
              ),
              if (bottomWidget != null)
                Semantics(
                  container: true,
                  sortKey: const OrdinalSortKey(2),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AvoSpacing.screen,
                      AvoSpacing.s,
                      AvoSpacing.screen,
                      keyboard > 0 ? _kBottomGapKeyboard : (safeBottom > 0 ? safeBottom : AvoSpacing.l),
                    ),
                    child: bottomWidget,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The inline title of a [CalorieFlowScaffold] (17/22 semibold, centred, a
/// VoiceOver header that names the screen). Wraps with large text.
class CalorieFlowTitle extends StatelessWidget {
  const CalorieFlowTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
      child: Center(
        child: Semantics(
          header: true,
          namesRoute: true,
          child: Text(text, textAlign: TextAlign.center, style: context.text(AvoTextStyle.headline)),
        ),
      ),
    );
  }
}
