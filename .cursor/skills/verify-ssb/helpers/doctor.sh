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

if [[ ! -f "$PID_FILE" || ! -f "$PORT_FILE" ]]; then
  echo "doctor: missing pid/port in $RUN_DIR (did Launch run?)" >&2
  exit 1
fi

PID="$(tr -d '[:space:]' <"$PID_FILE")"
PORT="$(tr -d '[:space:]' <"$PORT_FILE")"

if [[ -z "$PID" ]] || ! kill -0 "$PID" 2>/dev/null; then
  echo "doctor: pid $PID is not alive" >&2
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
    # flutter run often has a child dart/flutter_tools process owning the port
    if ps -o ppid= -p "$lp" 2>/dev/null | grep -q -E "^[[:space:]]*${PID}$"; then
      owned=1
      break
    fi
    # walk one more ancestor (dart vm <- flutter_tools <- flutter)
    anc="$(ps -o ppid= -p "$lp" 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ -n "$anc" ]] && ps -o ppid= -p "$anc" 2>/dev/null | grep -q -E "^[[:space:]]*${PID}$"; then
      owned=1
      break
    fi
  done
  if [[ "$owned" -ne 1 ]]; then
    echo "doctor: port $PORT is listening but not owned by pid $PID (or its children). refuse to drive a shared instance." >&2
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

echo "doctor: ok pid=$PID port=$PORT url=http://127.0.0.1:${PORT}/"
