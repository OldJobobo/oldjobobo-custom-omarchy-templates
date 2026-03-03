#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

PASS_COUNT=0
FAIL_COUNT=0

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "Assertion failed: $msg" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="$3"
  if ! grep -Fq -- "$needle" <<< "$haystack"; then
    echo "Assertion failed: $msg" >&2
    echo "  missing: $needle" >&2
    return 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="$3"
  if grep -Fq -- "$needle" <<< "$haystack"; then
    echo "Assertion failed: $msg" >&2
    echo "  unexpected: $needle" >&2
    return 1
  fi
}

next_patch_version() {
  local current="$1"
  local major minor patch
  IFS='.' read -r major minor patch <<< "$current"
  patch=$((patch + 1))
  echo "${major}.${minor}.${patch}"
}

make_fixture_repo() {
  local fixture="$1"
  mkdir -p "$fixture/repo" "$fixture/home" "$fixture/bin"
  cp -a "$ROOT_DIR/scripts" "$fixture/repo/"
  cp -a "$ROOT_DIR/VERSION" "$ROOT_DIR/CHANGELOG.md" "$ROOT_DIR/README.md" "$ROOT_DIR/colors.css.tpl" "$ROOT_DIR/waybar.css.tpl" "$fixture/repo/"

  cat > "$fixture/bin/gum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
shift || true
case "$cmd" in
  style)
    printf '%s\n' "$@"
    ;;
  confirm)
    if [[ "${GUM_CONFIRM:-yes}" == "no" ]]; then
      exit 1
    fi
    ;;
  input)
    printf '%s\n' "${GUM_INPUT:-0.1.3}"
    ;;
  choose)
    printf '%s\n' "${GUM_CHOOSE:-Replace}"
    ;;
  *)
    echo "mock gum: unsupported command: $cmd" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$fixture/bin/gum"
}

run_test() {
  local name="$1"
  shift
  if "$@"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "PASS: $name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "FAIL: $name"
  fi
}

test_bump_patch_updates_template_metadata() {
  local fixture
  fixture="$(mktemp -d)"
  trap 'if [[ -n "${fixture:-}" ]]; then rm -rf "$fixture"; fi' RETURN

  make_fixture_repo "$fixture"
  local repo="$fixture/repo"

  local before after expected
  before="$(tr -d '[:space:]' < "$repo/VERSION")"
  expected="$(next_patch_version "$before")"

  local out
  out="$(
    cd "$repo" &&
    ./scripts/bump-version.sh --yes patch
  )"

  after="$(tr -d '[:space:]' < "$repo/VERSION")"
  assert_eq "$expected" "$after" "VERSION should bump patch" || return 1
  assert_contains "$out" "Updated template metadata version: colors.css.tpl -> $expected" "colors template version should update" || return 1
  assert_contains "$out" "Updated template metadata version: waybar.css.tpl -> $expected" "waybar template version should update" || return 1
  assert_contains "$out" "Updated README.md version: $expected" "README version should update" || return 1
  assert_contains "$out" "Updated CHANGELOG.md: released $expected on " "changelog release section should be updated" || return 1
  grep -Fq "* Version: $expected" "$repo/colors.css.tpl" || return 1
  grep -Fq "* Version: $expected" "$repo/waybar.css.tpl" || return 1
  grep -Fq "Current version: \`$expected\`" "$repo/README.md" || return 1
  grep -Fq "## [$expected] - " "$repo/CHANGELOG.md" || return 1
  awk '
    BEGIN { found=0; ok=0 }
    /^## \[Unreleased\]$/ { found=1; next }
    found==1 && /^$/ { next }
    found==1 && /^## \[/ { ok=1; exit }
    END { if (ok!=1) exit 1 }
  ' "$repo/CHANGELOG.md" || return 1
}

