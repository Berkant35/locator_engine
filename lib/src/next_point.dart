import 'dart:math' as math;

import 'package:locator_engine/src/engine_profile.dart';
import 'package:locator_engine/src/link.dart';
import 'package:locator_engine/src/normal.dart';
import 'package:locator_engine/src/observation.dart';
import 'package:locator_engine/src/probability_map.dart';
import 'package:rubble_core/rubble_core.dart';

/// How far outside the rubble suggested points are.
const _offset = 1.0;

/// Spacing of candidate points along the outline.
const _spacing = 1.0;

/// No suggestion closer than this to a point already measured.
const _minSeparation = 2.0;

/// The measurement point that is expected to teach the most about [map]: a spot 1 m outside the
/// rubble, at least 2 m from every measured point, or null when there is none.
///
/// Expected information of a candidate under the current map, with the profile's middle values
/// (path-loss exponent, attenuation, phone height; no offset): the uncertainty of "heard or not"
/// (binary entropy of the detection probability) plus, if heard, how much the cells disagree about
/// the signal (½·ln(1 + Var μ / σ²)). Deterministic: ties keep the first candidate along the outline.
SitePoint? suggestNextPoint({
  required RubblePolygon outline,
  required List<Observation> observations,
  required ProbabilityMap map,
  required EngineProfile profile,
}) {
  final cells = [
    for (var i = 0; i < map.probabilities.length; i++)
      if (map.probabilities[i] > 0) i,
  ];
  final exponent = _middle(profile.pathLossExponents);
  final alpha = _middle(profile.attenuationDbPerM);
  final z = _middle(profile.victimHeightFractions) * profile.rubbleHeightM;
  final fading =
      profile.slowFadingDb * profile.slowFadingDb +
      profile.fastFadingDb * profile.fastFadingDb;

  SitePoint? best;
  var bestScore = double.negativeInfinity;
  for (final candidate in _candidates(outline)) {
    if (observations.any(
      (o) => o.at.distanceTo(candidate).value < _minSeparation,
    )) {
      continue;
    }
    var heard = 0.0;
    var mean = 0.0;
    var meanSquare = 0.0;
    var variance = 0.0;
    for (final i in cells) {
      final p = map.probabilities[i];
      final centre = map.centre(i);
      final dx = centre.x.value - candidate.x.value;
      final dy = centre.y.value - candidate.y.value;
      final length = math.sqrt(dx * dx + dy * dy + z * z);
      final rIn =
          insideFraction(outline, candidate, centre.x.value, centre.y.value) *
          length;
      final loss = profile.linkVariation * alpha * rIn;
      final sd = math.sqrt(fading + loss * loss);
      final mu =
          profile.txPowerAt1mDbm -
          10 * exponent * math.log(math.max(length, 0.3)) / math.ln10 -
          alpha * rIn;
      heard += p * math.exp(logNormalCdf((mu - profile.thresholdDbm) / sd));
      mean += p * mu;
      meanSquare += p * mu * mu;
      variance += p * sd * sd;
    }
    final spread = math.max(meanSquare - mean * mean, 0.0);
    final score =
        _binaryEntropy(heard) + heard * 0.5 * math.log(1 + spread / variance);
    if (score > bestScore + 1e-12) {
      bestScore = score;
      best = candidate;
    }
  }
  return best;
}

/// Spots every [_spacing] along each side, [_offset] outside the rubble.
Iterable<SitePoint> _candidates(RubblePolygon outline) sync* {
  for (final edge in outline.edges) {
    final dx = edge.end.x.value - edge.start.x.value;
    final dy = edge.end.y.value - edge.start.y.value;
    final length = math.sqrt(dx * dx + dy * dy);
    final (ux, uy) = (dx / length, dy / length);
    for (var s = _spacing / 2; s < length; s += _spacing) {
      final on = (edge.start.x.value + ux * s, edge.start.y.value + uy * s);
      for (final sign in const [1.0, -1.0]) {
        final candidate = SitePoint(
          Meters(on.$1 + sign * uy * _offset),
          Meters(on.$2 - sign * ux * _offset),
        );
        if (!outline.contains(candidate)) {
          yield candidate;
          break;
        }
      }
    }
  }
}

double _middle(List<double> values) => values[values.length ~/ 2];

double _binaryEntropy(double p) {
  if (p <= 0 || p >= 1) return 0;
  return -p * math.log(p) - (1 - p) * math.log(1 - p);
}
