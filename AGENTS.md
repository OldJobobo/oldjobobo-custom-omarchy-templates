# Repository Guidelines

## Project Structure & Module Organization
This repository stores user-managed Omarchy template overrides.

- `colors.css.tpl`: Main template source. Omarchy renders this into `colors.css` using theme `colors.toml` values.
- `waybar.css.tpl`: Waybar template source. Omarchy renders this into `waybar.css` using theme `colors.toml` values.
- `scripts/install.sh`: Interactive installer for linking repo `*.tpl` files into Omarchy overrides.
- `scripts/uninstall.sh`: Interactive uninstaller for removing repo-managed template links from Omarchy overrides.
- `scripts/bump-version.sh`: SemVer helper that updates `VERSION`.
- `VERSION`: Single source of truth for project version.
- `CHANGELOG.md`: Human-readable release notes.
- `README.md`: Usage and wiring details.
- `DEVELOPMENT.md`: Maintainer/developer workflows and release process.

Runtime integration is external to this repo:
- Symlink targets: `~/.config/omarchy/themed/*.tpl`
- Rendered outputs (after theme apply): `~/.config/omarchy/current/theme/colors.css`, `~/.config/omarchy/current/theme/waybar.css`

## Build, Test, and Development Commands
This repo has no compile/build step.

Developer and release workflow commands are documented in `DEVELOPMENT.md`.

## Coding Style & Naming Conventions
- Use Bash with `set -euo pipefail` for scripts.
- Use 2-space indentation in Markdown and shell snippets where practical.
- Keep templates flat and explicit: one `@define-color <name> <value>;` per line.
- Preserve placeholder format exactly: `{{ key }}`, `{{ key_strip }}`, `{{ key_rgb }}`.
- Use lowercase snake_case for color keys to match `colors.toml` patterns.

## Testing Guidelines
Automated tests are not set up yet; use manual validation:

1. Run `bash -n scripts/bump-version.sh`.
2. Apply a theme and confirm `~/.config/omarchy/current/theme/colors.css` and `~/.config/omarchy/current/theme/waybar.css` exist.
3. Ensure no unresolved placeholders remain in rendered files (for example, with `rg '{{'` against both rendered files).
4. Spot-check key mappings (`accent`, `background`, `color0`, `color15`) against the active `colors.toml`.

## Commit & Pull Request Guidelines
No historical convention exists yet. Use this standard:

- Commit format: `type(scope): summary` (example: `feat(template): add active tab colors`).
- Keep commits focused; include `VERSION`/`CHANGELOG.md` updates when behavior changes.
- PRs should include purpose, changed files, manual validation steps, and before/after snippets of generated `colors.css` when relevant.

## Security & Configuration Tips
- Do not commit secrets or machine-specific private paths.
- Keep symlink destinations under your home directory and verify with `ls -la ~/.config/omarchy/themed/*.tpl`.
