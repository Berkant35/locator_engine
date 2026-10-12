import 'dart:convert';
import 'dart:io';

import 'package:locator_engine/locator_engine.dart';
import 'package:rubble_core/rubble_core.dart';
import 'package:test/test.dart';

/// The golden fixtures of the Python reference (`tools/sim/engine_reference.py` in the hub): the
/// engine must give the same probability map (CLAUDE.md §7).
Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, Object?>;

SitePoint _point(Object? json) {
  final m = json! as Map<String, Object?>;
  return SitePoint(
    Meters((m['x']! as num).toDouble()),
    Meters((m['y']! as num).toDouble()),
  );
}

void main() {
  test('the built-in profiles are the reference profiles', () {
    final reference = jsonDecode(
      File('test/fixtures/profiles.json').readAsStringSync(),
    ) as Map<String, Object?>;
    for (final profile in EngineProfile.builtIn) {
      final expected = reference[profile.id]! as Map<String, Object?>;
      final actual = profile.toJson();
      for (final MapEntry(:key, :value) in expected.entries) {
        if (value is num) {
          expect(
            (actual[key]! as num).toDouble(),
            closeTo(value.toDouble(), 1e-9),
            reason: '${profile.id}.$key',
          );
        } else if (value is List) {
          final list = actual[key]! as List<Object?>;
          for (var i = 0; i < value.length; i++) {
            expect(
              (list[i]! as num).toDouble(),
              closeTo((value[i] as num).toDouble(), 1e-9),
              reason: '${profile.id}.$key[$i]',
            );
          }
        } else {
          expect(actual[key], value, reason: '${profile.id}.$key');
        }
      }
    }
  });

  for (final name in [
    'voided_rect_8',
    'dense_rect_8',
    'voided_l_shape',
    'all_silent',
  ]) {
    test('matches the reference: $name', () {
      final f = _fixture(name);
      final outline = RubblePolygon([
        for (final c in f['outline']! as List<Object?>) _point(c),
      ]);
      final observations = [
        for (final p in f['points']! as List<Object?>)
          () {
            final m = p! as Map<String, Object?>;
            final at = _point(m);
            return m['heard']! as bool
                ? Observation.heard(
                    at,
                    Dbm((m['medianDbm']! as num).toDouble()),
                  )
                : Observation.notHeard(at);
          }(),
      ];
      final map = estimate(
        outline: outline,
        observations: observations,
        profile: EngineProfile.byId(f['profile']! as String)!,
      );
      final grid = f['grid']! as Map<String, Object?>;
      expect((map.cols, map.rows), (grid['cols'], grid['rows']));
      expect(
        map.origin.x.value,
        closeTo((grid['originX']! as num).toDouble(), 1e-9),
      );
      final expected = [
        for (final v in f['probabilities']! as List<Object?>)
          (v! as num).toDouble(),
      ];
      var worst = 0.0;
      for (var i = 0; i < expected.length; i++) {
        final diff = (map.probabilities[i] - expected[i]).abs();
        if (diff > worst) worst = diff;
      }
      // Probabilities per 0.25 m cell; 1e-6 absolute is far below what a map can show.
      expect(worst, lessThan(1e-6));
      expect(map.area50.value, closeTo((f['area50']! as num).toDouble(), 1e-9));
      expect(map.area90.value, closeTo((f['area90']! as num).toDouble(), 1e-9));
    });
  }
}
