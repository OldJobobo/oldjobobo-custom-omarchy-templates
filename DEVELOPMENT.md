# Development Guide

Maintainer-focused notes for this repository.

## Project files

- `colors.css.tpl`: Main template source rendered by Omarchy.
- `waybar.css.tpl`: Waybar template.
- `scripts/bump-version.sh`: SemVer helper for `VERSION`.
- `VERSION`: Single source of truth for project version.
- `CHANGELOG.md`: Human-readable release history.

## Validation commands

This repo has no build step. Use:

```bash
bash -n scripts/bump-version.sh
rg '{{|}}' colors.css.tpl
```

Manual integration check:

```bash
omarchy-theme-set <theme>
rg '{{' "$HOME/.config/omarchy/current/theme/colors.css"
```

## Versioning

SemVer is stored in `VERSION`.

- Patch: fixes/small corrections (`0.1.0` -> `0.1.1`)
- Minor: backward-compatible additions (`0.1.0` -> `0.2.0`)
- Major: breaking changes (`0.1.0` -> `1.0.0`)

Bump commands:

```bash
./scripts/bump-version.sh patch
./scripts/bump-version.sh minor
./scripts/bump-version.sh major
```

When behavior changes, update `CHANGELOG.md` in the same commit.

## Commit style

- Preferred commit format: `type(scope): summary`
- Example: `feat(template): add active tab colors`
