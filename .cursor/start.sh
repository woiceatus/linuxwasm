#!/usr/bin/env bash
# Cloud Agent start: per-boot reconciliation. The VM has no init system, so the
# Nix build daemon must be (re)started on every boot before `nix build` works.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"

# shellcheck disable=SC1091
. "$REPO/.cursor/nixd.sh"

echo "[start] nix-daemon ready"
