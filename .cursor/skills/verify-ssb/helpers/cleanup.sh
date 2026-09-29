#!/usr/bin/env bash
# Tear down only the verify-ssb web-server recorded in <run-dir>.
# Does not delete .local/verify-ssb/evidence/.
# Usage: cleanup.sh <run-dir>
set -euo pipefail

RUN_DIR="${1:-}"
if [[ -z "$RUN_DIR" ]]; then
  echo "usage: $0 <run-dir>" >&2
  exit 2
fi

PID_FILE="$RUN_DIR/pid"
SPAWN_FILE="$RUN_DIR/spawn_pid"
PGID_FILE="$RUN_DIR/pgid"

stop_pid() {
  local pid="${1:-}"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  kill -TERM "$pid" 2>/dev/null || true
  local _i
  for _i in $(seq 1 20); do
    if ! kill -0 "$pid" 2>/dev/null; then
      return 0
    fi
    sleep 0.2
  done
  kill -KILL "$pid" 2>/dev/null || true
}

if [[ ! -f "$PID_FILE" && ! -f "$SPAWN_FILE" && ! -f "$PGID_FILE" ]]; then
  echo "cleanup: no pid/spawn/pgid in $RUN_DIR (nothing to kill)"
  rm -rf "$RUN_DIR"
  exit 0
fi

PGID=""
if [[ -f "$PGID_FILE" ]]; then
  PGID="$(tr -d '[:space:]' <"$PGID_FILE")"
fi
SPAWN_PID=""
if [[ -f "$SPAWN_FILE" ]]; then
  SPAWN_PID="$(tr -d '[:space:]' <"$SPAWN_FILE")"
fi
LISTEN_PID=""
if [[ -f "$PID_FILE" ]]; then
  LISTEN_PID="$(tr -d '[:space:]' <"$PID_FILE")"
fi

# Kill the session/process group we created (setsid/nohup), then any leftover
# listen/spawn pids. Never pkill by name.
if [[ "$PGID" =~ ^[0-9]+$ ]] && (( PGID > 1 )); then
  kill -TERM -"$PGID" 2>/dev/null || true
  for _ in $(seq 1 20); do
    alive=0
    if [[ -n "$SPAWN_PID" ]] && kill -0 "$SPAWN_PID" 2>/dev/null; then
      alive=1
    fi
    if [[ -n "$LISTEN_PID" ]] && kill -0 "$LISTEN_PID" 2>/dev/null; then
      alive=1
    fi
    if [[ "$alive" -eq 0 ]]; then
      break
    fi
    sleep 0.2
  done
  kill -KILL -"$PGID" 2>/dev/null || true
fi

stop_pid "$LISTEN_PID"
stop_pid "$SPAWN_PID"

echo "cleanup: stopped listen=${LISTEN_PID:-none} spawn=${SPAWN_PID:-none} pgid=${PGID:-none}"

rm -rf "$RUN_DIR"
echo "cleanup: removed $RUN_DIR (evidence directory was not touched)"
