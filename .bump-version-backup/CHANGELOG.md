# Changelog

All notable changes to this project are documented here.

## [Unreleased]

## [0.1.5] - 2026-03-03

## [0.1.4] - 2026-03-03

## [0.1.3] - 2026-03-03
- Added `scripts/uninstall.sh` for safe removal of repo-managed template links.
- Added uninstall flags: `--yes`, `--all`, and `--dry-run`.
- Added automated tests covering uninstall behavior and safety cases.
- Updated README/DEVELOPMENT/AGENTS docs for uninstall workflow.

## [0.1.1] - 2026-03-03
- Refocused `README.md` for end users.
- Added installer documentation for `scripts/install.sh` (recommended and manual install paths).
- Added installer screenshot (`preview-install.png`) to README.
- Clarified Waybar usage flow around consuming generated theme colors.
- Added `DEVELOPMENT.md` for maintainer/developer workflows.
- Added `examples/tilebar-v1` reference example files.
- Added `scripts/install.sh` interactive installer for linking `*.tpl` files into Omarchy overrides.

## [0.1.0] - 2026-02-26
- Initial project setup.
- Added `colors.css.tpl` for Omarchy theme color variable generation.
- Added README and simple SemVer versioning files/scripts.
- Added `waybar.css.tpl` override that imports `colors.css`.
