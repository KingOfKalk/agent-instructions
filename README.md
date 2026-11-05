# agent-instructions

One set of global instructions, [INSTRUCTIONS.md](INSTRUCTIONS.md), shared by several coding agents. `install.sh` copies it to each agent's global instructions file.

## Targets

| Target     | Agent        | Installed to                                       |
| ---------- | ------------ | -------------------------------------------------- |
| `claude`   | Claude Code  | `~/.claude/CLAUDE.md`                              |
| `opencode` | opencode     | `${XDG_CONFIG_HOME:-~/.config}/opencode/AGENTS.md` |
| `vibe`     | Mistral Vibe | `~/.vibe/AGENTS.md`                                |
| `codex`    | Codex CLI    | `~/.codex/AGENTS.md`                               |

## Usage

Requires bash 3.2+ (macOS default works). Run from a clone:

```sh
git clone https://github.com/KingOfKalk/agent-instructions.git
cd agent-instructions

./install.sh all                  # install for every agent
./install.sh claude codex         # install for some agents
./install.sh status all           # missing / up to date / differs, plus installed version
./install.sh all --dry-run        # show what would happen
./install.sh uninstall all        # remove files identical to INSTRUCTIONS.md
```

- Files are copied, not symlinked.
- An existing file that differs from `INSTRUCTIONS.md` is never overwritten silently. If any target conflicts, nothing is written and the script exits 1. Rerun with:
  - `--backup` — move the existing file to `<file>.bak.<YYYYmmddHHMMSS>`, then install.
  - `--force` — overwrite without backup.
- The same rules apply to `uninstall`.
- `./install.sh --help` lists all commands and options.

## Updating

```sh
git pull
./install.sh all --force
```

Use `--backup` instead of `--force` if you have local edits you want to keep.

## Development

```sh
shellcheck install.sh tests/*.sh
bash tests/install_test.sh        # runs against a temporary HOME
```

CI runs both on every pull request (Ubuntu and macOS). See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow.
