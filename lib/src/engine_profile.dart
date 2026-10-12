import 'dart:math' as math;

import 'package:meta/meta.dart';

List<double> _linspace(double from, double to, int count) => [
  for (var i = 0; i < count; i++) from + (to - from) * i / (count - 1),
];

/// The physics assumptions of a rubble type, versioned (`voided_pancake@1`). Never inline these
/// numbers elsewhere (CLAUDE.md §7); a change is a new version with updated reference fixtures.
@immutable
final class EngineProfile {
  /// Creates a profile.
  const EngineProfile({
    required this.id,
    required this.txPowerAt1mDbm,
    required this.thresholdDbm,
    required this.slowFadingDb,
    required this.fastFadingDb,
    required this.offsetSdDb,
    required this.offsetsDb,
    required this.linkVariation,
    required this.pathLossExponents,
    required this.attenuationDbPerM,
    required this.rubbleHeightM,
    required this.victimHeightFractions,
    required this.cellM,
  });

  /// Pancake collapse with voids (typical 4–5 storey apartment): 2–6 dB per metre of rubble.
  static final voidedPancake = EngineProfile(
    id: 'voided_pancake@1',
    txPowerAt1mDbm: -59,
    thresholdDbm: -100,
    slowFadingDb: 6,
    fastFadingDb: 5 / math.sqrt(20),
    offsetSdDb: 5,
    offsetsDb: _linspace(-12, 12, 9),
    linkVariation: 0.3,
    pathLossExponents: const [2, 2.5, 3],
    attenuationDbPerM: _linspace(2, 6, 5),
    rubbleHeightM: 4,
    victimHeightFractions: const [0.25, 0.6],
    cellM: 0.25,
  );

  /// Dense rubble: 5–15 dB per metre.
  static final dense = EngineProfile(
    id: 'dense@1',
    txPowerAt1mDbm: -59,
    thresholdDbm: -100,
    slowFadingDb: 6,
    fastFadingDb: 5 / math.sqrt(20),
    offsetSdDb: 5,
    offsetsDb: _linspace(-12, 12, 9),
    linkVariation: 0.3,
    pathLossExponents: const [2, 2.5, 3],
    attenuationDbPerM: _linspace(5, 15, 5),
    rubbleHeightM: 4,
    victimHeightFractions: const [0.25, 0.6],
    cellM: 0.25,
  );

  /// Every built-in profile.
  static final builtIn = [voidedPancake, dense];

  /// The built-in profile [id], or null.
  static EngineProfile? byId(String id) =>
      builtIn.where((p) => p.id == id).firstOrNull;

  /// Versioned id.
  final String id;

  /// Received signal 1 m from the phone in free air (dBm).
  final double txPowerAt1mDbm;

  /// Below this a phone is not heard (dBm).
  final double thresholdDbm;

  /// Slow fading (shadowing), does not average out (dB).
  final double slowFadingDb;

  /// Fast fading left after averaging a point's readings (dB).
  final double fastFadingDb;

  /// Spread of the common offset of the trapped phone (body, orientation, model) (dB).
  final double offsetSdDb;

  /// The offsets the common offset is marginalised over (dB).
  final List<double> offsetsDb;

  /// Relative spread of the rubble loss per link.
  final double linkVariation;

  /// Path-loss exponents marginalised over.
  final List<double> pathLossExponents;

  /// Rubble attenuations marginalised over (dB per metre inside the rubble).
  final List<double> attenuationDbPerM;

  /// Assumed rubble height (m).
  final double rubbleHeightM;

  /// Heights of the phone as fractions of [rubbleHeightM], marginalised over.
  final List<double> victimHeightFractions;

  /// Grid cell size (m).
  final double cellM;

  /// JSON (the same keys as the reference profiles in the hub's `tools/sim`).
  Map<String, Object?> toJson() => {
    'id': id,
    'txPowerAt1mDbm': txPowerAt1mDbm,
    'thresholdDbm': thresholdDbm,
    'slowFadingDb': slowFadingDb,
    'fastFadingDb': fastFadingDb,
    'offsetSdDb': offsetSdDb,
    'offsetsDb': offsetsDb,
    'linkVariation': linkVariation,
    'pathLossExponents': pathLossExponents,
    'attenuationDbPerM': attenuationDbPerM,
    'rubbleHeightM': rubbleHeightM,
    'victimHeightFractions': victimHeightFractions,
    'cellM': cellM,
  };
}
