# Development Guide

Maintainer-focused notes for this repository.

## Project files

- `colors.css.tpl`: Main template source rendered by Omarchy.
- `waybar.css.tpl`: Waybar template.
- `scripts/install-templates.sh`: Interactive installer that links all repo `*.tpl` files into `~/.config/omarchy/themed/`.
- `scripts/bump-version.sh`: SemVer helper for `VERSION`.
- `VERSION`: Single source of truth for project version.
- `CHANGELOG.md`: Human-readable release history.
- `examples/tilebar-v1`: Reference Waybar/Tilebar example files.

## Validation commands

This repo has no build or compile phase. It is templates + scripts, so validation is dry-run checks:

```bash
bash -n scripts/install-templates.sh
bash -n scripts/bump-version.sh
rg '{{|}}' colors.css.tpl waybar.css.tpl
```

Then run a manual integration check:

```bash
./scripts/install-templates.sh
omarchy-theme-set <theme>
ls -la "$HOME/.config/omarchy/themed/"*.tpl
if rg '{{' "$HOME/.config/omarchy/current/theme/colors.css" "$HOME/.config/omarchy/current/theme/waybar.css"; then
  echo "Unresolved placeholders found"
  exit 1
else
  echo "No unresolved placeholders"
fi
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
