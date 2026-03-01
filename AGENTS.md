# Repository Guidelines

## Project Structure & Module Organization
This repository stores user-managed Omarchy template overrides.

- `colors.css.tpl`: Main template source. Omarchy renders this into `colors.css` using theme `colors.toml` values.
- `scripts/bump-version.sh`: SemVer helper that updates `VERSION`.
- `VERSION`: Single source of truth for project version.
- `CHANGELOG.md`: Human-readable release notes.
- `README.md`: Usage and wiring details.

Runtime integration is external to this repo:
- Symlink target: `~/.config/omarchy/themed/colors.css.tpl`
- Rendered output (after theme apply): `~/.config/omarchy/current/theme/colors.css`

## Build, Test, and Development Commands
This repo has no compile/build step.

- `bash -n scripts/bump-version.sh`: Validate script syntax.
- `./scripts/bump-version.sh patch|minor|major`: Bump SemVer in `VERSION`.
- `rg '{{|}}' colors.css.tpl`: Quick placeholder sanity check.
- `omarchy-theme-set <theme>`: Trigger Omarchy render flow for manual verification.

## Coding Style & Naming Conventions
- Use Bash with `set -euo pipefail` for scripts.
- Use 2-space indentation in Markdown and shell snippets where practical.
- Keep templates flat and explicit: one `@define_color <name> <value>;` per line.
- Preserve placeholder format exactly: `{{ key }}`, `{{ key_strip }}`, `{{ key_rgb }}`.
- Use lowercase snake_case for color keys to match `colors.toml` patterns.

## Testing Guidelines
Automated tests are not set up yet; use manual validation:

1. Run `bash -n scripts/bump-version.sh`.
2. Apply a theme and confirm `~/.config/omarchy/current/theme/colors.css` exists.
3. Ensure no unresolved placeholders remain: `rg '{{' ~/.config/omarchy/current/theme/colors.css`.
4. Spot-check key mappings (`accent`, `background`, `color0`, `color15`) against the active `colors.toml`.

## Commit & Pull Request Guidelines
No historical convention exists yet. Use this standard:

- Commit format: `type(scope): summary` (example: `feat(template): add active tab colors`).
- Keep commits focused; include `VERSION`/`CHANGELOG.md` updates when behavior changes.
- PRs should include purpose, changed files, manual validation steps, and before/after snippets of generated `colors.css` when relevant.

## Security & Configuration Tips
- Do not commit secrets or machine-specific private paths.
- Keep symlink destinations under your home directory and verify with `ls -la ~/.config/omarchy/themed/colors.css.tpl`.
