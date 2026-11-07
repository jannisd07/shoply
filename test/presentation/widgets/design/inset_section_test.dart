import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/inset_section.dart';

import '../../../layout/layout_matrix.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  LayoutCase layout = const LayoutCase(width: 390, scale: 1),
}) async {
  tester.view.physicalSize = Size(layout.width * 3, kLayoutHeight * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    layoutHarness(layout, Align(alignment: Alignment.topCenter, child: child)),
  );
}

/// A simple row like the ones that go into a section.
class _Row extends StatelessWidget {
  const _Row(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AvoSpacing.l,
      vertical: AvoSpacing.m,
    ),
    child: Text(text, style: context.text(AvoTextStyle.body)),
  );
}

Finder _hairlines() => find.byWidgetPredicate(
  (w) => w is SizedBox && w.height == AvoSizes.hairline,
);

void main() {
  group('SectionCaps', () {
    testWidgets('shows upper case, reads normal case as a heading', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const SectionCaps('Obst & Gemüse'));
      expect(find.text('OBST & GEMÜSE'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Obst & Gemüse')),
        isSemantics(label: 'Obst & Gemüse', isHeader: true),
      );
      expect(find.bySemanticsLabel('OBST & GEMÜSE'), findsNothing);
      handle.dispose();
    });

    testWidgets('caps style: 13/18 semibold secondaryLabel, +0.3 tracking', (
      tester,
    ) async {
      await _pump(tester, const SectionCaps('Milchprodukte'));
      final style = tester.widget<Text>(find.text('MILCHPRODUKTE')).style!;
      expect(style.color, AvoColors.light.secondaryLabel);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.fontSize, 13);
      expect(
        style.letterSpacing,
        closeTo(AvoTypography.trackingFor(13) + 0.3, 0.001),
      );
    });

    testWidgets('upper-cases ß as SS', (tester) async {
      await _pump(tester, const SectionCaps('Süßwaren'));
      expect(find.text('SÜSSWAREN'), findsOneWidget);
    });

    testWidgets('upper-cases a Turkish i with its dot', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: const Locale('tr'),
            child: const SectionCaps('istanbul'),
          ),
        ),
      );
      expect(find.text('İSTANBUL'), findsOneWidget);
    });

    testWidgets('default padding is D2 20 32 6', (tester) async {
      await _pump(
        tester,
        const SizedBox(width: 390, child: SectionCaps('Backwaren')),
      );
      final text = tester.getRect(find.text('BACKWAREN'));
      final box = tester.getRect(find.byType(SectionCaps));
      expect(text.left - box.left, 32);
      expect(text.top - box.top, 20);
      expect(box.bottom - text.bottom, 6);
    });

    testWidgets('trailing sits at the end, below the text from AX1', (
      tester,
    ) async {
      Widget caps() => const SizedBox(
        width: 390,
        child: SectionCaps('Haushalt', trailing: Text('3')),
      );
      await _pump(tester, caps());
      var heading = tester.getRect(find.text('HAUSHALT'));
      var count = tester.getRect(find.text('3'));
      expect(count.left, greaterThan(heading.right));
      expect(count.right, closeTo(390 - 32, 0.5));
      final countStyle = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text('3'),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(countStyle.style.fontWeight, FontWeight.w400);

      await _pump(
        tester,
        caps(),
        layout: const LayoutCase(width: 390, scale: 2),
      );
      heading = tester.getRect(find.text('HAUSHALT'));
      count = tester.getRect(find.text('3'));
      expect(count.top, greaterThanOrEqualTo(heading.bottom));
      expect(count.left, heading.left);
    });
  });

  group('InsetSection', () {
    testWidgets('renders nothing without children', (tester) async {
      await _pump(
        tester,
        const InsetSection(header: 'Leer', footer: 'Nichts', children: []),
      );
      expect(tester.getSize(find.byType(InsetSection)), Size.zero);
      expect(find.text('LEER'), findsNothing);
    });

    testWidgets('inset group: 16 pt margins, radius 26, surface colour', (
      tester,
    ) async {
      await _pump(
        tester,
        const SizedBox(
          width: 390,
          child: InsetSection(children: [_Row('Hafermilch')]),
        ),
      );
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clip.borderRadius, BorderRadius.circular(AvoRadii.group));
      final group = tester.getRect(find.byType(ClipRRect));
      expect(group.left, 16);
      expect(group.right, 390 - 16);
      final fill = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ClipRRect),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(fill.color, AvoColors.light.surface);
    });

    testWidgets('hairlines between rows from the indent', (tester) async {
      await _pump(
        tester,
        const SizedBox(
          width: 390,
          child: InsetSection(
            separatorIndent: 58,
            children: [_Row('Avocados'), _Row('Bananen'), _Row('Feta')],
          ),
        ),
      );
      expect(_hairlines(), findsNWidgets(2));
      final line = tester.getRect(_hairlines().first);
      expect(line.left, 16 + 58);
      expect(line.right, 390 - 16);
      expect(line.height, AvoSizes.hairline);
      final colour = tester.widget<ColoredBox>(
        find.descendant(
          of: _hairlines().first,
          matching: find.byType(ColoredBox),
        ),
      );
      expect(colour.color, AvoColors.light.separator);
    });

    testWidgets('no hairlines when switched off', (tester) async {
      await _pump(
        tester,
        const InsetSection(
          showSeparators: false,
          children: [_Row('Avocados'), _Row('Bananen')],
        ),
      );
      expect(_hairlines(), findsNothing);
    });

    testWidgets('plain: edge to edge, no rounding', (tester) async {
      await _pump(
        tester,
        const SizedBox(
          width: 390,
          child: InsetSection(plain: true, children: [_Row('Eier')]),
        ),
      );
      expect(find.byType(ClipRRect), findsNothing);
      expect(tester.getRect(find.byType(ColoredBox).last).left, 0);
    });

    testWidgets('turns plain from AX1 on', (tester) async {
      await _pump(
        tester,
        const SizedBox(
          width: 390,
          child: InsetSection(header: 'Kühlregal', children: [_Row('Feta')]),
        ),
        layout: const LayoutCase(width: 390, scale: 2),
      );
      expect(find.byType(ClipRRect), findsNothing);
      final heading = tester.getRect(find.text('KÜHLREGAL'));
      expect(heading.left, 16);
    });

    testWidgets('header and footer around the group', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const SizedBox(
          width: 390,
          child: InsetSection(
            header: 'Module',
            headerTrailing: Text('4'),
            footer: 'Module lassen sich jederzeit wieder einschalten.',
            children: [_Row('Angebote')],
          ),
        ),
      );
      final heading = tester.getRect(find.text('MODULE'));
      final row = tester.getRect(find.text('Angebote'));
      final footer = tester.getRect(
        find.text('Module lassen sich jederzeit wieder einschalten.'),
      );
      expect(heading.bottom, lessThan(row.top));
      expect(footer.top, greaterThan(row.bottom));
      expect(heading.left, 32);
      expect(footer.left, 32);
      expect(find.text('4'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Module')),
        isSemantics(label: 'Module', isHeader: true),
      );
      final footerStyle = tester
          .widget<Text>(
            find.text('Module lassen sich jederzeit wieder einschalten.'),
          )
          .style!;
      expect(footerStyle.color, AvoColors.light.secondaryLabel);
      handle.dispose();
    });
  });

  layoutMatrix(
    'SectionCaps with a count',
    (context) => const SectionCaps(
      'Laktosefreie Bio-Milchprodukte und Käse',
      trailing: Text('12'),
    ),
  );

  layoutMatrix(
    'InsetSection with header, rows and footer',
    (context) => const InsetSection(
      header: 'Milchprodukte',
      headerTrailing: Text('3'),
      footer:
          'Preise laut Händler, in deiner Region. Stand: Samstag, 7. November, 1,29 € je Liter.',
      separatorIndent: 58,
      children: [
        _Row('Laktosefreie Bio-Vollmilch 3,8 % Fett, 1 l'),
        _Row('Hafermilch'),
        _Row('Feta, 200 g'),
      ],
    ),
    scrollable: true,
  );
}
