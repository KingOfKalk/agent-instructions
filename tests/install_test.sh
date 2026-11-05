#!/usr/bin/env bash
# Smoke test for install.sh. Runs against a throwaway HOME; never touches the real one.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL="$ROOT/install.sh"
SOURCE="$ROOT/INSTRUCTIONS.md"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

FAILURES=0
OUT=""
CODE=0

# Fresh, empty HOME and XDG_CONFIG_HOME for each case.
reset_home() {
  rm -rf "${SANDBOX:?}/home" "${SANDBOX:?}/xdg"
  mkdir -p "$SANDBOX/home"
  export HOME="$SANDBOX/home"
  export XDG_CONFIG_HOME="$SANDBOX/xdg"
}

claude_file() { printf '%s\n' "$HOME/.claude/CLAUDE.md"; }
opencode_file() { printf '%s\n' "$XDG_CONFIG_HOME/opencode/AGENTS.md"; }
vibe_file() { printf '%s\n' "$HOME/.vibe/AGENTS.md"; }
codex_file() { printf '%s\n' "$HOME/.codex/AGENTS.md"; }
all_files() { claude_file; opencode_file; vibe_file; codex_file; }

# Run install.sh with the current bash, capturing output and exit code.
run_install() {
  set +e
  OUT="$("$BASH" "$INSTALL" "$@" 2>&1)"
  CODE=$?
  set -e
}

pass() { printf 'ok   %s\n' "$1"; }
fail() {
  printf 'FAIL %s\n' "$1"
  if [ -n "$OUT" ]; then
    printf '%s\n' "$OUT" | sed 's/^/     | /'
  fi
  FAILURES=$((FAILURES + 1))
}

check() {
  local desc="$1"
  shift
  if "$@"; then pass "$desc"; else fail "$desc"; fi
}

exit_is() { [ "$CODE" -eq "$1" ]; }
out_has() { printf '%s\n' "$OUT" | grep -qF -- "$1"; }
is_installed() { [ -f "$1" ] && [ ! -L "$1" ] && cmp -s "$SOURCE" "$1"; }
all_installed() {
  local f
  for f in $(all_files); do is_installed "$f" || return 1; done
}
none_exist() {
  local f
  for f in "$@"; do if [ -e "$f" ] || [ -L "$f" ]; then return 1; fi; done
}
backups_of() { find "$(dirname "$1")" -name "$(basename "$1").bak.*" | wc -l | tr -d ' '; }

echo "== install all"
reset_home
run_install all
check "exits 0" exit_is 0
check "all targets match INSTRUCTIONS.md" all_installed

echo "== re-run install all"
run_install install all
check "exits 0" exit_is 0
check "reports up to date" out_has "up to date"

echo "== conflict blocks every write (preflight)"
reset_home
run_install install claude
echo "local edit" >"$(claude_file)"
run_install install all
check "exits 1" exit_is 1
check "names the conflicting target" out_has "[claude] conflict"
check "modified file untouched" grep -qx "local edit" "$(claude_file)"
# shellcheck disable=SC2046
check "no other target written" none_exist $(opencode_file) $(vibe_file) $(codex_file)

echo "== --backup"
run_install install all --backup
check "exits 0" exit_is 0
check "target updated" is_installed "$(claude_file)"
check "one backup created" [ "$(backups_of "$(claude_file)")" = 1 ]
check "backup holds old content" grep -qx "local edit" "$(dirname "$(claude_file)")"/CLAUDE.md.bak.*

echo "== --force"
echo "local edit" >"$(codex_file)"
run_install install codex --force
check "exits 0" exit_is 0
check "target updated" is_installed "$(codex_file)"
check "no backup created" [ "$(backups_of "$(codex_file)")" = 0 ]

echo "== --force replaces a symlink instead of writing through it"
echo "linked" >"$SANDBOX/linked.md"
rm "$(vibe_file)"
ln -s "$SANDBOX/linked.md" "$(vibe_file)"
run_install install vibe --force
check "exits 0" exit_is 0
check "target is a regular file" is_installed "$(vibe_file)"
check "link target untouched" grep -qx "linked" "$SANDBOX/linked.md"

echo "== --dry-run"
reset_home
run_install install all --dry-run
check "exits 0" exit_is 0
check "marks output as dry-run" out_has "(dry-run)"
# shellcheck disable=SC2046
check "creates nothing" none_exist $(all_files)
check "HOME stays empty" [ -z "$(ls -A "$HOME")" ]

echo "== status"
reset_home
run_install install claude opencode
echo "local edit" >"$(opencode_file)"
run_install status all
check "exits 0" exit_is 0
check "reports up to date with version" out_has "[claude] up to date (v$("$BASH" "$INSTALL" --version))"
check "reports differs" out_has "[opencode] differs"
check "reports missing" out_has "[vibe] missing"

echo "== uninstall"
reset_home
run_install install all
echo "local edit" >"$(claude_file)"
run_install uninstall all
check "differing file blocks uninstall" exit_is 1
check "nothing removed" is_installed "$(codex_file)"
run_install uninstall opencode vibe codex
check "exits 0" exit_is 0
# shellcheck disable=SC2046
check "files removed" none_exist $(opencode_file) $(vibe_file) $(codex_file)
run_install uninstall claude --backup
check "--backup exits 0" exit_is 0
check "--backup removes file" none_exist "$(claude_file)"
check "--backup keeps a copy" [ "$(backups_of "$(claude_file)")" = 1 ]
run_install uninstall all
check "missing targets exit 0" exit_is 0

echo "== usage errors"
run_install
check "no args exits 2" exit_is 2
run_install install
check "no target exits 2" exit_is 2
run_install install nope
check "bad target exits 2" exit_is 2
run_install all --nope
check "bad option exits 2" exit_is 2
run_install all --force --backup
check "--force with --backup exits 2" exit_is 2
run_install all install
check "command after target exits 2" exit_is 2

echo "== XDG_CONFIG_HOME unset"
reset_home
unset XDG_CONFIG_HOME
run_install install opencode
check "exits 0" exit_is 0
check "falls back to ~/.config" is_installed "$HOME/.config/opencode/AGENTS.md"

echo "== version"
run_install --version
check "matches INSTRUCTIONS.md frontmatter" [ "v$OUT" = "$(awk '/^version:/ { print $2; exit }' "$SOURCE")" ]

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "$FAILURES check(s) failed"
  exit 1
fi
echo "all checks passed"
