#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
SRC="$REPO/lib/domain/services/currency_service.dart"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

method_body() {
  awk -v m="$1" '$0 ~ ("> " m "\\(") {on=1} on {print} on && /^  }$/ {exit}' "$SRC"
}

ops=()
for m in addCoins spendCoins addGems spendGems; do
  body="$(method_body "$m")"
  [ -n "$body" ] || { echo "MODEL OUT OF SYNC: CurrencyService.$m not found in $SRC"; exit 2; }
  if grep -q '_serial\.run' <<<"$body"; then ops+=("\"$m\""); fi
done
for m in addReward exchangeCoinsForGems; do
  body="$(method_body "$m")"
  [ -n "$body" ] || { echo "MODEL OUT OF SYNC: CurrencyService.$m not found in $SRC"; exit 2; }
  if ! grep -q '_serial\.run' <<<"$body"; then
    echo "MODEL OUT OF SYNC: CurrencyService.$m is missing _serial.run in $SRC"
    exit 2
  fi
done
serialized="{$(IFS=,; echo "${ops[*]-}")}"
echo "SerializedOps from code: $serialized"

save_body="$(method_body save)"
[ -n "$save_body" ] || { echo "MODEL OUT OF SYNC: CurrencyService.save not found in $SRC"; exit 2; }
if ! grep -q '_restoreSnapshot' <<<"$save_body"; then
  echo "MODEL OUT OF SYNC: CurrencyService.save is missing _restoreSnapshot in $SRC"
  exit 2
fi
if ! grep -q 'rethrow' <<<"$save_body"; then
  echo "MODEL OUT OF SYNC: CurrencyService.save is missing rethrow in $SRC"
  exit 2
fi

cp "$HERE/CurrencyService.tla" "$WORK/"
sed "s/^  SerializedOps = .*/  SerializedOps = $serialized/" "$HERE/CurrencyService.cfg" > "$WORK/CurrencyService.cfg"

run() { (cd "$WORK" && tlc -workers auto -metadir "$WORK/states-$1" -config "$1.cfg" CurrencyService.tla > "$WORK/$1.out" 2>&1) || true; }

run CurrencyService
if grep -q "No error has been found" "$WORK/CurrencyService.out"; then
  echo "PASS  NoLostUpdate, NoDuplicateClaim, NoOverspend, FailedOpHasNoEffect"
  exit 0
fi
echo "FAIL  main check. TLC output:"
sed -n '/^Error:/,$p' "$WORK/CurrencyService.out"
exit 1
