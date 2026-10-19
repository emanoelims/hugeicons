# Contributing

Use Elixir `1.20.4-otp-29` and Erlang/OTP `29`, as configured in `mise.toml`.
Elixir is pinned to a specific release built for OTP 29. Erlang can receive
updates within the 29 series through `mise upgrade erlang`. Update the Elixir
pin explicitly when adopting a new release.

Run `mise install`, then `mise run setup`. Before opening a PR, run
`mise run precommit`, which executes `mix precommit`: compilation without
warnings, unused lockfile entries, formatting, strict Credo, Doctor, docs
without warnings, Dialyzer, and tests with the coverage floor. Mise tasks
automatically use the configured tools. For individual commands, use
`mise exec -- mix <task>`. See the
[mise documentation](https://mise.jdx.dev/getting-started.html) for installation
and shell activation.

The library's own builds read the fixture icons in `test/fixtures/icons`
(`config/config.exs`), so development and CI need neither the network nor a
license key.

## Benchmarks

`mise run bench` reproduces the measurements of the design spec
(`docs/superpowers/specs/2026-10-18-hugeicons-design.md`) with the real free
icons, and prints Markdown tables to paste in a PR:

- `bench/diff.exs`: the LiveView diff payload of a list of rows rendering the
  same icon (initial render, unrelated assign change, `size` change), for the
  shipped component and the rejected approaches kept as reference code.
  Options: `--rows 50`, `--icon FirstBracketIcon`.
- `bench/compile.exs`: the compile time of the chunk modules with a warm cache
  and their `.beam` size, next to a map literal and a single module.
  Option: `--rounds 3`.

Run one script with `mise exec -- elixir bench/diff.exs --rows 20`. The scripts
install this checkout with `Mix.install` (using `mix.lock`), download
`@hugeicons/core-free-icons` from npm on the first run, outside the timed
sections, and keep everything in `_build/bench`. They ignore
`HUGEICONS_LICENSE_KEY`, so they never download Pro icons. Re-run them when
LiveView, OTP or the design changes, and update the spec with the new numbers.

## Supported versions

The library supports Elixir `~> 1.20` and `phoenix_live_view` `~> 1.1`, as
declared in `mix.exs`. The required `Elixir checks` job runs everything against
the LiveView release locked in `mix.lock` (1.2). The `Lowest LiveView` job, not
required, sets `HUGEICONS_LIVE_VIEW_REQUIREMENT="~> 1.1.0"`, which `mix.exs`
reads in place of its default requirement, unlocks `phoenix_live_view` and runs
the compiler and the tests against the latest 1.1 release. To reproduce it
locally, then go back to the locked version (never commit the changed
`mix.lock`):

```sh
export HUGEICONS_LIVE_VIEW_REQUIREMENT="~> 1.1.0" MIX_ENV=test
mise exec -- mix deps.unlock phoenix_live_view
mise exec -- mix deps.get
mise exec -- mix test --warnings-as-errors
unset HUGEICONS_LIVE_VIEW_REQUIREMENT MIX_ENV
git checkout mix.lock
mise exec -- mix deps.get
```

When raising the lowest supported LiveView, update the requirement in
`mix.exs`, the job's `HUGEICONS_LIVE_VIEW_REQUIREMENT`, this section and the
README.

## Icons and the license key

This repository never contains Hugeicons Pro icons, in any form: not as SVG,
not as converted markup, not in fixtures, screenshots, docs or benchmarks.
Fixtures use free icons (MIT, with their license file) or synthetic shapes.
`_build/hugeicons` holds downloaded icons and is ignored by Git.

To try Pro styles locally, put your key in `mise.local.toml` (ignored by Git;
copy `mise.local.toml.example`). `mise exec -- mix test --only pro` downloads
every Pro style into a temporary directory, checks them and deletes them; the
regular suite removes the key from its environment and never uses it. Never commit a key, even temporarily: a
committed credential must be revoked, not just deleted. Do not paste keys in
issues, PRs, logs or test output.

## Branches and review

Create a branch such as `feat/variants`, `fix/fetcher`, or `docs/readme` and
open a PR against `main`. Merges use squash: the PR title becomes the commit
subject on `main`. Keep the title up to date and wait for `Conventions` and
`Elixir checks` to pass.

Use the issue forms for reproducible bugs and concrete feature proposals. PRs
should explain the resulting behavior, applicable documentation and tests, and
any impact on the public API or on what is downloaded. Focus each PR on one
subject and run the nearest tests while working.

CI cancels obsolete runs, limits job runtime, pins Actions to immutable commits,
and uses caches keyed by the BEAM versions, test environment, and lockfile.
Dependabot proposes weekly Mix and GitHub Actions updates using allowed
Conventional Commit prefixes. Updates are grouped: one PR for compatible Mix
updates, one for GitHub Actions, and separate PRs for major Mix updates.
A seven-day cooldown keeps brand-new releases out of version updates until they
have had time to be noticed if broken or compromised; security updates are not
delayed. Review its PRs and let the same required checks validate them; updates
are not merged automatically.

## Conventional Commits

Use `<type>[optional scope][!]: <description>` for commit subjects and PR titles.
Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
`build`, `ci`, `chore`, and `revert`. Scopes use lowercase letters, numbers,
periods, hyphens, underscores, or slashes. Write descriptions, documentation,
and developer-facing messages in English.

Examples:

- `feat(component): add the alt_icon attribute`
- `fix(fetcher): follow the registry's tarball host`
- `ci: validate project conventions`
- `feat(component)!: rename variant to style`

For incompatible changes, use `!` in the PR title and explain the migration
in the body with `BREAKING CHANGE: ...`. This preserves the signal during squash.
CI validates PR titles with `.github/scripts/check_pr_title.exs`.

## Semantic versioning

The version source is `@version` in `mix.exs`, using `MAJOR.MINOR.PATCH`.

- `fix`: increment PATCH, for example `1.2.0` → `1.2.1`.
- Backward-compatible `feat`: increment MINOR, for example `1.2.0` → `1.3.0`.
- Incompatible change: increment MAJOR, for example `1.2.0` → `2.0.0`.
- Other types do not require a release by themselves; assess the public impact.

During `0.x`, the project is experimental. Our policy is to increment MINOR
for features and incompatible changes, and PATCH for fixes. The first release
with a stability commitment will be `1.0.0`.

The public API is the `hugeicons_icon/1` component and its attributes, the
`config :hugeicons` options, `Hugeicons.names/0`, `Hugeicons.variants/0`,
`mix hugeicons.install`, `mix hugeicons.search`, and the documented modules.
`Hugeicons.Chunks.*` are generated internals.

## Changelog

`CHANGELOG.md` is curated manually for people, not generated from commits.
Add user-facing changes under `## [Unreleased]` in the same PR that makes them,
using Added, Changed, Deprecated, Removed, Fixed, and Security as applicable,
and omit empty categories. Add a Migration section when a release needs manual
steps (new configuration, renamed attributes). Describe the resulting behavior
rather than restating commit subjects; internal refactors and CI changes
usually need no entry.

## Releases

For a release, open a PR titled `chore(release): prepare X.Y.Z`, update
`@version` in `mix.exs`, and move the `[Unreleased]` entries to a new
`## [X.Y.Z] - YYYY-MM-DD` section. After merging and passing CI on `main`,
create tag `vX.Y.Z` at the corresponding commit and publish a GitHub release
for it. CI checks that the tag matches `mix.exs` exactly. Prereleases may use
`X.Y.Z-rc.1`. Version increments are reviewed manually. Do not move or reuse
release tags.

The package is not published to Hex yet: publishing waits for
[#1](https://github.com/emanoelims/hugeicons/issues/1) (licensing and naming
with Hugeicons). When it is, check with
`mix hex.build --unpack` that the package holds only `package: [files: ...]`
from `mix.exs` before `mix hex.publish`.

## Elixir and Phoenix

Follow `AGENTS.md`, the formatter configured in `.formatter.exs`, and official
conventions: `CamelCase` modules, `snake_case` functions and variables,
predicates ending in `?`, and functions ending in `!` for raising variants where
applicable.

`mix format` uses [Styler](https://github.com/adobe/elixir-styler) for Elixir
and `Phoenix.LiveView.HTMLFormatter` for HEEx. Styler automatically organizes
module directives and rewrites code to follow a consistent style. Credo remains
enabled for analysis beyond automatic formatting. Review the resulting diff,
particularly control flow and configuration changes, because some Styler
rewrites can affect behavior. CI verifies the same formatter output with
`mix format --check-formatted`.

Doctor requires a `@moduledoc` and `@doc` for every public module and function,
and a `@spec` for at least 90% of them. Use the
[official typespecs reference](https://elixir.hexdocs.pm/typespecs.html):
define types in the module that owns the concept, document them with
`@typedoc`, and include actual success, error and nullable results.

Use the [official Elixir anti-pattern guides](https://elixir.hexdocs.pm/what-anti-patterns.md)
alongside `AGENTS.md`. An anti-pattern alone does not justify a rewrite: explain
the behavior, contract, or maintenance problem before proposing a refactor, keep
it within scope, and preserve intentional framework conventions.

The CI audit uses `mix hex.audit`, which fails when a locked Hex dependency has
a security advisory or was retired by its maintainers. Run
`mise exec -- mix hex.audit` separately when changing dependencies. This check
needs network access and is separate from the local `precommit` alias. When a
finding does not affect the project, acknowledge it narrowly in the `:hex`
section of `mix.exs` (`ignore_advisories` or `ignore_retirements`) and explain
why in the PR; ignored findings are still listed but no longer fail CI.

GitHub's dependency graph does not read `mix.lock`, so the `Dependency
submission` workflow uses `erlef/mix-dependency-submission` to submit the
resolved Mix dependencies whenever `mix.exs` or `mix.lock` changes on `main`.
Alerts then cover Hex packages as well as GitHub Actions. A clean result from
either tool is not a guarantee that every dependency is free of
vulnerabilities.

## Security reports

Follow [SECURITY.md](SECURITY.md). Never include license keys, tokens, or
personal data in public issues, logs, screenshots, or test fixtures.

References:

- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
- [SemVer 2.0](https://semver.org/)
- [Elixir library guidelines](https://hexdocs.pm/elixir/library-guidelines.html)
- [Elixir naming conventions](https://hexdocs.pm/elixir/naming-conventions.html)
- [Elixir builds in mise](https://mise.jdx.dev/lang/elixir.html)
