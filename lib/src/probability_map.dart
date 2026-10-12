import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:rubble_core/rubble_core.dart';

/// Which probability region a cell belongs to.
enum Region {
  /// In the smallest set of cells holding 50 % of the probability: the most likely area.
  likely50,

  /// In the 90 % set but not the 50 % one.
  likely90,

  /// Outside both (or outside the rubble).
  outside,
}

/// Where the phone most likely is, as probabilities on a grid over the rubble and the 50 % / 90 %
/// regions — never a single point (rule 1). Cells outside the outline have probability 0.
@immutable
final class ProbabilityMap {
  /// Creates a map; [regions] holds 2 (50 %), 1 (90 %) or 0 per cell.
  ProbabilityMap({
    required this.origin,
    required this.cell,
    required this.cols,
    required this.rows,
    required Float64List probabilities,
    required Uint8List regions,
  }) : probabilities = probabilities.asUnmodifiableView(),
       _regions = regions.asUnmodifiableView();

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

  final Uint8List _regions;

  /// The region of cell [index].
  Region regionOf(int index) => switch (_regions[index]) {
    2 => Region.likely50,
    1 => Region.likely90,
    _ => Region.outside,
  };

  /// Area of the 50 % region.
  SquareMeters get area50 => _area((r) => r == 2);

  /// Area of the 90 % region (the 50 % region included).
  SquareMeters get area90 => _area((r) => r >= 1);

  SquareMeters _area(bool Function(int) counted) =>
      SquareMeters(_regions.where(counted).length * cell.value * cell.value);

  /// The centre of cell [index].
  SitePoint centre(int index) => SitePoint(
    Meters(origin.x.value + cell.value * (index % cols + 0.5)),
    Meters(origin.y.value + cell.value * (index ~/ cols + 0.5)),
  );
}
