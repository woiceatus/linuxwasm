#!/usr/bin/env bash
# Shared helper: make the Nix build daemon available.
#
# The Cloud Agent VM has no init system (PID 1 is tini), so the Determinate Nix
# installer is run with `--init none` and the daemon is supervised here instead.
# This script is idempotent: it installs Nix if it is missing and starts the
# daemon if its socket is not already listening.
set -euo pipefail

NIX_PROFILE=/nix/var/nix/profiles/default
NIX_DAEMON_SOCKET=/nix/var/nix/daemon-socket/socket

if [ ! -e "$NIX_PROFILE/bin/nix" ]; then
  echo "[nixd] installing Determinate Nix (--init none)"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install linux --init none --no-confirm
fi

if [ ! -S "$NIX_DAEMON_SOCKET" ]; then
  echo "[nixd] starting nix-daemon"
  sudo "$NIX_PROFILE/bin/nix-daemon" >/tmp/nix-daemon.log 2>&1 &
  for _ in $(seq 1 100); do
    [ -S "$NIX_DAEMON_SOCKET" ] && break
    sleep 0.2
  done
fi

if [ ! -S "$NIX_DAEMON_SOCKET" ]; then
  echo "[nixd] error: nix-daemon socket never appeared" >&2
  exit 1
fi

# shellcheck disable=SC1091
. "$NIX_PROFILE/etc/profile.d/nix-daemon.sh"
