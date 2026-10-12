# Contributing to BeneathSOS

Thanks for helping! This project may be used in real disasters, so correctness beats speed.
By participating you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

1. Read `CLAUDE.md` (rules — they apply to humans too) and `docs/architecture.md`.
2. Install FVM, then `fvm install` in the repo you work on.
3. To work on several repos together, clone the hub `Berkant35/beneathsos`, clone the other repos into
   `apps/` and `packages/`, then run `tools/link_local.sh` (creates `pubspec_overrides.yaml` files).
4. Open an issue first for anything bigger than a small fix, so the design can be agreed.
5. Branch from `main` (`feat/...`, `fix/...`), use Conventional Commits, open a PR with the template.
6. CI must be green; a code owner reviews every PR. Nobody — including maintainers — merges
   without review, and there is no auto-merge.

Engine changes must keep `tools/sim` golden fixtures passing or update them with justification.
New user-facing text needs both `app_en.arb` and `app_tr.arb` entries.
