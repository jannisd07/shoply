import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';
import 'package:shoply/presentation/widgets/design/app_tab_bar.dart';
import 'package:shoply/presentation/widgets/design/avo_icons.dart';

import '../../../layout/layout_matrix.dart';

const _items = [
  AppTabItem(icon: AvoIcons.home, label: 'Home'),
  AppTabItem(icon: AvoIcons.cart, label: 'Listen'),
  AppTabItem(icon: AvoIcons.sparkle, label: 'Avo'),
  AppTabItem(icon: AvoIcons.forkKnife, label: 'Rezepte'),
  AppTabItem(icon: AvoIcons.person, label: 'Profil'),
];

Widget _bar({int selected = 1, ValueChanged<int>? onSelect}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AvoSizes.tabBarSide),
      child: AppTabBar(
        items: _items,
        selectedIndex: selected,
        onSelect: onSelect ?? (_) {},
      ),
    );

void main() {
  layoutMatrix('AppTabBar', (context) => _bar(), checkTapTargets: true);

  testWidgets('tapping a tab reports its index, no haptics', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    int? tapped;
    await tester.pumpWidget(layoutHarness(
      const LayoutCase(width: 390, scale: 1),
      Align(
        alignment: Alignment.bottomCenter,
        child: _bar(onSelect: (i) => tapped = i),
      ),
    ));
    await tester.tap(find.text('Rezepte'));
    expect(tapped, 3);
    expect(calls.where((c) => c.method == 'HapticFeedback.vibrate'), isEmpty);
  });

  testWidgets('VoiceOver: label, position and selected state', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(layoutHarness(
      const LayoutCase(width: 390, scale: 1),
      Align(alignment: Alignment.bottomCenter, child: _bar(selected: 1)),
    ));
    expect(
      tester.getSemantics(find.text('Listen').first),
      matchesSemantics(
        label: 'Listen',
        hint: 'Tab 2 of 5',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    // The bar keeps its D2 height wherever it is placed.
    expect(tester.getSize(find.byType(AppTabBar)).height,
        AvoSizes.tabBarHeight);
    handle.dispose();
  });
}
