import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/glass_surface.dart';
import 'package:shoply/presentation/widgets/design/item_row.dart'
    show AdaptiveTrailing;
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// What the import capsule shows.
@immutable
class ImportStatus {
  /// Reading: a small activity indicator, [text] and a plain [actionLabel]
  /// ("Abbrechen").
  const ImportStatus.busy({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  }) : kind = null;

  /// A result to act on: a [StatusRow] of [kind] with an optional action
  /// ("Anderes Bild", "Erneut versuchen", "In Einstellungen erlauben").
  const ImportStatus.message({
    required StatusKind this.kind,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  /// Null while busy.
  final StatusKind? kind;

  /// The sentence.
  final String text;

  /// The action, if any.
  final String? actionLabel;

  /// Runs the action.
  final VoidCallback? onAction;

  /// Whether it shows the activity indicator.
  bool get busy => kind == null;
}

/// The floating status of a list import (Konzept 11 §3.2): a glass capsule
/// where the add field sits, above the tab bar, while the note is read and
/// when something went wrong. The list behind stays usable; only the
/// capsule takes touches.
///
/// One controller per import run; [hide] removes it again.
class ImportStatusCapsule {
  /// Shows the capsule in [overlay] (the root overlay) on the first [show].
  ImportStatusCapsule(this._overlay);

  final OverlayState _overlay;
  final ValueNotifier<ImportStatus?> _status = ValueNotifier(null);
  OverlayEntry? _entry;

  /// The status on screen, null when hidden.
  ImportStatus? get current => _status.value;

  /// Shows [status], replacing the previous one.
  void show(ImportStatus status) {
    _status.value = status;
    if (_entry != null || !_overlay.mounted) return;
    final entry = OverlayEntry(
      builder: (context) => _CapsuleLayer(status: _status),
    );
    _entry = entry;
    _overlay.insert(entry);
  }

  /// Removes the capsule.
  void hide() {
    _status.value = null;
    final entry = _entry;
    _entry = null;
    // Also before its first build: an entry inserted this frame is not
    // mounted yet but must go.
    entry?.remove();
  }

  /// Hides it and frees the notifier once the entry is gone.
  void dispose() {
    hide();
    WidgetsBinding.instance.addPostFrameCallback((_) => _status.dispose());
  }
}

class _CapsuleLayer extends StatelessWidget {
  const _CapsuleLayer({required this.status});

  final ValueListenable<ImportStatus?> status;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = keyboard > 0
        ? keyboard + AvoSizes.accessoryGap
        : ShellInsets.aboveTabBar(context);
    return Positioned(
      left: AvoSizes.tabBarSide,
      right: AvoSizes.tabBarSide,
      bottom: bottom,
      child: SafeArea(
        top: false,
        bottom: false,
        child: ValueListenableBuilder<ImportStatus?>(
          valueListenable: status,
          builder: (context, value, _) {
            if (value == null) return const SizedBox.shrink();
            return ImportStatusView(status: value);
          },
        ),
      ),
    );
  }
}

/// The capsule itself; public for tests and the gallery.
class ImportStatusView extends StatefulWidget {
  /// Creates the capsule for [status].
  const ImportStatusView({super.key, required this.status});

  /// What it shows.
  final ImportStatus status;

  @override
  State<ImportStatusView> createState() => _ImportStatusViewState();
}

class _ImportStatusViewState extends State<ImportStatusView> {
  @override
  void initState() {
    super.initState();
    if (widget.status.busy) _announceLater();
  }

  @override
  void didUpdateWidget(ImportStatusView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status.busy && oldWidget.status.text != widget.status.text) {
      _announceLater();
    }
  }

  /// iOS live regions only post a layout change; the busy text is spoken
  /// explicitly ([StatusRow] does this for the messages).
  void _announceLater() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || defaultTargetPlatform != TargetPlatform.iOS) return;
      final view = View.maybeOf(context);
      if (view == null) return;
      SemanticsService.sendAnnouncement(
        view,
        widget.status.text,
        Directionality.maybeOf(context) ?? TextDirection.ltr,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final Widget content;
    if (status.busy) {
      final label = status.actionLabel;
      final onAction = status.onAction;
      content = Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AvoSpacing.l,
          AvoSpacing.xs,
          AvoSpacing.l,
          AvoSpacing.xs,
        ),
        child: AdaptiveTrailing(
          stacked: context.isAccessibilityText,
          runGap: 0,
          trailing: label != null && onAction != null
              ? AppButton.plain(label: label, onPressed: onAction)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AvoSpacing.s),
            child: Row(
              children: [
                const CupertinoActivityIndicator(),
                const SizedBox(width: AvoSpacing.m),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      status.text,
                      style: context.text(AvoTextStyle.body),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: AvoSpacing.xs),
        child: StatusRow(
          kind: status.kind!,
          text: status.text,
          actionLabel: status.actionLabel,
          onAction: status.onAction,
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AvoSizes.accessoryHeight),
      child: GlassSurface(
        shape: GlassShape.rounded,
        radius: AvoRadii.group,
        child: Center(heightFactor: 1, child: content),
      ),
    );
  }
}
