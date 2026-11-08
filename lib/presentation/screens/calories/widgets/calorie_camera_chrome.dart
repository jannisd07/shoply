import 'package:flutter/widgets.dart';

import 'package:shoply/core/design/design.dart';

// The camera screens are drawn natively (`shoply/scanner`, `shoply/camera`);
// these pieces are the Flutter page behind them, so the cross-fade in and
// out stays black and the lookup after a scan sits on the same ground.
const Color _kCameraBlack = Color(0xFF000000); // D2 camera background
const Color _kHintCapsule = Color(0x99000000); // D2 rgba(0,0,0,.6), 5.7:1 on white motifs
const Color _kOnCamera = Color(0xFFFFFFFF); // D2 white on the camera
const double _kHintRadius = 16; // D2

/// The black ground of a camera screen.
class CameraBackdrop extends StatelessWidget {
  const CameraBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: _kCameraBlack, child: child);
}

/// White 15/20 text on the dark hint capsule (D2: radius 16, padding 12/8).
/// A live region, so a changed text ("… wird gesucht …") is announced.
class CameraHintCapsule extends StatelessWidget {
  const CameraHintCapsule({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _kHintCapsule,
          borderRadius: BorderRadius.circular(_kHintRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AvoSpacing.m, vertical: AvoSpacing.s),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: context.text(AvoTextStyle.subhead, color: _kOnCamera, tabular: true),
          ),
        ),
      ),
    );
  }
}
