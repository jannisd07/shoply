import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import 'package:shoply/core/constants/app_colors.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/core/widgets/design_system.dart';
import 'package:shoply/data/services/list_import_service.dart';

/// Opens the "+" attachment sheet: it morphs out of the button whose
/// [plusButtonKey] is given, offers Kamera / Fotos / Dateien, runs the
/// photo → items extraction inline (cancelable), and resolves with the
/// extraction result — or null when dismissed/cancelled.
///
/// The route is interactively drag-dismissable: dragging down scrubs the
/// morph animation 1:1, releasing decides by velocity.
Future<ListImportResult?> showAttachmentSheet(
  BuildContext context, {
  required GlobalKey plusButtonKey,
}) {
  // Resolve the morph origin before pushing — the button's global center.
  Alignment origin = const Alignment(-0.85, 1);
  final renderBox =
      plusButtonKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox != null && renderBox.hasSize) {
    final center = renderBox.localToGlobal(renderBox.size.center(Offset.zero));
    final screen = MediaQuery.sizeOf(context);
    origin = Alignment(
      (center.dx / screen.width) * 2 - 1,
      (center.dy / screen.height) * 2 - 1,
    );
  }

  return Navigator.of(context, rootNavigator: true).push<ListImportResult>(
    _MorphSheetRoute<ListImportResult>(
      origin: origin,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      barrierLabel: context.tr('cancel'),
      builder: (routeContext, route) =>
          _AttachmentSheetBody(route: route),
    ),
  );
}

/// A bottom-docked popup that expands from [origin] (the "+" button) into
/// the sheet — Messages-attachment-menu style — with drag-to-scrub
/// dismissal. With Reduce Motion the morph becomes a plain cross-fade of
/// the same duration.
class _MorphSheetRoute<T> extends PopupRoute<T> {
  final Alignment origin;
  final bool reduceMotion;
  final Widget Function(BuildContext, _MorphSheetRoute<T>) builder;
  @override
  final String barrierLabel;

  _MorphSheetRoute({
    required this.origin,
    required this.reduceMotion,
    required this.builder,
    required this.barrierLabel,
  });

  AnimationController? _dragController;

  @override
  AnimationController createAnimationController() {
    _dragController = super.createAnimationController();
    return _dragController!;
  }

  @override
  Color get barrierColor => Colors.black.withValues(alpha: 0.35);

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  // Never trigger the Cupertino secondary slide on the screen below — the
  // list stays put and only dims (the barrier).
  @override
  bool canTransitionTo(TransitionRoute nextRoute) => false;
  @override
  bool canTransitionFrom(TransitionRoute previousRoute) => false;

  /// Scrub the animation from the sheet's drag gesture (1 == fully open).
  void dragBy(double deltaFractionOfHeight) {
    final c = _dragController;
    if (c == null) return;
    if (!(navigator?.userGestureInProgress ?? true)) {
      navigator?.didStartUserGesture();
    }
    c.value = (c.value - deltaFractionOfHeight).clamp(0.0, 1.0);
  }

  /// Finish the drag: velocity (logical px/s, positive = downward) or
  /// position decides between dismiss and settle-back.
  void endDrag(double velocity, BuildContext sheetContext) {
    final c = _dragController;
    navigator?.didStopUserGesture();
    if (c == null) return;
    const dismissVelocity = 700.0;
    final shouldDismiss =
        velocity > dismissVelocity || (velocity > -dismissVelocity && c.value < 0.5);
    if (shouldDismiss) {
      Navigator.of(sheetContext).pop();
    } else {
      c.forward();
    }
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return builder(context, this);
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    if (reduceMotion) {
      return FadeTransition(opacity: animation, child: child);
    }
    final curved = CurvedAnimation(
      parent: animation,
      // Slight spring overshoot on the way in, clean ease on the way out.
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.45, curve: Curves.easeOut),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.15, end: 1).animate(curved),
        alignment: origin,
        child: child,
      ),
    );
  }
}

enum _SheetState { menu, processing, error, permissionDenied }

class _AttachmentSheetBody extends StatefulWidget {
  final _MorphSheetRoute<ListImportResult> route;

  const _AttachmentSheetBody({required this.route});

  @override
  State<_AttachmentSheetBody> createState() => _AttachmentSheetBodyState();
}

class _AttachmentSheetBodyState extends State<_AttachmentSheetBody> {
  _SheetState _state = _SheetState.menu;
  String _errorCode = 'provider_error';
  CancelToken? _cancelToken;

