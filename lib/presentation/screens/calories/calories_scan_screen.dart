import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/native/barcode_scanner_channel.dart';
import 'package:shoply/data/services/native/native_channel_errors.dart';
import 'package:shoply/data/services/open_food_facts_service.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_amount_food.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_barcode.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_camera_chrome.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_flow_scaffold.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/routes/route_paths.dart';

enum _Phase {
  /// The camera opens (or is open) over this page.
  camera,

  /// A code is being looked up.
  searching,

  /// The digit field (no scanner, camera not allowed, "Nummer eingeben").
  field,
  notFound,

  /// Offline and the code is not on this device.
  offline,

  /// Open Food Facts could not be reached.
  failed,
}

/// S6 "Barcode-Kamera" (`/calories/scan`, `?meal=`, `?date=`). The camera
/// itself is native (VisionKit over `shoply/scanner`: frame, flashlight,
/// "Nummer eingeben", the snap onto the code); this page asks for the
/// camera first, looks the code up (own foods, this device, Open Food
/// Facts) and replaces itself with S7. Unknown codes offer "Manuell
/// eintragen" with the barcode; no scanner or no camera permission lead
/// straight to the digit field.
class CaloriesScanScreen extends ConsumerStatefulWidget {
  const CaloriesScanScreen({super.key, this.meal, this.dateKey});

  final MealType? meal;
  final String? dateKey;

  @override
  ConsumerState<CaloriesScanScreen> createState() => _CaloriesScanScreenState();
}

class _CaloriesScanScreenState extends ConsumerState<CaloriesScanScreen> {
  _Phase _phase = _Phase.camera;
  String? _code;
  bool _unsupported = false;
  bool _denied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  CalorieCamera get _camera => ref.read(calorieCameraProvider);

  Future<void> _start() async {
    if (!mounted) return;
    if (!await _camera.scannerSupported()) {
      if (!mounted) return;
      setState(() {
        _unsupported = true;
        _phase = _Phase.field;
      });
      return;
    }
    var permission = await _camera.permission();
    if (!mounted) return;
    if (permission == CameraPermission.notDetermined) {
      final go = await showAvoConfirm(
        context,
        title: context.tr('cal_scan_pre_title'),
        message: context.tr('cal_scan_pre_body'),
        confirmLabel: context.tr('cal_continue'),
        cancelLabel: context.tr('cal_not_now'),
        destructive: false,
      );
      if (!mounted) return;
      if (!go) {
        CalorieFlowScaffold.leave(context);
        return;
      }
      permission = await _camera.requestAccess() ? CameraPermission.authorized : CameraPermission.denied;
      if (!mounted) return;
    }
    if (permission != CameraPermission.authorized) {
      setState(() {
        _denied = true;
        _phase = _Phase.field;
      });
      return;
    }
    await _scan();
  }

  Future<void> _scan() async {
    setState(() => _phase = _Phase.camera);
    final BarcodeScanResult result;
    try {
      result = await _camera.scan(BarcodeScannerLabels(
        hint: context.tr('cal_scan_hint'),
        manualEntry: context.tr('cal_barcode_enter'),
        close: context.tr('back'),
        torch: context.tr('cal_flashlight'),
        torchOn: context.tr('cal_state_on'),
        torchOff: context.tr('cal_state_off'),
      ));
    } on NativeChannelException catch (e) {
      if (!mounted) return;
      setState(() {
        _denied = e.code == NativeErrorCode.permissionDenied;
        _phase = _Phase.field;
      });
      return;
    }
    if (!mounted) return;
    switch (result.status) {
      case BarcodeScanStatus.scanned:
        await _lookup(result.code!);
      case BarcodeScanStatus.manualEntry:
        setState(() => _phase = _Phase.field);
      case BarcodeScanStatus.unavailable:
        setState(() {
        _unsupported = true;
        _phase = _Phase.field;
      });
      case BarcodeScanStatus.cancelled:
        CalorieFlowScaffold.leave(context);
    }
  }

