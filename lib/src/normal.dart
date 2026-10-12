import 'dart:math' as math;

const _logSqrtTwoPi = 0.91893853320467274178; // log(sqrt(2π))
const _logSqrtPi = 0.57236494292470008707; // log(sqrt(π))

/// Log density of a normal distribution.
double logNormalPdf(double x, double mean, double sd) {
  final z = (x - mean) / sd;
  return -_logSqrtTwoPi - math.log(sd) - 0.5 * z * z;
}

/// log Φ(z), accurate far into the lower tail (a point where the phone is not heard is a censored
/// observation: its probability can be tiny, and only its logarithm matters).
double logNormalCdf(double z) {
  final x = -z / math.sqrt2;
  // Φ(z) = erfc(x) / 2.
  if (x >= 0) return logErfc(x) - math.ln2;
  // x < 0: erfc(x) = 2 − erfc(−x), so Φ(z) = 1 − erfc(−x) / 2.
  final tail = math.exp(logErfc(-x)) / 2;
  return _log1p(-tail);
}

/// log erfc(x) for x ≥ 0, with full double precision: a Taylor series of erf below 3, a continued
/// fraction (Lentz) in log space above, so the far tail never underflows.
double logErfc(double x) {
  assert(x >= 0, 'logErfc is defined here for x >= 0');
  if (x < 3) return math.log(1 - _erfSeries(x));
  return -x * x - _logSqrtPi - math.log(_erfcContinuedFraction(x));
}

/// erf(x) = 2/√π Σ (−1)ⁿ x^(2n+1) / (n! (2n+1)).
double _erfSeries(double x) {
  final x2 = x * x;
  var term = x; // (−1)ⁿ x^(2n+1) / n!
  var sum = x;
  for (var n = 1; n < 200; n++) {
    term *= -x2 / n;
    final add = term / (2 * n + 1);
    sum += add;
    if (add.abs() < 1e-17 * sum.abs()) break;
  }
  return sum * 2 / math.sqrt(math.pi);
}

/// The continued fraction F with erfc(x) = exp(−x²) / (√π F):
/// F = x + (1/2)/(x + 1/(x + (3/2)/(x + 2/(x + …)))).
double _erfcContinuedFraction(double x) {
  // Modified Lentz on b0 + a1/(b1 + a2/(b2 + …)) with b = x, a_k = k/2.
  const tiny = 1e-300;
  var f = x;
  var c = f;
  var d = 0.0;
  for (var k = 1; k < 500; k++) {
    final a = k / 2;
    d = x + a * d;
    if (d.abs() < tiny) d = tiny;
    c = x + a / c;
    if (c.abs() < tiny) c = tiny;
    d = 1 / d;
    final delta = c * d;
    f *= delta;
    if ((delta - 1).abs() < 1e-16) break;
  }
  return f;
}

double _log1p(double x) {
  // log(1 + x) without losing precision for small x.
  final u = 1 + x;
  if (u == 1) return x;
  return math.log(u) * x / (u - 1);
}
