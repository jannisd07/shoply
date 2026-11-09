import 'package:flutter/widgets.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/onboarding/steps/step_common.dart';
import 'package:shoply/presentation/screens/onboarding/widgets/onboarding_step_scaffold.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';

/// "Angebote in deiner Region" (Konzept 17 §3.4, A-O1): Teil A draws the
/// frame, title, sentence, progress, back and "Überspringen"; Teil B's
/// `OffersSetupStep` draws the content and its own "Weiter" and calls
/// `onDone`.
///
/// The flow checks before the push whether B has anything to show
/// ([probeOffersSetup]). This page only catches the resume case (the app
/// was killed on this step): there it stays invisible for its first frames,
/// and a "done" from B in that time calls [onUnavailable] instead of
/// [onNext], so the step disappears without a flash.
class RegionStep extends StatefulWidget {
  const RegionStep({
    super.key,
    required this.onNext,
    required this.onUnavailable,
    this.onBack,
    this.progress,
  });

  final VoidCallback onNext;
  final VoidCallback onUnavailable;
  final VoidCallback? onBack;
  final Widget? progress;

  @override
  State<RegionStep> createState() => _RegionStepState();
}

class _RegionStepState extends State<RegionStep> {
  /// True until the second frame after the step appeared.
  bool _appearing = true;

  /// The page is the first one shown (no push animation): hide it while
  /// [_appearing].
  bool? _hideWhileAppearing;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    // Registered before B's own callback, so B's first "done" still sees
    // [_appearing]; it ends one frame later.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _appearing = false);
      });
      WidgetsBinding.instance.scheduleFrame();
    });
  }

  void _onDone() {
    if (!mounted || _left) return;
    if (_appearing) {
      _left = true;
      widget.onUnavailable();
      return;
    }
    runIfCurrent(context, widget.onNext);
  }

  @override
  Widget build(BuildContext context) {
    _hideWhileAppearing ??=
        (ModalRoute.of(context)?.animation?.isCompleted ?? true);
    final page = OnboardingStepPage(
      title: context.tr('onb_region_title'),
      message: context.tr('onb_region_sentence'),
      progress: widget.progress,
      onBack: widget.onBack,
      onSkip: () => runIfCurrent(context, widget.onNext),
      status: const OnboardingSyncStatus(),
      children: [OffersSetupStep(onDone: _onDone)],
    );
    if (_appearing && _hideWhileAppearing!) {
      return Opacity(opacity: 0, child: page);
    }
    return page;
  }
}

/// Whether Teil B's region step has something to show: it is mounted
/// offstage for two frames; a "done" in that time means "nothing to show"
/// (kill switch or the shell before S4). Host it with [OffersSetupProbe].
class OffersSetupProbe extends StatelessWidget {
  const OffersSetupProbe({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Offstage(
    child: SingleChildScrollView(child: OffersSetupStep(onDone: onDone)),
  );
}

/// Runs the probe through [show] (which puts an [OffersSetupProbe] into the
/// tree and removes it again with null) and completes with true when B has
/// content.
Future<bool> probeOffersSetup(void Function(Widget? probe) show) async {
  var nothing = false;
  show(OffersSetupProbe(key: UniqueKey(), onDone: () => nothing = true));
  for (var i = 0; i < 2 && !nothing; i++) {
    await WidgetsBinding.instance.endOfFrame;
  }
  show(null);
  return !nothing;
}
