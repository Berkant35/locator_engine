import 'dart:math' as math;
import 'dart:typed_data';

import 'package:locator_engine/src/engine_profile.dart';
import 'package:rubble_core/rubble_core.dart';

/// Points sampled along a link to measure how much of it runs inside the rubble.
const _pathSamples = 21;

/// Links shorter than this are treated as this long (near field).
const minLinkM = 0.3;

/// The rubble footprint as plain coordinates, for the millions of point tests of one map. Same rule
/// as `RubblePolygon.contains`: ray casting, a point on a side counts as inside.
final class Footprint {
  /// The footprint of [outline].
  Footprint(RubblePolygon outline)
    : _x = Float64List.fromList([for (final c in outline.corners) c.x.value]),
      _y = Float64List.fromList([for (final c in outline.corners) c.y.value]);

  final Float64List _x;
  final Float64List _y;

  /// Whether (x, y) is inside or on a side.
  bool contains(double x, double y) {
    final n = _x.length;
    var inside = false;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final (ax, ay, bx, by) = (_x[j], _y[j], _x[i], _y[i]);
      final cross = (bx - ax) * (y - ay) - (by - ay) * (x - ax);
      if (cross.abs() <= 1e-9 &&
          x >= math.min(ax, bx) - 1e-9 &&
          x <= math.max(ax, bx) + 1e-9 &&
          y >= math.min(ay, by) - 1e-9 &&
          y <= math.max(ay, by) + 1e-9) {
        return true;
      }
      if ((ay > y) != (by > y) && x < ax + (y - ay) * (bx - ax) / (by - ay)) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// The fraction of the link from (ax, ay) on the ground to above (x, y) that lies inside the
  /// footprint. (The reference also requires each sample below the rubble height; with points on the
  /// ground and the phone inside the rubble that always holds.)
  double insideFraction(double ax, double ay, double x, double y) {
    var hits = 0;
    for (var s = 0; s < _pathSamples; s++) {
      final t = s / (_pathSamples - 1);
      if (contains(ax + t * (x - ax), ay + t * (y - ay))) hits++;
    }
    return hits / _pathSamples;
  }
}

/// The link model of [profile] (reference `bayes`): the mean signal without the common offset and its
/// spread, for path-loss exponent [exponent], attenuation [alpha], a link of [length] m with [rIn] m
/// inside the rubble.
({double mean, double sd}) linkModel(
  EngineProfile profile, {
  required double exponent,
  required double alpha,
  required double length,
  required double rIn,
}) {
  final loss = profile.linkVariation * alpha * rIn;
  return (
    mean:
        profile.txPowerAt1mDbm -
        10 * exponent * math.log(math.max(length, minLinkM)) / math.ln10 -
        alpha * rIn,
    sd: math.sqrt(
      profile.slowFadingDb * profile.slowFadingDb +
          profile.fastFadingDb * profile.fastFadingDb +
          loss * loss,
    ),
  );
}