  Map<String, String> get _params => {
        if (widget.meal case final m?) 'meal': m.dbValue,
        if (widget.dateKey case final d?) 'date': d,
      };

  Future<void> _lookup(String code) async {
    setState(() {
      _phase = _Phase.searching;
      _code = code;
    });
    try {
      final product = await ref.read(calorieBarcodeLookupProvider)(code);
      if (!mounted) return;
      if (product == null) {
        setState(() => _phase = _Phase.notFound);
        return;
      }
      context.pushReplacement(
        Uri(path: '${RoutePaths.calories}/add/food/$code', queryParameters: _params.isEmpty ? null : _params).toString(),
        extra: CalorieAmountFood.fromProduct(product, origin: FoodEntryOrigin.barcode),
      );
    } on OffRequestFailed catch (e) {
      if (mounted) setState(() => _phase = e.reason == 'offline' ? _Phase.offline : _Phase.failed);
    }
  }

  void _manual() => context.pushReplacement(Uri(
        path: '${RoutePaths.calories}/add/manual',
        queryParameters: {..._params, if (_code case final c?) 'barcode': c},
      ).toString());

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.camera || _phase == _Phase.searching) {
      final code = _code;
      return CameraBackdrop(
        child: Stack(
          children: [
            Positioned(
              top: GlassToolbar.topOffset(context),
              left: AvoSpacing.screen,
              child: GlassIconButton(
                icon: const AvoIcon(AvoIcons.chevronBack),
                semanticLabel: context.tr('back'),
                onPressed: () => CalorieFlowScaffold.leave(context),
              ),
            ),
            if (_phase == _Phase.searching && code != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
                  child: CameraHintCapsule(text: context.tr('cal_scan_searching', params: {'code': formatGtin(code)})),
                ),
              ),
          ],
        ),
      );
    }

    final code = _code;
    final canScan = !_unsupported && !_denied;
    final Widget? status = switch (_phase) {
      _Phase.notFound => StatusRow(kind: StatusKind.sectionError, text: context.tr('cal_scan_not_found')),
      _Phase.offline => StatusRow(kind: StatusKind.offline, text: context.tr('cal_scan_offline')),
      _Phase.failed => StatusRow(
          kind: StatusKind.sectionError,
          text: context.tr('cal_search_error'),
          actionLabel: context.tr('retry'),
          onAction: code == null ? null : () => _lookup(code),
        ),
      _ when _denied => StatusRow(kind: StatusKind.permission, text: context.tr('cal_camera_denied')),
      _ => null,
    };

    return CalorieFlowScaffold(
      leading: CalorieFlowLeading.back,
      title: CalorieFlowTitle(context.tr('cal_seg_barcode')),
      children: [
        if (status != null) ...[status, const SizedBox(height: AvoSpacing.s)],
        if (code != null && _phase != _Phase.field)
          Padding(
            padding: const EdgeInsets.fromLTRB(AvoSpacing.screen + AvoSpacing.l, 0, AvoSpacing.screen, AvoSpacing.s),
            child: Text(formatGtin(code), style: context.text(AvoTextStyle.title3, tabular: true)),
          ),
        InsetSection(
          footer: _unsupported ? context.tr('cal_barcode_unsupported') : null,
          children: [
            CalorieBarcodeField(autofocus: _phase == _Phase.field, onSubmit: _lookup),
          ],
        ),
        if (_phase == _Phase.notFound || _phase == _Phase.offline) ...[
          const SizedBox(height: AvoSpacing.section),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: AppButton.primary(label: context.tr('cal_manual_row'), expand: true, onPressed: _manual),
          ),
        ],
        if (canScan && _phase != _Phase.searching) ...[
          const SizedBox(height: AvoSpacing.m),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: AppButton.secondary(label: context.tr('cal_scan_again'), expand: true, onPressed: _scan),
          ),
        ],
      ],
    );
  }
}
