import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:go_router/go_router.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/core/localization/localization_helper.dart';
import 'package:shoply/presentation/widgets/design/app_button.dart';
import 'package:shoply/presentation/widgets/design/avo_figure.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';
import 'package:shoply/presentation/widgets/design/home_card.dart';
import 'package:shoply/presentation/widgets/slots/b_slots.dart';
import 'package:shoply/routes/route_paths.dart';

/// Avo figure in the card: 112 × 137, 34 pt above the card, 6 pt from the
/// right edge; the text keeps 116 pt free on the right (D2 `.avo-m`).
const double _kFigureHeight = 137; // D2
const double _kFigureTop = -34; // D2
const double _kFigureRight = 6; // D2
const double _kTextRightInset = 116; // D2

/// Smaller figure at accessibility sizes, placed above the text.
const double _kFigureHeightLarge = 72;

/// "Frag Avo …" field: white pill, at least 48 pt (D2 form).
const double _kAskMinHeight = 48; // D2
const EdgeInsets _kCardPadding = EdgeInsets.fromLTRB(16, 18, 16, 16); // D2

/// Shadows of the ask field and the white chips (D2).
const List<(double alpha, double y, double blur)> _kAskShadows = [
  (0.08, 1, 3),
  (0.06, 6, 16),
];
const double _kChipHeight = 34; // D2
const double _kChipShadowAlpha = 0.07; // D2

/// Opens the Avo tab with [question] sent once (`/avo?q=`, Teil B).
void openAvoWithQuestion(BuildContext context, String question) {
  final q = question.trim();
  if (q.isEmpty) return;
  context.go(Uri(path: RoutePaths.avo, queryParameters: {'q': q}).toString());
}

/// The first card on Home (D2 "Avo-Karte"): Avo waving, the savings hint of
/// Teil B when there is one (else a short intro), the field "Frag Avo …"
/// and question chips that open the Avo tab.
class HomeAvoCard extends StatelessWidget {
  const HomeAvoCard({
    super.key,
    required this.firstName,
    required this.offersOn,
    required this.hasSavingsHint,
  });

  /// First name for "Hey Jannis!", or null.
  final String? firstName;

  /// Offers module on and kill switch off: offers chip and savings hint.
  final bool offersOn;

  /// Teil B's `HomeSavingsHint` has content right now.
  final bool hasSavingsHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final large = context.isAccessibilityText;
    final name = firstName?.trim();

    final Widget message;
    if (offersOn && hasSavingsHint) {
      message = const HomeSavingsHint();
    } else {
      message = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name == null || name.isEmpty
                ? context.tr('home_avo_hello_anonymous')
                : context.tr('home_avo_hello', params: {'name': name}),
            style: context.text(AvoTextStyle.title3, weight: FontWeight.w700),
          ),
          const SizedBox(height: AvoSpacing.xs),
          Text(
            context.tr('home_avo_intro'),
            style: context.text(
              AvoTextStyle.subhead,
              color: colors.secondaryLabel,
            ),
          ),
        ],
      );
    }

    final eyebrow = context.tr('home_avo_eyebrow');
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          semanticsLabel: eyebrow,
          style: context.text(
            AvoTextStyle.caption2,
            color: colors.tint,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AvoSpacing.xs),
        message,
      ],
    );

    final chips = [
      context.tr('home_chip_cook'),
      context.tr('home_chip_weekend'),
      if (offersOn) context.tr('home_chip_offers'),
    ];

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (large) ...[
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: AvoFigure(pose: AvoPose.waving, size: _kFigureHeightLarge),
          ),
          const SizedBox(height: AvoSpacing.s),
          text,
        ] else
          Padding(
            padding: const EdgeInsetsDirectional.only(end: _kTextRightInset),
            child: text,
          ),
        const SizedBox(height: AvoSpacing.l),
        const _AskAvoField(),
        const SizedBox(height: AvoSpacing.s),
        // D2: one row of chips; it scrolls sideways when they don't fit.
        // At accessibility sizes they wrap instead.
        if (large)
          Wrap(
            spacing: AvoSpacing.s,
            children: [
              for (final chip in chips)
                _AskChip(
                  label: chip,
                  onTap: () => openAvoWithQuestion(context, chip),
                ),
            ],
          )
        else
          // Runs to the card's edges (D2 margin -16, padding 16) and is
          // clipped there.
          LayoutBuilder(
            builder: (context, constraints) => OverflowBox(
              fit: OverflowBoxFit.deferToChild,
              minWidth: constraints.maxWidth + 2 * _kCardPadding.left,
              maxWidth: constraints.maxWidth + 2 * _kCardPadding.left,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: _kCardPadding.left),
                child: Row(
                  children: [
                    for (var i = 0; i < chips.length; i++) ...[
                      if (i > 0) const SizedBox(width: AvoSpacing.s),
                      _AskChip(
                        label: chips[i],
                        onTap: () => openAvoWithQuestion(context, chips[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AvoCard(tone: AvoCardTone.tint, padding: _kCardPadding, child: body),
        if (!large)
          const PositionedDirectional(
            top: _kFigureTop,
            end: _kFigureRight,
            child: AvoFigure(pose: AvoPose.waving, size: _kFigureHeight),
          ),
      ],
    );
  }
}

/// White pill "Frag Avo …" with a dictation button; sending opens the Avo
/// tab with the question.
class _AskAvoField extends StatefulWidget {
  const _AskAvoField();

  @override
  State<_AskAvoField> createState() => _AskAvoFieldState();
}

class _AskAvoFieldState extends State<_AskAvoField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send(String value) {
    if (value.trim().isEmpty) return;
    openAvoWithQuestion(context, value);
    _controller.clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final placeholder = context.tr('home_ask_avo');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(_kAskMinHeight / 2),
        boxShadow: [
          for (final (alpha, y, blur) in _kAskShadows)
            BoxShadow(
              color: colors.shadow.withValues(alpha: alpha),
              offset: Offset(0, y),
              blurRadius: blur,
            ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kAskMinHeight),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: AvoSpacing.l),
                child: CupertinoTextField.borderless(
                  controller: _controller,
                  focusNode: _focus,
                  placeholder: placeholder,
                  placeholderStyle: context.text(
                    AvoTextStyle.body,
                    color: colors.placeholder,
                  ),
                  style: context.text(AvoTextStyle.body),
                  padding: const EdgeInsets.symmetric(vertical: AvoSpacing.m),
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: context.tr('common_dictate'),
              onTap: () => context.go('${RoutePaths.avo}/voice'),
              excludeSemantics: true,
              child: PressableScale(
                onPressed: () => context.go('${RoutePaths.avo}/voice'),
                child: SizedBox.square(
                  dimension: AvoSizes.hitTarget,
                  child: Center(
                    child: AvoIcon(
                      AvoIcons.mic,
                      size: 20,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AvoSpacing.xxs),
          ],
        ),
      ),
    );
  }
}

/// White question chip (D2 `.chip-w`): 13/18, 34 pt pill in a 44 pt target.
class _AskChip extends StatelessWidget {
  const _AskChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      onTap: onTap,
      child: PressableScale(
        onPressed: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AvoSizes.hitTarget),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(_kChipHeight / 2),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: _kChipShadowAlpha),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _kChipHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, // D2
                    vertical: AvoSpacing.s,
                  ),
                  child: Text(
                    label,
                    style: context.text(
                      AvoTextStyle.footnote,
                      color: colors.tertiaryLabel,
                    ),
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
