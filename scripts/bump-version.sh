#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/bump-version.sh
  ./scripts/bump-version.sh [--yes] [--dry-run] [major|minor|patch]
  ./scripts/bump-version.sh [--yes] [--dry-run] [--interactive] set [major.minor.patch]
  ./scripts/bump-version.sh [--yes] [--dry-run] undo

Options:
  (no action)     Start full interactive mode.
  --yes          Skip confirmation prompts.
  --dry-run      Show planned changes without modifying files.
  --interactive  Prompt for missing 'set' version value.
  --help         Show this help.
USAGE
  exit 1
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
version_file="$repo_root/VERSION"
changelog_file="$repo_root/CHANGELOG.md"
readme_file="$repo_root/README.md"
backup_dir="$repo_root/.bump-version-backup"
[[ -f "$version_file" ]] || { echo "VERSION file not found: $version_file"; exit 1; }

HAS_GUM=0
if command -v gum >/dev/null 2>&1; then
  HAS_GUM=1
fi

HAS_TPUT=0
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
  HAS_TPUT=1
fi

AUTO_YES=0
DRY_RUN=0
INTERACTIVE=0

color_wrap() {
  local color="$1"
  local msg="$2"
  if [[ $HAS_TPUT -eq 1 ]]; then
    printf '%s%s%s\n' "$(tput setaf "$color")" "$msg" "$(tput sgr0)"
  else
    printf '%s\n' "$msg"
  fi
}

title_wrap() {
  local msg="$1"
  if [[ $HAS_TPUT -eq 1 ]]; then
    printf '%s%s%s%s\n' "$(tput bold)" "$(tput setaf 4)" "$msg" "$(tput sgr0)"
  else
    printf '%s\n' "$msg"
  fi
}

panel_separator() {
  if [[ $HAS_TPUT -eq 1 ]]; then
    printf '%s%s%s\n' "$(tput setaf 4)" "------------------------------------------------------------" "$(tput sgr0)"
  else
    printf '%s\n' "------------------------------------------------------------"
  fi
}

