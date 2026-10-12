import 'dart:math' as math;

import 'package:locator_engine/src/normal.dart';
import 'package:test/test.dart';

void main() {
  // Values from scipy.stats.norm.logcdf.
  const reference = [
    (-40.0, -804.6084420137538),
    (-10.0, -53.23128515051248),
    (-5.0, -15.064998393988727),
    (-3.0, -6.60772622151035),
    (-1.0, -1.8410216450092634),
    (0.0, -0.6931471805599453),
    (1.0, -0.1727537790234499),
    (3.0, -0.0013508099647481923),
    (8.0, -6.220960574271742e-16),
  ];

  test('log Φ matches scipy from the far tail to the top', () {
    for (final (z, expected) in reference) {
      final relative = ((logNormalCdf(z) - expected) / expected).abs();
      expect(relative, lessThan(1e-12), reason: 'z = $z');
    }
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

  test('log Φ is continuous where the two methods meet (erfc argument 3)', () {
    const z = -3 * math.sqrt2;
    expect(
      (logNormalCdf(z - 1e-9) - logNormalCdf(z + 1e-9)).abs(),
      lessThan(1e-7),
    );
  });
}
