// Guards against the "No Material widget found" regression: the attachment
// sheet is a PopupRoute, which provides no Material ancestor for its InkWells.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/localization/app_localizations.dart';
import 'package:shoply/presentation/screens/lists/widgets/attachment_sheet.dart';

void main() {
  testWidgets('attachment sheet opens', (tester) async {
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

    // Report what the sheet rendered, then let any pending exception surface
    // through the normal test-failure path.
    // ignore: avoid_print
    print('>>> Kamera sichtbar: ${find.text('Kamera').evaluate().length}');
    // ignore: avoid_print
    print('>>> Fotos  sichtbar: ${find.text('Fotos').evaluate().length}');
    // ignore: avoid_print
    print('>>> Dateien sichtbar: ${find.text('Dateien').evaluate().length}');
  });
}
