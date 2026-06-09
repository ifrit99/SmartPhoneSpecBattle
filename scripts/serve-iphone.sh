#!/bin/bash
# iPhone の Safari からローカル開発サーバーへアクセスするための起動スクリプト。
# - 同一 Wi-Fi の場合: http://<LAN IP>:8090
# - Tailscale 経由（回線問わず・推奨）: http://<Tailscale IP>:8090
set -euo pipefail

PORT=8090
LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")
TS_IP=$(tailscale ip -4 2>/dev/null | head -1 || echo "")

echo "iPhone の Safari で次のいずれかの URL を開いてください:"
if [ -n "${TS_IP}" ]; then
  echo "  [推奨/回線問わず] Tailscale: http://${TS_IP}:${PORT}"
fi
if [ -n "${LAN_IP}" ]; then
  echo "  [同一Wi-Fiのみ]    LAN:       http://${LAN_IP}:${PORT}"
fi
echo ""

exec ~/development/flutter/bin/flutter run -d web-server --web-hostname 0.0.0.0 --web-port "${PORT}"
