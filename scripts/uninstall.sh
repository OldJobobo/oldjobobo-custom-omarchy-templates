#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/uninstall.sh [--yes] [--all] [--dry-run] [--help]

Remove template links from ~/.config/omarchy/themed.

Options:
  --yes      Skip confirmation prompts.
  --all      Also remove matching entries not linked to this repo (dangerous).
  --dry-run  Show what would be removed without changing files.
  --help     Show this help.
EOF
}

auto_yes=0
remove_all=0
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      auto_yes=1
      ;;
    --all)
      remove_all=1
      ;;
    --dry-run)
      dry_run=1
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

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

mode="managed-links-only"
if [[ $remove_all -eq 1 ]]; then
  mode="all-matching-entries"
fi

action_label="remove"
if [[ $dry_run -eq 1 ]]; then
  action_label="dry-run (no files will be removed)"
fi

render_panel \
  "Uninstall Preflight" \
  "This uninstaller will remove template entries from your Omarchy user template overrides directory.

Source directory:
$source_dir

Destination directory:
$target_dir

Mode:
$mode

Action:
$action_label

Templates considered:
$template_list" \
  "1 2" \
  "1 0"

if [[ $auto_yes -eq 0 ]]; then
  if ! gum confirm "Proceed with uninstall from ~/.config/omarchy/themed/?"; then
    status_info "Cancelled. No changes were made."
    exit 2
  fi
fi

removed=0
skipped=0
missing=0
failed=0

for src in "${template_paths[@]}"; do
  name="$(basename -- "$src")"
  dest="$target_dir/$name"

  if [[ ! -e "$dest" && ! -L "$dest" ]]; then
    status_info "Missing: $name"
    missing=$((missing + 1))
    continue
  fi

  remove_this=0
  reason=""

  if [[ -L "$dest" ]]; then
    resolved_src="$(readlink -f -- "$src")"
    if resolved_dest="$(readlink -f -- "$dest" 2>/dev/null)" && [[ "$resolved_dest" == "$resolved_src" ]]; then
      remove_this=1
      reason="managed symlink"
    elif [[ $remove_all -eq 1 ]]; then
      remove_this=1
      reason="non-managed symlink (--all)"
    else
      status_info "Skipped: $name (non-managed symlink)"
      skipped=$((skipped + 1))
      continue
    fi
  elif [[ $remove_all -eq 1 ]]; then
    if [[ $auto_yes -eq 0 ]]; then
      status_warn "Conflict: $name is not a symlink."
      choice="$(
        gum choose "Remove" "Skip" "Abort"
      )"
      case "$choice" in
        Remove) remove_this=1 ;;
        Skip)
          status_info "Skipped: $name (non-symlink)"
          skipped=$((skipped + 1))
          continue
          ;;
        Abort)
          status_warn "Aborted by user."
          exit 2
          ;;
        *)
          status_error "Unexpected choice: $choice"
          exit 1
          ;;
      esac
    else
      remove_this=1
    fi
    reason="non-symlink (--all)"
  else
    status_info "Skipped: $name (non-symlink)"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ $remove_this -ne 1 ]]; then
    status_info "Skipped: $name"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ $dry_run -eq 1 ]]; then
    status_warn "Would remove: $name ($reason)"
    removed=$((removed + 1))
    continue
  fi

  if rm -rf -- "$dest"; then
    status_success "Removed: $name ($reason)"
    removed=$((removed + 1))
  else
    status_error "Failed: $name"
    failed=$((failed + 1))
  fi
done

render_panel \
  "Uninstall Summary" \
  "Uninstall summary
Removed: $removed
Skipped: $skipped
Missing: $missing
Failed:  $failed" \
  "1 2" \
  "1 0"

if [[ $failed -gt 0 ]]; then
  exit 1
fi
