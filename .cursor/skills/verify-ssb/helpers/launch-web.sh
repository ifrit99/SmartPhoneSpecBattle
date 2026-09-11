#!/usr/bin/env bash
# Start Flutter web-server for verify-ssb. Does not open a browser.
# Detaches into its own session (setsid / nohup) so the server survives
# when the launching command/agent turn exits.
#
# Usage: launch-web.sh <port> <run-dir> [release|debug]
# Default mode is release: debug DDC can wedge after a failed first client
# (blank body, only flutter_bootstrap.js).
set -euo pipefail

PORT="${1:-8091}"
RUN_DIR="${2:-}"
MODE="${3:-release}"

if [[ -z "$RUN_DIR" ]]; then
  echo "usage: $0 <port> <run-dir> [release|debug]" >&2
  exit 2
fi

if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1024 || PORT > 65535 )); then
  echo "refusing port '$PORT' (expected 1024-65535)" >&2
  exit 2
fi

if [[ "$MODE" != "release" && "$MODE" != "debug" ]]; then
  echo "mode must be 'release' or 'debug' (got '$MODE')" >&2
  exit 2
fi

mkdir -p "$RUN_DIR"
PORT_FILE="$RUN_DIR/port"
PID_FILE="$RUN_DIR/pid"
SPAWN_FILE="$RUN_DIR/spawn_pid"
PGID_FILE="$RUN_DIR/pgid"
LOG_FILE="$RUN_DIR/flutter.log"
SERVE_FILE="$RUN_DIR/serve-url"
MODE_FILE="$RUN_DIR/mode"

if command -v lsof >/dev/null 2>&1; then
  if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "port $PORT is already listening; refuse to steal it. pick 8091 or 8092." >&2
    lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >&2 || true
    exit 1
  fi
fi

FLUTTER_BIN="$(command -v flutter || true)"
if [[ -z "$FLUTTER_BIN" || ! -x "$FLUTTER_BIN" ]]; then
  FLUTTER_BIN="${HOME}/development/flutter/bin/flutter"
fi
if [[ ! -x "$FLUTTER_BIN" ]]; then
  echo "flutter not found on PATH or at $HOME/development/flutter/bin/flutter" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  cd "$ROOT"
else
  cd "$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi

# Record intent before spawn so doctor/cleanup have something to read on failure.
printf '%s\n' "$PORT" >"$PORT_FILE"
printf '%s\n' "$MODE" >"$MODE_FILE"

RUN_ARGS=(run -d web-server --web-hostname 127.0.0.1 --web-port "$PORT")
if [[ "$MODE" == "release" ]]; then
  RUN_ARGS+=(--release)
fi
printf '%s\n' "$FLUTTER_BIN ${RUN_ARGS[*]}" >"$RUN_DIR/launch-cmd"

# Detach so the server survives when the helper/agent command exits.
# A bare `flutter ... &` gets SIGHUP on that exit (Mac live failure).
# Plain `setsid cmd &` EPERMs: a background job is already a process-group
# leader. Portable fix: nohup (ignore SIGHUP) + disown (drop the bash job).
: >"$LOG_FILE"
nohup "$FLUTTER_BIN" "${RUN_ARGS[@]}" >"$LOG_FILE" 2>&1 < /dev/null &
SPAWN_PID=$!
disown "$SPAWN_PID" 2>/dev/null || true
if ! kill -0 "$SPAWN_PID" 2>/dev/null; then
  echo "failed to spawn detached flutter (pid='$SPAWN_PID')" >&2
  tail -n 40 "$LOG_FILE" >&2 || true
  exit 1
fi
printf '%s\n' "$SPAWN_PID" >"$SPAWN_FILE"

PGID="$(ps -o pgid= -p "$SPAWN_PID" 2>/dev/null | tr -d '[:space:]' || true)"
if [[ -z "$PGID" ]]; then
  PGID="$SPAWN_PID"
fi
printf '%s\n' "$PGID" >"$PGID_FILE"
# Until the port is bound, doctor can still see the session we started.
printf '%s\n' "$SPAWN_PID" >"$PID_FILE"

# Do NOT treat HTML <title>SPEC BATTLE</title> or
# "Waiting for connection from debug service..." as ready.
# Those appear while the Dart/Flutter app is not served yet.
SERVE_RE="is being served at http://127\\.0\\.0\\.1:${PORT}"
WAIT_SECS=180
if [[ "$MODE" == "debug" ]]; then
  WAIT_SECS=90
fi

ready=0
for _ in $(seq 1 "$WAIT_SECS"); do
  if ! kill -0 "$SPAWN_PID" 2>/dev/null; then
    echo "flutter run exited before the server was ready. last log:" >&2
    tail -n 80 "$LOG_FILE" >&2 || true
    exit 1
  fi
  if grep -E "$SERVE_RE" "$LOG_FILE" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done

if [[ "$ready" -ne 1 ]]; then
  echo "timed out waiting for serve line in $LOG_FILE" >&2
  echo "need: lib/main.dart is being served at http://127.0.0.1:${PORT}" >&2
  echo "(HTML title alone is NOT ready; 'Waiting for connection from debug service' is NOT ready)" >&2
  tail -n 80 "$LOG_FILE" >&2 || true
  if [[ "$PGID" =~ ^[0-9]+$ ]] && (( PGID > 1 )); then
    kill -TERM -"$PGID" 2>/dev/null || true
  fi
  kill -TERM "$SPAWN_PID" 2>/dev/null || true
  exit 1
fi

SERVE_URL="$(grep -E "$SERVE_RE" "$LOG_FILE" | tail -n 1 | grep -oE "http://127\\.0\\.0\\.1:${PORT}" | tail -n 1 || true)"
if [[ -z "$SERVE_URL" ]]; then
  SERVE_URL="http://127.0.0.1:${PORT}"
fi
printf '%s\n' "$SERVE_URL" >"$SERVE_FILE"

# Record the process that actually owns the listen port (often a child of flutter run).
LISTEN_PID=""
if command -v lsof >/dev/null 2>&1; then
  for _ in $(seq 1 15); do
    LISTEN_PID="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null | head -n 1 || true)"
    if [[ -n "$LISTEN_PID" ]]; then
      break
    fi
    sleep 1
  done
fi
if [[ -z "$LISTEN_PID" ]]; then
  LISTEN_PID="$SPAWN_PID"
fi
printf '%s\n' "$LISTEN_PID" >"$PID_FILE"

echo "verify-ssb web-server ready mode=$MODE spawn=$SPAWN_PID listen=$LISTEN_PID pgid=$PGID url=${SERVE_URL}/"
echo "log=$LOG_FILE"
