import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/app_translations.dart';
import 'package:shoply/core/utils/item_input_parser.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/data/services/list_import_service.dart';
import 'package:shoply/presentation/screens/lists/widgets/import_review_sheet.dart';
import 'package:shoply/presentation/screens/lists/widgets/import_status_capsule.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/avo_menu.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// Reading a note takes longer than this: "Dauert etwas länger …"
/// (Konzept 11 §3.2). A display time, not an animation duration.
const Duration _slowAfter = Duration(seconds: 8);

/// How long a problem stays in the capsule before the field comes back
/// (Konzept 11 §3.2). A display time, not an animation duration.
const Duration _messageFor = Duration(seconds: 6);

/// Where the items of an import come from.
enum ListImportSource {
  /// Take a photo of the note.
  camera,

  /// Pick a photo or screenshot.
  photos,

  /// Pick an image or PDF from Files.
  files,

  /// Paste text from the clipboard.
  paste,
}

/// A picked picture.
@immutable
class ImportPick {
  /// Creates a pick of [bytes].
  const ImportPick(this.bytes, {this.isPdf = false});

  /// The image or PDF.
  final Uint8List bytes;

  /// Whether [bytes] is a PDF.
  final bool isPdf;
}

/// The camera is not allowed.
class ImportPermissionDenied implements Exception {
  /// Creates the exception.
  const ImportPermissionDenied();
}

/// Everything the import needs from the device and from Avo; overridden in
/// tests through [listImportPortProvider].
class ListImportPort {
  /// Creates the port of the app.
  const ListImportPort();

  /// Lets the person pick a picture; null when they cancel. Throws
  /// [ImportPermissionDenied] when the camera is not allowed.
  Future<ImportPick?> pick(ListImportSource source) async {
    switch (source) {
      case ListImportSource.camera:
        try {
          final file = await ImagePicker().pickImage(
            source: ImageSource.camera,
            imageQuality: 92,
          );
          return file == null ? null : ImportPick(await file.readAsBytes());
        } on PlatformException catch (e) {
          if (e.code == 'camera_access_denied') {
            throw const ImportPermissionDenied();
          }
          rethrow;
        }
      case ListImportSource.photos:
        // PHPicker: no permission prompt on iOS 14 and later.
        final file = await ImagePicker().pickImage(source: ImageSource.gallery);
        return file == null ? null : ImportPick(await file.readAsBytes());
      case ListImportSource.files:
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const [
            'jpg',
            'jpeg',
            'png',
            'heic',
            'webp',
            'pdf',
          ],
          withData: true,
        );
        final file = result?.files.firstOrNull;
        final bytes = file?.bytes;
        if (file == null || bytes == null) return null;
        return ImportPick(bytes, isPdf: file.extension?.toLowerCase() == 'pdf');
      case ListImportSource.paste:
        return null;
    }
  }

  /// The text on the clipboard, if any.
  Future<String?> readClipboard() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;

  /// Lets Avo read [pick] (Teil B's service).
  Future<ListImportResult> read(ImportPick pick, CancelToken cancelToken) =>
      ListImportService.instance.importFromBytes(
        pick.bytes,
        isPdf: pick.isPdf,
        cancelToken: cancelToken,
      );

  /// Opens the app's page in Settings (camera permission).
  Future<void> openSettings() async {
    await openAppSettings();
  }
}

/// The [ListImportPort] in use.
final listImportPortProvider = Provider<ListImportPort>(
  (ref) => const ListImportPort(),
);

