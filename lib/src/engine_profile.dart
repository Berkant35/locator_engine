import 'dart:math' as math;

import 'package:meta/meta.dart';

List<double> _linspace(double from, double to, int count) => List.unmodifiable([
  for (var i = 0; i < count; i++) from + (to - from) * i / (count - 1),
]);

/// The physics assumptions of a rubble type, versioned (`voided_pancake@1`). Never inline these
/// numbers elsewhere (CLAUDE.md §7); a change is a new version with updated reference fixtures.
@immutable
final class EngineProfile {
  /// Creates a profile; throws [ArgumentError] when a grid of unknowns is empty, the phone would be
  /// above the rubble, or a spread or size is not positive.
  EngineProfile({
    required this.id,
    required this.txPowerAt1mDbm,
    required this.thresholdDbm,
    required this.slowFadingDb,
    required this.fastFadingDb,
    required this.offsetSdDb,
    required List<double> offsetsDb,
    required this.linkVariation,
    required List<double> pathLossExponents,
    required List<double> attenuationDbPerM,
    required this.rubbleHeightM,
    required List<double> victimHeightFractions,
    required this.cellM,
  }) : offsetsDb = List.unmodifiable(offsetsDb),
       pathLossExponents = List.unmodifiable(pathLossExponents),
       attenuationDbPerM = List.unmodifiable(attenuationDbPerM),
       victimHeightFractions = List.unmodifiable(victimHeightFractions) {
    for (final (name, list) in [
      ('offsetsDb', offsetsDb),
      ('pathLossExponents', pathLossExponents),
      ('attenuationDbPerM', attenuationDbPerM),
      ('victimHeightFractions', victimHeightFractions),
    ]) {
      if (list.isEmpty) {
        throw ArgumentError.value(list, name, 'must not be empty');
      }
    }
    if (victimHeightFractions.any((f) => f < 0 || f > 1)) {
      throw ArgumentError.value(
        victimHeightFractions,
        'victimHeightFractions',
        'the phone is inside the rubble: 0–1',
      );
    }
    for (final (name, value) in [
      ('slowFadingDb', slowFadingDb),
      ('offsetSdDb', offsetSdDb),
      ('rubbleHeightM', rubbleHeightM),
      ('cellM', cellM),
    ]) {
      if (!(value > 0)) throw ArgumentError.value(value, name, 'must be > 0');
    }
  }

  /// A profile from [toJson]'s output (throws [ArgumentError] when invalid).
  factory EngineProfile.fromJson(Map<String, Object?> json) {
    double number(String key) => (json[key]! as num).toDouble();
    List<double> numbers(String key) => [
      for (final v in json[key]! as List<Object?>) (v! as num).toDouble(),
    ];
    return EngineProfile(
      id: json['id']! as String,
      txPowerAt1mDbm: number('txPowerAt1mDbm'),
      thresholdDbm: number('thresholdDbm'),
      slowFadingDb: number('slowFadingDb'),
      fastFadingDb: number('fastFadingDb'),
      offsetSdDb: number('offsetSdDb'),
      offsetsDb: numbers('offsetsDb'),
      linkVariation: number('linkVariation'),
      pathLossExponents: numbers('pathLossExponents'),
      attenuationDbPerM: numbers('attenuationDbPerM'),
      rubbleHeightM: number('rubbleHeightM'),
      victimHeightFractions: numbers('victimHeightFractions'),
      cellM: number('cellM'),
    );
  }

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
    pathLossExponents: [2, 2.5, 3],
    attenuationDbPerM: _linspace(2, 6, 5),
    rubbleHeightM: 4,
    victimHeightFractions: [0.25, 0.6],
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
    pathLossExponents: [2, 2.5, 3],
    attenuationDbPerM: _linspace(5, 15, 5),
    rubbleHeightM: 4,
    victimHeightFractions: [0.25, 0.6],
    cellM: 0.25,
  );

  /// Every built-in profile.
  static final builtIn = List<EngineProfile>.unmodifiable([
    voidedPancake,
    dense,
  ]);

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
