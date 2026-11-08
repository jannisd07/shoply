// "Zettel importieren" opens as a pull-down menu (no sheet) from the button,
// also without a ProviderScope or Material ancestor around it.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/localization/app_localizations.dart';
import 'package:shoply/presentation/screens/lists/widgets/attachment_sheet.dart';

void main() {
  testWidgets('import menu opens', (tester) async {
    final plusKey = GlobalKey();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: GestureDetector(
                onTap: () =>
                    showAttachmentSheet(context, plusButtonKey: plusKey),
                child: Container(key: plusKey, width: 44, height: 44,
                    color: const Color(0xFF888888)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(plusKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // All four sources, without an exception (which would fail the test on
    // its own).
    expect(find.text('Foto aufnehmen'), findsOneWidget);
    expect(find.text('Foto wählen'), findsOneWidget);
    expect(find.text('Datei wählen'), findsOneWidget);
    expect(find.text('Text einfügen'), findsOneWidget);
  });
}
