## 0.1.2
- rubble_core v0.3.0.

## 0.1.1
- Faster on large and early-stage sites: a site above `maxCells` (6000) gets a coarser grid (a whole
  multiple of the profile's cell); the share of each path inside the rubble is computed once per point
  and cell; the next point is scored against 1 m blocks. 40 × 30 m with 15 points heard nowhere: both
  profiles in under 3 s on a laptop (was 7 s); 80 × 60 m in seconds (was ~50 s).

## 0.1.0
- `estimate`: Bayesian probability map over the rubble outline (0.25 m cells) with 50 % / 90 % regions
  (by cell count, so a region is exactly its reported area);
  non-detections as censored observations; unknowns marginalised; matches the Python reference.
- `suggestNextPoint`: the most informative spot 1 m outside the rubble, 2 m from measured points.
- `EngineProfile`: `voided_pancake@1`, `dense@1`.
