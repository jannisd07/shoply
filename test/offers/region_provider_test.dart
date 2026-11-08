// The region of the offers (Kap. 12, rule 4): a real zip code from the
// location or typed by the person, never a stand-in like 10115. Loading it
// never asks for location permission; only "Standort verwenden" does.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/user_location_service.dart';
import 'package:shoply/presentation/providers/region_provider.dart';

class _FakeLookup implements RegionLookup {
  _FakeLookup([this.region]);

  Region? region;
  final prompts = <bool>[];
  final saved = <String>[];
  final located = <Region>[];
  var removed = 0;
  var locates = 0;
  LocateResult locateResult = const LocateResult(
    LocateOutcome.found,
    region: Region(zip: '79098', city: 'Freiburg', source: RegionSource.gps),
  );
  final _changes = StreamController<void>.broadcast();

  void changeElsewhere(Region? next) {
    region = next;
    _changes.add(null);
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Region?> getRegion({
    bool allowPermissionPrompt = false,
    bool forceRefresh = false,
  }) async {
    prompts.add(allowPermissionPrompt);
    return region;
  }

  @override
  Future<void> setManualZipCode(String zip) async {
    saved.add(zip);
    region = zip.isEmpty
        ? null
        : Region(zip: zip, source: RegionSource.manual);
    _changes.add(null);
  }

  @override
  Future<LocateResult> locate() async {
    locates++;
    return locateResult;
  }

  @override
  Future<void> saveLocatedRegion(Region next) async {
    located.add(next);
    region = next;
    _changes.add(null);
  }

  @override
  Future<void> removeRegion() async {
    removed++;
    region = null;
    _changes.add(null);
  }
}

ProviderContainer _container(_FakeLookup lookup) {
  final container = ProviderContainer(
    overrides: [regionLookupProvider.overrideWithValue(lookup)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('unknown while loading, then the real region', () async {
    final lookup = _FakeLookup(
      const Region(zip: '89077', city: 'Ulm', source: RegionSource.gps),
    );
    final container = _container(lookup);

    expect(container.read(regionProvider), isNull);
    expect(container.read(regionLoadedProvider), isFalse);
    await _settle();

    expect(
      container.read(regionProvider),
      const Region(zip: '89077', city: 'Ulm', source: RegionSource.gps),
    );
    expect(container.read(regionLoadedProvider), isTrue);
  });

  test('without location and without a typed zip there is no region', () async {
    final container = _container(_FakeLookup());
    container.read(regionProvider);
    await _settle();

    expect(container.read(regionProvider), isNull);
    expect(container.read(regionLoadedProvider), isTrue);
  });

  test('loading never asks for location permission', () async {
    final lookup = _FakeLookup();
    final container = _container(lookup);
    container.read(regionProvider);
    await _settle();

    expect(lookup.prompts, [false]);
  });

  test('a typed zip code becomes the region everywhere', () async {
    final lookup = _FakeLookup();
    final container = _container(lookup);
    container.read(regionProvider);
    await _settle();

    final ok = await container
        .read(regionControllerProvider.notifier)
        .setManualZip(' 79098 ');
    await _settle();

    expect(ok, isTrue);
    expect(lookup.saved, ['79098']);
    expect(container.read(regionProvider)?.zip, '79098');
    expect(container.read(regionProvider)?.source, RegionSource.manual);
  });

  test('a zip code without five digits is refused', () async {
    final lookup = _FakeLookup();
    final container = _container(lookup);
    container.read(regionProvider);
    await _settle();

    final notifier = container.read(regionControllerProvider.notifier);
    expect(await notifier.setManualZip('1011'), isFalse);
    expect(await notifier.setManualZip('abcde'), isFalse);
    expect(lookup.saved, isEmpty);
    expect(container.read(regionProvider), isNull);
  });

  test('"Region entfernen" leaves no region, at once', () async {
    final lookup = _FakeLookup(
      const Region(zip: '79098', source: RegionSource.manual),
    );
    final container = _container(lookup);
    container.read(regionProvider);
    await _settle();

    final done = container.read(regionControllerProvider.notifier).remove();
    expect(container.read(regionProvider), isNull);
    await done;
    await _settle();

    expect(lookup.removed, 1);
    expect(container.read(regionProvider), isNull);
  });

  test('a located region is saved as the location, a typed one as the zip',
      () async {
    final lookup = _FakeLookup();
    final container = _container(lookup);
    container.read(regionProvider);
    await _settle();
    final notifier = container.read(regionControllerProvider.notifier);

    const gps = Region(zip: '89077', city: 'Ulm', source: RegionSource.gps);
    await notifier.saveRegion(gps);
    expect(lookup.located, [gps]);
    expect(container.read(regionProvider), gps);

    await notifier.saveRegion(
      const Region(zip: '10115', source: RegionSource.manual),
    );
    expect(lookup.saved, ['10115']);
    expect(container.read(regionProvider)?.zip, '10115');
  });

  test('a change saved elsewhere (profile, Avo) shows at once', () async {
    final lookup = _FakeLookup();
    final container = _container(lookup);
    container.read(regionProvider);
    await _settle();

    lookup.changeElsewhere(
      const Region(zip: '10117', source: RegionSource.manual),
    );
    await _settle();
    await _settle();

    expect(container.read(regionProvider)?.zip, '10117');
  });

  test('"Standort verwenden" finds the region but saves nothing', () async {
    final lookup = _FakeLookup();
    final container = _container(lookup);
    container.read(regionProvider);
    await _settle();

    final result = await container
        .read(regionControllerProvider.notifier)
        .locate();

    expect(lookup.locates, 1);
    expect(result.region?.zip, '79098');
    expect(lookup.located, isEmpty);
    expect(lookup.saved, isEmpty);
    expect(container.read(regionProvider), isNull);
  });

  test('a German zip code has exactly five digits', () {
    expect(isValidZip('10115'), isTrue);
    expect(isValidZip(''), isFalse);
    expect(isValidZip('1011'), isFalse);
    expect(isValidZip('101155'), isFalse);
  });

  test('zone 00 and 99999 are no German zip codes', () {
    expect(isKnownZip('01067'), isTrue);
    expect(isKnownZip('79098'), isTrue);
    expect(isKnownZip('00123'), isFalse);
    expect(isKnownZip('99999'), isFalse);
    expect(isKnownZip('7909'), isFalse);
  });
}
