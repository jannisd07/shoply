import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/screens/recipes/widgets/cooking_mode_logic.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_editor_fields.dart';
import 'package:shoply/presentation/screens/recipes/widgets/recipe_editor_form.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';
import 'package:shoply/presentation/widgets/design/segmented_control.dart';
import 'package:shoply/presentation/widgets/design/settings_rows.dart';
import 'package:shoply/presentation/widgets/design/value_stepper.dart';

/// Glyph of the empty photo area (Konzept 13 §17.3: 48 pt light).
const double _cameraGlyph = 48;

/// Width of the step number column ("12").
const double _numberWidth = 28;

const double _photoAspect = 4 / 3;

/// Space between the sections of a step.
const double _sectionGap = AvoSpacing.section;

EdgeInsets get _rowPadding => const EdgeInsets.symmetric(
  horizontal: AvoSpacing.l,
  vertical: kEditorRowVertical,
);

Widget _errorBelow(String text) => Padding(
  padding: const EdgeInsets.fromLTRB(
    AvoSpacing.xxxl,
    AvoSpacing.s,
    AvoSpacing.xxxl,
    0,
  ),
  child: RecipeEditorError(text),
);

// --------------------------------------------------------------- step 1

/// Step 1 "Foto und Name": an optional 4:3 photo (tap opens a menu), the
/// name (required) and a short description.
class RecipeEditorPhotoNameStep extends StatelessWidget {
  const RecipeEditorPhotoNameStep({
    super.key,
    required this.form,
    required this.onPhotoTap,
    this.nameError,
  });

  final RecipeEditorForm form;

  /// Opens the photo menu, anchored at the photo area's context.
  final ValueChanged<BuildContext> onPhotoTap;

  /// The sentence under the name, or null.
  final String? nameError;

  @override
  Widget build(BuildContext context) {
    final error = nameError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InsetSection(
          footer: form.hasPhoto
              ? null
              : context.tr('recipe_editor_photo_optional'),
          children: [
            Builder(
              builder: (anchor) =>
                  _PhotoArea(form: form, onTap: () => onPhotoTap(anchor)),
            ),
            Padding(
              padding: _rowPadding,
              child: RecipeEditorTextField(
                controller: form.name,
                focusNode: form.nameFocus,
                style: context.text(AvoTextStyle.title3),
                placeholder: context.tr('recipe_editor_name_hint'),
                semanticLabel: context.tr('recipe_editor_name_label'),
                onSubmitted: (_) => form.descriptionFocus.requestFocus(),
              ),
            ),
            Padding(
              padding: _rowPadding,
              child: RecipeEditorTextField(
                controller: form.description,
                focusNode: form.descriptionFocus,
                style: context.text(AvoTextStyle.body),
                placeholder: context.tr('recipe_editor_description_hint'),
                semanticLabel: context.tr('recipe_editor_description_label'),
                textInputAction: TextInputAction.newline,
              ),
            ),
          ],
        ),
        if (error != null) _errorBelow(error),
      ],
    );
  }
}

class _PhotoArea extends StatelessWidget {
  const _PhotoArea({required this.form, required this.onTap});

