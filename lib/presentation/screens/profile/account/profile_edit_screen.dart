import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/profile/account/account_backend.dart';
import 'package:shoply/presentation/screens/profile/account/account_screen.dart';
import 'package:shoply/presentation/screens/profile/account/account_search.dart';
import 'package:shoply/presentation/screens/profile/account/account_widgets.dart';
import 'package:shoply/presentation/screens/profile/account/profile_edit_controller.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/row_highlight.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';
import 'package:shoply/presentation/widgets/design/undo_toast.dart';
import 'package:shoply/routes/route_paths.dart';

/// Undo window of "Foto entfernt" (Konzept 00 §12.28: 4 s, 10 s with
/// VoiceOver).
const Duration _kUndo = Duration(seconds: 4);
const Duration _kUndoVoiceOver = Duration(seconds: 10);

/// The symbol before the field error, next to 13 pt text.
const double _kErrorSymbol = 14;

/// The sync sign behind the name field.
const double _kSyncSymbol = 17;

/// Vertical padding of the name and email rows: with 22 pt text they reach
/// the 52 pt row height of D2.
const double _kFieldVertical = 15; // D2

/// Profil bearbeiten (`/settings/profile`, Konzept 18 §4): avatar with the
/// pull-down menu Foto auswählen / aufnehmen / entfernen (with undo), the
/// name (taken over on Return and when leaving the page, 2 to 40
/// characters) and the email, read only, with a link to Konto. No save
/// button. The constructor is the contract with the router;
/// [highlightRowId] highlights a row once (`?row=`, ids in
/// [ProfileEditRows]).
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key, this.highlightRowId});

  /// Row to highlight once (`?row=`), see `RowHighlightScope`.
  final String? highlightRowId;

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final GlobalKey _avatarKey = GlobalKey(debugLabel: 'profileAvatar');
  final FocusNode _focus = FocusNode();
  late final ProfileEditController _controller;
  late final TextEditingController _name;
  late final AppLifecycleListener _lifecycle;

  /// The profile as last built; read in [dispose], where `ref` is gone.
  AccountProfile _profile = const AccountProfile();

  /// Shows the toast after the page is gone (the root navigator survives).
  BuildContext? _toastContext;
  String _notChangedText = '';
  bool _tickerActive = true;
  bool _nameError = false;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(profileEditControllerProvider.notifier);
    _profile = ref.read(accountProfileProvider);
    _name = TextEditingController(text: _currentName ?? '');
    _focus.addListener(_focusChanged);
    _lifecycle = AppLifecycleListener(onHide: _commitIfValid);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _toastContext = Navigator.maybeOf(context, rootNavigator: true)?.context;
    _notChangedText = context.tr('acct_name_not_changed');
    // An inactive tab stops its tickers: the page was left by a tab switch.
    final active = TickerMode.valuesOf(context).enabled;
    if (_tickerActive && !active) {
      // Not during the build: taking the name over notifies providers.
      scheduleMicrotask(() {
        if (!mounted) return;
        _leave();
        _focus.unfocus();
      });
    }
    _tickerActive = active;
  }

  @override
  void dispose() {
    // Left without back or a tab switch (the route was removed): a valid
    // name still counts. After the frame, the tree is being torn down now.
    if (!_unchanged) {
      final controller = _controller;
      final text = _name.text;
      scheduleMicrotask(() {
        try {
          controller.commitName(text);
        } catch (e) {
          // The app (or test) is gone with its providers.
          debugPrint('[ACCOUNT] name not taken over: ${e.runtimeType}');
        }
      });
    }
    _lifecycle.dispose();
    _focus
      ..removeListener(_focusChanged)
      ..dispose();
    _name.dispose();
    super.dispose();
  }

  String? get _currentName => _controller.displayName(_profile);

  /// Nothing to take over: the text is the current name, or both are empty.
  bool get _unchanged {
    final text = _name.text.trim();
    return text == (_currentName?.trim() ?? '');
  }

  void _focusChanged() {
    if (_focus.hasFocus || _unchanged) return;
    if (!_controller.commitName(_name.text)) {
      setState(() => _nameError = true);
    }
  }

  void _commitIfValid() {
    if (!_unchanged) _controller.commitName(_name.text);
  }

  void _submitted(String _) {
    if (_unchanged || _controller.commitName(_name.text)) {
      _focus.unfocus();
      return;
    }
    setState(() => _nameError = true);
    AvoHaptics.error();
    _focus.requestFocus();
  }

  /// Leaving the page (back, swipe, tab switch): a valid name is taken
  /// over; an invalid one keeps the old name and says so (Konzept 18 §4.3).
  void _leave() {
    if (_unchanged || _controller.commitName(_name.text)) return;
    _name.text = _currentName ?? '';
    if (mounted) setState(() => _nameError = false);
    final toastContext = _toastContext;
    if (toastContext != null && toastContext.mounted) {
      AvoToast.show(toastContext, message: _notChangedText);
    }
  }

  void _changed(String value) {
    if (_nameError && isValidDisplayName(value)) {
      setState(() => _nameError = false);
    }
  }

  Future<void> _openMenu() async {
    final access = await ref.read(cameraAccessProvider)();
    if (!mounted) return;
    final state = ref.read(profileEditControllerProvider);
    final profile = ref.read(accountProfileProvider);
    final hasPhoto =
        !state.removed &&
        (state.localPhoto != null || (profile.avatarUrl ?? '').isNotEmpty);
    await showAvoMenu(
      context,
      anchorKey: _avatarKey,
      semanticLabel: context.tr('acct_photo_change'),
      items: [
        AvoMenuItem(
          label: context.tr('acct_photo_choose'),
          icon: AvoIcons.photo,
          onSelected: () => _pick(PhotoSource.library),
        ),
        AvoMenuItem(
          label: context.tr('acct_photo_take'),
          icon: AvoIcons.camera,
          subtitle: access == CameraAccess.notAsked
              ? context.tr('acct_photo_take_hint')
              : null,
          onSelected: () => _pick(PhotoSource.camera),
        ),
        if (hasPhoto && !state.uploading) ...[
          const AvoMenuDivider(),
          AvoMenuItem(
            label: context.tr('acct_photo_remove'),
            icon: AvoIcons.trash,
            destructive: true,
            onSelected: _removePhoto,
          ),
        ],
      ],
    );
  }

  Future<void> _pick(PhotoSource source) async {
    final PickedPhoto? photo;
    try {
      photo = await ref.read(photoPickerProvider)(source);
    } on PlatformException catch (e) {
      debugPrint('[ACCOUNT] photo not picked: ${e.code}');
      if (e.code == 'camera_access_denied') {
        _controller.setCameraDenied(true);
      } else if (mounted) {
        AvoToast.show(context, message: context.tr('action_failed'));
      }
      AvoHaptics.error();
      return;
    } catch (e) {
      debugPrint('[ACCOUNT] photo not picked: ${e.runtimeType}');
      AvoHaptics.error();
      if (mounted) {
        AvoToast.show(context, message: context.tr('action_failed'));
      }
      return;
    }
    if (photo == null) return;
    if (source == PhotoSource.camera) _controller.setCameraDenied(false);
    await _controller.setPhoto(photo);
  }

  void _removePhoto() {
    final window = MediaQuery.accessibleNavigationOf(context)
        ? _kUndoVoiceOver
        : _kUndo;
    _controller.removePhoto(window);
    AvoToast.show(
      context,
      message: context.tr('acct_photo_removed'),
      actionLabel: context.tr('common_undo'),
      onAction: _controller.undoRemove,
      duration: window,
    );
  }

  void _openAccount() => pushAccountPage<void>(
    context,
    RoutePaths.settingsAccount,
    (_) => const AccountScreen(),
  );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileEditControllerProvider);
    final profile = ref.watch(accountProfileProvider);
    _profile = profile;
    final identity = ref.watch(accountIdentityProvider);
    final name = state.savedName ?? profile.displayName ?? '';

    ref.listen<ProfileEditState>(profileEditControllerProvider, (prev, next) {
      final failedNow =
          (next.uploadFailed && !(prev?.uploadFailed ?? false)) ||
          (next.removeFailed && !(prev?.removeFailed ?? false));
      if (failedNow) AvoHaptics.error();
    });
    // A name taken over elsewhere (Avo) shows up while the field is idle.
    ref.listen<AccountProfile>(accountProfileProvider, (prev, next) {
      final shown = _controller.displayName(next) ?? '';
      if (!_focus.hasFocus && _name.text != shown) _name.text = shown;
    });

    final Widget? status;
    if (state.uploadFailed) {
      status = StatusRow(
        kind: StatusKind.failed,
        text: context.tr('acct_photo_upload_failed'),
        actionLabel: context.tr('common_try_again'),
        onAction: _controller.retryUpload,
      );
    } else if (state.removeFailed) {
      status = StatusRow(
        kind: StatusKind.failed,
        text: context.tr('acct_photo_remove_failed'),
        actionLabel: context.tr('common_try_again'),
        onAction: _removePhoto,
      );
    } else if (state.cameraDenied) {
      status = StatusRow(
        kind: StatusKind.permission,
        text: context.tr('acct_camera_off'),
        actionLabel: context.tr('acct_allow_in_settings'),
        onAction: () => ref.read(openAppSettingsProvider)(),
      );
    } else {
      status = null;
    }

    final avatar = Semantics(
      image: true,
      label: context.tr('acct_photo_label'),
      value: state.uploading ? context.tr('acct_photo_uploading') : null,
      child: GestureDetector(
        key: _avatarKey,
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: _openMenu,
        child: ProfilePhotoAvatar(
          name: name,
          photo: state.removed ? null : state.localPhoto,
          url: state.removed ? null : profile.avatarUrl,
          syncing: state.uploading,
        ),
      ),
    );

    final page = FullScreenEditor(
      title: context.tr('acct_edit_title'),
      leading: EditorLeading.back,
      leadingLabel: context.tr(
        'common_back_to',
        params: {'title': context.tr('common_tab_profile')},
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          HighlightableRow(
            id: ProfileEditRows.photo,
            child: Padding(
              padding: const EdgeInsets.only(top: AvoSpacing.s),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  avatar,
                  const SizedBox(height: AvoSpacing.xs),
                  AppButton.plain(
                    label: context.tr('acct_photo_change'),
                    onPressed: _openMenu,
                  ),
                ],
              ),
            ),
          ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.only(top: AvoSpacing.s),
              child: status,
            ),
          InsetSection(
            header: context.tr('acct_name_section'),
            footer: context.tr('acct_name_footer'),
            children: [
              HighlightableRow(
                id: ProfileEditRows.name,
                child: _NameField(
                  controller: _name,
                  focusNode: _focus,
                  error: _nameError,
                  waiting: state.nameWaiting,
                  onChanged: _changed,
                  onSubmitted: _submitted,
                ),
              ),
            ],
          ),
          if (identity != null) ...[
            InsetSection(
              header: context.tr('acct_email_section'),
              children: [
                HighlightableRow(
                  id: ProfileEditRows.email,
                  child: _EmailRow(email: identity.email),
                ),
              ],
            ),
            _EmailFooter(onAccount: _openAccount),
          ],
        ],
      ),
    );

    return RowHighlightScope(
      rowId: widget.highlightRowId,
      child: PopScope<Object?>(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) _leave();
        },
        child: page,
      ),
    );
  }
}

