#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ! -d "$ROOT/tt/.git" ]]; then
    git clone --depth 1 https://github.com/TinyTapeout/tt-support-tools.git "$ROOT/tt"
else
    echo "Tiny Tapeout support tools already present: $ROOT/tt"
fi
PATCH_FILE="$ROOT/patches/tt-support-tools-monorepo.patch"
if git -C "$ROOT/tt" apply --reverse --check "$PATCH_FILE" >/dev/null 2>&1; then
    echo "Monorepo support patch already applied."
elif git -C "$ROOT/tt" apply --check "$PATCH_FILE" >/dev/null 2>&1; then
    git -C "$ROOT/tt" apply "$PATCH_FILE"
    echo "Applied monorepo support patch."
else
    echo "Cannot apply $PATCH_FILE to the current tt-support-tools checkout." >&2
    echo "Check the pinned tt-support-tools commit before proceeding." >&2
    exit 2
fi
