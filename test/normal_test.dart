import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:locator_engine/src/normal.dart';
import 'package:test/test.dart';

void main() {
  // scipy.special.log_ndtr on a dense grid from −60 to 10 (7007 values).
  final reference = jsonDecode(
    File('test/fixtures/log_ndtr.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final zs = [
    for (final v in reference['z']! as List<Object?>) (v! as num).toDouble(),
  ];
  final expected = [
    for (final v in reference['logPhi']! as List<Object?>)
      (v! as num).toDouble(),
  ];

  double worst(double Function(double) f) {
    var worst = 0.0;
    for (var i = 0; i < zs.length; i++) {
      final error = (f(zs[i]) - expected[i]).abs();
      if (error > worst) worst = error;
    }
    return worst;
  }

  test('exact log Φ matches scipy to 1e-11 everywhere (no cancellation near erfc argument 3)', () {
    expect(worst(logNormalCdfExact), lessThan(1e-11));
  });

  test('fast log Φ (table) matches scipy to 1e-9 everywhere', () {
    expect(worst(logNormalCdf), lessThan(1e-9));
  });

  test('fast log Φ costs a few operations, not a series', () {
    logNormalCdf(0); // builds the table
    final watch = Stopwatch()..start();
    var sink = 0.0;
    for (var i = 0; i < 1000000; i++) {
      sink += logNormalCdf(-8 + i * 1e-5);
    }
    watch.stop();
    expect(sink.isFinite, isTrue);
    expect(watch.elapsedMilliseconds, lessThan(400));
  });

  test('the log density of a normal distribution', () {
    expect(
      logNormalPdf(-80, -75, 6),
      closeTo(
        -0.5 * math.log(2 * math.pi) - math.log(6) - 0.5 * (5 / 6) * (5 / 6),
        1e-15,
      ),
    );
  });
}
