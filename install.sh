#!/usr/bin/env bash
# Install INSTRUCTIONS.md as the global instructions file of coding agents.
set -euo pipefail

VERSION="0.1.1" # x-release-please-version

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/INSTRUCTIONS.md"
ALL_TARGETS="claude opencode vibe codex"

usage() {
  cat <<'EOF'
Usage: install.sh [command] <target...> [options]

Commands:
  install     copy INSTRUCTIONS.md to each target (default)
  uninstall   remove the installed file from each target
  status      show the state of each target

Targets:
  claude      ~/.claude/CLAUDE.md
  opencode    $XDG_CONFIG_HOME/opencode/AGENTS.md (default ~/.config)
  vibe        ~/.vibe/AGENTS.md
  codex       ~/.codex/AGENTS.md
  all         all of the above

Options:
  --force     overwrite / remove differing files without backup
  --backup    move differing files to <file>.bak.<YYYYmmddHHMMSS> first
  --dry-run   print actions, change nothing
  --version   print version
  -h, --help  print this help
EOF
}

usage_error() {
  printf 'error: %s\n\n' "$1" >&2
  usage >&2
  exit 2
}

# Single place to map a target name to its global instructions path.
target_path() {
  case "$1" in
    claude) printf '%s\n' "$HOME/.claude/CLAUDE.md" ;;
    opencode) printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/AGENTS.md" ;;
    vibe) printf '%s\n' "$HOME/.vibe/AGENTS.md" ;;
    codex) printf '%s\n' "$HOME/.codex/AGENTS.md" ;;
    *) return 1 ;;
  esac
}

# Print a path with $HOME shortened to ~.
pretty() {
  case "$1" in
    "$HOME"/*) printf '%s\n' "~${1#"$HOME"}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# missing | same | differs | invalid (exists but is not a file)
state_of() {
  if [ ! -e "$1" ] && [ ! -L "$1" ]; then
    echo missing
  elif [ ! -f "$1" ]; then
    echo invalid
  elif cmp -s "$SOURCE" "$1"; then
    echo same
  else
    echo differs
  fi
}

# Version from the YAML frontmatter of a file, empty if none.
version_of() {
  awk 'NR == 1 { if ($0 != "---") exit; next } /^---$/ { exit } /^version:/ { print $2; exit }' "$1"
}

# Free backup path for a file; never reuses an existing one.
backup_path() {
  local bak="$1.bak.$TIMESTAMP" i=1
  while [ -e "$bak" ] || [ -L "$bak" ]; do
    bak="$1.bak.$TIMESTAMP.$i"
    i=$((i + 1))
  done
  printf '%s\n' "$bak"
}

# Run a command unless --dry-run is set.
run() {
  if [ "$DRY_RUN" -eq 0 ]; then
    "$@"
  fi
}

report() {
  local suffix=""
  if [ "$DRY_RUN" -eq 1 ]; then
    suffix=" (dry-run)"
  fi
  printf '[%s] %s%s\n' "$1" "$2" "$suffix"
}

# Move a differing file aside (--backup) or delete it (--force).
clear_differing() {
  local name="$1" path="$2" bak
  if [ "$MODE" = backup ]; then
    bak="$(backup_path "$path")"
    run mv "$path" "$bak"
    report "$name" "backed up → $(pretty "$bak")"
  else
    run rm -f "$path"
  fi
}

do_install() {
  local name="$1" path="$2"
  case "$(state_of "$path")" in
    same)
      report "$name" "up to date → $(pretty "$path")"
      ;;
    missing)
      run mkdir -p "$(dirname "$path")"
      run cp "$SOURCE" "$path"
      report "$name" "installed → $(pretty "$path")"
      ;;
    differs)
      clear_differing "$name" "$path"
      run cp "$SOURCE" "$path"
      report "$name" "installed → $(pretty "$path")"
      ;;
  esac
}

do_uninstall() {
  local name="$1" path="$2"
  case "$(state_of "$path")" in
    missing)
      report "$name" "not installed → $(pretty "$path")"
      ;;
    same)
      run rm -f "$path"
      report "$name" "removed → $(pretty "$path")"
      ;;
    differs)
      clear_differing "$name" "$path"
      report "$name" "removed → $(pretty "$path")"
      ;;
  esac
}

do_status() {
  local name="$1" path="$2" state version label
  state="$(state_of "$path")"
  case "$state" in
    missing) label="missing" ;;
    same) label="up to date" ;;
    differs) label="differs" ;;
    invalid) label="not a regular file" ;;
  esac
  if [ "$state" = same ] || [ "$state" = differs ]; then
    version="$(version_of "$path")"
    if [ -n "$version" ]; then
      label="$label ($version)"
    fi
  fi
  printf '[%s] %s → %s\n' "$name" "$label" "$(pretty "$path")"
}

# Fail before writing anything if a target can't be handled as requested.
preflight() {
  local name path state blocked=0
  for name in $TARGETS; do
    path="$(target_path "$name")"
    state="$(state_of "$path")"
    if [ "$state" = invalid ]; then
      printf '[%s] error: not a regular file → %s\n' "$name" "$(pretty "$path")" >&2
      blocked=1
    elif [ "$state" = differs ] && [ -z "$MODE" ]; then
      printf '[%s] conflict: differs from INSTRUCTIONS.md → %s\n' "$name" "$(pretty "$path")" >&2
      blocked=1
    fi
  done
  if [ "$blocked" -eq 1 ]; then
    printf 'nothing changed; resolve the above or rerun with --backup or --force\n' >&2
    exit 1
  fi
}

add_target() {
  case " $TARGETS " in
    *" $1 "*) ;;
    *) TARGETS="${TARGETS:+$TARGETS }$1" ;;
  esac
}

COMMAND=""
TARGETS=""
MODE=""
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    -h | --help)
      usage
      exit 0
      ;;
    --version)
      printf '%s\n' "$VERSION"
      exit 0
      ;;
    --force | --backup)
      if [ -n "$MODE" ] && [ "$MODE" != "${arg#--}" ]; then
        usage_error "--force and --backup are mutually exclusive"
      fi
      MODE="${arg#--}"
      ;;
    --dry-run) DRY_RUN=1 ;;
    -*) usage_error "unknown option: $arg" ;;
    install | uninstall | status)
      if [ -n "$COMMAND" ] || [ -n "$TARGETS" ]; then
        usage_error "command must come first and only once: $arg"
      fi
      COMMAND="$arg"
      ;;
    all)
      for name in $ALL_TARGETS; do
        add_target "$name"
      done
      ;;
    *)
      if ! target_path "$arg" >/dev/null; then
        usage_error "unknown target: $arg"
      fi
      add_target "$arg"
      ;;
  esac
done

COMMAND="${COMMAND:-install}"
if [ -z "$TARGETS" ]; then
  usage_error "no target given"
fi
if [ ! -f "$SOURCE" ]; then
  printf 'error: source not found: %s\n' "$SOURCE" >&2
  exit 1
fi

TIMESTAMP="$(date +%Y%m%d%H%M%S)"

if [ "$COMMAND" != status ]; then
  preflight
fi

for name in $TARGETS; do
  "do_$COMMAND" "$name" "$(target_path "$name")"
done
