# Security policy

BeneathSOS is safety-critical software. Please report vulnerabilities privately via
**GitHub → Security → Report a vulnerability** (private advisory). Do not open public issues for them.

## Repository protections
Applied as GitHub rulesets on `main` and `release/*` (definitions in `.github/rulesets/`):
- **Everyone, including maintainers:** no force push, no branch deletion, linear history (no merge
  commits — pull requests are squashed or rebased).
- **Contributors:** changes only through pull requests; review threads must be resolved; in
  repositories with CI, the `checks` job must pass. Maintainers (repository admins) may push directly
  while the project has a single maintainer; this will be tightened when a second maintainer joins.
- **Auto-merge is disabled.** Every merge is a deliberate human action.
- Workflows from first-time contributors' forks require maintainer approval before running.
  Workflows use `pull_request` (never `pull_request_target`) and read-only token permissions.
- Dependabot updates pub and GitHub Actions dependencies weekly.
- Private vulnerability reporting is enabled (Security → Report a vulnerability).

## App principles
No network calls, no analytics, no account system in v1. All data stays on the device until the user
explicitly exports it.
