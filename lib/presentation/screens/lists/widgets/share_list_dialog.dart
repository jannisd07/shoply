import 'package:flutter/widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/presentation/screens/lists/widgets/share_list_screen.dart';
import 'package:shoply/presentation/widgets/design/full_screen_editor.dart';

/// Opens "Liste teilen" full screen (Konzept 11 §9; the name stays from the
/// old dialog so every caller keeps working). Opens at once: the code is
/// only made when the person invites or shows it and the list has none.
Future<void> showShareListDialog(
  BuildContext context,
  WidgetRef ref, {
  required String listId,
  required String listName,
}) async {
  var intro = false;
  try {
    intro = await ref.read(shareNotificationIntroProvider.future);
  } catch (e) {
    debugPrint('⚠️ [SHARE_LIST] Intro check failed: $e');
  }
  if (!context.mounted) return;
  await pushFullScreenEditor<void>(
    context,
    (_) => ShareListScreen(
      listId: listId,
      listName: listName,
      showIntro: intro,
    ),
  );
}
