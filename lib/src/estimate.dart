import 'dart:math' as math;
import 'dart:typed_data';

import 'package:locator_engine/src/engine_profile.dart';
import 'package:locator_engine/src/link.dart';
import 'package:locator_engine/src/normal.dart';
import 'package:locator_engine/src/observation.dart';
import 'package:locator_engine/src/probability_map.dart';
import 'package:rubble_core/rubble_core.dart';

/// The probability map of where the phone most likely is, given the [observations] of one target
/// around the rubble [outline]. Pure and deterministic; heavy — call it off the UI isolate.
///
/// Per cell (centres inside the outline) and phone height z, with the unknowns of [profile]
/// marginalised (path-loss exponent, rubble attenuation, common offset):
/// heard: log N(median; μ, σ); not heard: log Φ((threshold − μ) / σ) — a point with no signal is
/// data (rule 3). μ = P0 + c − 10 n log10(r) − α·r_in, σ² = slow² + fast² + (v·α·r_in)², r_in the
/// part of the link inside the rubble. Matches the hub's `tools/sim/engine_reference.py`.
ProbabilityMap estimate({
  required RubblePolygon outline,
  required List<Observation> observations,
  required EngineProfile profile,
}) {
  final cell = profile.cellM;
  final bounds = outline.bounds;
  final x0 = bounds.min.x.value;
  final y0 = bounds.min.y.value;
  final cols = ((bounds.max.x.value - x0) / cell - 1e-9).ceil();
  final rows = ((bounds.max.y.value - y0) / cell - 1e-9).ceil();
  final count = cols * rows;

  final cx = Float64List(count);
  final cy = Float64List(count);
  final inside = <int>[];
  for (var i = 0; i < count; i++) {
    cx[i] = x0 + cell / 2 + cell * (i % cols);
    cy[i] = y0 + cell / 2 + cell * (i ~/ cols);
    if (outline.contains(SitePoint(Meters(cx[i]), Meters(cy[i])))) {
      inside.add(i);
    }
  }

  final offsetWeights = [
    for (final c in profile.offsetsDb)
      math.exp(-0.5 * (c / profile.offsetSdDb) * (c / profile.offsetSdDb)),
  ];
  final weightSum = offsetWeights.fold(0.0, (a, b) => a + b);
  final logWeights = [for (final w in offsetWeights) math.log(w / weightSum)];

  final n = inside.length;
  final acc = Float64List(n)..fillRange(0, n, double.negativeInfinity);
  final k = observations.length;
  final logR = List.generate(k, (_) => Float64List(n));
  final rIn = List.generate(k, (_) => Float64List(n));
  final ll = Float64List(n);
  final fading =
      profile.slowFadingDb * profile.slowFadingDb +
      profile.fastFadingDb * profile.fastFadingDb;

  for (final fraction in profile.victimHeightFractions) {
    final z = fraction * profile.rubbleHeightM;
    for (var o = 0; o < k; o++) {
      final at = observations[o].at;
      for (var j = 0; j < n; j++) {
        final i = inside[j];
        final dx = cx[i] - at.x.value;
        final dy = cy[i] - at.y.value;
        final length = math.sqrt(dx * dx + dy * dy + z * z);
        logR[o][j] = math.log(math.max(length, 0.3)) / math.ln10;
        rIn[o][j] = insideFraction(outline, at, cx[i], cy[i]) * length;
      }
    }
    for (final exponent in profile.pathLossExponents) {
      for (final alpha in profile.attenuationDbPerM) {
        for (var c = 0; c < profile.offsetsDb.length; c++) {
          final offset = profile.offsetsDb[c];
          ll.fillRange(0, n, logWeights[c]);
          for (var o = 0; o < k; o++) {
            final observation = observations[o];
            final median = observation.median?.value;
            for (var j = 0; j < n; j++) {
              final loss = profile.linkVariation * alpha * rIn[o][j];
              final sd = math.sqrt(fading + loss * loss);
              final mu =
                  profile.txPowerAt1mDbm +
                  offset -
                  10 * exponent * logR[o][j] -
                  alpha * rIn[o][j];
              ll[j] += median != null
                  ? logNormalPdf(median, mu, sd)
                  : logNormalCdf((profile.thresholdDbm - mu) / sd);
            }
          }
          for (var j = 0; j < n; j++) {
            acc[j] = _logAddExp(acc[j], ll[j]);
          }
        }
      }
    }
  }

  var top = double.negativeInfinity;
  for (final v in acc) {
    if (v > top) top = v;
  }
  final probabilities = Float64List(count);
  var sum = 0.0;
  for (var j = 0; j < n; j++) {
    final p = math.exp(acc[j] - top);
    probabilities[inside[j]] = p;
    sum += p;
  }
  for (final i in inside) {
    probabilities[i] /= sum;
  }

  final sorted = [for (final i in inside) probabilities[i]]
    ..sort((a, b) => b.compareTo(a));
  final (k50, t50) = _smallestHolding(sorted, 0.5);
  final (k90, t90) = _smallestHolding(sorted, 0.9);
  return ProbabilityMap(
    origin: SitePoint(Meters(x0), Meters(y0)),
    cell: Meters(cell),
    cols: cols,
    rows: rows,
    probabilities: probabilities,
    area50: SquareMeters(k50 * cell * cell),
    area90: SquareMeters(k90 * cell * cell),
    threshold50: t50,
    threshold90: t90,
  );
}

/// How many of the [sorted] (descending) probabilities hold [mass], and the smallest of them.
(int, double) _smallestHolding(List<double> sorted, double mass) {
  var cumulative = 0.0;
  for (var i = 0; i < sorted.length; i++) {
    cumulative += sorted[i];
    if (cumulative >= mass) return (i + 1, sorted[i]);
  }
  return (sorted.length, sorted.isEmpty ? 0 : sorted.last);
}

double _logAddExp(double a, double b) {
  if (a == double.negativeInfinity) return b;
  if (b == double.negativeInfinity) return a;
  final high = math.max(a, b);
  return high + math.log(math.exp(a - high) + math.exp(b - high));
}
