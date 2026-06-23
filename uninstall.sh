#!/usr/bin/env bash
set -euo pipefail
rm -f "$HOME/.local/bin/adom-google" "$HOME/.local/bin/adom-gmail"
rm -f "$HOME/.claude/skills/adom-google"   # remove the skill symlink
echo "adom-google uninstalled (your ~/.config/adom-google token + provider are left intact)."
