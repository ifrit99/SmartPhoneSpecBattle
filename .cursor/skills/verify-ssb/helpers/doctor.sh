#!/usr/bin/env bash
# Read-only health check for a verify-ssb web-server run.
# Usage: doctor.sh <run-dir>
set -euo pipefail

RUN_DIR="${1:-}"
if [[ -z "$RUN_DIR" ]]; then
  echo "usage: $0 <run-dir>" >&2
  exit 2
fi

PID_FILE="$RUN_DIR/pid"
PORT_FILE="$RUN_DIR/port"
LOG_FILE="$RUN_DIR/flutter.log"
SERVE_FILE="$RUN_DIR/serve-url"
SPAWN_FILE="$RUN_DIR/spawn_pid"

if [[ ! -f "$PID_FILE" || ! -f "$PORT_FILE" ]]; then
  echo "doctor: missing pid/port in $RUN_DIR (did Launch run?)" >&2
  exit 1
fi

PID="$(tr -d '[:space:]' <"$PID_FILE")"
PORT="$(tr -d '[:space:]' <"$PORT_FILE")"
SPAWN_PID=""
if [[ -f "$SPAWN_FILE" ]]; then
  SPAWN_PID="$(tr -d '[:space:]' <"$SPAWN_FILE")"
fi

if [[ -z "$PID" ]] || ! kill -0 "$PID" 2>/dev/null; then
  echo "doctor: listen pid $PID is not alive" >&2
  exit 1
fi

if [[ -n "$SPAWN_PID" ]] && ! kill -0 "$SPAWN_PID" 2>/dev/null; then
  echo "doctor: spawn pid $SPAWN_PID is not alive (listen pid $PID may be an orphan)" >&2
  exit 1
fi

# Serve line is the ready signal. HTML <title>SPEC BATTLE</title> is served from
# web/index.html before Dart is ready; "Waiting for connection from debug
# service..." is also too early.
SERVE_RE="is being served at http://127\\.0\\.0\\.1:${PORT}"
if [[ ! -f "$LOG_FILE" ]] || ! grep -E "$SERVE_RE" "$LOG_FILE" >/dev/null 2>&1; then
  echo "doctor: flutter.log does not contain 'lib/main.dart is being served at http://127.0.0.1:${PORT}'" >&2
  echo "doctor: title/HTML 200 is not ready. last log:" >&2
  tail -n 20 "$LOG_FILE" >&2 || true
  exit 1
fi
if [[ ! -f "$SERVE_FILE" ]]; then
  echo "doctor: missing $SERVE_FILE (launch did not finish the serve-ready step)" >&2
  exit 1
fi

if command -v lsof >/dev/null 2>&1; then
  LISTEN_PIDS="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null || true)"
  if [[ -z "$LISTEN_PIDS" ]]; then
    echo "doctor: nothing listening on $PORT (pid $PID is alive but not serving)" >&2
    exit 1
  fi
  owned=0
  for lp in $LISTEN_PIDS; do
    if [[ "$lp" == "$PID" ]]; then
      owned=1
      break
    fi
    if [[ -n "$SPAWN_PID" && "$lp" == "$SPAWN_PID" ]]; then
      owned=1
      break
    fi
    # flutter run often has a child dart/flutter_tools process owning the port
    if ps -o ppid= -p "$lp" 2>/dev/null | grep -q -E "^[[:space:]]*${PID}$"; then
      owned=1
      break
    fi
    if [[ -n "$SPAWN_PID" ]] && ps -o ppid= -p "$lp" 2>/dev/null | grep -q -E "^[[:space:]]*${SPAWN_PID}$"; then
      owned=1
      break
    fi
    anc="$(ps -o ppid= -p "$lp" 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ -n "$anc" ]]; then
      if ps -o ppid= -p "$anc" 2>/dev/null | grep -q -E "^[[:space:]]*${PID}$"; then
        owned=1
        break
      fi
      if [[ -n "$SPAWN_PID" ]] && ps -o ppid= -p "$anc" 2>/dev/null | grep -q -E "^[[:space:]]*${SPAWN_PID}$"; then
        owned=1
        break
      fi
    fi
  done
  if [[ "$owned" -ne 1 ]]; then
    echo "doctor: port $PORT is listening but not owned by listen pid $PID / spawn ${SPAWN_PID:-none}. refuse to drive a shared instance." >&2
    lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >&2 || true
    exit 1
  fi
fi

BODY="$(mktemp)"
trap 'rm -f "$BODY"' EXIT
CODE="$(curl -fsS -o "$BODY" -w '%{http_code}' "http://127.0.0.1:${PORT}/" || true)"
if [[ "$CODE" != "200" ]]; then
  echo "doctor: GET http://127.0.0.1:${PORT}/ -> HTTP ${CODE:-curl-failed}" >&2
  exit 1
fi
if ! grep -q "<title>SPEC BATTLE</title>" "$BODY"; then
  echo "doctor: HTML 200 but <title>SPEC BATTLE</title> missing (wrong process on this port?)" >&2
  exit 1
fi
# Identity check only. Title is also present during the too-early bootstrap
# window; the serve line above is what makes this instance worth driving.

echo "doctor: ok listen=$PID spawn=${SPAWN_PID:-n/a} port=$PORT url=http://127.0.0.1:${PORT}/"
