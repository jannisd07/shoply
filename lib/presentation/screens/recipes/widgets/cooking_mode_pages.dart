import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_logic.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/check_circle.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/status_row.dart';

/// Start of a row's text: 6 + 44 pt check hit area + 6.
const double _checkRowIndent =
    AvoSpacing.xs + AvoSizes.hitTarget + AvoSpacing.s;

/// Stars on the "Fertig" page. Fixed glyph size inside a 44 pt target.
const double _starSize = 28;

/// Vertical text padding of a 44 pt row at the default size: (44 - 22) / 2.
const double _rowVertical = 11;

/// Scrolls one page vertically when its text is longer than the screen
/// (Konzept 13 §16.2 Nr. 5), with the screen margins.
class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        top: AvoSpacing.xxl,
        bottom: AvoSpacing.section,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Margin extends StatelessWidget {
  const _Margin({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
    child: child,
  );
}

/// One ingredient as the cooking mode shows it.
@immutable
class CookingIngredientLine {
  const CookingIngredientLine({required this.name, this.amount});

  /// "Olivenöl".
  final String name;

  /// "3 EL", or null for "Salz nach Geschmack".
  final String? amount;
}

/// Page "Zutaten": everything to lay out, each with a check circle. Checked
/// rows stay where they are (nothing moves while cooking).
class CookingIngredientsPage extends StatelessWidget {
  const CookingIngredientsPage({
    super.key,
    required this.ingredients,
    required this.servings,
    required this.checked,
    required this.onToggle,
    required this.onToggleAll,
  });

  final List<CookingIngredientLine> ingredients;
  final int servings;
  final Set<int> checked;
  final ValueChanged<int> onToggle;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final allChecked =
        ingredients.isNotEmpty && checked.length >= ingredients.length;
    return _PageScroll(
      children: [
        _Margin(
          child: Semantics(
            header: true,
            child: Text(
              context.tr('recipe_cook_gather_title'),
              style: context.text(AvoTextStyle.title1),
            ),
          ),
        ),
        const SizedBox(height: AvoSpacing.xs),
        _Margin(
          child: Text(
            context.tr(
              servings == 1
                  ? 'recipe_cook_for_servings_one'
                  : 'recipe_cook_for_servings',
              params: {'n': '$servings'},
            ),
            style: context.text(
              AvoTextStyle.callout,
              color: colors.secondaryLabel,
            ),
          ),
        ),
        const SizedBox(height: AvoSpacing.l),
        if (ingredients.isEmpty)
          _Margin(
            child: Text(
              context.tr('recipe_cook_no_ingredients'),
              style: context.text(AvoTextStyle.body),
            ),
          )
        else ...[
          InsetSection(
            separatorIndent: _checkRowIndent,
            children: [
              for (var i = 0; i < ingredients.length; i++)
                _CheckRow(
                  line: ingredients[i],
                  checked: checked.contains(i),
                  onToggle: () => onToggle(i),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvoSpacing.xxxl,
              AvoSpacing.xs,
              AvoSpacing.xxxl,
              0,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.plain(
                label: context.tr(
                  allChecked
                      ? 'recipe_cook_reset_all'
                      : 'recipe_cook_check_all',
                ),
                onPressed: onToggleAll,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.line,
    required this.checked,
    required this.onToggle,
  });

  final CookingIngredientLine line;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ax = context.isAccessibilityText;
    final color = checked ? colors.secondaryLabel : colors.label;
    final decoration = checked ? TextDecoration.lineThrough : null;
    final nameStyle = context
        .text(AvoTextStyle.body, color: color)
        .copyWith(decoration: decoration, decorationColor: color);
    final amountStyle = context
        .text(AvoTextStyle.body, color: colors.secondaryLabel, tabular: true)
        .copyWith(decoration: decoration, decorationColor: color);
    final amount = line.amount;

    final text = ax || amount == null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.name, style: nameStyle),
              if (amount != null) Text(amount, style: amountStyle),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(line.name, style: nameStyle)),
              const SizedBox(width: AvoSpacing.m),
              Text(amount, style: amountStyle, textAlign: TextAlign.end),
            ],
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onToggle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AvoSpacing.xs,
            end: AvoSpacing.l,
          ),
          child: Row(
            crossAxisAlignment: ax
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              CheckCircle(
                checked: checked,
                itemName: [line.name, ?amount].join(', '),
                onChanged: (_) => onToggle(),
              ),
              const SizedBox(width: AvoSpacing.s),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: _rowVertical),
                  child: text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the timer of a step is doing, for its page.
enum StepTimerState { none, running, paused, finished }

/// One step page: "Schritt 3", the step text large (28 pt regular, left
/// aligned), times in it tappable, "Dafür" with the ingredients of the step
/// and the timer button.
class CookingStepPage extends StatefulWidget {
  const CookingStepPage({
    super.key,
    required this.number,
    required this.text,
    required this.ingredients,
    required this.times,
    required this.timerState,
    required this.onStartTimer,
  });

  /// 1-based.
  final int number;
  final String text;

  /// "3 EL Olivenöl", "Salz, Pfeffer".
  final List<String> ingredients;

  /// Times found in [text]; the first one gets the button.
  final List<StepTime> times;

  final StepTimerState timerState;

  /// Starts the timer of this step.
  final ValueChanged<Duration> onStartTimer;

  @override
  State<CookingStepPage> createState() => _CookingStepPageState();
}

class _CookingStepPageState extends State<CookingStepPage> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  TextSpan _textSpan(BuildContext context) {
    // The old spans stay attached until this frame is laid out.
    final old = List.of(_recognizers);
    _recognizers.clear();
    if (old.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final r in old) {
          r.dispose();
        }
      });
    }
    final colors = context.colors;
    final style = context.text(AvoTextStyle.title1, weight: FontWeight.w400);
    final text = widget.text;
    final canStart = widget.timerState == StepTimerState.none;
    final spans = <InlineSpan>[];
    var at = 0;
    for (final time in widget.times) {
      if (time.start < at) continue;
      spans.add(TextSpan(text: text.substring(at, time.start)));
      final recognizer = TapGestureRecognizer()
        ..onTap = canStart ? () => widget.onStartTimer(time.duration) : null;
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: text.substring(time.start, time.end),
          recognizer: recognizer,
          style: TextStyle(
            color: colors.tint,
            decoration: TextDecoration.underline,
            decorationColor: colors.tint,
          ),
        ),
      );
      at = time.end;
    }
    spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lang = Localizations.localeOf(context).languageCode;
    final first = widget.times.isEmpty ? null : widget.times.first;

    Widget? timer;
    if (first != null) {
      switch (widget.timerState) {
        case StepTimerState.none:
          final upper = first.upper;
          timer = Wrap(
            spacing: AvoSpacing.s,
            runSpacing: AvoSpacing.s,
            children: [
              AppButton.secondary(
                icon: const AvoIcon(AvoIcons.clock),
                label: context.tr(
                  'recipe_cook_timer_button',
                  params: {'time': formatDurationLabel(first.duration, lang)},
                ),
                onPressed: () => widget.onStartTimer(first.duration),
              ),
              if (upper != null)
                AppButton.secondary(
                  label: formatDurationLabel(upper, lang),
                  onPressed: () => widget.onStartTimer(upper),
                ),
            ],
          );
        case StepTimerState.running:
        case StepTimerState.paused:
        case StepTimerState.finished:
          final key = switch (widget.timerState) {
            StepTimerState.running => 'recipe_cook_timer_running',
            StepTimerState.paused => 'recipe_cook_timer_paused',
            _ => 'recipe_cook_timer_finished',
          };
          timer = Text(
            context.tr(key),
            style: context.text(
              AvoTextStyle.body,
              color: colors.secondaryLabel,
            ),
          );
      }
    }

    return _PageScroll(
      children: [
        _Margin(
          child: Text(
            context.tr(
              'recipe_cook_step_label',
              params: {'n': '${widget.number}'},
            ),
            style: context.text(
              AvoTextStyle.headline,
              color: colors.secondaryLabel,
            ),
          ),
        ),
        const SizedBox(height: AvoSpacing.s),
        _Margin(
          child: Semantics(header: true, child: Text.rich(_textSpan(context))),
        ),
        if (widget.ingredients.isNotEmpty) ...[
          const SizedBox(height: AvoSpacing.xxl),
          _Margin(
            child: Text(
              context.tr('recipe_cook_needed'),
              style: context.text(AvoTextStyle.headline),
            ),
          ),
          const SizedBox(height: AvoSpacing.xs),
          for (final line in widget.ingredients)
            _Margin(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AvoSpacing.xxs),
                child: Text(line, style: context.text(AvoTextStyle.body)),
              ),
            ),
        ],
        if (timer != null) ...[
          const SizedBox(height: AvoSpacing.xxl),
          _Margin(child: timer),
        ],
      ],
    );
  }
}

