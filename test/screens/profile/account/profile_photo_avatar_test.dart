import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/screens/profile/account/account_widgets.dart';

/// A 4 x 3 px landscape PNG.
final _landscape = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAADCAIAAAA7ljmRAAAAEElEQVR4nGP4z8AARww4OQD1MQv1NXv7ggAAAABJRU5ErkJggg==',
);

void main() {
  testWidgets('a landscape photo fills the whole circle', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: AvoDesignScope(
          child: Center(
            child: ProfilePhotoAvatar(name: 'Jannis', photo: _landscape),
          ),
        ),
      ),
    );
    // Let the image decode, so the photo itself (not the initials) is laid out.
    await tester.runAsync(() async {
      await precacheImage(
        MemoryImage(_landscape),
        tester.element(find.byType(ProfilePhotoAvatar)),
      );
    });
    await tester.pump();
    expect(find.byType(RawImage), findsOneWidget);
    expect(
      tester.getSize(find.byType(RawImage)),
      const Size(kProfileAvatarSize, kProfileAvatarSize),
    );
  });
}
