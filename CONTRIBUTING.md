# Contributing

Thanks for your interest. This repo follows a tight, issue-driven workflow. Always-on rules live in [INSTRUCTIONS.md](INSTRUCTIONS.md); this doc defines the commit and issue/PR workflow.

## Before You Start

- Open an issue (or claim an existing one) describing the change.
- Small fixes (typos, clear bugs) can skip the issue, but a PR is still required.

## Branching

- One branch per issue.
- Naming: `<type>/<issue-number>-<slug>` — e.g. `feat/12-add-x`, `fix/34-typo-in-readme`.
- Without an issue: `<type>/<slug>` — e.g. `docs/fix-readme-typo`.
- `<type>` is the dominant Conventional Commit type of the change; `<slug>` is a short kebab-case description.
- Never commit directly to `main`.

## Commits

- Follow [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).
- Format: `<type>[optional scope][!]: <description>` — e.g. `docs(rules/general): tighten rule 7 wording`.
- Types:
  - `feat` — new feature
  - `fix` — bug fix
  - `docs` — documentation only
  - `style` — formatting, no code change
  - `refactor` — code change that neither fixes a bug nor adds a feature
  - `perf` — performance improvement
  - `test` — add or fix tests
  - `build` — build system or dependencies
  - `ci` — CI configuration
  - `chore` — maintenance, no production code change
  - `revert` — revert a previous commit
- Scope: optional, lowercase, hierarchical with `/` separators. It names the logical area, not a file path.
  - Be specific: `rules/general`, `rules/git-workflow`.
  - Use a broader scope for cross-cutting changes: `rules`.
- Description: imperative mood, lowercase, no trailing period.
- Body: reference the issue with `Refs #<issue-number>` (if one exists).
- Breaking changes: add `!` after type/scope and a `BREAKING CHANGE: <details>` footer.
- Atomic: one logical concern per commit. Don't mix unrelated changes.
- No AI attribution or co-authoring trailers.

## Pull Requests

- Title uses Conventional Commits and mirrors the primary commit subject.
- Body follows the [PR template](.github/PULL_REQUEST_TEMPLATE.md):
  - `Closes #<issue-number>` (omit if there is no issue).
  - **Summary**: 1–3 bullets on what changed and why.
  - **Test Plan**: how the change was verified (omit for pure docs/typo changes).
- Label issues and PRs with existing labels only; don't create new ones.
- After opening, watch CI checks if any are configured (`gh pr checks`) and review feedback (`gh pr view --comments`). Resolve conflicts by rebasing onto `main`.
- Keep scope tight — open a separate PR for unrelated work.
- Maintainer merges; do not self-merge.

## Releases

- Fully automated via [release-please](https://github.com/googleapis/release-please), configured in [release-please-config.json](release-please-config.json).
- Version bumps:
  - Major: breaking change (`!` or `BREAKING CHANGE:` footer).
  - Minor: `feat`.
  - Patch: `fix`, `perf`, `revert`, `docs`.
- `style`, `refactor`, `test`, `build`, `ci`, and `chore` are hidden from the changelog and don't trigger a release on their own.
- Don't edit `CHANGELOG.md`, the version in `INSTRUCTIONS.md` frontmatter or `install.sh`, or `.release-please-manifest.json` by hand — release-please owns them.