panel_print_line() {
  local line="$1"
  if [[ $HAS_TPUT -ne 1 ]]; then
    printf '%s\n' "$line"
    return 0
  fi

  if [[ -z "$line" ]]; then
    printf '\n'
    return 0
  fi

  if [[ "$line" == " - "* ]]; then
    printf '%s - %s%s\n' "$(tput setaf 6)" "${line# - }" "$(tput sgr0)"
    return 0
  fi

  if [[ "$line" == *":"* ]]; then
    local key="${line%%:*}"
    local rest="${line#*:}"
    printf '%s%s:%s%s\n' "$(tput bold)$(tput setaf 5)" "$key" "$(tput sgr0)" "$rest"
    return 0
  fi

  printf '%s%s%s\n' "$(tput setaf 7)" "$line" "$(tput sgr0)"
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

ui_info() {
  local msg="$1"
  if [[ $HAS_GUM -eq 1 ]]; then
    gum style "$msg"
  else
    color_wrap 6 "$msg"
  fi
}

ui_warn() {
  local msg="$1"
  if [[ $HAS_GUM -eq 1 ]]; then
    gum style "Warning: $msg"
  else
    color_wrap 3 "Warning: $msg"
  fi
}

ui_error() {
  local msg="$1"
  if [[ $HAS_GUM -eq 1 ]]; then
    gum style "Error: $msg"
  else
    if [[ $HAS_TPUT -eq 1 ]]; then
      printf '%sError: %s%s\n' "$(tput setaf 1)" "$msg" "$(tput sgr0)" >&2
    else
      echo "Error: $msg" >&2
    fi
  fi
}

ui_success() {
  local msg="$1"
  if [[ $HAS_GUM -eq 1 ]]; then
    gum style "$msg"
  else
    color_wrap 2 "$msg"
  fi
}

render_panel() {
  local title="$1"
  local body="$2"
  local panel

  if [[ $HAS_GUM -eq 1 ]]; then
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
      --padding "1 2" \
      --margin "1 0" \
      "$panel"
  elif [[ $HAS_TPUT -eq 1 ]]; then
    title_wrap "$title"
    panel_separator
    while IFS= read -r line; do
      panel_print_line "$line"
    done <<< "$body"
    panel_separator
  else
    printf '%s\n\n%s\n' "$title" "$body"
  fi
}

confirm_action() {
  local prompt="$1"

  if [[ $AUTO_YES -eq 1 || $DRY_RUN -eq 1 ]]; then
    return 0
  fi

  if [[ $HAS_GUM -eq 1 ]]; then
    gum confirm "$prompt"
    return $?
  fi

  if [[ -t 0 ]]; then
    local answer
    read -r -p "$prompt [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]]
    return $?
  fi

  # Non-interactive fallback: do not block automation when gum is unavailable.
  return 0
}

validate_semver() {
  local version="$1"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

prompt_for_version() {
  local input=""

  if [[ $HAS_GUM -eq 1 ]]; then
    while true; do
      input="$(gum input --placeholder "0.1.3" --prompt "Target version: ")"
      if validate_semver "$input"; then
        printf '%s\n' "$input"
        return 0
      fi
      ui_error "Invalid version format: $input (expected major.minor.patch)"
    done
  fi

  if [[ -t 0 ]]; then
    while true; do
      read -r -p "Target version (major.minor.patch): " input
      if validate_semver "$input"; then
        printf '%s\n' "$input"
        return 0
      fi
      ui_error "Invalid version format: $input (expected major.minor.patch)"
    done
  fi

  ui_error "Missing version value for 'set' and interactive input unavailable."
  exit 1
}

prompt_for_action() {
  local choice=""

  if [[ $HAS_GUM -eq 1 ]]; then
    choice="$(gum choose "Patch" "Minor" "Major" "Set specific version" "Undo last backup" "Cancel")"
    case "$choice" in
      "Patch") echo "patch" ;;
      "Minor") echo "minor" ;;
      "Major") echo "major" ;;
      "Set specific version") echo "set" ;;
      "Undo last backup") echo "undo" ;;
      "Cancel") echo "cancel" ;;
      *)
        ui_error "Unexpected action selection: $choice"
        exit 1
        ;;
    esac
    return 0
  fi

  if [[ -t 0 ]]; then
    echo "Select action:"
    echo "  1) patch"
    echo "  2) minor"
    echo "  3) major"
    echo "  4) set specific version"
    echo "  5) undo last backup"
    echo "  6) cancel"
    read -r -p "Choice [1-6]: " choice
    case "$choice" in
      1) echo "patch" ;;
      2) echo "minor" ;;
      3) echo "major" ;;
      4) echo "set" ;;
      5) echo "undo" ;;
      6) echo "cancel" ;;
      *)
        ui_error "Invalid selection: $choice"
        exit 1
        ;;
    esac
    return 0
  fi

  ui_error "No action provided and interactive selection is unavailable."
  exit 1
}

render_preflight() {
  local action="$1"
  local current_version="$2"
  local next_version="${3:-}"
  local mode_text="apply"
  local details

  if [[ $DRY_RUN -eq 1 ]]; then
    mode_text="dry-run"
  fi

  printf -v details 'Action: %s\nMode: %s\nCurrent version: %s' "$action" "$mode_text" "$current_version"
  if [[ -n "$next_version" ]]; then
    printf -v details '%s\nTarget version: %s' "$details" "$next_version"
  fi

  if [[ "$action" == "undo" ]]; then
    printf -v details '%s\n\nFiles affected:\n - VERSION\n - CHANGELOG.md (if backup exists)\n - README.md (if backup exists)\n - *.tpl metadata headers (if backup exists)\nBackup source: %s' "$details" "$backup_dir"
  else
    printf -v details '%s\n\nFiles affected:\n - VERSION\n - *.tpl metadata headers\n - README.md Current version line (if present)\n - CHANGELOG.md\nBackup destination: %s' "$details" "$backup_dir"
  fi

  render_panel "Preflight" "$details"
}

