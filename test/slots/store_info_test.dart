// storeForListProvider (contract b_slots.dart): synchronous, and only a
// confirmed market becomes a StoreInfo; a mere suggestion stays null.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shoply/data/models/store_info.dart';
import 'package:shoply/data/services/store_detection_service.dart';
import 'package:shoply/presentation/providers/store_for_list_provider.dart';

void main() {
  test('short labels for the D2 letter tile', () {
    expect(storeShortLabel('Lidl'), 'L');
    expect(storeShortLabel('Aldi Süd'), 'AS');
    expect(storeShortLabel('REWE'), 'R');
    expect(storeShortLabel(''), '');
  });

  test('unknown chain id has no StoreInfo', () {
    expect(storeInfoForChain('no-such-chain'), isNull);
  });

  Future<StoreInfo?> storeFor(StoreGuess? guess) async {
    final container = ProviderContainer(
      overrides: [
        storeGuessForListProvider.overrideWith((ref, id) async => guess),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(storeForListProvider('l')), isNull,
        reason: 'null while loading, never waits');
    await container.read(storeGuessForListProvider('l').future);
    return container.read(storeForListProvider('l'));
  }

  test('a confirmed market becomes a StoreInfo', () async {
    final info = await storeFor(
      const StoreGuess('lidl', StoreSource.user, confirmed: true),
    );
    expect(info?.id, 'lidl');
    expect(info?.name, 'Lidl');
    expect(info?.shortLabel, 'L');
  });

  test('a suggestion stays null', () async {
    final info = await storeFor(
      const StoreGuess('lidl', StoreSource.name, confirmed: false),
    );
    expect(info, isNull);
  });
}
