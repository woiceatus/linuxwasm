#!/usr/bin/env bash
# Shared helper: make the Nix build daemon available.
#
# The Cloud Agent VM has no init system (PID 1 is tini), so the Determinate Nix
# installer is run with `--init none` and the daemon is supervised here instead.
# This script is idempotent: it installs Nix if it is missing and starts the
# daemon whenever it is not actually responding (a restored snapshot can leave a
# stale socket file behind with no daemon listening on it).
set -euo pipefail

NIX_PROFILE=/nix/var/nix/profiles/default
NIX_DAEMON_SOCKET=/nix/var/nix/daemon-socket/socket

if [ ! -e "$NIX_PROFILE/bin/nix" ]; then
  echo "[nixd] installing Determinate Nix (--init none)"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install linux --init none --no-confirm
fi

# Put the client tools on PATH and point them at the daemon (NIX_REMOTE=daemon).
# shellcheck disable=SC1091
. "$NIX_PROFILE/etc/profile.d/nix-daemon.sh"

daemon_alive() {
  # Probe the daemon instead of trusting that the socket file exists: a snapshot
  # restore can carry over the socket path while the daemon process is gone.
  timeout 10 nix store ping >/dev/null 2>&1
}

if ! daemon_alive; then
  echo "[nixd] starting nix-daemon"
  sudo rm -f "$NIX_DAEMON_SOCKET"
  # setsid so the daemon outlives this script (and the `start` phase wrapper).
  sudo setsid "$NIX_PROFILE/bin/nix-daemon" >/tmp/nix-daemon.log 2>&1 </dev/null &
  for _ in $(seq 1 100); do
    daemon_alive && break
    sleep 0.3
  done
fi

if ! daemon_alive; then
  echo "[nixd] error: nix-daemon is not responding" >&2
  cat /tmp/nix-daemon.log >&2 || true
  exit 1
fi
