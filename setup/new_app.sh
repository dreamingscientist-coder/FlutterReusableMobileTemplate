#!/usr/bin/env bash
# =====================================================================
# setup/new_app.sh — start a new app from this template.
# Run from the project root:   make setup
# It checks your tools, then runs setup/setup_project.py (the real work).
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."   # always work from the project root

echo "Checking tools..."
missing=0
for tool in flutter python3 git; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "  ✔ $tool"
  else
    echo "  ✘ $tool is not installed"; missing=1
  fi
done
if command -v fastlane >/dev/null 2>&1; then
  echo "  ✔ fastlane"
else
  echo "  ! fastlane not found — needed later for releases (brew install fastlane)"
fi
[ "$missing" -eq 0 ] || { echo "Install the missing tools, then run make setup again."; exit 1; }

PYTHONUTF8=1 PYTHONIOENCODING=UTF-8 python3 setup/setup_project.py "$@"
