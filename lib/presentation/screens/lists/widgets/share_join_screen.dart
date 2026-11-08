import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/data/models/shopping_list_model.dart';
import 'package:shoply/data/services/connectivity_service.dart';
import 'package:shoply/presentation/screens/lists/widgets/all_lists_data.dart';
import 'package:shoply/presentation/screens/lists/widgets/list_info_actions.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// Length of a share code (`ListRepository.generateShareCode`).
const int kShareCodeLength = 6;

/// Corner radius of the code field (a capsule on one line).
const double _kFieldRadius = 30;

/// Opens "Liste beitreten" full screen (Konzept 11 §9.4, as a cover instead
/// of a sheet). Completes with the joined list, or with the list the person
/// is already on when they chose "Öffnen"; null when closed.
Future<ShoppingListModel?> openJoinListScreen(
  BuildContext context, {
  String initialCode = '',
}) => pushFullScreenEditor<ShoppingListModel>(
  context,
  (_) => JoinListScreen(initialCode: initialCode),
);

/// Upper-cases a code and drops everything but letters and digits (pasted
/// "482 913" works), at most [kShareCodeLength] characters.
String normalizeShareCode(String input) {
  final cleaned = input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  return cleaned.length > kShareCodeLength
      ? cleaned.substring(0, kShareCodeLength)
      : cleaned;
}

class _CodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = normalizeShareCode(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

enum _JoinProblem { none, notFound, failed }

/// The code field and "Beitreten". The code the person typed is checked
/// against their own lists first ("Du bist schon auf dieser Liste.").
class JoinListScreen extends ConsumerStatefulWidget {
  const JoinListScreen({super.key, this.initialCode = ''});

  final String initialCode;

  @override
  ConsumerState<JoinListScreen> createState() => _JoinListScreenState();
}

class _JoinListScreenState extends ConsumerState<JoinListScreen> {
  late final TextEditingController _code = TextEditingController(
    text: normalizeShareCode(widget.initialCode),
  );
  bool _working = false;
  _JoinProblem _problem = _JoinProblem.none;
  ShoppingListModel? _already;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String get _value => _code.text;

  bool _canJoin(bool offline) =>
      !offline && !_working && _value.length == kShareCodeLength;

  void _changed(String _) => setState(() {
    _problem = _JoinProblem.none;
    _already = null;
  });

  Future<void> _join() async {
    if (!_canJoin(ref.read(isOfflineProvider))) return;
    final code = _value;
    final lists = ref.read(allListsSourceProvider).valueOrNull ?? const [];
    for (final l in lists) {
      if (l.shareCode?.toUpperCase() == code) {
        setState(() => _already = l);
        return;
      }
    }
    setState(() => _working = true);
    try {
      final list = await ref.read(listActionsProvider).joinWithCode(code);
      if (!mounted) return;
      if (list == null) {
        AvoHaptics.error();
        setState(() {
          _working = false;
          _problem = _JoinProblem.notFound;
        });
        return;
      }
      Navigator.of(context).pop(list);
    } catch (e) {
      debugPrint('❌ [JOIN_LIST] Failed to join: $e');
      if (!mounted) return;
      AvoHaptics.error();
      setState(() {
        _working = false;
        _problem = _JoinProblem.failed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final offline = ref.watch(isOfflineProvider);
    final style = context.text(
      AvoTextStyle.title1,
      weight: FontWeight.w600,
      tabular: true,
    );
    final already = _already;

    Widget? status;
    if (offline) {
      status = StatusRow(
        kind: StatusKind.offline,
        text: context.tr('list_ov_join_offline'),
      );
    } else if (already != null) {
      status = Padding(
        padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                context.tr('list_ov_join_already'),
                style: context.text(AvoTextStyle.body),
              ),
            ),
            AppButton.plain(
              label: context.tr('list_ov_open_list'),
              onPressed: () => Navigator.of(context).pop(already),
            ),
          ],
        ),
      );
    } else if (_problem == _JoinProblem.notFound) {
      status = StatusRow(
        kind: StatusKind.failed,
        text: context.tr('list_ov_join_not_found'),
      );
    } else if (_problem == _JoinProblem.failed) {
      status = StatusRow(
        kind: StatusKind.failed,
        text: context.tr('list_ov_join_failed'),
      );
    }

    return FullScreenEditor(
      title: context.tr('list_ov_join_list'),
      bottom: AppButton.primary(
        label: context.tr('list_ov_join_action'),
        size: AppButtonSize.large,
        expand: true,
        working: _working,
        workingLabel: context.tr('list_ov_joining'),
        onPressed: _canJoin(offline) ? _join : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: Text(
              context.tr('list_ov_join_intro'),
              style: context.text(AvoTextStyle.body),
            ),
          ),
          const SizedBox(height: AvoSpacing.l),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
            child: Semantics(
              textField: true,
              label: context.tr('list_ov_code_field'),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.fill,
                  borderRadius: BorderRadius.circular(_kFieldRadius),
                ),
                child: CupertinoTextField.borderless(
                  controller: _code,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.join,
                  keyboardType: TextInputType.visiblePassword,
                  inputFormatters: [_CodeFormatter()],
                  style: style,
                  placeholder: '••••••',
                  placeholderStyle: style.copyWith(color: colors.placeholder),
                  minLines: 1,
                  maxLines: null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AvoSpacing.l,
                    vertical: AvoSpacing.m,
                  ),
                  onChanged: _changed,
                  onSubmitted: (_) => _join(),
                ),
              ),
            ),
          ),
          if (status != null) ...[
            const SizedBox(height: AvoSpacing.m),
            status,
          ],
        ],
      ),
    );
  }
}
