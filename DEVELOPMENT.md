# Development Guide

Maintainer-focused notes for this repository.

## Project files

- `colors.css.tpl`: Main template source rendered by Omarchy.
- `waybar.css.tpl`: Waybar template.
- `scripts/install.sh`: Interactive installer that links all repo `*.tpl` files into `~/.config/omarchy/themed/`.
- `scripts/uninstall.sh`: Interactive uninstaller for removing repo-managed template links from `~/.config/omarchy/themed/`.
- `scripts/bump-version.sh`: SemVer helper for `VERSION`.
- `VERSION`: Single source of truth for project version.
- `CHANGELOG.md`: Human-readable release history.
- `examples/tilebar-v1`: Reference Waybar/Tilebar example files.

## Validation commands

This repo has no build or compile phase. It is templates + scripts, so validation is dry-run checks:

```bash
bash -n scripts/install.sh
bash -n scripts/uninstall.sh
bash -n scripts/bump-version.sh
rg '{{|}}' colors.css.tpl waybar.css.tpl
```

Then run a manual integration check:

```bash
./scripts/install.sh
omarchy-theme-set <theme>
ls -la "$HOME/.config/omarchy/themed/"*.tpl
if rg '{{' "$HOME/.config/omarchy/current/theme/colors.css" "$HOME/.config/omarchy/current/theme/waybar.css"; then
  echo "Unresolved placeholders found"
  exit 1
else
  echo "No unresolved placeholders"
fi
```

Uninstall dry-run check:

```bash
./scripts/uninstall.sh --dry-run
```

## Versioning

SemVer is stored in `VERSION`.

- Patch: fixes/small corrections (`0.1.0` -> `0.1.1`)
- Minor: backward-compatible additions (`0.1.0` -> `0.2.0`)
- Major: breaking changes (`0.1.0` -> `1.0.0`)

Bump commands:

```bash
./scripts/bump-version.sh
./scripts/bump-version.sh patch
./scripts/bump-version.sh minor
./scripts/bump-version.sh major
./scripts/bump-version.sh set 0.1.3
./scripts/bump-version.sh --interactive set
./scripts/bump-version.sh undo
./scripts/bump-version.sh --dry-run patch
./scripts/bump-version.sh --yes patch
```

- Running with no action starts full interactive mode.
- `set <version>` forces a specific SemVer value (`major.minor.patch`) and syncs template/README metadata.
- `--interactive set` prompts for a missing version value.
- `undo` restores files from the last bump script backup snapshot (`.bump-version-backup`).
- `--dry-run` shows planned changes without modifying files.
- `--yes` skips confirmations for automation.
- If `gum` is installed, confirmations and summaries use `gum` UI; otherwise plain CLI output is used.

When behavior changes, update `CHANGELOG.md` in the same commit.

## Commit style

- Preferred commit format: `type(scope): summary`
- Example: `feat(template): add active tab colors`