test_bump_invalid_input_does_not_change_files() {
  local fixture
  fixture="$(mktemp -d)"
  trap 'if [[ -n "${fixture:-}" ]]; then rm -rf "$fixture"; fi' RETURN

  make_fixture_repo "$fixture"
  local repo="$fixture/repo"
  local version_before changelog_before readme_before colors_before waybar_before
  version_before="$(cat "$repo/VERSION")"
  changelog_before="$(cat "$repo/CHANGELOG.md")"
  readme_before="$(cat "$repo/README.md")"
  colors_before="$(cat "$repo/colors.css.tpl")"
  waybar_before="$(cat "$repo/waybar.css.tpl")"

  if (cd "$repo" && ./scripts/bump-version.sh --yes nope >/dev/null 2>&1); then
    echo "Expected invalid bump type to fail" >&2
    return 1
  fi

  assert_eq "$version_before" "$(cat "$repo/VERSION")" "VERSION should remain unchanged on invalid input" || return 1
  assert_eq "$changelog_before" "$(cat "$repo/CHANGELOG.md")" "CHANGELOG.md should remain unchanged on invalid input" || return 1
  assert_eq "$readme_before" "$(cat "$repo/README.md")" "README.md should remain unchanged on invalid input" || return 1
  assert_eq "$colors_before" "$(cat "$repo/colors.css.tpl")" "colors.css.tpl should remain unchanged on invalid input" || return 1
  assert_eq "$waybar_before" "$(cat "$repo/waybar.css.tpl")" "waybar.css.tpl should remain unchanged on invalid input" || return 1
}

test_bump_set_specific_version() {
  local fixture
  fixture="$(mktemp -d)"
  trap 'if [[ -n "${fixture:-}" ]]; then rm -rf "$fixture"; fi' RETURN

  make_fixture_repo "$fixture"
  local repo="$fixture/repo"
  local target="0.1.9"

  local out
  out="$(
    cd "$repo" &&
    ./scripts/bump-version.sh --yes set "$target"
  )"

  assert_contains "$out" "Bumped VERSION:" "set should report version change" || return 1
  assert_contains "$out" "Updated README.md version: $target" "set should update README version" || return 1
  grep -Fxq "$target" "$repo/VERSION" || return 1
  grep -Fq "* Version: $target" "$repo/colors.css.tpl" || return 1
  grep -Fq "* Version: $target" "$repo/waybar.css.tpl" || return 1
  grep -Fq "Current version: \`$target\`" "$repo/README.md" || return 1
  grep -Eq "^## \\[$target\\] - " "$repo/CHANGELOG.md" || return 1
}

test_bump_undo_restores_previous_state() {
  local fixture
  fixture="$(mktemp -d)"
  trap 'if [[ -n "${fixture:-}" ]]; then rm -rf "$fixture"; fi' RETURN

  make_fixture_repo "$fixture"
  local repo="$fixture/repo"

  local version_before changelog_before readme_before colors_before waybar_before
  version_before="$(cat "$repo/VERSION")"
  changelog_before="$(cat "$repo/CHANGELOG.md")"
  readme_before="$(cat "$repo/README.md")"
  colors_before="$(cat "$repo/colors.css.tpl")"
  waybar_before="$(cat "$repo/waybar.css.tpl")"

  (
    cd "$repo" &&
    ./scripts/bump-version.sh --yes patch >/dev/null
  )
  (
    cd "$repo" &&
    ./scripts/bump-version.sh --yes undo >/dev/null
  )

  assert_eq "$version_before" "$(cat "$repo/VERSION")" "undo should restore VERSION" || return 1
  assert_eq "$changelog_before" "$(cat "$repo/CHANGELOG.md")" "undo should restore CHANGELOG.md" || return 1
  assert_eq "$readme_before" "$(cat "$repo/README.md")" "undo should restore README.md" || return 1
  assert_eq "$colors_before" "$(cat "$repo/colors.css.tpl")" "undo should restore colors.css.tpl" || return 1
  assert_eq "$waybar_before" "$(cat "$repo/waybar.css.tpl")" "undo should restore waybar.css.tpl" || return 1
}

test_bump_dry_run_does_not_change_files() {
  local fixture
  fixture="$(mktemp -d)"
  trap 'if [[ -n "${fixture:-}" ]]; then rm -rf "$fixture"; fi' RETURN

  make_fixture_repo "$fixture"
  local repo="$fixture/repo"
  local version_before changelog_before readme_before colors_before waybar_before
  version_before="$(cat "$repo/VERSION")"
  changelog_before="$(cat "$repo/CHANGELOG.md")"
  readme_before="$(cat "$repo/README.md")"
  colors_before="$(cat "$repo/colors.css.tpl")"
  waybar_before="$(cat "$repo/waybar.css.tpl")"

  local out
  out="$(
    cd "$repo" &&
    ./scripts/bump-version.sh --dry-run patch
  )"

  assert_contains "$out" "Dry run complete: no files modified." "dry-run should report no modifications" || return 1
  assert_eq "$version_before" "$(cat "$repo/VERSION")" "dry-run should not change VERSION" || return 1
  assert_eq "$changelog_before" "$(cat "$repo/CHANGELOG.md")" "dry-run should not change CHANGELOG.md" || return 1
  assert_eq "$readme_before" "$(cat "$repo/README.md")" "dry-run should not change README.md" || return 1
  assert_eq "$colors_before" "$(cat "$repo/colors.css.tpl")" "dry-run should not change colors.css.tpl" || return 1
  assert_eq "$waybar_before" "$(cat "$repo/waybar.css.tpl")" "dry-run should not change waybar.css.tpl" || return 1
}

