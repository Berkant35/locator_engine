import 'package:rubble_core/rubble_core.dart';

/// Points sampled along a link to measure how much of it runs inside the rubble.
const _pathSamples = 21;

/// The fraction of the link from [at] (on the ground) to the cell centre (above it) that lies
/// inside the rubble footprint. (The reference also requires the sample to be below the rubble
/// height; with points on the ground and the phone inside the rubble that always holds.)
double insideFraction(RubblePolygon outline, SitePoint at, double x, double y) {
  var hits = 0;
  for (var s = 0; s < _pathSamples; s++) {
    final t = s / (_pathSamples - 1);
    final px = at.x.value + t * (x - at.x.value);
    final py = at.y.value + t * (y - at.y.value);
    if (outline.contains(SitePoint(Meters(px), Meters(py)))) {
      hits++;
    }
  }
  return hits / _pathSamples;
}
