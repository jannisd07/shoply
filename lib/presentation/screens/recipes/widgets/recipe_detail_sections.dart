import 'package:flutter/cupertino.dart';

import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_detail_texts.dart';
import 'package:shoply/presentation/screens/recipes/widgets/servings_stepper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/empty_state.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';
import 'package:shoply/presentation/widgets/design/skeleton.dart';

// The content sections of the recipe detail (Konzept 13 §12.1 Nr. 4 to 12).

/// Minimum height of a row in these sections (D2 settings rows).
const double _rowMinHeight = 52; // D2

/// Lines of the description before "Mehr" (Konzept 13 §12.1 Nr. 5).
const int _descriptionLines = 4;

/// Width of the step number column, in multiples of the number's size.
const double _stepNumberWidth = 1.6;

// ------------------------------------------------------------------ notice

/// The allergy and adaptation notice (Konzept 13 §2.3, §12.1 Nr. 4, E-03):
/// its own section, one sentence per case with its symbol, then the fixed
/// footnote. Never hidden for space; renders nothing without [lines].
class RecipeAllergenNotice extends StatelessWidget {
  const RecipeAllergenNotice({super.key, required this.lines});

  final List<RecipeNoticeLine> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final hasAllergy = lines.any(
      (l) =>
          l.kind == RecipeNoticeKind.allergen ||
          l.kind == RecipeNoticeKind.unchecked,
    );
    final symbolSize = context.typography.sizeOf(AvoTextStyle.callout);
    final lineHeight = context.typography.lineHeightOf(AvoTextStyle.callout);
    return InsetSection(
      footer: hasAllergy ? context.tr('recipe_detail_allergy_footnote') : null,
      showSeparators: false,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.l,
              vertical: AvoSpacing.s,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: lineHeight,
                  child: Center(
                    widthFactor: 1,
                    child: AvoIcon(
                      switch (line.kind) {
                        RecipeNoticeKind.allergen =>
                          AvoIcons.exclamationmarkTriangleFill,
                        RecipeNoticeKind.adapted =>
                          AvoIcons.leafArrowCirclepath,
                        RecipeNoticeKind.diet => AvoIcons.infoCircle,
                        RecipeNoticeKind.unchecked =>
                          AvoIcons.questionmarkCircle,
                      },
                      size: symbolSize,
                      color: line.kind == RecipeNoticeKind.allergen
                          ? colors.destructive
                          : colors.secondaryLabel,
                    ),
                  ),
                ),
                const SizedBox(width: AvoSpacing.m),
                Expanded(
                  child: Text(
                    line.text,
                    style: context.text(AvoTextStyle.callout),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------- description

/// The description in body text, four lines with a plain "Mehr", then in
/// full (Konzept 13 §12.1 Nr. 5). Renders nothing for an empty text.
class RecipeDescription extends StatefulWidget {
  const RecipeDescription({super.key, required this.text});

  final String text;

  @override
  State<RecipeDescription> createState() => _RecipeDescriptionState();
}

class _RecipeDescriptionState extends State<RecipeDescription> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    final style = context.text(AvoTextStyle.body);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.screen),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: _descriptionLines,
          )..layout(maxWidth: constraints.maxWidth);
          final long = painter.didExceedMaxLines;
          painter.dispose();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: style,
                maxLines: _open ? null : _descriptionLines,
                overflow: _open ? null : TextOverflow.ellipsis,
              ),
              if (long && !_open)
                AppButton.plain(
                  label: context.tr('recipe_detail_more_text'),
                  onPressed: () => setState(() => _open = true),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------- ingredients

/// One ingredient as the detail shows it.
class RecipeIngredientLine {
  const RecipeIngredientLine({
    required this.name,
    required this.amount,
    this.sublines = const [],
    this.allergen,
    this.unchecked = false,
    this.adapted = false,
    this.offerBadge,
  });

  /// "Feta" or, adapted, "laktosefreier Hirtenkäse".
  final String name;

  /// "200 g"; empty for "Salz" without an amount.
  final String amount;

  /// "statt Feta · wegen Laktose", "Schon auf Wocheneinkauf".
  final List<String> sublines;

  /// The allergen it contains without a substitute: warning sign.
  final String? allergen;

  /// Could not be checked for allergens: question mark.
  final bool unchecked;

  /// Replaced for the person: swap sign before the name.
  final bool adapted;

  /// Teil B's offer pill after the name (`IngredientOfferBadge`); it may
  /// render nothing. Its own sentence joins the row's VoiceOver label.
  final Widget? offerBadge;
}

/// "Zutaten" (Konzept 13 §12.1 Nr. 7): servings stepper, "Für dich
/// angepasst | Original" when something was replaced, then one row per
/// ingredient with the amount in its own column. From xxxL on the amount
/// stands before the name ("200 g Feta").
class RecipeIngredientsSection extends StatelessWidget {
  const RecipeIngredientsSection({
    super.key,
    required this.lines,
    required this.servings,
    required this.onServings,
    this.adapted,
    this.onAdapted,
    this.footer,
  });

  final List<RecipeIngredientLine> lines;

  /// The group's last row, e.g. Teil B's `RecipeOfferSummary`; pass it only
  /// when it shows something (an empty row would leave a gap).
  final Widget? footer;
  final int servings;
  final ValueChanged<int> onServings;

  /// Current version; null hides the segment (nothing replaced).
  final bool? adapted;
  final ValueChanged<bool>? onAdapted;

  @override
  Widget build(BuildContext context) {
    final mode = adapted;
    final change = onAdapted;
    return InsetSection(
      header: context.tr('recipe_detail_ingredients'),
      children: [
        _ServingsRow(servings: servings, onChanged: onServings),
        if (mode != null && change != null)
          Padding(
            padding: const EdgeInsets.all(AvoSpacing.m),
            child: AppSegmentedControl<bool>(
              semanticLabel: context.tr('recipe_detail_variant'),
              selected: mode,
              onChanged: change,
              segments: [
                SegmentItem(
                  value: true,
                  label: context.tr('recipe_detail_variant_adapted'),
                ),
                SegmentItem(
                  value: false,
                  label: context.tr('recipe_detail_variant_original'),
                ),
              ],
            ),
          ),
        for (final line in lines) _IngredientRow(line: line),
        ?footer,
      ],
    );
  }
}

class _ServingsRow extends StatelessWidget {
  const _ServingsRow({required this.servings, required this.onChanged});

  final int servings;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final title = ExcludeSemantics(
      child: Text(
        context.tr('recipe_detail_servings'),
        style: context.text(AvoTextStyle.body),
      ),
    );
    final stepper = ServingsStepper(value: servings, onChanged: onChanged);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowMinHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: AvoSpacing.xs,
        ),
        child: context.isAccessibilityText
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AvoSpacing.s),
                    child: title,
                  ),
                  stepper,
                ],
              )
            : Row(
                children: [
                  Expanded(child: title),
                  stepper,
                ],
              ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.line});

  final RecipeIngredientLine line;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final inline =
        typography.category.index >= ContentSizeCategory.xxxLarge.index;
    final glyph = typography.sizeOf(AvoTextStyle.subhead);
    final warning = line.allergen;
    final amount = line.amount;

    final nameText = Text.rich(
      TextSpan(
        children: [
          if (line.adapted) ...[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: AvoIcon(
                AvoIcons.arrowRightArrowLeft,
                size: glyph,
                color: colors.secondaryLabel,
              ),
            ),
            const TextSpan(text: ' '),
          ],
          if (inline && amount.isNotEmpty)
            TextSpan(
              text: '$amount ',
              style: context.text(
                AvoTextStyle.body,
                color: colors.secondaryLabel,
                tabular: true,
              ),
            ),
          TextSpan(text: line.name),
          if (warning != null) ...[
            const TextSpan(text: ' '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: AvoIcon(
                AvoIcons.exclamationmarkTriangleFill,
                size: glyph,
                color: colors.destructive,
              ),
            ),
          ] else if (line.unchecked) ...[
            const TextSpan(text: ' '),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: AvoIcon(
                AvoIcons.questionmarkCircle,
                size: glyph,
                color: colors.secondaryLabel,
              ),
            ),
          ],
        ],
      ),
      style: context.text(AvoTextStyle.body),
    );

    final label = [
      line.name,
      if (amount.isNotEmpty) amount,
      if (warning != null)
        context.tr(
          'recipe_detail_contains_short',
          params: {'allergen': warning},
        )
      else if (line.unchecked)
        context.tr('recipe_detail_unchecked_short'),
      ...line.sublines,
    ].join(', ');

    final badge = line.offerBadge;
    final name = badge == null
        ? ExcludeSemantics(child: nameText)
        : Wrap(
            spacing: AvoSpacing.s,
            runSpacing: AvoSpacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ExcludeSemantics(child: nameText),
              badge,
            ],
          );

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AvoSpacing.l,
          vertical: AvoSpacing.m - AvoSpacing.xxs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  name,
                  for (final sub in line.sublines)
                    ExcludeSemantics(
                      child: Text(
                        sub,
                        style: context.text(
                          AvoTextStyle.subhead,
                          color: colors.secondaryLabel,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!inline && amount.isNotEmpty) ...[
              const SizedBox(width: AvoSpacing.m),
              ExcludeSemantics(
                child: Text(
                  amount,
                  textAlign: TextAlign.end,
                  style: context.text(
                    AvoTextStyle.body,
                    color: colors.secondaryLabel,
                    tabular: true,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (badge == null) {
      return Semantics(label: label, excludeSemantics: true, child: row);
    }
    // The pill speaks its own sentence ("im Angebot für 0,99 €"), merged
    // after the row's label; the row's texts are excluded one by one.
    return MergeSemantics(
      child: Semantics(label: label, child: row),
    );
  }
}

// ------------------------------------------------------------------- steps

/// One step: its text and, adapted, "statt Feta · wegen Laktose".
class RecipeStepLine {
  const RecipeStepLine({required this.text, this.note});

  final String text;
  final String? note;
}

/// "Zubereitung" with "5 Schritte" in the heading (Konzept 13 §12.1 Nr. 8):
/// the number left, the text in body. Times are plain text here (timers
/// belong to the cooking mode).
class RecipeStepsSection extends StatelessWidget {
  const RecipeStepsSection({super.key, required this.steps});

  final List<RecipeStepLine> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final numberStyle = context.text(
      AvoTextStyle.body,
      color: colors.secondaryLabel,
      weight: FontWeight.w600,
      tabular: true,
    );
    final numberWidth =
        context.typography.sizeOf(AvoTextStyle.body) * _stepNumberWidth;
    return InsetSection(
      header: context.tr('recipe_detail_steps'),
      headerTrailing: Text(
        steps.length == 1
            ? context.tr('recipe_detail_steps_one')
            : context.tr(
                'recipe_detail_steps_many',
                params: {'count': '${steps.length}'},
              ),
      ),
      separatorIndent: AvoSpacing.l + numberWidth + AvoSpacing.s,
      children: [
        for (var i = 0; i < steps.length; i++)
          Semantics(
            label:
                '${context.tr('recipe_detail_step', params: {'n': '${i + 1}'})}, '
                '${steps[i].text}${steps[i].note == null ? '' : ', ${steps[i].note}'}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AvoSpacing.l,
                vertical: AvoSpacing.m,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: numberWidth,
                    child: Text('${i + 1}', style: numberStyle),
                  ),
                  const SizedBox(width: AvoSpacing.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].text,
                          style: context.text(AvoTextStyle.body),
                        ),
                        if (steps[i].note case final note?)
                          Padding(
                            padding: const EdgeInsets.only(top: AvoSpacing.xxs),
                            child: Text(
                              note,
                              style: context.text(
                                AvoTextStyle.footnote,
                                color: colors.secondaryLabel,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ source

/// "Quelle: Wikibooks Kochbuch · CC BY-SA 4.0" under the content of an
/// imported recipe (licence duty, Konzept 13 §12.1 Nr. 12); the source name
/// is a link.
class RecipeSourceFooter extends StatelessWidget {
  const RecipeSourceFooter({
    super.key,
    required this.source,
    this.license,
    required this.onOpen,
  });

  final String source;
  final String? license;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final prefix = context.tr(
      'recipe_detail_source_footer',
      params: {'source': ''},
    );
    final style = context.text(
      AvoTextStyle.footnote,
      color: colors.secondaryLabel,
    );
    return Semantics(
      link: true,
      label: [
        context.tr('recipe_detail_source_footer', params: {'source': source}),
        ?license,
      ].join(', '),
      hint: context.tr('recipe_detail_source_open'),
      excludeSemantics: true,
      onTap: onOpen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AvoSpacing.xxxl,
              vertical: AvoSpacing.s,
            ),
            child: Text.rich(
              TextSpan(
                text: prefix,
                children: [
                  TextSpan(
                    text: source,
                    style: style.copyWith(color: colors.tint),
                  ),
                  if (license != null) TextSpan(text: ' · $license'),
                ],
              ),
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ states

/// First open without any local copy (deep link): calm shapes where photo,
/// title and sections will be, no spinner (Konzept 13 §12.3).
class RecipeDetailPlaceholder extends StatelessWidget {
  const RecipeDetailPlaceholder({super.key, required this.photoHeight});

  final double photoHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bar = context.typography.sizeOf(AvoTextStyle.title1);
    Widget shape(double widthFactor, double height) => FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: colors.fill,
          borderRadius: BorderRadius.circular(AvoRadii.capsule(height)),
        ),
      ),
    );
    return Semantics(
      label: context.tr('recipe_detail_loading'),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: photoHeight,
            child: ColoredBox(color: colors.fill),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AvoSpacing.screen,
              AvoSpacing.xl,
              AvoSpacing.screen,
              AvoSpacing.section,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                shape(0.8, bar),
                const SizedBox(height: AvoSpacing.m),
                shape(0.5, bar / 2),
              ],
            ),
          ),
          const SkeletonSection(rows: 4, withImage: false),
          const SizedBox(height: AvoSpacing.section),
          const SkeletonSection(rows: 3, withImage: false),
        ],
      ),
    );
  }
}

/// "Dieses Rezept gibt es nicht mehr." (deleted or private) or "Das Rezept
/// konnte nicht geladen werden." with "Erneut versuchen" (Konzept 13 §12.3);
/// a symbol, never the figure.
class RecipeDetailProblem extends StatelessWidget {
  const RecipeDetailProblem({
    super.key,
    required this.gone,
    required this.onAction,
    this.offline = false,
  });

  final bool gone;
  final bool offline;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: AvoIcon(gone ? AvoIcons.book : AvoIcons.exclamationmarkCircle),
      title: context.tr(
        gone ? 'recipe_detail_gone_title' : 'recipe_detail_failed_title',
      ),
      message: context.tr(
        gone
            ? 'recipe_detail_gone_message'
            : offline
            ? 'recipe_detail_failed_offline'
            : 'recipe_detail_failed_message',
      ),
      actionLabel: context.tr(
        gone ? 'recipe_detail_gone_action' : 'common_try_again',
      ),
      onAction: onAction,
    );
  }
}
