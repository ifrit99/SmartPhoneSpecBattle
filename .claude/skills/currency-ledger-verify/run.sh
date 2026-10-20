#!/usr/bin/env bash
# Model-check CurrencyService gem/coin updates with TLC.
# Usage (from repo root): bash .claude/skills/currency-ledger-verify/run.sh
# Exit 0: all four invariants pass on both configs.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
SRC="$REPO/lib/domain/services/currency_service.dart"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# SerializedOps is read from the code: a method counts when its body calls _serial.run.
ops=()
for m in addCoins spendCoins addGems spendGems; do
  body="$(awk -v m="$m" '$0 ~ ("> " m "\\(") {on=1} on {print} on && /^  }$/ {exit}' "$SRC")"
  [ -n "$body" ] || { echo "MODEL OUT OF SYNC: CurrencyService.$m not found in $SRC"; exit 2; }
  if grep -q '_serial\.run' <<<"$body"; then ops+=("\"$m\""); fi
done
serialized="{$(IFS=,; echo "${ops[*]-}")}"
echo "SerializedOps from code: $serialized"

cp "$HERE/CurrencyService.tla" "$WORK/"
for cfg in CurrencyService CurrencyServiceFailedOp; do
  sed "s/^  SerializedOps = .*/  SerializedOps = $serialized/" "$HERE/$cfg.cfg" > "$WORK/$cfg.cfg"
done

run() { (cd "$WORK" && tlc -workers auto -metadir "$WORK/states-$1" -config "$1.cfg" CurrencyService.tla > "$WORK/$1.out" 2>&1) || true; }

run CurrencyService
if grep -q "No error has been found" "$WORK/CurrencyService.out"; then
  echo "PASS  NoLostUpdate, NoDuplicateClaim, NoOverspend, FailedOpHasNoEffect"
  main=0
else
  echo "FAIL  main check. TLC output:"
  sed -n '/^Error:/,$p' "$WORK/CurrencyService.out"
  main=1
fi

run CurrencyServiceFailedOp
if grep -q "No error has been found" "$WORK/CurrencyServiceFailedOp.out"; then
  echo "PASS  FailedOpHasNoEffect (CONSTANTS match main cfg)"
  finding=0
else
  echo "FAIL  FailedOpHasNoEffect check. TLC output:"
  sed -n '/^Error:/,$p' "$WORK/CurrencyServiceFailedOp.out"
  finding=1
fi

exit $(( main ? 1 : finding ))
