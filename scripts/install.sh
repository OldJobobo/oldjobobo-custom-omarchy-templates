#!/usr/bin/env bash
set -euo pipefail

if ! command -v gum >/dev/null 2>&1; then
  echo "Error: 'gum' is required but not installed or not in PATH."
  exit 1
fi

HAS_TPUT=0
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
  HAS_TPUT=1
fi

colorize_text() {
  local color="$1"
  local text="$2"
  if [[ $HAS_TPUT -eq 1 ]]; then
    printf '%s%s%s' "$(tput setaf "$color")" "$text" "$(tput sgr0)"
  else
    printf '%s' "$text"
  fi
}

status_info() {
  gum style "$(colorize_text 6 "$1")"
}

status_warn() {
  gum style "$(colorize_text 3 "$1")"
}

status_error() {
  gum style "$(colorize_text 1 "$1")"
}

status_success() {
  gum style "$(colorize_text 2 "$1")"
}

panel_format_line() {
  local line="$1"
  if [[ $HAS_TPUT -ne 1 ]]; then
    printf '%s' "$line"
    return 0
  fi
  if [[ -z "$line" ]]; then
    printf '%s' ""
    return 0
  fi
  if [[ "$line" == " - "* ]]; then
    printf '%s - %s%s' "$(tput setaf 6)" "${line# - }" "$(tput sgr0)"
    return 0
  fi
  if [[ "$line" == *":"* ]]; then
    local key="${line%%:*}"
    local rest="${line#*:}"
    printf '%s%s:%s%s' "$(tput bold)$(tput setaf 5)" "$key" "$(tput sgr0)" "$rest"
    return 0
  fi
  printf '%s%s%s' "$(tput setaf 7)" "$line" "$(tput sgr0)"
}

render_panel() {
  local title="$1"
  local body="$2"
  local padding="$3"
  local margin="$4"
  local panel=""

  if [[ $HAS_TPUT -eq 1 ]]; then
    local colored_title
    local colored_body=""
    local line
    colored_title="$(printf '%s%s%s%s' "$(tput bold)" "$(tput setaf 4)" "$title" "$(tput sgr0)")"
    while IFS= read -r line; do
      colored_body+="$(panel_format_line "$line")"$'\n'
    done <<< "$body"
    colored_body="${colored_body%$'\n'}"
    printf -v panel '%s\n\n%s' "$colored_title" "$colored_body"
  else
    printf -v panel '%s\n\n%s' "$title" "$body"
  fi

  gum style \
    --border rounded \
    --padding "$padding" \
    --margin "$margin" \
    "$panel"
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
source_dir="$repo_root"
target_dir="$HOME/.config/omarchy/themed"

shopt -s nullglob
template_paths=("$source_dir"/*.tpl)
shopt -u nullglob

if [[ ${#template_paths[@]} -eq 0 ]]; then
  status_warn "No template files (*.tpl) found in: $source_dir"
  exit 1
fi

template_list=""
for path in "${template_paths[@]}"; do
  template_list+=" - $(basename -- "$path")"$'\n'
done

render_panel \
  "Install Preflight" \
  "This installer will symlink template files from this repository into your Omarchy user template overrides directory.

Source directory:
$source_dir

Destination directory:
$target_dir

Templates to link:
$template_list" \
  "1 2" \
  "1 0"

if ! gum confirm "Proceed with linking templates to ~/.config/omarchy/themed/?"; then
  status_info "Cancelled. No changes were made."
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
    if [[ -L "$dest" ]]; then
      resolved_src="$(readlink -f -- "$src")"
      if resolved_dest="$(readlink -f -- "$dest" 2>/dev/null)" && [[ "$resolved_dest" == "$resolved_src" ]]; then
        status_info "Already linked: $name"
        skipped=$((skipped + 1))
        continue
      fi
    fi

    if [[ -L "$dest" ]]; then
      existing_target="$(readlink -- "$dest")"
      existing_desc="Existing symlink target: $existing_target"
    else
      existing_desc="Existing entry: regular file or directory"
    fi

    render_panel \
      "Install Conflict" \
      "Conflict for: $name
Source: $src
Destination: $dest
$existing_desc" \
      "0 1" \
      "0 0"

    choice="$(
      gum choose "Replace" "Skip" "Abort"
    )"
    case "$choice" in
      Replace) action="replace" ;;
      Skip) action="skip" ;;
      Abort)
        status_warn "Aborted by user."
        exit 1
        ;;
      *)
        status_error "Unexpected choice: $choice"
        exit 1
        ;;
    esac
  fi

  if [[ "$action" == "skip" ]]; then
    status_info "Skipped: $name"
    skipped=$((skipped + 1))
    continue
  fi

  if ln -sfn -- "$src" "$dest"; then
    status_success "Linked: $name -> $dest"
    linked=$((linked + 1))
  else
    status_error "Failed: $name"
    failed=$((failed + 1))
  fi
done

render_panel \
  "Install Summary" \
  "Install summary
Linked:  $linked
Skipped: $skipped
Failed:  $failed" \
  "1 2" \
  "1 0"

if [[ $failed -gt 0 ]]; then
  exit 1
fi
