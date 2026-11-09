import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/food_log_entry.dart';
import 'package:shoply/data/services/native/barcode_scanner_channel.dart';
import 'package:shoply/data/services/native/meal_camera_channel.dart';
import 'package:shoply/data/services/native/native_channel_errors.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_camera_chrome.dart';
import 'package:shoply/presentation/screens/calories/widgets/calorie_flow_scaffold.dart';
import 'package:shoply/presentation/state/calorie_entry_provider.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/confirm_dialog.dart';
import 'package:shoply/presentation/widgets/design/glass_icon_button.dart';
import 'package:shoply/presentation/widgets/design/glass_toolbar.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/route_paths.dart';

/// Asks "Kamera für Essensfotos" before the system question, once (S3 and
/// S4). True when the camera may be used now.
Future<bool> ensureMealCameraAccess(BuildContext context, CalorieCamera camera) async {
  final permission = await camera.permission();
  if (permission == CameraPermission.authorized) return true;
  if (permission != CameraPermission.notDetermined || !context.mounted) return false;
  final go = await showAvoConfirm(
    context,
    title: context.tr('cal_cam_pre_title'),
    message: context.tr('cal_cam_pre_body'),
    confirmLabel: context.tr('cal_continue'),
    cancelLabel: context.tr('cal_not_now'),
    destructive: false,
  );
  if (!go) return false;
  return camera.requestAccess();
}

/// Opens S5 for [photo] in place of the current screen ([replace], S4) or
/// on top of it (S3 "Aus Fotos wählen").
void openMealEstimate(BuildContext context, Uint8List photo, {MealType? meal, String? dateKey, bool replace = false}) {
  final location = Uri(
    path: '${RoutePaths.calories}/add/estimate',
    queryParameters: {
      if (meal != null) 'meal': meal.dbValue,
      if (dateKey != null) 'date': dateKey,
    },
  ).toString();
  if (replace) {
    context.pushReplacement(location, extra: photo);
  } else {
    unawaited(context.push(location, extra: photo));
  }
}

/// "Die Fotoauswahl hat nicht geklappt." as a toast (S3, S4).
void showPhotoPickFailed(BuildContext context) {
  unawaited(AvoHaptics.error());
  AvoToast.show(context, message: context.tr('cal_photo_pick_failed'));
}

enum _Phase { camera, denied, noCamera, failed }

/// S4 "Foto aufnehmen" (`/calories/add/photo`, `?meal=`, `?date=`). The
/// camera is native (`shoply/camera`: black, back and flash, the hint on a
/// dark capsule, the shutter, "Aus Fotos"); this page asks for the camera
/// first and hands the photo to S5, which replaces it. Camera not allowed:
/// a status line and "Aus Fotos wählen".
class CaloriesPhotoScreen extends ConsumerStatefulWidget {
  const CaloriesPhotoScreen({super.key, this.meal, this.dateKey});

  final MealType? meal;
  final String? dateKey;

  @override
  ConsumerState<CaloriesPhotoScreen> createState() => _CaloriesPhotoScreenState();
}

class _CaloriesPhotoScreenState extends ConsumerState<CaloriesPhotoScreen> {
  _Phase _phase = _Phase.camera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  CalorieCamera get _camera => ref.read(calorieCameraProvider);

  Future<void> _start() async {
    if (!mounted) return;
    if (!await _camera.cameraAvailable()) {
      if (mounted) setState(() => _phase = _Phase.noCamera);
      return;
    }
    if (!mounted) return;
    final permission = await _camera.permission();
    if (!mounted) return;
    if (permission == CameraPermission.notDetermined) {
      final allowed = await ensureMealCameraAccess(context, _camera);
      if (!mounted) return;
      if (!allowed) {
        // "Nicht jetzt" goes back; a refusal in the system question shows why.
        if (await _camera.permission() == CameraPermission.notDetermined) {
          if (mounted) CalorieFlowScaffold.leave(context);
          return;
        }
        if (mounted) setState(() => _phase = _Phase.denied);
        return;
      }
    } else if (permission != CameraPermission.authorized) {
      setState(() => _phase = _Phase.denied);
      return;
    }
    await _take();
  }

  Future<void> _take() async {
    final MealPhotoResult result;
    try {
      result = await _camera.takePhoto(MealCameraLabels(
        hint: context.tr('cal_camera_hint'),
        hintShort: context.tr('cal_camera_hint_short'),
        back: context.tr('back'),
        flash: context.tr('cal_flash'),
        flashOn: context.tr('cal_state_on'),
        flashOff: context.tr('cal_state_off'),
        shutter: context.tr('cal_shutter'),
        library: context.tr('cal_from_photos'),
      ));
    } on NativeChannelException catch (e) {
      if (!mounted) return;
      // "busy": a camera is already open (it answers there).
      if (e.code == NativeErrorCode.busy) return;
      setState(() => _phase = e.code == NativeErrorCode.permissionDenied ? _Phase.denied : _Phase.failed);
      return;
    }
    if (!mounted) return;
    _handle(result);
  }

  Future<void> _pick() async {
    final MealPhotoResult result;
    try {
      result = await _camera.pickPhoto();
    } on NativeChannelException catch (e) {
      if (mounted && e.code != NativeErrorCode.busy) showPhotoPickFailed(context);
      return;
    }
    if (!mounted || !result.hasPhoto) return;
    _handle(result);
  }

  void _handle(MealPhotoResult result) {
    final photo = result.bytes;
    if (result.hasPhoto && photo != null) {
      openMealEstimate(context, photo, meal: widget.meal, dateKey: widget.dateKey, replace: true);
    } else if (result.status == MealPhotoStatus.unavailable) {
      setState(() => _phase = _Phase.noCamera);
    } else if (_phase == _Phase.camera) {
      CalorieFlowScaffold.leave(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.camera) {
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
          ],
        ),
      );
    }
    return CalorieFlowScaffold(
      leading: CalorieFlowLeading.back,
      title: CalorieFlowTitle(context.tr('cal_photo_take')),
      bottom: AppButton.primary(
        label: context.tr('cal_photo_pick'),
        size: AppButtonSize.large,
        expand: true,
        floating: true,
        onPressed: _pick,
      ),
      children: [
        StatusRow(
          kind: StatusKind.permission,
          text: context.tr(switch (_phase) {
            _Phase.denied => 'cal_camera_denied',
            _Phase.failed => 'cal_camera_failed',
            _ => 'cal_camera_missing',
          }),
        ),
      ],
    );
  }
}
