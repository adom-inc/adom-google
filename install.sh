#!/usr/bin/env bash
# adom-google installer — the open-source Google Workspace CLI. Runs in the container via
# `adom-wiki pkg install adom/adom-google`. Ships with NO OAuth provider.
#
# We install by COPYING real files (NO symlinks): the binaries land in ~/.local/bin and the
# skills land in ~/.claude/skills as real directories. Copies are self-contained — they keep
# working if the module dir moves or is pruned, and the agent reads a real file (no symlink
# chains, no dangling links). Re-run the installer (pkg update) to pick up a new version.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

BIN_DIR="$HOME/.local/bin"
SKILLS_DIR="$HOME/.claude/skills"
mkdir -p "$BIN_DIR" "$SKILLS_DIR"

install_bin() {            # install_bin <name>  → copy bin/<name> to ~/.local/bin/<name>
  local name="$1"
  rm -rf "$BIN_DIR/$name"               # clear any prior file OR symlink from an old install
  install -m 0755 "bin/$name" "$BIN_DIR/$name"
  echo "   bin   → $BIN_DIR/$name"
}

install_skill() {         # install_skill <slug> → copy skills/<slug>/ to ~/.claude/skills/<slug>/
  local slug="$1"
  [ -f "skills/$slug/SKILL.md" ] || { echo "[adom-google] WARN: skills/$slug/SKILL.md missing" >&2; return; }
  rm -rf "$SKILLS_DIR/$slug"            # clear any prior dir OR symlink from an old install
  mkdir -p "$SKILLS_DIR/$slug"
  cp -R "skills/$slug/." "$SKILLS_DIR/$slug/"
  echo "   skill → $SKILLS_DIR/$slug/"
}

echo "[adom-google] installing (copies, not symlinks)…"
install_bin   adom-google
install_bin   adom-gmail              # deprecation shim → forwards to adom-google
install_skill adom-google
install_skill adom-google-onboarding  # guided org-onboarding skill (drives the browser)

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "[adom-google] NOTE: $HOME/.local/bin is not on PATH — add it to your shell rc." ;;
esac

echo "✅ adom-google installed. It ships with NO OAuth provider — set one up:"
echo "   • new org (self-serve): adom-google onboard   (the AI drives your browser through Google setup)"
echo "   • self-host (manual):   adom-google provider set --gateway https://your-gateway --client-id <id>"
echo "   • Adom staff:           adom-wiki pkg install adom/adom-google-adom   (drops the Adom provider)"
echo "   Then: 'adom-google setup' (asks safe vs full) and 'adom-google auth'."
