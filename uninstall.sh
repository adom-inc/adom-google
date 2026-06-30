#!/usr/bin/env bash
set -euo pipefail
rm -f  "$HOME/.local/bin/adom-google" "$HOME/.local/bin/adom-gmail"
rm -rf "$HOME/.claude/skills/adom-google" "$HOME/.claude/skills/adom-google-onboarding"
echo "adom-google uninstalled (your ~/.config/adom-google token + provider are left intact)."
