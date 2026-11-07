import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shoply/core/modules/app_modules.dart';
import 'package:shoply/data/services/app_flags_service.dart';
import 'package:shoply/presentation/providers/app_flags_provider.dart';

const _limits = {
  'free': {'avo_chat': 3, 'meal_photo': 1},
  'pro': {'avo_chat': 60, 'meal_photo': 15},
};

List<Map<String, dynamic>> _rows({bool offers = true, bool ai = true}) => [
  {'key': 'offers_enabled', 'enabled': offers, 'value': null},
  {'key': 'ai_enabled', 'enabled': ai, 'value': null},
  {'key': 'ai_limits', 'enabled': true, 'value': _limits},
];

/// The cache entry a successful refresh of [_rows] writes.
String _cached({bool offers = true, bool ai = true}) =>
    jsonEncode(AppFlags.fromRows(_rows(offers: offers, ai: ai)).toJson());

/// Fetcher that answers with [answers] in order; an [Exception] is thrown.
class _ScriptedFetcher {
  _ScriptedFetcher(this.answers);

  final List<Object> answers;
  int calls = 0;

  Future<List<Map<String, dynamic>>> call() async {
    final answer = answers[calls < answers.length ? calls : answers.length - 1];
    calls++;
    if (answer is Exception) throw answer;
    return answer as List<Map<String, dynamic>>;
  }
}

