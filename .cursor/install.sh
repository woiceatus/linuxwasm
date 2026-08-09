#!/usr/bin/env bash
# Cloud Agent install: build the WebAssembly Linux kernel package and set up the
# @tombl/linux host-library dev workflow. Idempotent and safe to re-run.
set -euo pipefail

REPO="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO"

# 1. Ensure the Nix toolchain + build daemon are ready (see .cursor/nixd.sh).
# shellcheck disable=SC1091
. "$REPO/.cursor/nixd.sh"

# 2. Build the wasm kernel npm package. This is exactly what CI runs and
#    produces vmlinux.wasm plus the compiled TypeScript dist. Results are cached
#    in the Nix store, so re-runs after the first build are fast.
nix build . --print-build-logs

# 3. Place the freshly built kernel binary where the dev tooling and browser
#    demo expect it (tools/wasm/vmlinux.wasm, loaded by dist as ../vmlinux.wasm).
tmp="$(mktemp -d)"
tar xzf "$(readlink -f result)" -C "$tmp" package/vmlinux.wasm
install -m 0644 "$tmp/package/vmlinux.wasm" tools/wasm/vmlinux.wasm
rm -rf "$tmp"

# 4. Install the host-library dev dependencies (pinned typescript + @types/node)
#    and build the TypeScript dist from source so `make check` and the demo run.
NVM_BIN="$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -1 || true)"
[ -n "$NVM_BIN" ] && export PATH="$NVM_BIN:$PATH"

cd tools/wasm
pnpm install --frozen-lockfile
./node_modules/.bin/tsc

echo "[install] done: kernel built, vmlinux.wasm placed, dist compiled"