test_bump_gum_confirm_cancel_stops_changes() {
  local fixture
  fixture="$(mktemp -d)"
  trap 'if [[ -n "${fixture:-}" ]]; then rm -rf "$fixture"; fi' RETURN

  make_fixture_repo "$fixture"
  local repo="$fixture/repo"
  local version_before
  version_before="$(cat "$repo/VERSION")"

  local out status
  set +e
  out="$(
    cd "$repo" &&
    PATH="$fixture/bin:$PATH" GUM_CONFIRM=no ./scripts/bump-version.sh patch 2>&1
  )"
  status=$?
  set -e

  assert_eq "2" "$status" "cancelled confirmation should exit 2" || return 1
  assert_contains "$out" "Cancelled. No changes were made." "cancelled confirmation should show message" || return 1
  assert_eq "$version_before" "$(cat "$repo/VERSION")" "cancelled confirmation should not change VERSION" || return 1
}

test_bump_no_args_defaults_to_interactive() {
  local fixture
  fixture="$(mktemp -d)"
  trap 'if [[ -n "${fixture:-}" ]]; then rm -rf "$fixture"; fi' RETURN

  make_fixture_repo "$fixture"
  local repo="$fixture/repo"
  local before expected after
  before="$(tr -d '[:space:]' < "$repo/VERSION")"
  expected="$(next_patch_version "$before")"

  local out
  out="$(
    cd "$repo" &&
    PATH="$fixture/bin:$PATH" GUM_CHOOSE=Patch ./scripts/bump-version.sh
  )"

  after="$(tr -d '[:space:]' < "$repo/VERSION")"
  assert_eq "$expected" "$after" "no-args interactive flow should apply selected bump action" || return 1
  assert_contains "$out" "Action: patch" "interactive preflight should show selected action" || return 1
  assert_not_contains "$out" "\\nMode:" "interactive preflight should render real newlines, not escaped literals" || return 1
}

test_installer_treats_relative_symlink_as_already_linked() {
  local fixture
  fixture="$(mktemp -d)"
  trap 'if [[ -n "${fixture:-}" ]]; then rm -rf "$fixture"; fi' RETURN

  make_fixture_repo "$fixture"
  local repo="$fixture/repo"
  local home="$fixture/home"
  local themed="$home/.config/omarchy/themed"
  mkdir -p "$themed"

  local src="$repo/colors.css.tpl"
  local rel
  rel="$(realpath --relative-to="$themed" "$src")"
  ln -s -- "$rel" "$themed/colors.css.tpl"

  local out
  out="$(
    cd "$repo" &&
    HOME="$home" PATH="$fixture/bin:$PATH" ./scripts/install.sh
  )"

  assert_contains "$out" "Already linked: colors.css.tpl" "relative symlink should be recognized as already linked" || return 1
  assert_not_contains "$out" "Conflict for: colors.css.tpl" "relative symlink should not trigger conflict prompt" || return 1
}

test_installer_conflict_output_includes_context() {
  local fixture
  fixture="$(mktemp -d)"
  trap 'if [[ -n "${fixture:-}" ]]; then rm -rf "$fixture"; fi' RETURN

  make_fixture_repo "$fixture"
  local repo="$fixture/repo"
  local home="$fixture/home"
  local themed="$home/.config/omarchy/themed"
  mkdir -p "$themed"
  printf 'existing\n' > "$themed/colors.css.tpl"

  local out
  out="$(
    cd "$repo" &&
    HOME="$home" PATH="$fixture/bin:$PATH" GUM_CHOOSE=Skip ./scripts/install.sh
  )"

  assert_contains "$out" "Conflict for: colors.css.tpl" "conflict output should include file name" || return 1
  assert_contains "$out" "Source: $repo/colors.css.tpl" "conflict output should include source path" || return 1
  assert_contains "$out" "Destination: $themed/colors.css.tpl" "conflict output should include destination path" || return 1
  assert_contains "$out" "Existing entry: regular file or directory" "conflict output should describe existing entry type" || return 1
}

