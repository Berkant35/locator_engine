import 'package:locator_engine/locator_engine.dart';
import 'package:rubble_core/rubble_core.dart';
import 'package:test/test.dart';

SitePoint p(double x, double y) => SitePoint(Meters(x), Meters(y));

void main() {
  final rect = RubblePolygon([p(0, 0), p(12, 0), p(12, 10), p(0, 10)]);
  final profile = EngineProfile.voidedPancake;

  ProbabilityMap mapOf(
    List<Observation> observations, [
    RubblePolygon? outline,
  ]) => estimate(
    outline: outline ?? rect,
    observations: observations,
    profile: profile,
  );

  test(
    'without any observation there is no map (never a region out of nothing)',
    () {
      expect(() => mapOf(const []), throwsArgumentError);
    },
  );

  test('an outline too small for one cell centre has no map', () {
    final tiny = RubblePolygon([
      p(0.13, 0.13),
      p(0.23, 0.13),
      p(0.23, 0.23),
      p(0.13, 0.23),
    ]);
    expect(
      () => mapOf([Observation.notHeard(p(-1, -1))], tiny),
      throwsArgumentError,
    );
  });

  test('regions are exactly the cells counted in their areas; nothing outside the outline', () {
    final ell = RubblePolygon([
      p(0, 0),
      p(12, 0),
      p(12, 5),
      p(6, 5),
      p(6, 10),
      p(0, 10),
    ]);
    final map = mapOf([
      Observation.heard(p(-1, 2), const Dbm(-85)),
      Observation.notHeard(p(13, 2)),
      Observation.notHeard(p(-1, 11)),
    ], ell);
    var in50 = 0;
    var in90 = 0;
    for (var i = 0; i < map.probabilities.length; i++) {
      final region = map.regionOf(i);
      if (region != Region.outside) expect(ell.contains(map.centre(i)), isTrue);
      if (region == Region.likely50) in50++;
      if (region != Region.outside) in90++;
    }
    const cellArea = 0.25 * 0.25;
    expect(in50 * cellArea, closeTo(map.area50.value, 1e-9));
    expect(in90 * cellArea, closeTo(map.area90.value, 1e-9));
    expect(map.area50.value, lessThan(map.area90.value));
  });

  test('a point where the phone is not heard lowers the probability near it (rule 3)', () {
    double southWest(ProbabilityMap map) {
      var sum = 0.0;
      for (var i = 0; i < map.probabilities.length; i++) {
        final c = map.centre(i);
        if (c.x.value < 4 && c.y.value < 4) sum += map.probabilities[i];
      }
      return sum;
    }

    final heard = [Observation.heard(p(6, -1), const Dbm(-88))];
    final before = southWest(mapOf(heard));
    final after = southWest(mapOf([...heard, Observation.notHeard(p(-1, -1))]));
    expect(after, lessThan(before * 0.8));
  });

  test('maps and profiles cannot be changed by callers', () {
    final map = mapOf([Observation.notHeard(p(-1, -1))]);
    expect(() => map.probabilities[0] = 1, throwsUnsupportedError);
    expect(
      () => EngineProfile.voidedPancake.offsetsDb.add(1),
      throwsUnsupportedError,
    );
    expect(EngineProfile.builtIn.clear, throwsUnsupportedError);
  });

  test('a profile with an empty grid of unknowns or a phone above the rubble is rejected', () {
    final json = EngineProfile.voidedPancake.toJson();
    expect(
      () => EngineProfile.fromJson({...json, 'offsetsDb': <double>[]}),
      throwsArgumentError,
    );
    expect(
      () => EngineProfile.fromJson({
        ...json,
        'victimHeightFractions': [1.2],
      }),
      throwsArgumentError,
    );
    expect(EngineProfile.fromJson(json).id, 'voided_pancake@1');
  });

  test('suggestions keep 1 m from every wall, also in a narrow notch', () {
    // A U with a 1.2 m wide notch from the north.
    final u = RubblePolygon([
      p(0, 0),
      p(10, 0),
      p(10, 10),
      p(5.6, 10),
      p(5.6, 3),
      p(4.4, 3),
      p(4.4, 10),
      p(0, 10),
    ]);
    final observations = [
      Observation.notHeard(p(-1, -1)),
      Observation.notHeard(p(11, -1)),
    ];
    final map = mapOf(observations, u);
    final next = suggestNextPoint(
      outline: u,
      observations: observations,
      map: map,
      profile: profile,
    )!;
    for (final e in u.edges) {
      expect(_distance(next, e.start, e.end), greaterThanOrEqualTo(1 - 1e-9));
    }
  });

  test(
    'a 40 × 30 m site with 12 points is mapped and suggested within the budget',
    () {
      final site = RubblePolygon([p(0, 0), p(40, 0), p(40, 30), p(0, 30)]);
      final observations = [
        for (var i = 0; i < 12; i++)
          i.isEven
              ? Observation.notHeard(p(-1 + i * 3.5, -1))
              : Observation.heard(p(-1 + i * 3.5, 31), Dbm(-90 + i.toDouble())),
      ];
      final dense = EngineProfile.dense;
      final watch = Stopwatch()..start();
      final map = estimate(
        outline: site,
        observations: observations,
        profile: dense,
      );
      suggestNextPoint(
        outline: site,
        observations: observations,
        map: map,
        profile: dense,
      );
      watch.stop();
      // ~19 200 cells × 12 points × 270 combinations; was 13 s before the table and hoisting.
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    },
  );

  test('early in a search (15 points, nothing heard) a 40 × 30 m site stays within the budget', () {
    final site = RubblePolygon([p(0, 0), p(40, 0), p(40, 30), p(0, 30)]);
    // Around the whole site: the map stays nearly flat, the hardest case for the suggestion.
    final observations = [
      for (var i = 0; i < 5; i++) Observation.notHeard(p(-1 + i * 10.5, -1)),
      for (var i = 0; i < 5; i++) Observation.notHeard(p(-1 + i * 10.5, 31)),
      for (var i = 1; i < 4; i++) Observation.notHeard(p(-1, i * 7.5)),
      for (var i = 1; i < 3; i++) Observation.notHeard(p(41, i * 10.0)),
    ];
    final watch = Stopwatch()..start();
    for (final profile in EngineProfile.builtIn) {
      final map = estimate(
        outline: site,
        observations: observations,
        profile: profile,
      );
      suggestNextPoint(
        outline: site,
        observations: observations,
        map: map,
        profile: profile,
      );
    }
    watch.stop();
    // Both profiles; a phone is a few times slower than a laptop.
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });

  test('a very large site is mapped on a coarser grid, not for minutes', () {
    final site = RubblePolygon([p(0, 0), p(80, 0), p(80, 60), p(0, 60)]);
    final observations = [
      Observation.notHeard(p(-1, -1)),
      Observation.notHeard(p(81, 61)),
      Observation.heard(p(-1, 61), const Dbm(-95)),
    ];
    final watch = Stopwatch()..start();
    final map = estimate(
      outline: site,
      observations: observations,
      profile: EngineProfile.voidedPancake,
    );
    suggestNextPoint(
      outline: site,
      observations: observations,
      map: map,
      profile: EngineProfile.voidedPancake,
    );
    watch.stop();
    expect(map.cols * map.rows, lessThanOrEqualTo(maxCells));
    expect(map.cell.value, greaterThan(EngineProfile.voidedPancake.cellM));
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
  });
}

double _distance(SitePoint q, SitePoint a, SitePoint b) {
  final (abx, aby) = (b.x.value - a.x.value, b.y.value - a.y.value);
  final t =
      (((q.x.value - a.x.value) * abx + (q.y.value - a.y.value) * aby) /
              (abx * abx + aby * aby))
          .clamp(0.0, 1.0);
  return q
      .distanceTo(
        SitePoint(Meters(a.x.value + t * abx), Meters(a.y.value + t * aby)),
      )
      .value;
}
