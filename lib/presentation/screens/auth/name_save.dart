import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/auth/auth_gateway.dart';
import 'package:shoply/presentation/screens/auth/widgets/auth_status.dart';
import 'package:shoply/presentation/state/auth_provider.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// Where saving the name from the name step stands (Konzept 17 §3.8).
@immutable
class NameSaveState {
  const NameSaveState({this.name, this.saving = false, this.failed = false});

  /// The name last given to [NameSaveController.save].
  final String? name;
  final bool saving;

  /// The last attempt failed; the next step shows [NameSaveStatus].
  final bool failed;
}

/// Saves the display name optimistically: the name step moves on at once,
/// this saves in the background. After a failure it tries again by itself
/// when the connection comes back, or on "Erneut versuchen".
class NameSaveController extends Notifier<NameSaveState> {
  @override
  NameSaveState build() {
    ref.listen<bool>(isOfflineProvider, (previous, offline) {
      if (previous == true && !offline && state.failed) retry();
    });
    return const NameSaveState();
  }

  Future<void> save(String name) async {
    state = NameSaveState(name: name, saving: true);
    try {
      await ref.read(authGatewayProvider).saveDisplayName(name);
      state = NameSaveState(name: name);
      ref.invalidate(currentUserProvider);
    } catch (e) {
      debugPrint('[AUTH] saving the name failed: $e');
      state = NameSaveState(name: name, failed: true);
    }
  }

  Future<void> retry() async {
    final name = state.name;
    if (name == null || state.saving) return;
    await save(name);
  }
}

final nameSaveProvider = NotifierProvider<NameSaveController, NameSaveState>(
  NameSaveController.new,
);

/// "Dein Name ist noch nicht gespeichert. Erneut versuchen" for the step
/// after the name step (Konzept 17 §3.8). Draws nothing while all is well;
/// pass it as that step's `OnboardingStepPage.status`.
class NameSaveStatus extends ConsumerWidget {
  const NameSaveStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = ref.watch(nameSaveProvider.select((s) => s.failed));
    if (!failed) return const SizedBox.shrink();
    return AuthStatusLine(
      kind: StatusKind.failed,
      text: context.tr('auth_name_not_saved'),
      actionLabel: context.tr('retry'),
      onAction: () => ref.read(nameSaveProvider.notifier).retry(),
    );
  }
}