test_uninstaller_removes_managed_symlink() {
  local fixture
  fixture="$(mktemp -d)"
  trap 'if [[ -n "${fixture:-}" ]]; then rm -rf "$fixture"; fi' RETURN

  make_fixture_repo "$fixture"
  local repo="$fixture/repo"
  local home="$fixture/home"
  local themed="$home/.config/omarchy/themed"
  mkdir -p "$themed"
  ln -s -- "$repo/colors.css.tpl" "$themed/colors.css.tpl"

  local out
  out="$(
    cd "$repo" &&
    HOME="$home" PATH="$fixture/bin:$PATH" ./scripts/uninstall.sh --yes
  )"

  assert_contains "$out" "Removed: colors.css.tpl (managed symlink)" "managed symlink should be removed" || return 1
  [[ ! -e "$themed/colors.css.tpl" && ! -L "$themed/colors.css.tpl" ]] || return 1
}

test_uninstaller_skips_non_managed_symlink_by_default() {
  local fixture
  fixture="$(mktemp -d)"
  trap 'if [[ -n "${fixture:-}" ]]; then rm -rf "$fixture"; fi' RETURN

  make_fixture_repo "$fixture"
  local repo="$fixture/repo"
  local home="$fixture/home"
  local themed="$home/.config/omarchy/themed"
  mkdir -p "$themed"
  printf 'external\n' > "$fixture/external.tpl"
  ln -s -- "$fixture/external.tpl" "$themed/colors.css.tpl"

  local out
  out="$(
    cd "$repo" &&
    HOME="$home" PATH="$fixture/bin:$PATH" ./scripts/uninstall.sh --yes
  )"

  assert_contains "$out" "Skipped: colors.css.tpl (non-managed symlink)" "non-managed symlink should be skipped by default" || return 1
  [[ -L "$themed/colors.css.tpl" ]] || return 1
}

test_uninstaller_all_and_dry_run_behavior() {
  local fixture
  fixture="$(mktemp -d)"
  trap 'if [[ -n "${fixture:-}" ]]; then rm -rf "$fixture"; fi' RETURN

  make_fixture_repo "$fixture"
  local repo="$fixture/repo"
  local home="$fixture/home"
  local themed="$home/.config/omarchy/themed"
  mkdir -p "$themed"
  printf 'custom\n' > "$themed/colors.css.tpl"

  local out_dry
  out_dry="$(
    cd "$repo" &&
    HOME="$home" PATH="$fixture/bin:$PATH" ./scripts/uninstall.sh --yes --all --dry-run
  )"
  assert_contains "$out_dry" "Would remove: colors.css.tpl (non-symlink (--all))" "dry-run should report planned non-symlink removal" || return 1
  [[ -f "$themed/colors.css.tpl" ]] || return 1

  local out_real
  out_real="$(
    cd "$repo" &&
    HOME="$home" PATH="$fixture/bin:$PATH" ./scripts/uninstall.sh --yes --all
  )"
  assert_contains "$out_real" "Removed: colors.css.tpl (non-symlink (--all))" "all mode should remove non-symlink when --yes is set" || return 1
  [[ ! -e "$themed/colors.css.tpl" && ! -L "$themed/colors.css.tpl" ]] || return 1
}

main() {
  run_test "bump patch updates metadata" test_bump_patch_updates_template_metadata
  run_test "bump invalid input does not change files" test_bump_invalid_input_does_not_change_files
  run_test "bump set updates to specific version" test_bump_set_specific_version
  run_test "bump undo restores previous state" test_bump_undo_restores_previous_state
  run_test "bump dry-run does not change files" test_bump_dry_run_does_not_change_files
  run_test "bump gum confirm cancel stops changes" test_bump_gum_confirm_cancel_stops_changes
  run_test "bump no args defaults to interactive mode" test_bump_no_args_defaults_to_interactive
  run_test "installer recognizes relative symlink as already linked" test_installer_treats_relative_symlink_as_already_linked
  run_test "installer conflict output includes context" test_installer_conflict_output_includes_context
  run_test "uninstaller removes managed symlink" test_uninstaller_removes_managed_symlink
  run_test "uninstaller skips non-managed symlink by default" test_uninstaller_skips_non_managed_symlink_by_default
  run_test "uninstaller all mode supports dry-run and remove" test_uninstaller_all_and_dry_run_behavior

  echo
  echo "Passed: $PASS_COUNT"
  echo "Failed: $FAIL_COUNT"

  if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
