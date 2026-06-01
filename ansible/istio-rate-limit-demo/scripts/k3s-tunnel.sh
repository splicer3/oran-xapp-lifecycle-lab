#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="${REMOTE_HOST:?set REMOTE_HOST to the SSH host that can reach the K3s API}"
REMOTE_USER="${REMOTE_USER:?set REMOTE_USER for SSH}"
REMOTE_API_HOST="${REMOTE_API_HOST:-127.0.0.1}"
REMOTE_API_PORT="${REMOTE_API_PORT:-6443}"
LOCAL_API_PORT="${LOCAL_API_PORT:-6443}"
SSH_KEY="${SSH_KEY:-}"

ssh_args=()
if [[ -n "$SSH_KEY" ]]; then
  ssh_args+=("-i" "$SSH_KEY")
fi

case "${1:-}" in
  connect)
    ssh "${ssh_args[@]}" -f -N -L "${LOCAL_API_PORT}:${REMOTE_API_HOST}:${REMOTE_API_PORT}" "${REMOTE_USER}@${REMOTE_HOST}"
    echo "Tunnel active on https://localhost:${LOCAL_API_PORT}"
    ;;
  disconnect)
    pkill -f "ssh.*${LOCAL_API_PORT}:${REMOTE_API_HOST}:${REMOTE_API_PORT}" || true
    ;;
  *)
    echo "Usage: REMOTE_HOST=<host> REMOTE_USER=<user> $0 {connect|disconnect}"
    exit 1
    ;;
esac
