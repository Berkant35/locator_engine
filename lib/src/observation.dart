import 'package:meta/meta.dart';
import 'package:rubble_core/rubble_core.dart';

/// What was heard of one target at one measurement point.
@immutable
final class Observation {
  /// Heard with this median.
  const Observation.heard(this.at, Dbm this.median);

  /// Not heard — information too (rule 3): it lowers the probability near the point.
  const Observation.notHeard(this.at) : median = null;

  /// Where the rescuer stood (on the ground).
  final SitePoint at;

  /// The median signal, or null when not heard.
  final Dbm? median;

  /// Whether the phone was heard.
  bool get heard => median != null;
}
