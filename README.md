# Omarchy Templates

User-maintained Omarchy template overrides, currently focused on generating a `colors.css` file from theme `colors.toml` values.

## What this project contains

- `colors.css.tpl`: Mustache-style placeholder template consumed by Omarchy's template renderer.
- `VERSION`: Current project version (SemVer).
- `CHANGELOG.md`: Human-readable change history.
- `scripts/bump-version.sh`: Simple helper to bump `VERSION` (major/minor/patch).

## How it is wired into Omarchy

This project file is symlinked into Omarchy user overrides:

- Source: `~/Projects/omarchy-templates/colors.css.tpl`
- Link: `~/.config/omarchy/themed/colors.css.tpl`

Omarchy renders `colors.css.tpl` to `colors.css` during theme apply, using values from `colors.toml`.

## Editing workflow

1. Edit `colors.css.tpl` in this repo.
2. Apply/switch theme in Omarchy.
3. Verify generated output in `~/.config/omarchy/current/theme/colors.css`.

## Versioning

This repo uses simple SemVer in `VERSION`:

- Patch: fixes, small corrections (`0.1.0` -> `0.1.1`)
- Minor: backward-compatible additions (`0.1.0` -> `0.2.0`)
- Major: breaking changes (`0.1.0` -> `1.0.0`)

Bump version:

```bash
./scripts/bump-version.sh patch
./scripts/bump-version.sh minor
./scripts/bump-version.sh major
```

After bumping, add a short note in `CHANGELOG.md` and commit.
