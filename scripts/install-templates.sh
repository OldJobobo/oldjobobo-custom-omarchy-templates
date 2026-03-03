#!/usr/bin/env bash
set -euo pipefail

if ! command -v gum >/dev/null 2>&1; then
  echo "Error: 'gum' is required but not installed or not in PATH."
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
source_dir="$repo_root"
target_dir="$HOME/.config/omarchy/themed"

shopt -s nullglob
template_paths=("$source_dir"/*.tpl)
shopt -u nullglob

if [[ ${#template_paths[@]} -eq 0 ]]; then
  gum style --foreground 214 "No template files (*.tpl) found in: $source_dir"
  exit 1
fi

template_list=""
for path in "${template_paths[@]}"; do
  template_list+=" - $(basename -- "$path")"$'\n'
done

gum style \
  --border rounded \
  --padding "1 2" \
  --margin "1 0" \
  "This installer will symlink template files from this repository into your Omarchy user template overrides directory.

Source directory:
$source_dir

Destination directory:
$target_dir

Templates to link:
$template_list"

if ! gum confirm "Proceed with linking templates to ~/.config/omarchy/themed/?"; then
  gum style --foreground 244 "Cancelled. No changes were made."
  exit 0
fi

mkdir -p "$target_dir"

linked=0
skipped=0
failed=0

for src in "${template_paths[@]}"; do
  name="$(basename -- "$src")"
  dest="$target_dir/$name"

  action="replace"
  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" && "$(readlink -- "$dest")" == "$src" ]]; then
      gum style --foreground 244 "Already linked: $name"
      skipped=$((skipped + 1))
      continue
    fi

    choice="$(
      gum choose "Replace" "Skip" "Abort"
    )"
    case "$choice" in
      Replace) action="replace" ;;
      Skip) action="skip" ;;
      Abort)
        gum style --foreground 214 "Aborted by user."
        exit 1
        ;;
      *)
        gum style --foreground 196 "Unexpected choice: $choice"
        exit 1
        ;;
    esac
  fi

  if [[ "$action" == "skip" ]]; then
    gum style --foreground 244 "Skipped: $name"
    skipped=$((skipped + 1))
    continue
  fi

  if ln -sfn -- "$src" "$dest"; then
    gum style --foreground 42 "Linked: $name -> $dest"
    linked=$((linked + 1))
  else
    gum style --foreground 196 "Failed: $name"
    failed=$((failed + 1))
  fi
done

gum style \
  --border rounded \
  --padding "1 2" \
  --margin "1 0" \
  "Install summary
Linked:  $linked
Skipped: $skipped
Failed:  $failed"

if [[ $failed -gt 0 ]]; then
  exit 1
fi

