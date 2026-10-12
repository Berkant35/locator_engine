# locator_engine

[![CI](https://github.com/Berkant35/locator_engine/actions/workflows/ci.yml/badge.svg)](https://github.com/Berkant35/locator_engine/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

The probability engine of [BeneathSOS](https://github.com/Berkant35/beneathsos), pure Dart: where a phone
under rubble most likely is, from the Bluetooth signal measured at a few points around the rubble.

- **`estimate`** — a probability map on a 0.25 m grid over the rubble outline, with the 50 % and 90 %
  regions and their areas. Never a single point: RSSI cannot separate distance from attenuation, so the
  unknowns (path-loss exponent, rubble attenuation, the phone's common offset and height) are
  marginalised. **A point where the phone was not heard is data** — a censored observation.
- **`suggestNextPoint`** — the spot 1 m outside the rubble expected to teach the most (uncertainty of
  "heard or not" plus, if heard, how much the likely cells disagree about the signal).
- **`EngineProfile`** — versioned physics assumptions (`voided_pancake@1`, `dense@1`).

It reproduces the hub's Python reference (`tools/sim/engine_reference.py`, golden fixtures in
`test/fixtures`). Heavy: call it off the UI isolate (`Isolate.run`).

```dart
final map = estimate(
  outline: outline,
  observations: [Observation.heard(a, const Dbm(-84)), Observation.notHeard(b)],
  profile: EngineProfile.voidedPancake,
);
map.area50; // SquareMeters — the most likely area
map.regionOf(i); // Region.likely50 / likely90 / outside, per cell
```

`estimate` needs at least one observation (a map out of nothing would mislead) and an outline larger
than one cell; it throws `ArgumentError` otherwise.

Depends only on [`rubble_core`](https://github.com/Berkant35/rubble_core). Licence: Apache-2.0.
