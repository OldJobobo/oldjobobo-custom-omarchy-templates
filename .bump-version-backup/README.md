# Omarchy Templates
Current version: `0.1.5`

User-facing Omarchy template overrides and ready-to-copy examples.

## Why this exists

Omarchy themes store colors in `colors.toml`, but many GTK-based layer-shell clients style from GTKCSS.
This repo bridges that gap by rendering theme values into GTKCSS so those clients can stay synced with the active theme.

Current implementation target:

- Waybar, via the provided `waybar.css.tpl` template.

## What you get

- `colors.css.tpl`: Theme color template Omarchy renders into `colors.css`.
- `waybar.css.tpl`: Waybar-ready example for GTK layer-shell color usage.
- `examples/tilebar-v1`: Tilebar example (`config.jsonc` + `style.css`).

## What to expect after install

This repo installs template files, not final CSS files.

After `./scripts/install.sh`, you should see:

- `~/.config/omarchy/themed/colors.css.tpl`
- `~/.config/omarchy/themed/waybar.css.tpl`

You will **not** see `colors.css` in `~/.config/omarchy/themed/`.
`colors.css` is generated only after a theme is applied/switched.

## Render flow (important)

1. Install templates (`*.tpl`) into `~/.config/omarchy/themed/`.
2. Run `omarchy-theme-set <theme>` (or your normal theme switch flow).
3. Omarchy renders final CSS outputs to:
   - `~/.config/omarchy/current/theme/colors.css`
   - `~/.config/omarchy/current/theme/waybar.css`

## Install

### Install (recommended)

Links all template sources (`*.tpl`) from this repo into `~/.config/omarchy/themed/`.

```bash
./scripts/install.sh
```

![Installer preview](preview-install.png)

- Requires `gum` in `PATH`.
- Prompts on conflicts: `Replace`, `Skip`, or `Abort`.

### Install (manual)

Copy or link template files (`*.tpl`) from this repo into:

- `~/.config/omarchy/themed/`

Then apply/switch a theme. Omarchy renders final CSS outputs to:

- Output file: `~/.config/omarchy/current/theme/colors.css`
- Output file: `~/.config/omarchy/current/theme/waybar.css`

## Verify installation and render

```bash
ls -la ~/.config/omarchy/themed/*.tpl
ls -la ~/.config/omarchy/current/theme/colors.css ~/.config/omarchy/current/theme/waybar.css
rg '{{' ~/.config/omarchy/current/theme/colors.css ~/.config/omarchy/current/theme/waybar.css
```

If `rg '{{' ...` prints nothing, placeholders were resolved successfully.

## Troubleshooting

### I installed, but `colors.css` is missing

This is expected until a theme is applied.
Run `omarchy-theme-set <theme>` and check `~/.config/omarchy/current/theme/colors.css`.

## Uninstall

### Uninstall (recommended)

Removes managed template links from `~/.config/omarchy/themed/`.

```bash
./scripts/uninstall.sh
```

- Requires `gum` in `PATH`.
- Safe by default: only removes links managed by this repo.

### Uninstall options

- `--dry-run`: show what would be removed.
- `--yes`: skip confirmations.
- `--all`: also remove matching entries not linked to this repo (dangerous).

## Typical usage

1. Edit your Waybar `style.css` to use colors defined in `colors.css`.
2. Apply a theme (`omarchy-theme-set <theme>` or your normal theme workflow).
3. Waybar picks up the active theme colors through the generated `colors.css`.