  // Kept for "try again" without re-picking.
  Uint8List? _lastBytes;
  bool _lastWasPdf = false;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _pickFromCamera() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );
      if (file == null) return;
      await _process(await file.readAsBytes(), isPdf: false);
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') {
        setState(() => _state = _SheetState.permissionDenied);
      } else {
        setState(() {
          _errorCode = 'unreadable_image';
          _state = _SheetState.error;
        });
      }
    }
  }

  Future<void> _pickFromPhotos() async {
    // PHPicker — no permission prompt needed on iOS 14+.
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await _process(await file.readAsBytes(), isPdf: false);
  }

  Future<void> _pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'heic', 'webp', 'pdf'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    await _process(bytes, isPdf: file.extension?.toLowerCase() == 'pdf');
  }

  Future<void> _process(Uint8List bytes, {required bool isPdf}) async {
    _lastBytes = bytes;
    _lastWasPdf = isPdf;
    final token = CancelToken();
    _cancelToken = token;
    setState(() => _state = _SheetState.processing);
    try {
      final result = await ListImportService.instance
          .importFromBytes(bytes, isPdf: isPdf, cancelToken: token);
      if (!mounted) return;
      // Resolve the whole sheet with the result — the caller presents the
      // review sheet after this one is fully gone (no stacked sheets).
      Navigator.of(context).pop(result);
    } on ListImportException catch (e) {
      if (!mounted) return;
      if (e.code == 'cancelled') {
        setState(() => _state = _SheetState.menu);
      } else {
        setState(() {
          _errorCode = e.code;
          _state = _SheetState.error;
        });
      }
    }
  }

  void _cancelProcessing() {
    HapticFeedback.lightImpact();
    _cancelToken?.cancel();
  }

  String _errorMessage(BuildContext context) {
    return switch (_errorCode) {
      'no_items_found' => context.tr('import_error_no_items'),
      'unreadable_image' => context.tr('import_error_unreadable'),
      'rate_limited' => context.tr('import_error_rate_limited'),
      'timeout' => context.tr('import_error_timeout'),
      'network_error' => context.tr('import_error_network'),
      'not_signed_in' => context.tr('import_error_network'),
      _ => context.tr('import_error_provider'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final reduceTransparency = MediaQuery.highContrastOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    final tint = reduceTransparency
        ? AppColors.surface(context)
        : (isDark
              ? const Color(0xFF1C1C1E).withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.72));

    final body = switch (_state) {
      _SheetState.menu => _MenuView(
          onCamera: _pickFromCamera,
          onPhotos: _pickFromPhotos,
          onFiles: _pickFromFiles,
        ),
      _SheetState.processing => _ProcessingView(onCancel: _cancelProcessing),
      _SheetState.error => _ErrorView(
          message: _errorMessage(context),
          canRetry: _lastBytes != null,
          onRetry: () => _process(_lastBytes!, isPdf: _lastWasPdf),
          onBack: () => setState(() => _state = _SheetState.menu),
        ),
      _SheetState.permissionDenied => _PermissionDeniedView(
          onOpenSettings: openAppSettings,
          onBack: () => setState(() => _state = _SheetState.menu),
        ),
    };

    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          // Positive delta = finger moving down = scrub the route toward
          // dismissed, 1:1 with the sheet's own height.
          final height = context.size?.height ?? 320;
          widget.route.dragBy((details.primaryDelta ?? 0) / height);
        },
        onVerticalDragEnd: (details) =>
            widget.route.endDrag(details.primaryVelocity ?? 0, context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: reduceTransparency
                  ? ImageFilter.blur(sigmaX: 0, sigmaY: 0)
                  : ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.only(bottom: safeBottom > 0 ? 4 : 12),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.7),
                    width: 0.8,
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 4),
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border(context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: KeyedSubtree(
                          key: ValueKey(_state),
                          child: body,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuView extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onPhotos;
  final VoidCallback onFiles;

  const _MenuView({
    required this.onCamera,
    required this.onPhotos,
    required this.onFiles,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            context.tr('import_sheet_explainer'),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
              height: 1.35,
            ),
          ),
        ),
        _SheetRow(
          icon: CupertinoIcons.camera,
          label: context.tr('import_source_camera'),
          onTap: onCamera,
        ),
        _SheetRow(
          icon: CupertinoIcons.photo_on_rectangle,
          label: context.tr('import_source_photos'),
          onTap: onPhotos,
        ),
        _SheetRow(
          icon: CupertinoIcons.doc,
          label: context.tr('import_source_files'),
          onTap: onFiles,
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Icon(
                icon,
                size: 24,
                color: AppColors.accentColor(context),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16.5,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcessingView extends StatelessWidget {
  final VoidCallback onCancel;

  const _ProcessingView({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(radius: 13),
          const SizedBox(height: 12),
          Text(
            context.tr('import_processing'),
            style: TextStyle(
              fontSize: 14.5,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 14),
          AppOutlineButton(
            text: context.tr('cancel'),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final bool canRetry;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ErrorView({
    required this.message,
    required this.canRetry,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle,
            size: 30,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary(context),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (canRetry)
            AppButton(text: context.tr('import_retry'), onPressed: onRetry),
          const SizedBox(height: 8),
          AppOutlineButton(
            text: context.tr('import_pick_other'),
            onPressed: onBack,
          ),
        ],
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onBack;

  const _PermissionDeniedView({
    required this.onOpenSettings,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.camera,
            size: 30,
            color: AppColors.textSecondary(context),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('camera_permission_denied'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary(context),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          AppButton(
            text: context.tr('open_settings'),
            onPressed: onOpenSettings,
          ),
          const SizedBox(height: 8),
          AppOutlineButton(text: context.tr('back'), onPressed: onBack),
        ],
      ),
    );
  }
}
