import 'dart:math' as math;
import 'dart:typed_data';

import 'package:locator_engine/src/engine_profile.dart';
import 'package:locator_engine/src/link.dart';
import 'package:locator_engine/src/normal.dart';
import 'package:locator_engine/src/observation.dart';
import 'package:locator_engine/src/probability_map.dart';
import 'package:rubble_core/rubble_core.dart';

const _logSqrtTwoPi = 0.91893853320467274178;

/// The most grid cells a map gets: a larger site gets cells coarser than the profile's (a whole
/// multiple), so a phone maps it in seconds — the cost grows with cells × points × unknowns. 6000 keeps
/// 0.25 m cells up to about 20 × 15 m and 0.5 m cells up to 40 × 30 m; the regions are many m² anyway.
const maxCells = 6000;

/// The probability map of where the phone most likely is, given the [observations] of one target
/// around the rubble [outline]. Pure and deterministic; heavy — call it off the UI isolate.
///
/// Per cell (centres inside the outline) and phone height, with the unknowns of [profile]
/// marginalised (path-loss exponent, rubble attenuation, common offset): heard: log N(median; μ, σ);
/// not heard: log Φ((threshold − μ) / σ) — a point with no signal is data (rule 3). Matches the hub's
/// `tools/sim/engine_reference.py`.
///
/// Throws [ArgumentError] without observations (a region out of nothing would mislead) or when no
/// cell centre lies inside the outline.
ProbabilityMap estimate({
  required RubblePolygon outline,
  required List<Observation> observations,
  required EngineProfile profile,
}) {
  if (observations.isEmpty) {
    throw ArgumentError.value(
      observations,
      'observations',
      'need at least one point',
    );
  }
  final bounds = outline.bounds;
  final x0 = bounds.min.x.value;
  final y0 = bounds.min.y.value;
  final width = bounds.max.x.value - x0;
  final depth = bounds.max.y.value - y0;
  // The profile's cell, or a whole multiple of it on a site too large for [maxCells].
  var cell = profile.cellM;
  while ((width / cell - 1e-9).ceil() * (depth / cell - 1e-9).ceil() >
      maxCells) {
    cell += profile.cellM;
  }
  final cols = (width / cell - 1e-9).ceil();
  final rows = (depth / cell - 1e-9).ceil();
  final count = cols * rows;
  final footprint = Footprint(outline);

  final inside = <int>[];
  for (var i = 0; i < count; i++) {
    if (footprint.contains(_cx(x0, cell, cols, i), _cy(y0, cell, cols, i))) {
      inside.add(i);
    }
  }
  if (inside.isEmpty) {
    throw ArgumentError.value(
      outline,
      'outline',
      'smaller than one $cell m cell',
    );
  }

  final offsetWeights = [
    for (final c in profile.offsetsDb)
      math.exp(-0.5 * (c / profile.offsetSdDb) * (c / profile.offsetSdDb)),
  ];
  final weightSum = offsetWeights.fold(0.0, (a, b) => a + b);
  final logWeights = [for (final w in offsetWeights) math.log(w / weightSum)];

  final n = inside.length;
  final k = observations.length;
  final acc = Float64List(n)..fillRange(0, n, double.negativeInfinity);
  final length = List.generate(k, (_) => Float64List(n));
  final rIn = List.generate(k, (_) => Float64List(n));
  // The share of the path inside the rubble does not depend on the phone's height.
  final fractionIn = List.generate(k, (o) {
    final at = observations[o].at;
    return Float64List.fromList([
      for (var j = 0; j < n; j++)
        footprint.insideFraction(
          at.x.value,
          at.y.value,
          _cx(x0, cell, cols, inside[j]),
          _cy(y0, cell, cols, inside[j]),
        ),
    ]);
  });
  final mean = List.generate(k, (_) => Float64List(n));
  final sd = List.generate(k, (_) => Float64List(n));
  final logSd = List.generate(k, (_) => Float64List(n));
  final ll = Float64List(n);

  for (final fraction in profile.victimHeightFractions) {
    final z = fraction * profile.rubbleHeightM;
    for (var o = 0; o < k; o++) {
      final at = observations[o].at;
      for (var j = 0; j < n; j++) {
        final x = _cx(x0, cell, cols, inside[j]);
        final y = _cy(y0, cell, cols, inside[j]);
        final dx = x - at.x.value;
        final dy = y - at.y.value;
        length[o][j] = math.sqrt(dx * dx + dy * dy + z * z);
        rIn[o][j] = fractionIn[o][j] * length[o][j];
      }
    }
    for (final exponent in profile.pathLossExponents) {
      for (final alpha in profile.attenuationDbPerM) {
        // Everything but the offset, once per (exponent, attenuation).
        for (var o = 0; o < k; o++) {
          for (var j = 0; j < n; j++) {
            final link = linkModel(
              profile,
              exponent: exponent,
              alpha: alpha,
              length: length[o][j],
              rIn: rIn[o][j],
            );
            mean[o][j] = link.mean;
            sd[o][j] = link.sd;
            logSd[o][j] = math.log(link.sd);
          }
        }
        for (var c = 0; c < profile.offsetsDb.length; c++) {
          final offset = profile.offsetsDb[c];
          ll.fillRange(0, n, logWeights[c]);
          for (var o = 0; o < k; o++) {
            final median = observations[o].median?.value;
            final mo = mean[o];
            final so = sd[o];
            if (median != null) {
              final lso = logSd[o];
              for (var j = 0; j < n; j++) {
                final u = (median - mo[j] - offset) / so[j];
                ll[j] += -_logSqrtTwoPi - lso[j] - 0.5 * u * u;
              }
            } else {
              for (var j = 0; j < n; j++) {
                ll[j] += logNormalCdf(
                  (profile.thresholdDbm - mo[j] - offset) / so[j],
                );
              }
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
  return ProbabilityMap(
    origin: SitePoint(Meters(x0), Meters(y0)),
    cell: Meters(cell),
    cols: cols,
    rows: rows,
    probabilities: probabilities,
    regions: _regions(probabilities, inside),
  );
}

double _cx(double x0, double cell, int cols, int i) =>
    x0 + cell / 2 + cell * (i % cols);

double _cy(double y0, double cell, int cols, int i) =>
    y0 + cell / 2 + cell * (i ~/ cols);

/// 2 for the smallest set of cells holding 50 %, 1 for the rest of the 90 % set, 0 otherwise — by
/// count, so the regions are exactly the areas reported (ties keep the lower index).
Uint8List _regions(Float64List probabilities, List<int> inside) {
  final order = [...inside]
    ..sort((a, b) {
      final byP = probabilities[b].compareTo(probabilities[a]);
      return byP != 0 ? byP : a.compareTo(b);
    });
  final regions = Uint8List(probabilities.length);
  var cumulative = 0.0;
  for (final i in order) {
    if (cumulative >= 0.9 - 1e-12) break;
    regions[i] = cumulative < 0.5 - 1e-12 ? 2 : 1;
    cumulative += probabilities[i];
  }
  return regions;
}

double _logAddExp(double a, double b) {
  if (a == double.negativeInfinity) return b;
  if (b == double.negativeInfinity) return a;
  final high = math.max(a, b);
  return high + math.log(math.exp(a - high) + math.exp(b - high));
}
