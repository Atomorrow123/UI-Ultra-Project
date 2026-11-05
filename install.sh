#!/usr/bin/env bash
# Install the UI Ultra skill into one or more AI coding agents.
#
#   ./install.sh                         # auto-detect installed agents, user scope
#   ./install.sh antigravity cursor      # specific agents
#   ./install.sh --project all           # into the current project
#   ./install.sh --dest ~/my/skills      # custom skills directory
#   ./install.sh --uninstall             # remove from detected agents
#
# Agents: antigravity gemini cursor codex agents all
set -eo pipefail

NAME="ui-ultra"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$ROOT/skills/$NAME"
SCOPE="user"; DEST=""; UNINSTALL=0; AGENTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) SCOPE="project" ;;
    --user) SCOPE="user" ;;
    --dest) DEST="$2"; shift ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) AGENTS+=("$1") ;;
  esac
  shift
done

[[ -f "$SKILL/SKILL.md" ]] || { echo "SKILL.md not found under $SKILL" >&2; exit 1; }

user_dir() { case "$1" in
  antigravity) echo "$HOME/.gemini/config/plugins" ;; gemini) echo "$HOME/.gemini/skills" ;;
  cursor) echo "$HOME/.cursor/skills" ;;              codex) echo "$HOME/.codex/skills" ;;
  agents) echo "$HOME/.agents/skills" ;;
esac; }
project_dir() { case "$1" in
  gemini) echo "$PWD/.gemini/skills" ;;
  cursor) echo "$PWD/.cursor/skills" ;;  codex) echo "$PWD/.codex/skills" ;;
  antigravity|agents) echo "$PWD/.agents/skills" ;;
esac; }
detect_dir() { case "$1" in
  antigravity) echo "$HOME/.gemini/antigravity" ;; gemini) echo "$HOME/.gemini" ;;
  cursor) echo "$HOME/.cursor" ;;                  codex) echo "$HOME/.codex" ;;
  agents) echo "$HOME/.agents" ;;
esac; }

ALL=(antigravity gemini cursor codex agents)

install_to() { # dir label as_plugin
  local target="$1/$NAME"
  if [[ $UNINSTALL -eq 1 ]]; then
    if [[ -d "$target" ]]; then rm -rf "$target"; echo "  - removed   $2 -> $target"; else echo "  · skipped   $2 (not installed)"; fi
    return
  fi
  rm -rf "$target"; mkdir -p "$target"
  if [[ "$3" == "1" ]]; then
    cp "$ROOT/plugin.json" "$target/"; cp "$ROOT/README.md" "$target/" 2>/dev/null || true
    mkdir -p "$target/assets" "$target/skills"; cp "$ROOT/assets/"*.svg "$target/assets/"; cp -R "$SKILL" "$target/skills/"
  else
    cp -R "$SKILL/." "$target/"
  fi
  echo "  + installed $2 -> $target"
}

echo; echo "UI Ultra $([[ $UNINSTALL -eq 1 ]] && echo uninstaller || echo installer)"

if [[ -n "$DEST" ]]; then install_to "$DEST" custom 0; exit 0; fi

SELECTED=()
if [[ ${#AGENTS[@]} -eq 0 || " ${AGENTS[*]} " == *" auto "* ]]; then
  for a in "${ALL[@]}"; do if [[ -d "$(detect_dir "$a")" ]]; then SELECTED+=("$a"); fi; done
  if [[ " ${SELECTED[*]:-} " == *" antigravity "* && ! -f "$HOME/.gemini/settings.json" ]]; then
    TMP=(); for a in "${SELECTED[@]}"; do if [[ "$a" != gemini ]]; then TMP+=("$a"); fi; done; SELECTED=("${TMP[@]}")
  fi
  if [[ ${#SELECTED[@]} -eq 0 ]]; then SELECTED=(agents); fi
elif [[ " ${AGENTS[*]} " == *" all "* ]]; then SELECTED=("${ALL[@]}")
else SELECTED=("${AGENTS[@]}"); fi

DONE=""
for a in "${SELECTED[@]}"; do
  if [[ "$SCOPE" == "user" ]]; then dir="$(user_dir "$a")"; else dir="$(project_dir "$a")"; fi
  if [[ -z "$dir" ]]; then echo "  ! unknown agent: $a" >&2; continue; fi
  if [[ "$DONE" == *"|$dir|"* ]]; then continue; fi; DONE="$DONE|$dir|"
  plugin=0; if [[ "$a" == antigravity && "$SCOPE" == user ]]; then plugin=1; fi
  install_to "$dir" "$a" "$plugin"
done

echo; if [[ $UNINSTALL -eq 0 ]]; then echo "Done. Restart your agent so it discovers the new skill."; fi
