import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:rubble_core/rubble_core.dart';

/// Where the phone most likely is, as probabilities on a grid over the rubble — never a single
/// point (rule 1). Cells outside the outline have probability 0.
@immutable
final class ProbabilityMap {
  /// Creates a map.
  const ProbabilityMap({
    required this.origin,
    required this.cell,
    required this.cols,
    required this.rows,
    required this.probabilities,
    required this.area50,
    required this.area90,
    required this.threshold50,
    required this.threshold90,
  });

  /// South-west corner of the grid.
  final SitePoint origin;

  /// Cell size.
  final Meters cell;

  /// Cells west → east.
  final int cols;

  /// Cells south → north.
  final int rows;

  /// Probability per cell, row by row from the south (index = row × cols + col); sums to 1.
  final Float64List probabilities;

  /// Area of the smallest set of cells holding 50 % of the probability.
  final SquareMeters area50;

  /// Area of the smallest set of cells holding 90 % of the probability.
  final SquareMeters area90;

  /// A cell is in the 50 % region when its probability is at least this.
  final double threshold50;

  /// A cell is in the 90 % region when its probability is at least this.
  final double threshold90;

  /// The centre of cell [index].
  SitePoint centre(int index) => SitePoint(
    Meters(origin.x.value + cell.value * (index % cols + 0.5)),
    Meters(origin.y.value + cell.value * (index ~/ cols + 0.5)),
  );

  /// Whether cell [index] is in the 50 % region.
  bool in50(int index) => probabilities[index] >= threshold50;

  /// Whether cell [index] is in the 90 % region.
  bool in90(int index) => probabilities[index] >= threshold90;
}
