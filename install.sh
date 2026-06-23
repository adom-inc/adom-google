#!/usr/bin/env bash
# adom-google installer — the open-source Google Workspace CLI. Runs in the container via
# `adompkg install`. Ships with NO OAuth provider: the binary + skill are symlinked onto PATH
# via the adompkg sh-helpers (lint-sanctioned convention). Configure a provider after install
# (`adom-google provider set ...`) — or, Adom staff, install the private `adom-google-adom`.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

if ! command -v adompkg >/dev/null 2>&1; then
  echo "[adom-google] FATAL: adompkg not on PATH — install via 'adompkg install adom-google'." >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$(adompkg sh-helpers)"

chmod +x bin/adom-google bin/adom-gmail
adompkg-link-bin adom-google          # ~/.local/bin/adom-google -> $PWD/bin/adom-google
adompkg-link-bin adom-gmail           # deprecation shim -> adom-google
adompkg-link-skill adom-google             # ~/.claude/skills/adom-google -> $PWD/skills/adom-google
adompkg-link-skill adom-google-onboarding  # the guided org-onboarding skill (drives the browser)

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) echo "[adom-google] NOTE: $HOME/.local/bin is not on PATH — add it to your shell rc." ;;
esac
echo "✅ adom-google installed. It ships with NO OAuth provider — set one up:"
echo "   • new org (self-serve): adom-google onboard   (the AI drives your browser through Google setup)"
echo "   • self-host (manual):   adom-google provider set --gateway https://your-gateway --client-id <id>"
echo "   • Adom staff:           adompkg install adom-google-adom   (drops the Adom provider)"
echo "   Then: 'adom-google setup' (asks safe vs full) and 'adom-google auth'."
