import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/core/modules/module_labels.dart';
import 'package:shoply/presentation/widgets/design/module_off_alert.dart';
import 'package:shoply/routes/route_error_screen.dart';
import 'package:shoply/routes/route_paths.dart';

/// Shows [child] only while [module] is on (Konzept 00 §15.2).
///
/// Opened while the module is off (deep link, widget, Siri, notification):
/// a centred alert offers to switch it on ("Einschalten" opens the original
/// screen, "Nicht jetzt" goes back). Unreleased modules behave like a link
/// that leads nowhere. Teil A wraps every Teil-B module root with it.
class ModuleGate extends ConsumerStatefulWidget {
  const ModuleGate({super.key, required this.module, required this.child});

  final AppModule module;
  final Widget child;

  @override
  ConsumerState<ModuleGate> createState() => _ModuleGateState();
}

class _ModuleGateState extends ConsumerState<ModuleGate> {
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.module.released) return const RouteErrorScreen();
    final enabled = ref.watch(moduleEnabledProvider(widget.module));
    if (enabled) {
      _asked = false;
      return widget.child;
    }
    if (!_asked) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask());
    }
    return ColoredBox(color: context.colors.background);
  }

  Future<void> _ask() async {
    if (!mounted) return;
    final turnedOn = await showModuleOffAlert(
      context,
      moduleName: widget.module.label(context),
      onEnable: () =>
          ref.read(appModulesProvider.notifier).setEnabled(widget.module, true),
    );
    if (turnedOn || !mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.home);
    }
  }
}