/// Lets pending futures, stream events and Riverpod's scheduled rebuilds
/// (cache read, notifier, dependents) settle.
Future<void> _settle() async {
  for (var turn = 0; turn < 5; turn++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Sends a lifecycle change the way the engine does.
Future<void> _lifecycle(AppLifecycleState state) =>
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          SystemChannels.lifecycle.name,
          SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
          (_) {},
        );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppFlags', () {
    test('an unknown key returns the fallback', () {
      expect(AppFlags.empty.isEnabled('nope'), isTrue);
      expect(AppFlags.empty.isEnabled('nope', fallback: false), isFalse);
    });

    test('a known key wins over the fallback', () {
      const flags = AppFlags(enabled: {'offers_enabled': false});
      expect(flags.isEnabled('offers_enabled'), isFalse);
      expect(flags.isEnabled('offers_enabled', fallback: true), isFalse);
    });

    test('empty is neither loaded nor known', () {
      expect(AppFlags.empty.source, AppFlagsSource.none);
      expect(AppFlags.empty.isLoaded, isFalse);
      expect(AppFlags.empty.isKnown, isFalse);
    });

    test('defaults are loaded but not known', () {
      const flags = AppFlags(source: AppFlagsSource.defaults);
      expect(flags.isLoaded, isTrue);
      expect(flags.isKnown, isFalse);
    });

    test('flags built by hand count as known', () {
      const flags = AppFlags(enabled: {'offers_enabled': true});
      expect(flags.isKnown, isTrue);
    });
  });

  group('AppFlagsService', () {
    test('refresh reads the rows into enabled and values', () async {
      final service = AppFlagsService(
        fetcher: _ScriptedFetcher([_rows(offers: false)]).call,
      );

      final flags = await service.refresh();

      expect(flags.isEnabled(AppFlagKeys.offersEnabled), isFalse);
      expect(flags.isEnabled(AppFlagKeys.aiEnabled), isTrue);
      expect(flags.values[AppFlagKeys.aiLimits], _limits);
      expect(flags.source, AppFlagsSource.server);
      expect(service.current, same(flags));
    });

    test('the cache survives a new service instance (app restart)', () async {
      await AppFlagsService(
        fetcher: _ScriptedFetcher([_rows(ai: false)]).call,
      ).refresh();

      final restarted = AppFlagsService(
        fetcher: _ScriptedFetcher([Exception('offline')]).call,
      );
      expect(
        restarted.current.isLoaded,
        isFalse,
        reason: 'nothing is read before loadCache',
      );

      await restarted.loadCache();

      expect(restarted.current.source, AppFlagsSource.cache);
      expect(restarted.current.isEnabled(AppFlagKeys.aiEnabled), isFalse);
      expect(restarted.current.isEnabled(AppFlagKeys.offersEnabled), isTrue);
      expect(restarted.current.values[AppFlagKeys.aiLimits], _limits);
    });

    test('a missing cache entry loads as defaults', () async {
      final service = AppFlagsService(
        fetcher: _ScriptedFetcher([_rows()]).call,
      );
      final next = service.changes.first;

      await service.loadCache();

      expect(service.current.source, AppFlagsSource.defaults);
      expect((await next).source, AppFlagsSource.defaults);
    });

    test('a broken cache entry loads as defaults', () async {
      SharedPreferences.setMockInitialValues({
        AppFlagsService.cacheKey: 'not json {',
      });
      final service = AppFlagsService(
        fetcher: _ScriptedFetcher([_rows()]).call,
      );

      await service.loadCache();

      expect(service.current.enabled, isEmpty);
      expect(service.current.source, AppFlagsSource.defaults);
    });

    test('a cache entry without flags loads as defaults', () async {
      SharedPreferences.setMockInitialValues({AppFlagsService.cacheKey: '{}'});
      final service = AppFlagsService(
        fetcher: _ScriptedFetcher([_rows()]).call,
      );

      await service.loadCache();

      expect(service.current.source, AppFlagsSource.defaults);
    });

    test('a failing refresh keeps the previous state', () async {
      final fetcher = _ScriptedFetcher([
        _rows(offers: false),
        Exception('timeout'),
      ]);
      final service = AppFlagsService(fetcher: fetcher.call);
      final first = await service.refresh();

      final second = await service.refresh(force: true);

      expect(fetcher.calls, 2);
      expect(second, same(first));
      expect(service.current.isEnabled(AppFlagKeys.offersEnabled), isFalse);
    });

    test('a failing first refresh keeps the cached state', () async {
      SharedPreferences.setMockInitialValues({
        AppFlagsService.cacheKey: _cached(offers: false),
      });
      final service = AppFlagsService(
        fetcher: _ScriptedFetcher([Exception('offline')]).call,
      );
      await service.loadCache();

      final flags = await service.refresh();

      expect(flags.source, AppFlagsSource.cache);
      expect(flags.isEnabled(AppFlagKeys.offersEnabled), isFalse);
    });

    test('an empty answer is not trusted', () async {
      SharedPreferences.setMockInitialValues({
        AppFlagsService.cacheKey: _cached(offers: false),
      });
      final fetcher = _ScriptedFetcher([<Map<String, dynamic>>[], _rows()]);
      final service = AppFlagsService(fetcher: fetcher.call);
      await service.loadCache();

      final flags = await service.refresh();

      expect(flags.source, AppFlagsSource.cache);
      expect(flags.isEnabled(AppFlagKeys.offersEnabled), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppFlagsService.cacheKey), _cached(offers: false));

      await service.refresh();
      expect(fetcher.calls, 2, reason: 'an empty answer is not throttled');
      expect(service.current.isEnabled(AppFlagKeys.offersEnabled), isTrue);
    });

    test(
      'refresh is skipped for 30 minutes after a success unless forced',
      () async {
        var now = DateTime(2026, 11, 8, 12);
        final fetcher = _ScriptedFetcher([_rows()]);
        final service = AppFlagsService(
          fetcher: fetcher.call,
          clock: () => now,
        );

        await service.refresh();
        now = now.add(const Duration(minutes: 29));
        await service.refresh();
        expect(fetcher.calls, 1);

        await service.refresh(force: true);
        expect(fetcher.calls, 2);

        now = now.add(const Duration(minutes: 31));
        await service.refresh();
        expect(fetcher.calls, 3);
      },
    );

    test('a clock that went back does not block refreshes', () async {
      var now = DateTime(2026, 11, 8, 12);
      final fetcher = _ScriptedFetcher([_rows()]);
      final service = AppFlagsService(fetcher: fetcher.call, clock: () => now);

      await service.refresh();
      now = now.subtract(const Duration(hours: 3));
      await service.refresh();

      expect(fetcher.calls, 2);
    });

    test('concurrent refreshes share one request', () async {
      final fetcher = _ScriptedFetcher([_rows()]);
      final service = AppFlagsService(fetcher: fetcher.call);

      await Future.wait([
        service.refresh(force: true),
        service.refresh(force: true),
      ]);

      expect(fetcher.calls, 1);
    });

    test('a failed refresh is not throttled', () async {
      final fetcher = _ScriptedFetcher([Exception('offline'), _rows()]);
      final service = AppFlagsService(fetcher: fetcher.call);

      await service.refresh();
      await service.refresh();

      expect(fetcher.calls, 2);
    });

    test('a cache read racing a refresh does not overwrite it', () async {
      SharedPreferences.setMockInitialValues({
        AppFlagsService.cacheKey: _cached(offers: false),
      });
      // Warm the instance so the cache read finishes right after the fetch.
      await SharedPreferences.getInstance();
      final service = AppFlagsService(
        fetcher: _ScriptedFetcher([_rows()]).call,
      );

      await Future.wait([service.refresh(), service.loadCache()]);

      expect(service.current.source, AppFlagsSource.server);
      expect(service.current.isEnabled(AppFlagKeys.offersEnabled), isTrue);
    });

    test('changes emits the refreshed flags', () async {
      final service = AppFlagsService(
        fetcher: _ScriptedFetcher([_rows(ai: false)]).call,
      );
      final next = service.changes.first;

      await service.refresh();

      expect((await next).isEnabled(AppFlagKeys.aiEnabled), isFalse);
    });
  });

  group('providers', () {
    ProviderContainer container(AppFlagsService service, {bool module = true}) {
      final c = ProviderContainer(
        overrides: [
          appFlagsServiceProvider.overrideWithValue(service),
          moduleEnabledProvider(AppModule.offers).overrideWithValue(module),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    /// Every value [provider] takes, starting with the first one.
    List<bool> record(ProviderContainer c, ProviderListenable<bool> provider) {
      final seen = <bool>[];
      c.listen<bool>(
        provider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );
      return seen;
    }

    test('a cached off is off from the very first value', () async {
      SharedPreferences.setMockInitialValues({
        AppFlagsService.cacheKey: _cached(offers: false, ai: false),
      });
      final service = AppFlagsService(
        fetcher: _ScriptedFetcher([Exception('offline')]).call,
      );

      final c = container(service);
      final offers = record(c, offersAvailableProvider);
      final ai = record(c, aiRemoteEnabledProvider);
      await _settle();

      expect(offers, [false]);
      expect(ai, [false]);
      expect(c.read(appFlagsProvider).source, AppFlagsSource.cache);
    });

    test('the notifier loads the cache by itself', () async {
      SharedPreferences.setMockInitialValues({
        AppFlagsService.cacheKey: _cached(),
      });
      final fetcher = _ScriptedFetcher([Exception('offline')]);
      final service = AppFlagsService(fetcher: fetcher.call);

      final c = container(service);
      final offers = record(c, offersAvailableProvider);
      await _settle();

      expect(offers, [false, true]);
      expect(fetcher.calls, 0);
    });

    test('offers stay off until the flags are known', () async {
      final service = AppFlagsService(
        fetcher: _ScriptedFetcher([_rows()]).call,
      );

      final c = container(service);
      final offers = record(c, offersRemoteEnabledProvider);
      final ai = record(c, aiRemoteEnabledProvider);
      await _settle();

      expect(c.read(appFlagsProvider).source, AppFlagsSource.defaults);
      expect(offers, [false], reason: 'no cache: the offers source stays shut');
      expect(ai, [false, true], reason: 'ai opens once the cache was read');

      await service.refresh();
      await _settle();

      expect(offers, [false, true]);
    });

    test('offers follow the kill switch from off to on', () async {
      SharedPreferences.setMockInitialValues({
        AppFlagsService.cacheKey: _cached(offers: false),
      });
      final service = AppFlagsService(
        fetcher: _ScriptedFetcher([_rows()]).call,
      );
      final c = container(service);
      final offers = record(c, offersAvailableProvider);
      await _settle();

      await service.refresh();
      await _settle();

      expect(offers, [false, true]);
      expect(c.read(offersRemoteEnabledProvider), isTrue);
      expect(c.read(aiRemoteEnabledProvider), isTrue);
    });

    test('offers are unavailable when the module is off', () async {
      final service = AppFlagsService(
        fetcher: _ScriptedFetcher([_rows()]).call,
      );
      final c = container(service, module: false);
      final offers = record(c, offersAvailableProvider);

      await service.refresh();
      await _settle();

      expect(c.read(offersRemoteEnabledProvider), isTrue);
      expect(offers, [false]);
    });

    test('offers are unavailable when the kill switch turns off', () async {
      SharedPreferences.setMockInitialValues({
        AppFlagsService.cacheKey: _cached(),
      });
      final service = AppFlagsService(
        fetcher: _ScriptedFetcher([_rows(offers: false)]).call,
      );
      final c = container(service);
      final offers = record(c, offersAvailableProvider);
      await _settle();

      await service.refresh();
      await _settle();

      expect(offers, [false, true, false]);
      expect(c.read(offersRemoteEnabledProvider), isFalse);
    });

    test('the ai kill switch follows ai_enabled', () async {
      final service = AppFlagsService(
        fetcher: _ScriptedFetcher([_rows(ai: false)]).call,
      );
      final c = container(service);
      c.listen(aiRemoteEnabledProvider, (_, __) {});

      await service.refresh();
      await _settle();

      expect(c.read(aiRemoteEnabledProvider), isFalse);
      expect(c.read(offersRemoteEnabledProvider), isTrue);
    });

    test('coming back to the foreground refreshes, throttled', () async {
      final fetcher = _ScriptedFetcher([_rows(offers: false)]);
      final service = AppFlagsService(fetcher: fetcher.call);
      final c = container(service);
      c.read(appFlagsProvider);
      await _settle();

      await _lifecycle(AppLifecycleState.paused);
      await _lifecycle(AppLifecycleState.resumed);
      await _settle();

      expect(fetcher.calls, 1);
      expect(c.read(appFlagsProvider).source, AppFlagsSource.server);

      await _lifecycle(AppLifecycleState.paused);
      await _lifecycle(AppLifecycleState.resumed);
      await _settle();

      expect(fetcher.calls, 1, reason: 'within 30 minutes of the last success');
    });

    test('a disposed notifier no longer refreshes on resume', () async {
      final fetcher = _ScriptedFetcher([_rows()]);
      final service = AppFlagsService(fetcher: fetcher.call);
      final c = ProviderContainer(
        overrides: [appFlagsServiceProvider.overrideWithValue(service)],
      );
      c.read(appFlagsProvider);
      await _settle();
      c.dispose();

      await _lifecycle(AppLifecycleState.paused);
      await _lifecycle(AppLifecycleState.resumed);
      await _settle();

      expect(fetcher.calls, 0);
    });
  });
}