make_backup() {
  if [[ $DRY_RUN -eq 1 ]]; then
    ui_info "Dry run: would create backup snapshot at $backup_dir"
    return 0
  fi

  rm -rf -- "$backup_dir"
  mkdir -p "$backup_dir/templates"
  cp -f -- "$version_file" "$backup_dir/VERSION"
  [[ -f "$changelog_file" ]] && cp -f -- "$changelog_file" "$backup_dir/CHANGELOG.md"
  [[ -f "$readme_file" ]] && cp -f -- "$readme_file" "$backup_dir/README.md"

  shopt -s nullglob
  local template
  for template in "$repo_root"/*.tpl; do
    cp -f -- "$template" "$backup_dir/templates/$(basename -- "$template")"
  done
  shopt -u nullglob
}

restore_backup() {
  [[ -d "$backup_dir" ]] || { ui_error "No backup found at $backup_dir"; exit 1; }
  [[ -f "$backup_dir/VERSION" ]] || { ui_error "Backup is incomplete: missing VERSION"; exit 1; }

  if [[ $DRY_RUN -eq 1 ]]; then
    ui_info "Dry run: would restore files from backup: $backup_dir"
    return 0
  fi

  cp -f -- "$backup_dir/VERSION" "$version_file"
  [[ -f "$backup_dir/CHANGELOG.md" ]] && cp -f -- "$backup_dir/CHANGELOG.md" "$changelog_file"
  [[ -f "$backup_dir/README.md" ]] && cp -f -- "$backup_dir/README.md" "$readme_file"

  shopt -s nullglob
  local template_backup
  for template_backup in "$backup_dir"/templates/*.tpl; do
    cp -f -- "$template_backup" "$repo_root/$(basename -- "$template_backup")"
  done
  shopt -u nullglob
}

report_undo_debrief() {
  local before_version="$1"
  local after_version="$2"
  local template_count=0

  shopt -s nullglob
  local templates=("$repo_root"/*.tpl)
  shopt -u nullglob
  template_count="${#templates[@]}"

  local report
  printf -v report 'Undo debrief\nVersion before undo: %s\nVersion after undo:  %s\nRestored from: %s\nFiles restored:\n - VERSION' \
    "$before_version" "$after_version" "$backup_dir"

  if [[ -f "$changelog_file" ]]; then
    printf -v report '%s\n - CHANGELOG.md' "$report"
  fi
  if [[ -f "$readme_file" ]]; then
    printf -v report '%s\n - README.md' "$report"
  fi
  printf -v report '%s\n - %s template file(s) (*.tpl)' "$report" "$template_count"

  render_panel "Undo Summary" "$report"
}

update_templates() {
  local new_version="$1"
  shopt -s nullglob
  local template_files=("$repo_root"/*.tpl)
  shopt -u nullglob

  local template
  for template in "${template_files[@]}"; do
    if grep -qE '^[[:space:]]*\*[[:space:]]Version:' "$template"; then
      if [[ $DRY_RUN -eq 1 ]]; then
        ui_info "Would update template metadata version: $(basename -- "$template") -> $new_version"
      else
        sed -i -E "s/^([[:space:]]*\\*[[:space:]]Version:[[:space:]]*).*/\\1$new_version/" "$template"
        ui_success "Updated template metadata version: $(basename -- "$template") -> $new_version"
      fi
    fi
  done
}

update_readme_version() {
  local new_version="$1"
  [[ -f "$readme_file" ]] || return 0

  if grep -qE '^Current version: `[^`]+`$' "$readme_file"; then
    if [[ $DRY_RUN -eq 1 ]]; then
      ui_info "Would update README.md version: $new_version"
    else
      sed -i -E "s/^Current version: \`[^\`]+\`$/Current version: \`$new_version\`/" "$readme_file"
      ui_success "Updated README.md version: $new_version"
    fi
  else
    ui_warn "README.md has no 'Current version:' line; skipped README update."
  fi
}

insert_changelog_release() {
  local new_version="$1"
  local today="$2"

  if ! grep -q '^## \[Unreleased\]$' "$changelog_file"; then
    ui_warn "CHANGELOG.md has no [Unreleased] section; skipped changelog update."
    return 0
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    ui_info "Would update CHANGELOG.md: released $new_version on $today"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"
  awk -v new_version="$new_version" -v today="$today" '
    BEGIN { inserted=0 }
    /^## \[Unreleased\]$/ && inserted==0 {
      print "## [Unreleased]"
      print ""
      print "## [" new_version "] - " today
      inserted=1
      next
    }
    { print }
  ' "$changelog_file" > "$tmp"
  mv "$tmp" "$changelog_file"
  ui_success "Updated CHANGELOG.md: released $new_version on $today"
}

update_changelog_version() {
  local old_version="$1"
  local new_version="$2"
  local mode="$3"
  [[ -f "$changelog_file" ]] || return 0

  local today
  today="$(date +%F)"

  if [[ "$mode" == "set" ]]; then
    if grep -q "^## \\[$new_version\\] - " "$changelog_file"; then
      ui_info "CHANGELOG.md already contains version heading: $new_version"
      return 0
    fi

    if grep -q "^## \\[$old_version\\] - " "$changelog_file"; then
      if [[ $DRY_RUN -eq 1 ]]; then
        ui_info "Would update CHANGELOG.md heading: $old_version -> $new_version"
      else
        sed -i "0,/^## \\[$old_version\\] - /s//## [$new_version] - /" "$changelog_file"
        ui_success "Updated CHANGELOG.md heading: $old_version -> $new_version"
      fi
      return 0
    fi
  fi

  insert_changelog_release "$new_version" "$today"
}