/// "Zettel importieren" (Konzept 11 §3): a pull-down menu from
/// [plusButtonKey] with "Foto aufnehmen", "Foto wählen", "Datei wählen" and
/// "Text einfügen"; while Avo reads the note a glass status capsule floats
/// where the add field is ("Zettel wird gelesen …", "Abbrechen"), the list
/// stays usable. Problems stay in the capsule with an action ("Anderes
/// Bild", "Erneut versuchen") for a few seconds.
///
/// Resolves with what was recognized, or null when the person cancelled or
/// gave up. No bottom sheet. The signature of the old sheet is kept; review
/// the result with [showImportReviewSheet], or use [openListImport] for the
/// whole flow.
Future<ListImportResult?> showAttachmentSheet(
  BuildContext context, {
  required GlobalKey plusButtonKey,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return _ImportRun(context, plusButtonKey).run();
}

/// The whole import for list [listId]: menu from [anchorKey], reading,
/// review full screen, adding in one batch with "Widerrufen".
Future<void> openListImport(
  BuildContext context, {
  required String listId,
  required GlobalKey anchorKey,
}) async {
  final result = await showAttachmentSheet(context, plusButtonKey: anchorKey);
  if (result == null || !context.mounted) return;
  await showImportReviewSheet(context, result: result, listId: listId);
}

enum _Next { menu, retry, done }

/// One import run: menu, picking, reading and its capsule.
class _ImportRun {
  _ImportRun(this.context, this.anchorKey)
    : overlay = Overlay.of(context, rootOverlay: true),
      lang = Localizations.localeOf(context).languageCode,
      _container = _containerOf(context);

  final BuildContext context;
  final GlobalKey anchorKey;
  final OverlayState overlay;
  final String lang;
  final ProviderContainer? _container;
  late final ImportStatusCapsule _capsule = ImportStatusCapsule(overlay);

  static ProviderContainer? _containerOf(BuildContext context) {
    try {
      return ProviderScope.containerOf(context, listen: false);
    } catch (_) {
      return null; // No ProviderScope (isolated widget): app defaults.
    }
  }

  ListImportPort get _port =>
      _container?.read(listImportPortProvider) ?? const ListImportPort();

  bool get _offline => _container?.read(isOfflineProvider) ?? false;

  String _t(String key, [Map<String, String>? params]) =>
      AppTranslations.get(key, lang, params: params);

  Future<ListImportResult?> run() async {
    try {
      var source = await _choose();
      while (source != null) {
        final (result, next) = await _from(source);
        if (result != null) return result;
        if (next != _Next.menu) return null;
        source = await _choose();
      }
      return null;
    } finally {
      _capsule.dispose();
    }
  }

  /// The menu; null when it was closed without a choice.
  Future<ListImportSource?> _choose() async {
    final anchor = anchorKey.currentContext;
    final menuContext = anchor != null && anchor.mounted
        ? anchor
        : (context.mounted ? context : null);
    if (menuContext == null) return null;
    final offline = _offline;
    final needsConnection = offline ? _t('common_needs_connection') : null;
    ListImportSource? chosen;
    AvoMenuItem picture(
      ListImportSource source,
      String key,
      AvoIconData icon,
    ) => AvoMenuItem(
      label: _t(key),
      icon: icon,
      subtitle: needsConnection,
      enabled: !offline,
      onSelected: () => chosen = source,
    );
    await showAvoMenu(
      menuContext,
      anchorKey: anchor != null ? anchorKey : null,
      semanticLabel: _t('list_item_import_menu'),
      items: [
        picture(
          ListImportSource.camera,
          'list_item_import_take_photo',
          _ImportIcons.camera,
        ),
        picture(
          ListImportSource.photos,
          'list_item_import_choose_photo',
          _ImportIcons.photo,
        ),
        picture(
          ListImportSource.files,
          'list_item_import_choose_file',
          _ImportIcons.folder,
        ),
        const AvoMenuDivider(),
        AvoMenuItem(
          label: _t('list_item_import_paste_text'),
          icon: _ImportIcons.paste,
          onSelected: () => chosen = ListImportSource.paste,
        ),
      ],
    );
    return chosen;
  }

  Future<(ListImportResult?, _Next)> _from(ListImportSource source) async {
    if (source == ListImportSource.paste) return _fromClipboard();

    final ImportPick? pick;
    try {
      pick = await _port.pick(source);
    } on ImportPermissionDenied {
      final next = await _problem(
        StatusKind.permission,
        _t('list_item_import_camera_off'),
        actionLabel: _t('list_item_import_allow_in_settings'),
        onAction: () => unawaited(_port.openSettings()),
      );
      return (null, next);
    } catch (e) {
      // Any picker failure ends in a state with an action, never a hang.
      debugPrint('❌ [LIST_IMPORT] Picking failed: $e');
      final next = await _problem(
        StatusKind.sectionError,
        _t('list_item_import_unreadable'),
        actionLabel: _t('list_item_import_other_picture'),
        next: _Next.menu,
      );
      return (null, next);
    }
    if (pick == null) return (null, _Next.done);
    return _read(pick);
  }

  Future<(ListImportResult?, _Next)> _fromClipboard() async {
    String? text;
    try {
      text = await _port.readClipboard();
    } catch (e) {
      debugPrint('⚠️ [LIST_IMPORT] Clipboard not readable: $e');
    }
    if (text == null || text.trim().isEmpty) {
      await _problem(
        StatusKind.sectionError,
        _t('list_item_import_clipboard_empty'),
      );
      return (null, _Next.done);
    }
    final parsed = parseItemInput(text, lang: lang);
    if (parsed.isEmpty) {
      await _problem(
        StatusKind.sectionError,
        _t('list_item_import_text_no_items'),
      );
      return (null, _Next.done);
    }
    final result = ListImportResult(
      items: [
        for (final p in parsed)
          ExtractedListItem(
            // The review has no note field; the note stays visible.
            name: p.note == null ? p.name : '${p.name} (${p.note})',
            quantity: p.quantityGiven ? p.quantity : null,
            unit: p.unit,
          ),
      ],
      unparsedLines: const [],
    );
    markPastedImport(result);
    return (result, _Next.done);
  }

  Future<(ListImportResult?, _Next)> _read(ImportPick pick) async {
    while (true) {
      final token = CancelToken();
      ImportStatus busy(String key) => ImportStatus.busy(
        text: _t(key),
        actionLabel: _t('cancel'),
        onAction: () {
          unawaited(AvoHaptics.light());
          token.cancel();
        },
      );
      _capsule.show(busy('list_item_import_reading'));
      final slow = Timer(_slowAfter, () {
        if (_capsule.current?.busy ?? false) {
          _capsule.show(busy('list_item_import_slow'));
        }
      });
      try {
        final result = await _port.read(pick, token);
        if (token.isCancelled) {
          _capsule.hide();
          return (null, _Next.done);
        }
        _capsule.hide();
        return (result, _Next.done);
      } on ListImportException catch (e) {
        if (e.code == 'cancelled' || token.isCancelled) {
          _capsule.hide();
          return (null, _Next.done);
        }
        final next = await _failure(e.code);
        if (next != _Next.retry) return (null, next);
      } catch (e) {
        debugPrint('❌ [LIST_IMPORT] Reading failed: $e');
        if (token.isCancelled) {
          _capsule.hide();
          return (null, _Next.done);
        }
        final next = await _failure('provider_error');
        if (next != _Next.retry) return (null, next);
      } finally {
        slow.cancel();
      }
    }
  }

  /// The capsule for a failed reading (Konzept 11 §3.2).
  Future<_Next> _failure(String code) {
    unawaited(AvoHaptics.error());
    return switch (code) {
      'no_items_found' => _problem(
        StatusKind.sectionError,
        _t('list_item_import_no_items'),
        actionLabel: _t('list_item_import_other_picture'),
        next: _Next.menu,
      ),
      'unreadable_image' => _problem(
        StatusKind.sectionError,
        _t('list_item_import_unreadable'),
        actionLabel: _t('list_item_import_other_picture'),
        next: _Next.menu,
      ),
      'rate_limited' => _problem(
        StatusKind.sectionError,
        _t('list_item_import_rate_limited'),
      ),
      'not_signed_in' => _problem(
        StatusKind.sectionError,
        _t('list_item_import_signed_out'),
      ),
      _ => _problem(
        StatusKind.failed,
        _t('list_item_import_failed'),
        actionLabel: _t('common_try_again'),
        next: _Next.retry,
      ),
    };
  }

  /// Shows a problem for [_messageFor]; resolves with [next] when its action
  /// is tapped, otherwise with [_Next.done] once it is gone. [onAction]
  /// runs instead of [next] for actions outside the import.
  Future<_Next> _problem(
    StatusKind kind,
    String text, {
    String? actionLabel,
    VoidCallback? onAction,
    _Next next = _Next.done,
  }) async {
    final done = Completer<_Next>();
    final timer = Timer(_messageFor, () {
      if (!done.isCompleted) done.complete(_Next.done);
    });
    _capsule.show(
      ImportStatus.message(
        kind: kind,
        text: text,
        actionLabel: actionLabel,
        onAction: actionLabel == null
            ? null
            : () {
                onAction?.call();
                if (!done.isCompleted) done.complete(next);
              },
      ),
    );
    final result = await done.future;
    timer.cancel();
    _capsule.hide();
    return result;
  }
}

/// Menu glyphs for the import sources. `AvoIcons` has no camera, photo,
/// folder or clipboard yet; drawn on the same 24 grid with round strokes.
abstract final class _ImportIcons {
  static const camera = AvoIconData([
    AvoIconPath(
      'M4 7.5h3l1.6-2.5h6.8L17 7.5h3a1.5 1.5 0 0 1 1.5 1.5v9a1.5 1.5 0 0 1'
      '-1.5 1.5H4A1.5 1.5 0 0 1 2.5 18V9A1.5 1.5 0 0 1 4 7.5z',
    ),
    AvoIconCircle(12, 13, 3.6),
  ]);

  static const photo = AvoIconData([
    AvoIconRect(3, 4.5, 18, 15, radius: 2.5),
    AvoIconCircle(8.5, 9.5, 1.6),
    AvoIconPath('M3.5 17l5-5 4 4 2.5-2.5 5.5 5.5'),
  ]);

  static const folder = AvoIconData([
    AvoIconPath(
      'M3 7.5A1.5 1.5 0 0 1 4.5 6h4.8l2 2h8.2A1.5 1.5 0 0 1 21 9.5v8'
      'a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 17.5z',
    ),
  ]);

  static const paste = AvoIconData([
    AvoIconRect(5, 4.5, 14, 16.5, radius: 2),
    AvoIconPath('M9 3.5h6v3H9zM8.5 11h7M8.5 14.5h7M8.5 18h4'),
  ]);
}
