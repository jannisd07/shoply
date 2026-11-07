import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/core/design/design.dart';

void main() {
  test('springs convert response and damping ratio (Konzept 00 §10.1)', () {
    expect(AvoMotion.standard.stiffness, closeTo(322.27, 0.05));
    expect(AvoMotion.standard.damping, closeTo(35.90, 0.05));
    expect(AvoMotion.quick.stiffness, closeTo(631.65, 0.05));
    expect(AvoMotion.quick.damping, closeTo(50.27, 0.05));
    expect(AvoMotion.menu.stiffness, closeTo(438.65, 0.05));
    expect(AvoMotion.move.stiffness, closeTo(246.74, 0.05));
    expect(AvoMotion.fling.damping, closeTo(28.72, 0.05));
    expect(AvoMotion.celebrate.damping, closeTo(25.13, 0.05));
    expect(AvoMotion.standard.mass, 1);
  });

  test('momentum projection and rubber band', () {
    expect(AvoMotion.project(1000), closeTo(499, 0.01));
    expect(AvoMotion.rubberBand(0, 300), 0);
    expect(AvoMotion.rubberBand(100, 300), lessThan(100));
  });

  testWidgets('reduce motion follows the system setting', (tester) async {
    late bool reduced;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Builder(builder: (context) {
        reduced = context.reduceMotion;
        return const SizedBox();
      }),
    ));
    expect(reduced, isTrue);
  });
}
