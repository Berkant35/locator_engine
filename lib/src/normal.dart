import 'dart:math' as math;
import 'dart:typed_data';

const _logSqrtTwoPi = 0.91893853320467274178; // log(sqrt(2π))
const _logSqrtPi = 0.57236494292470008707; // log(sqrt(π))

/// Log density of a normal distribution.
double logNormalPdf(double x, double mean, double sd) {
  final z = (x - mean) / sd;
  return -_logSqrtTwoPi - math.log(sd) - 0.5 * z * z;
}

/// log Φ(z), fast: a cubic Hermite table on [−40, 10) (step 0.005; the derivative φ/Φ is exact), the
/// asymptotic series below and the tail above. Within 1e-9 of [logNormalCdfExact] everywhere.
///
/// A point where the phone is not heard is a censored observation: its probability can be tiny, and
/// the engine evaluates this some ten million times per map.
double logNormalCdf(double z) {
  if (z < _tableFrom) return _lowerTail(z);
  if (z >= _tableTo) {
    return -math.exp(_logStdPdf(z) - math.log(z)); // log Φ ≈ −φ(z)/z
  }
  final position = (z - _tableFrom) / _step;
  final i = position.floor();
  final t = position - i;
  final values = _table.values;
  final slopes = _table.slopes;
  final t2 = t * t;
  final t3 = t2 * t;
  return (2 * t3 - 3 * t2 + 1) * values[i] +
      (t3 - 2 * t2 + t) * _step * slopes[i] +
      (-2 * t3 + 3 * t2) * values[i + 1] +
      (t3 - t2) * _step * slopes[i + 1];
}

const _tableFrom = -40.0;
const _tableTo = 10.0;
const _step = 0.005;

final _table = () {
  final count = ((_tableTo - _tableFrom) / _step).round() + 1;
  final values = Float64List(count);
  final slopes = Float64List(count);
  for (var i = 0; i < count; i++) {
    final z = _tableFrom + i * _step;
    values[i] = logNormalCdfExact(z);
    slopes[i] = math.exp(_logStdPdf(z) - values[i]); // d/dz log Φ = φ / Φ
  }
  return (values: values, slopes: slopes);
}();

double _logStdPdf(double z) => -_logSqrtTwoPi - 0.5 * z * z;

/// log Φ(z) for z far in the lower tail: log φ(z) − log(−z) + log(1 − 1/z² + 3/z⁴ − 15/z⁶ + 105/z⁸).
double _lowerTail(double z) {
  final r = 1 / (z * z);
  final series = 1 - r * (1 - r * (3 - r * (15 - r * 105)));
  return _logStdPdf(z) - math.log(-z) + math.log(series);
}

/// log Φ(z) with full double precision (slow; builds the table): erfc by a Taylor series of erf below
/// 2 and a continued fraction in log space above, so neither cancels nor underflows.
double logNormalCdfExact(double z) {
  final x = -z / math.sqrt2;
  // Φ(z) = erfc(x) / 2.
  if (x >= 0) return logErfc(x) - math.ln2;
  // x < 0: erfc(x) = 2 − erfc(−x), so Φ(z) = 1 − erfc(−x) / 2.
  final tail = math.exp(logErfc(-x)) / 2;
  return _log1p(-tail);
}

/// log erfc(x) for x ≥ 0.
double logErfc(double x) {
  assert(x >= 0, 'logErfc is defined here for x >= 0');
  if (x < 2) return math.log(1 - _erfSeries(x));
  return -x * x - _logSqrtPi - math.log(_erfcContinuedFraction(x));
}

/// erf(x) = 2/√π Σ (−1)ⁿ x^(2n+1) / (n! (2n+1)); below 2 the terms stay small enough not to cancel.
double _erfSeries(double x) {
  final x2 = x * x;
  var term = x;
  var sum = x;
  for (var n = 1; n < 200; n++) {
    term *= -x2 / n;
    final add = term / (2 * n + 1);
    sum += add;
    if (add.abs() < 1e-17 * sum.abs()) break;
  }
  return sum * 2 / math.sqrt(math.pi);
}

/// The continued fraction F with erfc(x) = exp(−x²) / (√π F) (modified Lentz).
double _erfcContinuedFraction(double x) {
  const tiny = 1e-300;
  var f = x;
  var c = f;
  var d = 0.0;
  for (var k = 1; k < 5000; k++) {
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
  final u = 1 + x;
  if (u == 1) return x;
  return math.log(u) * x / (u - 1);
}
