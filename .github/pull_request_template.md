## What & why

## How it was verified
- [ ] `fvm flutter analyze --fatal-infos` ✅
- [ ] `fvm dart format --set-exit-if-changed .` ✅
- [ ] `fvm flutter test` ✅
- [ ] `tools/dev.sh check` (hub: dependency rules + l10n) ✅
- [ ] Screenshots / recordings for UI changes

## Rules checklist (CLAUDE.md)
- [ ] No "victim is here" wording; uncertainty always shown
- [ ] No hard-coded user-facing strings (en + tr ARB updated)
- [ ] Screens ≤ ~200 lines, widget logic in mixins, AppScaffold used
- [ ] Hardware accessed only via `core/services`
- [ ] No network calls / telemetry / secrets added
- [ ] `docs/architecture.md` updated if a boundary, event, route or table changed
- [ ] UI changes: [accessibility checklist](https://github.com/Berkant35/beneathsos/blob/main/docs/design/accessibility.md#pull-request-checklist-ui-changes) completed