/// Page "Fertig": "Guten Appetit.", rate (not for own recipes), log to the
/// diary (calories module), share. No mascot, no confetti.
class CookingDonePage extends StatelessWidget {
  const CookingDonePage({
    super.key,
    required this.rating,
    required this.canRate,
    required this.onRate,
    required this.onShare,
    this.onLog,
    this.rateFailed = false,
    this.offline = false,
  });

  /// The person's stars so far, 0 for none.
  final int rating;

  /// False for the person's own recipe.
  final bool canRate;
  final ValueChanged<int> onRate;
  final VoidCallback onShare;

  /// "Ins Tagebuch eintragen"; null hides the row (calories off, no values).
  final VoidCallback? onLog;

  /// The last rating could not be sent.
  final bool rateFailed;

  /// No connection: rating waits.
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final log = onLog;
    return _PageScroll(
      children: [
        _Margin(
          child: Semantics(
            header: true,
            child: Text(
              context.tr('recipe_cook_enjoy'),
              style: context.text(AvoTextStyle.title1),
            ),
          ),
        ),
        const SizedBox(height: AvoSpacing.l),
        if (canRate && (rateFailed || offline)) ...[
          StatusRow(
            kind: offline ? StatusKind.offline : StatusKind.failed,
            text: context.tr(
              offline ? 'recipe_cook_rate_offline' : 'recipe_cook_rate_failed',
            ),
          ),
          const SizedBox(height: AvoSpacing.s),
        ],
        InsetSection(
          children: [
            if (canRate)
              _RatingRow(rating: rating, onRate: offline ? null : onRate),
            if (log != null)
              NavRow(title: context.tr('recipe_cook_log_diary'), onTap: log),
            NavRow(title: context.tr('recipe_cook_share'), onTap: onShare),
          ],
        ),
      ],
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.rating, required this.onRate});

  final int rating;
  final ValueChanged<int>? onRate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onRate = this.onRate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AvoSpacing.l,
        AvoSpacing.m,
        AvoSpacing.l,
        AvoSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('recipe_cook_rate'),
            style: context.text(AvoTextStyle.body),
          ),
          Wrap(
            children: [
              for (var star = 1; star <= 5; star++)
                Semantics(
                  button: true,
                  selected: star <= rating,
                  enabled: onRate != null,
                  label: context.tr(
                    star == 1
                        ? 'recipe_cook_rate_star_one'
                        : 'recipe_cook_rate_stars',
                    params: {'n': '$star'},
                  ),
                  onTap: onRate == null ? null : () => onRate(star),
                  excludeSemantics: true,
                  child: PressableScale(
                    onPressed: onRate == null ? null : () => onRate(star),
                    child: SizedBox.square(
                      dimension: AvoSizes.hitTarget,
                      child: Center(
                        child: AvoIcon(
                          AvoIcons.star,
                          filled: star <= rating,
                          size: _starSize,
                          color: star <= rating
                              ? colors.tint
                              : colors.secondaryLabel,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
