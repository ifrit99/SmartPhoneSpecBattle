#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
SRC="$REPO/lib/domain/services/currency_service.dart"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

EXPECT_FAIL_NO_UNMARK=0
if [ "${1:-}" = "--expect-fail-no-unmark" ]; then
  EXPECT_FAIL_NO_UNMARK=1
elif [ -n "${1:-}" ]; then
  echo "usage: bash $0 [--expect-fail-no-unmark]"
  exit 2
fi

method_body() {
  awk -v m="$1" '$0 ~ ("> " m "\\(") {on=1} on {print} on && /^  }$/ {exit}' "$SRC"
}

ops=()
for m in addCoins spendCoins addGems spendGems addReward; do
  body="$(method_body "$m")"
  [ -n "$body" ] || { echo "MODEL OUT OF SYNC: CurrencyService.$m not found in $SRC"; exit 2; }
  if grep -q '_serial\.run' <<<"$body"; then ops+=("\"$m\""); fi
done
for m in exchangeCoinsForGems; do
  body="$(method_body "$m")"
  [ -n "$body" ] || { echo "MODEL OUT OF SYNC: CurrencyService.$m not found in $SRC"; exit 2; }
  if ! grep -q '_serial\.run' <<<"$body"; then
    echo "MODEL OUT OF SYNC: CurrencyService.$m is missing _serial.run in $SRC"
    exit 2
  fi
done
serialized="{$(IFS=,; echo "${ops[*]-}")}"
echo "SerializedOps from code: $serialized"
if [[ "$serialized" != *addReward* ]]; then
  echo "MODEL OUT OF SYNC: CurrencyService.addReward is missing _serial.run in $SRC"
  exit 2
fi

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

restore_body="$(method_body _restoreSnapshot)"
[ -n "$restore_body" ] || { echo "MODEL OUT OF SYNC: CurrencyService._restoreSnapshot not found in $SRC"; exit 2; }
if ! grep -q 'snapshot\.coins' <<<"$restore_body" || ! grep -q 'saveCoins' <<<"$restore_body"; then
  echo "MODEL OUT OF SYNC: CurrencyService._restoreSnapshot does not restore coins from the snapshot in $SRC"
  exit 2
fi
if ! grep -q 'snapshot\.premiumGems' <<<"$restore_body" || ! grep -q 'savePremiumGems' <<<"$restore_body"; then
  echo "MODEL OUT OF SYNC: CurrencyService._restoreSnapshot does not restore gems from the snapshot in $SRC"
  exit 2
fi

if [ "$EXPECT_FAIL_NO_UNMARK" -eq 1 ]; then
  CFG_SRC="$HERE/CurrencyServiceNoUnmark.cfg"
  RUN_NAME="CurrencyServiceNoUnmark"
else
  CFG_SRC="$HERE/CurrencyService.cfg"
  RUN_NAME="CurrencyService"
fi

cp "$HERE/CurrencyService.tla" "$WORK/"
sed "s/^  SerializedOps = .*/  SerializedOps = $serialized/" "$CFG_SRC" > "$WORK/$RUN_NAME.cfg"

if ! command -v tlc >/dev/null 2>&1; then
  echo "FAIL  tlc is not on PATH. Sync checks passed. Install TLC2 (Java 21) and rerun."
  exit 1
fi

run() { (cd "$WORK" && tlc -workers auto -metadir "$WORK/states-$1" -config "$1.cfg" CurrencyService.tla > "$WORK/$1.out" 2>&1) || true; }

run "$RUN_NAME"
OUT="$WORK/$RUN_NAME.out"

if [ "$EXPECT_FAIL_NO_UNMARK" -eq 1 ]; then
  if grep -q "Invariant ClaimAllOrNothing is violated" "$OUT"; then
    echo "PASS  known-bad: ClaimAllOrNothing fails when RestoreClaimOnFailure is FALSE"
    exit 0
  fi
  echo "FAIL  known-bad variant did not violate ClaimAllOrNothing. TLC output:"
  sed -n '/^Error:/,$p' "$OUT"
  if grep -q "No error has been found" "$OUT"; then
    echo "(TLC reported no error. The unmark-off path should fail ClaimAllOrNothing.)"
  fi
  exit 1
fi

if grep -q "No error has been found" "$OUT"; then
  echo "PASS  NoLostUpdate, NoDuplicateClaim, NoOverspend, FailedOpHasNoEffect, ClaimAllOrNothing"
  exit 0
fi
echo "FAIL  main check. TLC output:"
sed -n '/^Error:/,$p' "$OUT"
exit 1