/// The name row: a plain field on the white group with the clear button
/// while editing, the field error under it and the sync sign behind it while
/// the name waits for a connection. No fixed height.
class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.waiting,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool error;
  final bool waiting;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.text(AvoTextStyle.body);
    final field = Semantics(
      label: context.tr('acct_name_section'),
      child: CupertinoTextField.borderless(
        controller: controller,
        focusNode: focusNode,
        placeholder: context.tr('acct_name_placeholder'),
        placeholderStyle: style.copyWith(color: colors.placeholder),
        style: style,
        cursorColor: colors.tint,
        padding: EdgeInsets.zero,
        clearButtonMode: OverlayVisibilityMode.editing,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        autofillHints: const [AutofillHints.name],
        inputFormatters: [LengthLimitingTextInputFormatter(kNameMaxLength)],
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AvoSpacing.l,
        vertical: _kFieldVertical,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: field),
              if (waiting) ...[
                const SizedBox(width: AvoSpacing.s),
                Semantics(
                  label: context.tr('acct_name_waiting'),
                  child: AvoIcon(
                    AvoIcons.sync,
                    size: _kSyncSymbol,
                    color: colors.secondaryLabel,
                  ),
                ),
              ],
            ],
          ),
          if (error)
            Padding(
              padding: const EdgeInsets.only(top: AvoSpacing.xs),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: AvoSpacing.xxs),
                      child: AvoIcon(
                        AvoIcons.exclamationmarkCircle,
                        size: _kErrorSymbol,
                        color: colors.destructive,
                      ),
                    ),
                    const SizedBox(width: AvoSpacing.xs),
                    Expanded(
                      child: Text(
                        context.tr('acct_name_too_short'),
                        style: context.text(
                          AvoTextStyle.footnote,
                          color: colors.destructive,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The email as plain text (not editable).
class _EmailRow extends StatelessWidget {
  const _EmailRow({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: context.tr('acct_email_section'),
      value: email,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: _kFieldVertical,
        ),
        child: Text(
          breakableEmail(email),
          style: context.text(AvoTextStyle.body),
        ),
      ),
    );
  }
}

/// "Ändern kannst du sie unter Konto." with the plain link "Konto".
class _EmailFooter extends StatelessWidget {
  const _EmailFooter({required this.onAccount});

  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AvoSpacing.xxxl,
        AvoSpacing.s,
        AvoSpacing.xxxl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('acct_email_footer'),
            style: context.text(
              AvoTextStyle.footnote,
              color: colors.secondaryLabel,
            ),
          ),
          AppButton.plain(
            label: context.tr('acct_title'),
            onPressed: onAccount,
          ),
        ],
      ),
    );
  }
}
