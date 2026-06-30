#!/usr/bin/env bash
# adom-google installer — the open-source Google Workspace CLI + its skills. Runs via
# `adom-wiki pkg install adom/adom-google`. Ships with NO OAuth provider.
#
# Skillpack layout: the MAIN skill is the repo-root SKILL.md (adom-google); sub-skills live
# under skills/<name>/SKILL.md (adom-google-onboarding). We install by COPYING real files
# (NO symlinks): binaries → ~/.local/bin, each skill → ~/.claude/skills/<name>/SKILL.md.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

BIN_DIR="$HOME/.local/bin"
SKILLS_DIR="$HOME/.claude/skills"
mkdir -p "$BIN_DIR" "$SKILLS_DIR"

install_bin() {            # copy bin/<name> → ~/.local/bin/<name> (clears any old file OR symlink)
  local name="$1"
  rm -rf "$BIN_DIR/$name"
  install -m 0755 "bin/$name" "$BIN_DIR/$name"
  echo "   bin   → $BIN_DIR/$name"
}

install_skill() {          # install_skill <install-name> <source SKILL.md path>
  local name="$1" src="$2"
  [ -f "$src" ] || { echo "[adom-google] WARN: $src missing" >&2; return; }
  rm -rf "$SKILLS_DIR/$name"            # clear any prior dir OR symlink from an old install
  mkdir -p "$SKILLS_DIR/$name"
  cp "$src" "$SKILLS_DIR/$name/SKILL.md"
  echo "   skill → $SKILLS_DIR/$name/SKILL.md"
}

echo "[adom-google] installing (copies, not symlinks)…"
install_bin   adom-google
install_bin   adom-gmail                                            # deprecation shim → adom-google
install_skill adom-google             SKILL.md                      # MAIN skill (repo root)
install_skill adom-google-onboarding  skills/adom-google-onboarding/SKILL.md   # sub-skill

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "[adom-google] NOTE: $HOME/.local/bin is not on PATH — add it to your shell rc." ;;
esac

echo "✅ adom-google installed (main skill + onboarding sub-skill). It ships with NO OAuth provider — set one up:"
echo "   • new org (self-serve): adom-google onboard   (the AI drives your browser through Google setup)"
echo "   • self-host (manual):   adom-google provider set --gateway https://your-gateway --client-id <id>"
echo "   • Adom staff:           adom-wiki pkg install adom/adom-google-adom   (drops the Adom provider)"
echo "   Then: 'adom-google setup' (asks safe vs full) and 'adom-google auth'."
