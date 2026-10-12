import 'package:locator_engine/locator_engine.dart';
import 'package:rubble_core/rubble_core.dart';
import 'package:test/test.dart';

SitePoint p(double x, double y) => SitePoint(Meters(x), Meters(y));

void main() {
  final rect = RubblePolygon([p(0, 0), p(12, 0), p(12, 10), p(0, 10)]);
  final profile = EngineProfile.voidedPancake;

  test(
    'with no measurement yet, the suggestion is a spot just outside the rubble',
    () {
      final map = estimate(
        outline: rect,
        observations: const [],
        profile: profile,
      );
      final next = suggestNextPoint(
        outline: rect,
        observations: const [],
        map: map,
        profile: profile,
      )!;
      expect(rect.contains(next), isFalse);
      final distanceToRubble = [
        for (final e in rect.edges) _distance(next, e.start, e.end),
      ].reduce((a, b) => a < b ? a : b);
      expect(distanceToRubble, closeTo(1, 0.05));
    },
  );

  test('never within 2 m of a point already measured', () {
    final observations = [
      Observation.heard(p(-1, -1), const Dbm(-85)),
      Observation.notHeard(p(13, -1)),
      Observation.notHeard(p(13, 11)),
    ];
    final map = estimate(
      outline: rect,
      observations: observations,
      profile: profile,
    );
    final next = suggestNextPoint(
      outline: rect,
      observations: observations,
      map: map,
      profile: profile,
    )!;
    for (final o in observations) {
      expect(next.distanceTo(o.at).value, greaterThanOrEqualTo(2));
    }
  });

  test(
    'measuring where the map is uncertain: not next to a side already covered',
    () {
      final observations = [
        Observation.heard(p(-1, 2), const Dbm(-80)),
        Observation.heard(p(-1, 5), const Dbm(-78)),
        Observation.heard(p(-1, 8), const Dbm(-82)),
      ];
      final map = estimate(
        outline: rect,
        observations: observations,
        profile: profile,
      );
      final next = suggestNextPoint(
        outline: rect,
        observations: observations,
        map: map,
        profile: profile,
      )!;
      // Not one more spot on the west side (x = −1): another side tells north from south.
      expect(next.x.value, greaterThan(-0.5));
    },
  );

  test('the same input gives the same suggestion', () {
    final observations = [Observation.notHeard(p(6, -1))];
    final map = estimate(
      outline: rect,
      observations: observations,
      profile: profile,
    );
    SitePoint run() => suggestNextPoint(
      outline: rect,
      observations: observations,
      map: map,
      profile: profile,
    )!;
    expect(run(), run());
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
