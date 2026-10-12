import 'dart:math' as math;

import 'package:locator_engine/src/engine_profile.dart';
import 'package:locator_engine/src/link.dart';
import 'package:locator_engine/src/normal.dart';
import 'package:locator_engine/src/observation.dart';
import 'package:locator_engine/src/probability_map.dart';
import 'package:rubble_core/rubble_core.dart';

/// How far outside the rubble suggested points are (from every wall).
const _offset = 1.0;

/// Spacing of candidate points along the outline.
const _spacing = 1.0;

/// No suggestion closer than this to a point already measured.
const _minSeparation = 2.0;

/// The cells that carry this much probability are enough to score candidates.
const _scoredMass = 0.99;

/// The measurement point expected to teach the most about [map]: a spot at least 1 m from every wall
/// of the rubble, at least 2 m from every measured point, or null when there is none.
///
/// Score = mutual information of the next reading with the phone's cell, with the profile's middle
/// unknowns: of "heard or not" (H(P heard) − Σ p·H(p heard | cell)) plus, if heard, how much the cells
/// that would be heard disagree about the signal (½·ln(1 + Var μ / σ²), cells weighted by p given
/// heard). Deterministic: ties keep the first candidate along the outline.
SitePoint? suggestNextPoint({
  required RubblePolygon outline,
  required List<Observation> observations,
  required ProbabilityMap map,
  required EngineProfile profile,
}) {
  final cells = _likelyCells(map);
  final exponent = _middle(profile.pathLossExponents);
  final alpha = _middle(profile.attenuationDbPerM);
  final z = _middle(profile.victimHeightFractions) * profile.rubbleHeightM;
  final footprint = Footprint(outline);

  SitePoint? best;
  var bestScore = double.negativeInfinity;
  for (final candidate in _candidates(outline)) {
    if (observations.any(
      (o) => o.at.distanceTo(candidate).value < _minSeparation,
    )) {
      continue;
    }
    var heard = 0.0;
    var cellEntropy = 0.0;
    var weight = 0.0;
    var mean = 0.0;
    var meanSquare = 0.0;
    var variance = 0.0;
    for (final (i, p) in cells) {
      final centre = map.centre(i);
      final x = centre.x.value;
      final y = centre.y.value;
      final dx = x - candidate.x.value;
      final dy = y - candidate.y.value;
      final length = math.sqrt(dx * dx + dy * dy + z * z);
      final link = linkModel(
        profile,
        exponent: exponent,
        alpha: alpha,
        length: length,
        rIn:
            footprint.insideFraction(
              candidate.x.value,
              candidate.y.value,
              x,
              y,
            ) *
            length,
      );
      final pHeard = math.exp(
        logNormalCdf((link.mean - profile.thresholdDbm) / link.sd),
      );
      heard += p * pHeard;
      cellEntropy += p * _binaryEntropy(pHeard);
      final w = p * pHeard;
      weight += w;
      mean += w * link.mean;
      meanSquare += w * link.mean * link.mean;
      variance += w * link.sd * link.sd;
    }
    var signalInformation = 0.0;
    if (weight > 0) {
      final m = mean / weight;
      final spread = math.max(meanSquare / weight - m * m, 0.0);
      signalInformation = 0.5 * math.log(1 + spread / (variance / weight));
    }
    final score =
        math.max(_binaryEntropy(heard) - cellEntropy, 0.0) +
        heard * signalInformation;
    if (score > bestScore + 1e-12) {
      bestScore = score;
      best = candidate;
    }
  }
  return best;
}

/// The most likely cells holding [_scoredMass] of the probability, with their probabilities.
List<(int, double)> _likelyCells(ProbabilityMap map) {
  final cells = [
    for (var i = 0; i < map.probabilities.length; i++)
      if (map.probabilities[i] > 0) (i, map.probabilities[i]),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  var cumulative = 0.0;
  final kept = <(int, double)>[];
  for (final cell in cells) {
    kept.add(cell);
    cumulative += cell.$2;
    if (cumulative >= _scoredMass) break;
  }
  return kept;
}

/// Spots every [_spacing] along each side, [_offset] out, kept only when at least [_offset] from every
/// wall (a narrow notch is no place to stand) and outside the rubble.
Iterable<SitePoint> _candidates(RubblePolygon outline) sync* {
  final edges = outline.edges;
  for (final edge in edges) {
    final dx = edge.end.x.value - edge.start.x.value;
    final dy = edge.end.y.value - edge.start.y.value;
    final length = math.sqrt(dx * dx + dy * dy);
    final (ux, uy) = (dx / length, dy / length);
    for (var s = _spacing / 2; s < length; s += _spacing) {
      final (ox, oy) = (
        edge.start.x.value + ux * s,
        edge.start.y.value + uy * s,
      );
      for (final sign in const [1.0, -1.0]) {
        final candidate = SitePoint(
          Meters(ox + sign * uy * _offset),
          Meters(oy - sign * ux * _offset),
        );
        if (outline.contains(candidate)) continue;
        final clear = edges.every(
          (e) => _distanceToSide(candidate, e) >= _offset - 1e-9,
        );
        if (clear) yield candidate;
        break;
      }
    }
  }
}

double _distanceToSide(SitePoint q, PolygonEdge e) {
  final (ax, ay) = (e.start.x.value, e.start.y.value);
  final (abx, aby) = (e.end.x.value - ax, e.end.y.value - ay);
  final t =
      (((q.x.value - ax) * abx + (q.y.value - ay) * aby) /
              (abx * abx + aby * aby))
          .clamp(0.0, 1.0);
  final (px, py) = (ax + t * abx - q.x.value, ay + t * aby - q.y.value);
  return math.sqrt(px * px + py * py);
}

/// The middle value of a grid of unknowns (the upper middle of an even count).
double _middle(List<double> values) => values[values.length ~/ 2];

double _binaryEntropy(double p) {
  if (p <= 0 || p >= 1) return 0;
  return -p * math.log(p) - (1 - p) * math.log(1 - p);
}