  final RecipeEditorForm form;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final file = form.photo;
    final url = form.photoUrl;
    final has = form.hasPhoto;
    return Semantics(
      button: true,
      label: context.tr(
        has ? 'recipe_editor_photo_change' : 'recipe_editor_photo_add',
      ),
      excludeSemantics: true,
      onTap: onTap,
      child: PressableScale(
        onPressed: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight = constraints.maxWidth / _photoAspect;
            if (has) {
              final image = file != null
                  ? Image.file(file, fit: BoxFit.cover)
                  : Image(
                      image: CachedNetworkImageProvider(url!),
                      fit: BoxFit.cover,
                    );
              return AspectRatio(aspectRatio: _photoAspect, child: image);
            }
            return ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: ColoredBox(
                color: colors.fill,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AvoSpacing.l),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AvoIcon(
                          AvoIcons.camera,
                          size: _cameraGlyph,
                          color: colors.secondaryLabel,
                        ),
                        const SizedBox(height: AvoSpacing.s),
                        Text(
                          context.tr('recipe_editor_photo_add'),
                          textAlign: TextAlign.center,
                          style: context.text(
                            AvoTextStyle.body,
                            color: colors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- step 2

/// Step 2 "Zeiten und Portionen": steppers (no sliders), the total in the
/// footnote, the difficulty as a segmented control (it becomes a pull-down
/// by itself when the labels do not fit).
class RecipeEditorTimesStep extends StatelessWidget {
  const RecipeEditorTimesStep({super.key, required this.form});

  final RecipeEditorForm form;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final minutes = context.tr('recipe_editor_minutes_unit');
    final total = Duration(minutes: form.prepMinutes + form.cookMinutes);
    return InsetSection(
      footer: context.tr(
        'recipe_editor_total_time',
        params: {'time': formatDurationLabel(total, lang)},
      ),
      children: [
        _StepperRow(
          title: context.tr('recipe_editor_prep_time'),
          value: form.prepMinutes,
          min: 0,
          max: kEditorMaxMinutes,
          unit: minutes,
          onChanged: (v) => form.prepMinutes = v,
        ),
        _StepperRow(
          title: context.tr('recipe_editor_cook_time'),
          value: form.cookMinutes,
          min: 0,
          max: kEditorMaxMinutes,
          unit: minutes,
          onChanged: (v) => form.cookMinutes = v,
        ),
        _StepperRow(
          title: context.tr('recipe_editor_servings'),
          value: form.servings,
          min: kEditorMinServings,
          max: kEditorMaxServings,
          onChanged: (v) => form.servings = v,
        ),
        Padding(
          padding: _rowPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('recipe_editor_difficulty'),
                style: context.text(AvoTextStyle.body),
              ),
              const SizedBox(height: AvoSpacing.s),
              AppSegmentedControl<String>(
                semanticLabel: context.tr('recipe_editor_difficulty'),
                selected: form.difficulty,
                onChanged: (v) => form.difficulty = v,
                segments: [
                  for (final id in kEditorDifficulties)
                    SegmentItem(
                      value: id,
                      label: context.tr('recipe_editor_difficulty_$id'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit,
  });

  final String title;
  final int value;
  final int min;
  final int max;
  final String? unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = Text(title, style: context.text(AvoTextStyle.body));
    final stepper = ValueStepper(
      value: value,
      min: min,
      max: max,
      unit: unit,
      semanticLabel: title,
      onChanged: onChanged,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AvoSpacing.l,
        vertical: AvoSpacing.s,
      ),
      child: context.isAccessibilityText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: AvoSpacing.s),
                stepper,
              ],
            )
          : Row(
              children: [
                Expanded(child: label),
                const SizedBox(width: AvoSpacing.m),
                stepper,
              ],
            ),
    );
  }
}

// --------------------------------------------------------------- step 3

/// Step 3 "Zutaten": one field per ingredient, read by the add-item parser
/// ("200 g Feta" → "200 g · Feta"); Return adds the next row, a swipe to
/// the left deletes with undo.
class RecipeEditorIngredientsStep extends StatelessWidget {
  const RecipeEditorIngredientsStep({
    super.key,
    required this.form,
    required this.onSubmitted,
    required this.onChanged,
    required this.onDelete,
    required this.onAdd,
    this.error,
  });

  final RecipeEditorForm form;
  final ValueChanged<RecipeEditorLine> onSubmitted;
  final ValueChanged<RecipeEditorLine> onChanged;
  final ValueChanged<RecipeEditorLine> onDelete;
  final VoidCallback onAdd;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InsetSection(
          header: context.tr('recipe_editor_ingredients'),
          children: [
            for (final line in form.ingredients)
              _Deletable(
                line: line,
                onDelete: onDelete,
                child: _IngredientRow(
                  line: line,
                  onSubmitted: () => onSubmitted(line),
                  onChanged: () => onChanged(line),
                ),
              ),
            _AddRow(
              label: context.tr('recipe_editor_add_ingredient'),
              onAdd: onAdd,
            ),
          ],
        ),
        if (error != null) _errorBelow(error),
      ],
    );
  }
}

class _Deletable extends StatelessWidget {
  const _Deletable({
    required this.line,
    required this.onDelete,
    required this.child,
  });

  final RecipeEditorLine line;
  final ValueChanged<RecipeEditorLine> onDelete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = context.tr('recipe_editor_delete');
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: label): () => onDelete(line),
      },
      child: Dismissible(
        key: ValueKey('line-${line.id}'),
        direction: DismissDirection.endToStart,
        background: RecipeEditorDeleteBackground(label: label),
        onDismissed: (_) => onDelete(line),
        child: ColoredBox(color: context.colors.surface, child: child),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.line,
    required this.onSubmitted,
    required this.onChanged,
  });

  final RecipeEditorLine line;
  final VoidCallback onSubmitted;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lang = Localizations.localeOf(context).languageCode;
    final parsed = parseIngredientLine(line.text, lang);
    final secondary = context.text(
      AvoTextStyle.subhead,
      color: colors.secondaryLabel,
    );
    Widget? summary;
    if (parsed != null) {
      summary = parsed.hasName
          ? Text(ingredientSummary(parsed, lang), style: secondary)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AvoSpacing.xxs),
                  child: AvoIcon(
                    AvoIcons.questionmarkCircle,
                    size: context.typography.sizeOf(AvoTextStyle.subhead),
                    color: colors.secondaryLabel,
                  ),
                ),
                const SizedBox(width: AvoSpacing.xs),
                Expanded(
                  child: Text(
                    context.tr('recipe_editor_name_missing'),
                    style: secondary,
                  ),
                ),
              ],
            );
    }
    return Padding(
      padding: _rowPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecipeEditorTextField(
            controller: line.controller,
            focusNode: line.focus,
            style: context.text(AvoTextStyle.body),
            placeholder: context.tr('recipe_editor_ingredient_hint'),
            semanticLabel: context.tr('recipe_editor_ingredient_label'),
            onSubmitted: (_) => onSubmitted(),
            onChanged: (_) => onChanged(),
          ),
          if (summary != null) ...[
            const SizedBox(height: AvoSpacing.xxs),
            ExcludeSemantics(child: summary),
          ],
        ],
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.label, required this.onAdd});

  final String label;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.l),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: AppButton.plain(
        icon: const AvoIcon(AvoIcons.plus),
        label: label,
        onPressed: onAdd,
      ),
    ),
  );
}

