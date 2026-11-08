import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shoply/data/services/native/accessibility_channel.dart';

/// The native accessibility channel; overridden in tests.
final accessibilityChannelProvider = Provider<AccessibilityChannel>(
  (ref) => AccessibilityChannel.instance,
);

/// iOS "Reduce Transparency". True means glass drawn in Flutter should fall
/// back to opaque surfaces. Read it as `ref.watch(reduceTransparencyProvider)
/// .valueOrNull ?? false` so the first frame does not wait for the channel.
final reduceTransparencyProvider = StreamProvider<bool>(
  (ref) => ref.watch(accessibilityChannelProvider).watchReduceTransparency(),
);
