import 'package:flutter/cupertino.dart';

import 'package:shoply/presentation/screens/avo/avo_suggestions.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

// Glyphs of the Avo tab that are not in [AvoIcons] (requested from Teil A).
// Drawn on the 24 grid like the D2 set.

/// "Neues Gespräch": speech bubble with a plus (SF `plus.bubble`).
const AvoIconData avoNewConversationIcon = AvoIconData([
  AvoIconPath(
    'M6.5 3.5h11A2.5 2.5 0 0 1 20 6v7.5a2.5 2.5 0 0 1-2.5 2.5H11L6.5 20v-4'
    'A2.5 2.5 0 0 1 4 13.5V6a2.5 2.5 0 0 1 2.5-2.5z',
  ),
  AvoIconPath('M12 6.8v6M9 9.8h6'),
], strokeWidth: 1.8); // D2 stroke

/// SF `leaf`.
const AvoIconData avoLeafIcon = AvoIconData([
  AvoIconPath('M5 19c0-8.3 5.2-14 14-14 0 8.8-5.7 14-14 14z'),
  AvoIconPath('M5 19l7.5-7.5'),
], strokeWidth: 1.8); // D2 stroke

/// SF `switch.2`.
const AvoIconData avoTogglesIcon = AvoIconData([
  AvoIconRect(3, 4.5, 18, 6, radius: 3),
  AvoIconCircle(16, 7.5, 1.6, style: AvoIconStyle.fill),
  AvoIconRect(3, 13.5, 18, 6, radius: 3),
  AvoIconCircle(8, 16.5, 1.6, style: AvoIconStyle.fill),
], strokeWidth: 1.8); // D2 stroke

/// The glyph of a suggestion at [size], in the surrounding icon colour.
Widget avoSuggestionGlyph(AvoSuggestionSymbol symbol, {required double size}) =>
    switch (symbol) {
      AvoSuggestionSymbol.plus => AvoIcon(AvoIcons.plus, size: size),
      AvoSuggestionSymbol.tag => AvoIcon(AvoIcons.tag, size: size),
      AvoSuggestionSymbol.clockArrow => AvoIcon(AvoIcons.clock, size: size),
      AvoSuggestionSymbol.forkKnife => AvoIcon(AvoIcons.forkKnife, size: size),
      AvoSuggestionSymbol.checklist => Icon(
        CupertinoIcons.square_list,
        size: size,
      ),
      AvoSuggestionSymbol.checkmark => AvoIcon(AvoIcons.check, size: size),
      AvoSuggestionSymbol.leaf => AvoIcon(avoLeafIcon, size: size),
      AvoSuggestionSymbol.bookmark => AvoIcon(AvoIcons.bookmark, size: size),
      AvoSuggestionSymbol.list => Icon(CupertinoIcons.list_bullet, size: size),
      AvoSuggestionSymbol.halfCircle => Icon(
        CupertinoIcons.circle_lefthalf_fill,
        size: size,
      ),
      AvoSuggestionSymbol.toggles => AvoIcon(avoTogglesIcon, size: size),
    };
