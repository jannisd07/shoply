import 'package:flutter/cupertino.dart';

import 'package:shoply/presentation/screens/avo/avo_suggestions.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

/// The glyph of a suggestion at [size], in the surrounding icon colour.
Widget avoSuggestionGlyph(AvoSuggestionSymbol symbol, {required double size}) =>
    switch (symbol) {
      AvoSuggestionSymbol.plus => AvoIcon(AvoIcons.plus, size: size),
      AvoSuggestionSymbol.tag => AvoIcon(AvoIcons.tag, size: size),
      AvoSuggestionSymbol.clockArrow => AvoIcon(AvoIcons.clock, size: size),
      AvoSuggestionSymbol.forkKnife => AvoIcon(AvoIcons.forkKnife, size: size),
      AvoSuggestionSymbol.checklist => AvoIcon(AvoIcons.checklist, size: size),
      AvoSuggestionSymbol.checkmark => AvoIcon(AvoIcons.check, size: size),
      AvoSuggestionSymbol.leaf => AvoIcon(AvoIcons.leaf, size: size),
      AvoSuggestionSymbol.bookmark => AvoIcon(AvoIcons.bookmark, size: size),
      AvoSuggestionSymbol.list => AvoIcon(AvoIcons.listBullet, size: size),
      AvoSuggestionSymbol.halfCircle => Icon(
        CupertinoIcons.circle_lefthalf_fill,
        size: size,
      ),
      AvoSuggestionSymbol.toggles => AvoIcon(AvoIcons.switch2, size: size),
    };
