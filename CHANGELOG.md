## 0.1.0
- `estimate`: Bayesian probability map over the rubble outline (0.25 m cells) with 50 % / 90 % regions
  (by cell count, so a region is exactly its reported area);
  non-detections as censored observations; unknowns marginalised; matches the Python reference.
- `suggestNextPoint`: the most informative spot 1 m outside the rubble, 2 m from measured points.
- `EngineProfile`: `voided_pancake@1`, `dense@1`.