// --------------------------------------------------------------- step 4

/// Step 4 "Zubereitung und Sichtbarkeit": numbered steps that grow without
/// limit (a found time shows "Timer 15 Min im Kochmodus"), and who sees the
/// recipe.
class RecipeEditorInstructionsStep extends StatelessWidget {
  const RecipeEditorInstructionsStep({
    super.key,
    required this.form,
    required this.onDelete,
    required this.onAdd,
    required this.authorName,
    required this.onSetName,
    this.stepsError,
    this.authorError,
  });

  final RecipeEditorForm form;
  final ValueChanged<RecipeEditorLine> onDelete;
  final VoidCallback onAdd;

  /// The display name a published recipe shows; null asks for one.
  final String? authorName;
  final VoidCallback onSetName;
  final String? stepsError;
  final String? authorError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final stepsError = this.stepsError;
    final authorError = this.authorError;
    final name = authorName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InsetSection(
          header: context.tr('recipe_editor_steps'),
          children: [
            for (var i = 0; i < form.steps.length; i++)
              _Deletable(
                line: form.steps[i],
                onDelete: onDelete,
                child: _StepRow(number: i + 1, line: form.steps[i]),
              ),
            _AddRow(label: context.tr('recipe_editor_add_step'), onAdd: onAdd),
          ],
        ),
        if (stepsError != null) _errorBelow(stepsError),
        const SizedBox(height: _sectionGap),
        InsetSection(
          header: context.tr('recipe_editor_visibility'),
          children: [
            Padding(
              padding: _rowPadding,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AvoSpacing.xxs),
                    child: AvoIcon(
                      AvoIcons.check,
                      size: context.typography.sizeOf(AvoTextStyle.body),
                      color: colors.tint,
                    ),
                  ),
                  const SizedBox(width: AvoSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('recipe_editor_visibility_all'),
                          style: context.text(AvoTextStyle.body),
                        ),
                        Text(
                          name == null
                              ? context.tr('recipe_editor_visibility_no_name')
                              : context.tr(
                                  'recipe_editor_visibility_as',
                                  params: {'name': name},
                                ),
                          style: context.text(
                            AvoTextStyle.subhead,
                            color: colors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            NavRow(
              title: context.tr(
                name == null
                    ? 'recipe_editor_set_name'
                    : 'recipe_editor_change_name',
              ),
              onTap: onSetName,
            ),
          ],
        ),
        if (authorError != null) _errorBelow(authorError),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.line});

  final int number;
  final RecipeEditorLine line;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lang = Localizations.localeOf(context).languageCode;
    final times = detectStepTimes(line.text);
    final number = Text(
      '${this.number}',
      style: context.text(
        AvoTextStyle.body,
        color: colors.secondaryLabel,
        tabular: true,
      ),
    );
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecipeEditorTextField(
          controller: line.controller,
          focusNode: line.focus,
          style: context.text(AvoTextStyle.body),
          placeholder: context.tr('recipe_editor_step_hint'),
          semanticLabel: context.tr(
            'recipe_editor_step_label',
            params: {'n': '${this.number}'},
          ),
          textInputAction: TextInputAction.newline,
        ),
        if (times.isNotEmpty) ...[
          const SizedBox(height: AvoSpacing.xxs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AvoSpacing.xxs),
                child: AvoIcon(
                  AvoIcons.clock,
                  size: context.typography.sizeOf(AvoTextStyle.subhead),
                  color: colors.secondaryLabel,
                ),
              ),
              const SizedBox(width: AvoSpacing.xs),
              Expanded(
                child: Text(
                  context.tr(
                    'recipe_editor_step_timer',
                    params: {
                      'time': formatDurationLabel(times.first.duration, lang),
                    },
                  ),
                  style: context.text(
                    AvoTextStyle.subhead,
                    color: colors.secondaryLabel,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
    return Padding(
      padding: _rowPadding,
      child: context.isAccessibilityText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [number, field],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: _numberWidth, child: number),
                Expanded(child: field),
              ],
            ),
    );
  }
}
