import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

/// Host side of the frame measurements in `integration_test/perf/`
/// (Konzept 20 §7.7). Writes one JSON file per scenario to `build/perf/`:
/// average, 90th and 99th percentile and worst frame, build (UI thread)
/// and raster apart, the verdict against §5.1, and the raw frame times.
///
/// ```
/// flutter drive --profile --driver=test_driver/perf_driver.dart \
///   --target=integration_test/perf/s1_scroll_list_test.dart -d <iPhone>
/// ```
const double _targetP90 = 8.3;
const double _limitWorst = 16;

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null || data.isEmpty) {
      stdout.writeln('No measurement in the report.');
      return;
    }
    final dir = Directory('build/perf')..createSync(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    for (final entry in data.entries) {
      final raw = Map<String, dynamic>.from(entry.value as Map);
      final summary = _summary(entry.key, raw, stamp);
      final file = File('${dir.path}/${entry.key}_$stamp.json');
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({...summary, 'raw': raw}),
      );
      stdout.writeln(
        '${entry.key}: ${summary['verdict']} '
        '(build p90 ${_ms(summary, 'build', 'p90')} / worst '
        '${_ms(summary, 'build', 'worst')}, raster p90 '
        '${_ms(summary, 'raster', 'p90')} / worst '
        '${_ms(summary, 'raster', 'worst')}) -> ${file.path}',
      );
    }
  },
);

Map<String, Object?> _summary(
  String scenario,
  Map<String, dynamic> raw,
  String stamp,
) {
  Map<String, Object?> thread(String name) => {
    'average_ms': raw['average_frame_${name}_time_millis'],
    'p90_ms': raw['90th_percentile_frame_${name}_time_millis'],
    'p99_ms': raw['99th_percentile_frame_${name}_time_millis'],
    'worst_ms': raw['worst_frame_${name}_time_millis'],
    'missed_budget_count': raw['missed_frame_${name}_budget_count'],
  };
  final build = thread('build');
  final raster = thread('rasterizer');
  bool within(Map<String, Object?> t) =>
      (t['p90_ms'] as num? ?? double.infinity) <= _targetP90 &&
      (t['worst_ms'] as num? ?? double.infinity) <= _limitWorst;
  final ok = within(build) && within(raster);
  return {
    'scenario': scenario,
    'measured_at': stamp,
    'budget': {'p90_ms': _targetP90, 'worst_ms': _limitWorst},
    'frame_count': raw['frame_count'],
    'build': build,
    'raster': raster,
    'verdict': ok ? 'within budget' : 'OVER BUDGET',
  };
}

String _ms(Map<String, Object?> summary, String thread, String key) {
  final value = (summary[thread] as Map)['${key}_ms'] as num?;
  return value == null ? '?' : '${value.toStringAsFixed(1)} ms';
}
