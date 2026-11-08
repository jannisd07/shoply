import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shoply/data/services/native/barcode_scanner_channel.dart';
import 'package:shoply/data/services/native/native_channel_errors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const method = MethodChannel('shoply/scanner');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];

  void answer(Object? Function(MethodCall call) reply) {
    messenger.setMockMethodCallHandler(method, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  setUp(calls.clear);
  tearDown(() => messenger.setMockMethodCallHandler(method, null));

  BarcodeScannerChannel ios() => BarcodeScannerChannel(isSupported: () => true);

  const labels = BarcodeScannerLabels(
    hint: 'Strichcode in den Rahmen halten',
    manualEntry: 'Nummer eingeben',
    close: 'Zurück',
    torch: 'Taschenlampe',
    torchOn: 'An',
    torchOff: 'Aus',
  );

  group('isSupported', () {
    test('asks the native side', () async {
      answer((_) => true);

      expect(await ios().isSupported(), isTrue);
      expect(calls.single.method, 'isSupported');
    });

    test('is false on iOS 15 or devices without the scanner', () async {
      answer((_) => false);

      expect(await ios().isSupported(), isFalse);
    });

    test('is false without a channel call on other platforms', () async {
      answer((_) => true);

      expect(
        await BarcodeScannerChannel(isSupported: () => false).isSupported(),
        isFalse,
      );
      expect(calls, isEmpty);
    });

    test('is false when the native side is missing', () async {
      expect(await ios().isSupported(), isFalse);
    });
  });

  group('camera permission', () {
    test('parses every status', () async {
      for (final entry in {
        'notDetermined': CameraPermission.notDetermined,
        'authorized': CameraPermission.authorized,
        'denied': CameraPermission.denied,
        'restricted': CameraPermission.restricted,
        'later': CameraPermission.denied,
      }.entries) {
        answer((_) => entry.key);

        expect(await ios().cameraPermission(), entry.value, reason: entry.key);
      }
      expect(calls.first.method, 'cameraPermission');
    });

    test('is denied on other platforms', () async {
      expect(
        await BarcodeScannerChannel(isSupported: () => false).cameraPermission(),
        CameraPermission.denied,
      );
    });

    test('requestCameraAccess returns the decision', () async {
      answer((_) => true);

      expect(await ios().requestCameraAccess(), isTrue);
      expect(calls.single.method, 'requestCameraAccess');
    });

    test('requestCameraAccess is false when unavailable', () async {
      answer((_) => throw PlatformException(code: 'unavailable'));

      expect(await ios().requestCameraAccess(), isFalse);
    });
  });

  group('scan', () {
    test('sends the labels and returns the scanned code', () async {
      answer(
        (_) => {
          'status': 'scanned',
          'code': '4056489123453',
          'symbology': 'ean13',
        },
      );

      final result = await ios().scan(labels: labels);

      expect(calls.single.method, 'scan');
      expect(calls.single.arguments, {
        'hint': 'Strichcode in den Rahmen halten',
        'manualEntry': 'Nummer eingeben',
        'close': 'Zurück',
        'torch': 'Taschenlampe',
        'torchOn': 'An',
        'torchOff': 'Aus',
      });
      expect(result.status, BarcodeScanStatus.scanned);
      expect(result.code, '4056489123453');
      expect(result.symbology, 'ean13');
    });

    test('reports the switch to digit entry', () async {
      answer((_) => {'status': 'manual'});

      final result = await ios().scan(labels: labels);

      expect(result.status, BarcodeScanStatus.manualEntry);
      expect(result.code, isNull);
    });

    test('reports a cancelled scan', () async {
      answer((_) => {'status': 'cancelled'});

      expect(
        (await ios().scan(labels: labels)).status,
        BarcodeScanStatus.cancelled,
      );
    });

    test('a scanned answer without a valid code counts as cancelled', () async {
      answer((_) => {'status': 'scanned', 'code': '12'});

      expect(
        (await ios().scan(labels: labels)).status,
        BarcodeScanStatus.cancelled,
      );
    });

    test('is unavailable on iOS 15 so the app shows digit entry', () async {
      answer((_) => throw PlatformException(code: 'unavailable'));

      expect(
        (await ios().scan(labels: labels)).status,
        BarcodeScanStatus.unavailable,
      );
    });

    test('is unavailable without a channel call on other platforms', () async {
      answer((_) => {'status': 'scanned', 'code': '4056489123453'});

      final result = await BarcodeScannerChannel(
        isSupported: () => false,
      ).scan(labels: labels);

      expect(result.status, BarcodeScanStatus.unavailable);
      expect(calls, isEmpty);
    });

    test('a refused camera throws permissionDenied', () async {
      answer((_) => throw PlatformException(code: 'permission_denied'));

      await expectLater(
        ios().scan(labels: labels),
        throwsA(
          isA<NativeChannelException>().having(
            (e) => e.code,
            'code',
            NativeErrorCode.permissionDenied,
          ),
        ),
      );
    });

    test('a second scan while one is open throws busy', () async {
      answer((_) => throw PlatformException(code: 'busy'));

      await expectLater(
        ios().scan(labels: labels),
        throwsA(
          isA<NativeChannelException>().having(
            (e) => e.code,
            'code',
            NativeErrorCode.busy,
          ),
        ),
      );
    });
  });

  group('normalizeGtin (digit entry)', () {
    test('accepts EAN-13 with spaces', () {
      expect(
        BarcodeScannerChannel.normalizeGtin('4 056489 123453'),
        '4056489123453',
      );
    });

    test('pads UPC-A to 13 digits', () {
      expect(
        BarcodeScannerChannel.normalizeGtin('036000291452'),
        '0036000291452',
      );
    });

    test('accepts EAN-8', () {
      expect(BarcodeScannerChannel.normalizeGtin('9638-5074'), '96385074');
    });

    test('rejects a wrong check digit', () {
      expect(BarcodeScannerChannel.normalizeGtin('4056489123457'), isNull);
    });

    test('rejects letters, wrong lengths and empty input', () {
      expect(BarcodeScannerChannel.normalizeGtin('40564891234a3'), isNull);
      expect(BarcodeScannerChannel.normalizeGtin('123'), isNull);
      expect(BarcodeScannerChannel.normalizeGtin(''), isNull);
    });
  });
}
