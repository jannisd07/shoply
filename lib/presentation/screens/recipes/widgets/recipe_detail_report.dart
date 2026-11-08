import 'package:flutter/cupertino.dart';

import 'package:shoply/core/constants/legal_links.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';

/// Minimum height of a reason row (D2 settings rows).
const double _rowMinHeight = 52; // D2

/// Lines the optional note grows to before it scrolls.
const int _noteMaxLines = 5;

/// Why a recipe is reported (Konzept 13 §18.4).
enum RecipeReportReason { inappropriate, spam, dangerous, copyright, other }

/// What [RecipeReportScreen] closes with.
typedef RecipeReport = ({RecipeReportReason reason, String note});

/// "Melden" as a full screen (Konzept 13 §18.4 describes a sheet; owner
/// rule: no sheets): one reason, an optional note, "Senden" in the toolbar,
/// disabled until a reason is chosen. Pops with the [RecipeReport].
class RecipeReportScreen extends StatefulWidget {
  const RecipeReportScreen({super.key});

  @override
  State<RecipeReportScreen> createState() => _RecipeReportScreenState();
}

class _RecipeReportScreenState extends State<RecipeReportScreen> {
  final _note = TextEditingController();
  RecipeReportReason? _reason;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reason = _reason;
    return FullScreenEditor(
      title: context.tr('recipe_detail_report'),
      doneLabel: context.tr('recipe_detail_report_send'),
      doneEnabled: reason != null,
      dirty: reason != null || _note.text.trim().isNotEmpty,
      onDone: () {
        final chosen = _reason;
        if (chosen == null) return;
        Navigator.of(
          context,
        ).pop<RecipeReport>((reason: chosen, note: _note.text.trim()));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InsetSection(
            header: context.tr('recipe_detail_report_reasons'),
            children: [
              for (final r in RecipeReportReason.values)
                Semantics(
                  button: true,
                  selected: r == reason,
                  inMutuallyExclusiveGroup: true,
                  label: recipeReportReasonText(context, r),
                  excludeSemantics: true,
                  onTap: () => setState(() => _reason = r),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _reason = r),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: _rowMinHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AvoSpacing.l,
                          vertical: AvoSpacing.m,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                recipeReportReasonText(context, r),
                                style: context.text(AvoTextStyle.body),
                              ),
                            ),
                            if (r == reason)
                              AvoIcon(AvoIcons.check, color: colors.tint),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AvoSpacing.section),
          InsetSection(
            footer: context.tr(
              'recipe_detail_report_footer',
              params: {'email': LegalLinks.supportEmail},
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(AvoSpacing.m),
                child: CupertinoTextField(
                  controller: _note,
                  placeholder: context.tr('recipe_detail_report_note'),
                  minLines: 1,
                  maxLines: _noteMaxLines,
                  style: context.text(AvoTextStyle.body),
                  placeholderStyle: context.text(
                    AvoTextStyle.body,
                    color: colors.placeholder,
                  ),
                  decoration: BoxDecoration(
                    color: colors.fill,
                    borderRadius: BorderRadius.circular(AvoRadii.imageSmall),
                  ),
                  padding: const EdgeInsets.all(AvoSpacing.m),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The visible text of a report reason.
String recipeReportReasonText(
  BuildContext context,
  RecipeReportReason r,
) => switch (r) {
  RecipeReportReason.inappropriate => context.tr(
    'recipe_detail_report_inappropriate',
  ),
  RecipeReportReason.spam => context.tr('recipe_detail_report_spam'),
  RecipeReportReason.dangerous => context.tr('recipe_detail_report_dangerous'),
  RecipeReportReason.copyright => context.tr('recipe_detail_report_copyright'),
  RecipeReportReason.other => context.tr('recipe_detail_report_other'),
};