apply_version() {
  local action="$1"
  local current_version="$2"
  local new_version="$3"
  local mode="$4"
  local summary

  if [[ $DRY_RUN -eq 1 ]]; then
    ui_info "Would update VERSION: $current_version -> $new_version"
  else
    printf '%s\n' "$new_version" > "$version_file"
  fi

  update_templates "$new_version"
  update_readme_version "$new_version"
  update_changelog_version "$current_version" "$new_version" "$mode"

  if [[ $DRY_RUN -eq 1 ]]; then
    ui_info "Dry run complete: no files modified."
    printf -v summary 'Action: %s\nMode: dry-run\nCurrent version: %s\nTarget version: %s' \
      "$action" "$current_version" "$new_version"
    render_panel "Dry-Run Summary" "$summary"
  else
    ui_success "Bumped VERSION: $current_version -> $new_version"
    ui_info "Review CHANGELOG.md before commit."
    printf -v summary 'Action: %s\nMode: apply\nVersion changed: %s -> %s\nBackup snapshot: %s' \
      "$action" "$current_version" "$new_version" "$backup_dir"
    render_panel "Update Summary" "$summary"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      AUTO_YES=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --interactive)
      INTERACTIVE=1
      ;;
    --help)
      usage
      ;;
    --*)
      ui_error "Unknown option: $1"
      usage
      ;;
    *)
      break
      ;;
  esac
  shift
done

if [[ $# -eq 0 ]]; then
  INTERACTIVE=1
  action="$(prompt_for_action)"
  if [[ "$action" == "cancel" ]]; then
    ui_warn "Cancelled. No changes were made."
    exit 2
  fi
else
  action="$1"
  shift
fi

if [[ "$action" == "undo" ]]; then
  [[ $# -eq 0 ]] || usage
  current="$(tr -d '[:space:]' < "$version_file")"
  render_preflight "undo" "$current"
  if ! confirm_action "Restore files from backup?"; then
    ui_warn "Cancelled. No changes were made."
    exit 2
  fi
  restore_backup
  if [[ $DRY_RUN -eq 0 ]]; then
    restored_version="$(tr -d '[:space:]' < "$version_file")"
    report_undo_debrief "$current" "$restored_version"
    ui_success "Restored files from backup: $backup_dir"
  fi
  exit 0
fi

current="$(tr -d '[:space:]' < "$version_file")"
validate_semver "$current" || { ui_error "Invalid current VERSION: $current"; exit 1; }
IFS='.' read -r major minor patch <<< "$current"

next=""
mode="bump"
case "$action" in
  major)
    [[ $# -eq 0 ]] || usage
    major=$((major + 1))
    minor=0
    patch=0
    next="${major}.${minor}.${patch}"
    ;;
  minor)
    [[ $# -eq 0 ]] || usage
    minor=$((minor + 1))
    patch=0
    next="${major}.${minor}.${patch}"
    ;;
  patch)
    [[ $# -eq 0 ]] || usage
    patch=$((patch + 1))
    next="${major}.${minor}.${patch}"
    ;;
  set)
    mode="set"
    if [[ $# -eq 1 ]]; then
      validate_semver "$1" || { ui_error "Invalid version format: $1 (expected major.minor.patch)"; exit 1; }
      next="$1"
    elif [[ $# -eq 0 ]]; then
      if [[ $INTERACTIVE -eq 1 || $HAS_GUM -eq 1 ]]; then
        next="$(prompt_for_version)"
      else
        ui_error "Missing version value for 'set'. Use: ./scripts/bump-version.sh set <major.minor.patch>"
        exit 1
      fi
    else
      usage
    fi
    ;;
  *)
    usage
    ;;
esac

if [[ "$next" == "$current" ]]; then
  ui_info "Version unchanged: $current"
  exit 0
fi

render_preflight "$action" "$current" "$next"
if ! confirm_action "Apply version change?"; then
  ui_warn "Cancelled. No changes were made."
  exit 2
fi

make_backup
apply_version "$action" "$current" "$next" "$mode"
