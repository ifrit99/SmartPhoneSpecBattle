---
name: currency-ledger-verify
description: Model-check (TLA+/TLC) that concurrent coin/gem updates in CurrencyService never lose, duplicate, or overspend currency, that a reward claim either credits the full addReward once or leaves the claimed flag and balances unchanged, and that a throwing currency call leaves no balance change. Use when a change touches lib/domain/services/currency_service.dart, serial_executor.dart, LocalStorageService.saveCoins/savePremiumGems, or any reward-claim / gacha / shop code that calls addReward/addCoins/addGems/spendCoins/spendGems/exchangeCoinsForGems.
---

# Currency ledger verification (TLA+)

**Property:** however earn, spend and claim calls overlap, including calls that throw, the stored coins and gems always equal the starting balance plus every change that was actually written; nothing goes negative; a claim either credits the full reward exactly once or leaves both the claimed flag and the balances as they were; a throwing currency call leaves the balance as it was before the call.
**Harm if broken:** players silently lose or gain gems/coins, get a half-paid event reward, lose a reward after a failed credit, or get free gacha pulls. #72 was a parallel `addCoins`/`addGems` overwrite. #75 made `CurrencyService.save` restore the pre-call snapshot before rethrowing. #77 made claimers mark, then `addReward`, then unmark and rethrow if credit throws, so a retry can still be paid once.

## Run

From the repo root:

```
bash .claude/skills/currency-ledger-verify/run.sh
```

The known-bad variant (unmark-on-failure removed in the model) is:

```
bash .claude/skills/currency-ledger-verify/run.sh --expect-fail-no-unmark
```

That run must print that `ClaimAllOrNothing` is violated. You can also run TLC yourself with `-config CurrencyServiceNoUnmark.cfg`.

It takes about 10s and ~878k distinct states (2,337,498 generated, depth 33). The older two-`add` model on this commit was ~1.75M distinct (4,894,176 generated, depth 31). One serialized `addReward` cut that graph. It needs `tlc` on PATH (TLC2 2026.10.15 rev 932d35e or TLC2 2026.10.20 rev d2e1472, Java 21). It does not use flutter.

Files in this skill: `SKILL.md`, `run.sh`, `CurrencyService.tla`, `CurrencyService.cfg`, `CurrencyServiceNoUnmark.cfg`.

| Output | Meaning | Exit |
| --- | --- | --- |
| `PASS  NoLostUpdate, NoDuplicateClaim, NoOverspend, FailedOpHasNoEffect, ClaimAllOrNothing` | Expected today. | 0 |
| `PASS  known-bad: ClaimAllOrNothing fails when RestoreClaimOnFailure is FALSE` | Expected for `--expect-fail-no-unmark`. | 0 |
| `FAIL  main check` and a trace | Real bug or modeling error. See below. | 1 |
| `FAIL  tlc is not on PATH` | Sync checks passed. TLC did not run. | 1 |
| `MODEL OUT OF SYNC` | A CurrencyService method was renamed or removed, `addCoins` / `addGems` / `addReward` / `exchangeCoinsForGems` lost `_serial.run`, `save` lost `_restoreSnapshot` or `rethrow`, `_restoreSnapshot` no longer writes `snapshot.coins` / `snapshot.premiumGems`, or `LimitedEventService.claim` lost `setLimitedEventClaimed(false)`. Update the model. | 2 |

`run.sh` reads these facts from `currency_service.dart` on every run: `SerializedOps` (which of `addCoins/spendCoins/addGems/spendGems/addReward` call `_serial.run`), that `addCoins`, `addGems`, and `addReward` are in that set (gacha refund and battle reward still call `addCoins` directly), that `exchangeCoinsForGems` exists and calls `_serial.run` (it is not added to `SerializedOps`), that `save` still calls `_restoreSnapshot` and `rethrow`, and that `_restoreSnapshot` still writes coins and gems from the snapshot object. It also reads `LimitedEventService.claim` and requires `setLimitedEventClaimed(false)` in that method body, not in `_ensureCurrentWeek`. An emptied `_restoreSnapshot` body fails this check. Removing `_serial.run` from `addCoins` / `addGems` / `addReward`, `_restoreSnapshot`, `rethrow`, the snapshot writes, or the claim unmark is checked with no model edit. Every other change needs the model updated by hand.

## Does my change touch this?

Yes if it changes any of these:

| Code | Modeled as |
| --- | --- |
| `CurrencyService.addCoins/spendCoins/addGems/spendGems/addReward` (`lib/domain/services/currency_service.dart`) | `CallOp`, `ActionStart` (load, check, `saveCoins`), `WriteGems` (`savePremiumGems`), `RollbackCoins` / `RollbackGems` (restore snapshot), `Finally` |
| `CurrencyService.addReward` | One serialized op whose `save` writes both deltas. Claimers call this, not `addCoins` then `addGems`. |
| `CurrencyService.exchangeCoinsForGems` | Not a TLA process. `run.sh` only checks that the method exists and uses `_serial.run`. |
| `CurrencyService.save` writing coins then gems, each with `await`; on throw, restore both keys independently then rethrow | the two write steps plus two rollback steps; each writes the *whole* value, not a delta |
| `SerialExecutor.run` (`lib/domain/services/serial_executor.dart`) | `chain`, `prev`, `completed`, token reset in `Finally`/`ClaimExit` |
| `LocalStorageService.saveCoins/savePremiumGems` (`lib/data/local_storage_service.dart`) | the cache write happens synchronously, then the `await` can throw (`persistThrows`) |
| `LimitedEventService.claim` (`lib/domain/services/limited_event_service.dart`) | `ClaimEnter`, `ClaimCheck` (check + `setLimitedEventClaimed(true)`), `ClaimCallReward`, `ClaimAwaitReward`, `ClaimUnmark`; two concurrent calls c1, c2 |
| `GachaService.pullSingle` / `pullPremium` (`lib/domain/services/gacha_service.dart`) | `PullStart` (precheck `load()` and spend call), `PullAwait`; g1, g2, p |
| `ThrowingCurrencyService` (test/domain/support) fault style | `callThrows`: the method throws before `run()` |

The other claimers (`DailyRewardService`, `BossBountyService`, `WeeklyChallengeService`, `SeasonPassService`, `PlayerRankService`, `AchievementService`, `DailyMissionService`, `RivalRoadService`, `LimitedEventService.claimAvailableMilestones`, `BattleResultService`) use the same shape: save previous, mark claimed, `await addReward`, on throw restore previous and rethrow. `LimitedEventService.claim` stands in for all of them. `DailyShopService.purchase` uses `exchangeCoinsForGems` and marks purchased only after success. If you add a claimer that credits *before* marking claimed, that has no restore on throw, or that has no executor and an `await` between its check and its mark, model it explicitly as a new process.

## Reading a failure

TLC prints a numbered trace. Each `State n: <Action("proc") ...>` line is one uninterrupted stretch of Dart between two `await`s. Translate it like this:

- `ActionStart("c1")` with `op.c1 = "addReward"`: c1 ran `load()` and wrote coins. `upd.c1` is the `updated` value it will write. `snap.c1` is the pre-call balance.
- `WriteGems("p")`: p's `savePremiumGems(updated.premiumGems)` hit the cache.
- `RollbackCoins("p")` / `RollbackGems("p")`: persistThrows fired; save restores both keys to `snap`.
- `ClaimUnmark("c1")`: credit threw; c1 restores `setLimitedEventClaimed(false)`, or the restore write fails and `unmarkFailed` becomes TRUE.
- `NoLostUpdate` violated: `coins`/`gems` differ from `effCoins`/`effGems`. A write based on a stale `load()` overwrote another call's change.
- `NoDuplicateClaim`: `claimCredits` is greater than 1.
- `ClaimAllOrNothing` violated: a finished claim left `eventClaimed` true with no credit and `unmarkFailed` false (lost reward, no retry), or paid without remaining marked. Partial coin-without-gem pay cannot survive `Finally`; mid-save is still rolled back.
- `NoOverspend`: a balance went negative.
- `FailedOpHasNoEffect`: a throwing op left a nonzero delta in the cache (`failedWithEffect`).

**Real bug or modeling error?** Open the code at each step of the trace and ask whether Dart can really reach that order. Two things in the model are coarser than the code: (1) entering `run()` and starting the action are split into two steps even when `_chain` was null, and (2) a few async-return hops are merged. Both only add or remove orderings that cannot change a balance. Unmark-write failure is also coarser: it does not consume `MaxFaults`, so credit-throw plus stuck-unclaimable is always reachable on the catch path. If the trace depends on something else the code cannot do, fix the model. Never weaken an invariant to get a pass.

Reference break: remove `_serial.run` from `addCoins` or `addGems`. `run.sh` exits 2. Those methods are still live callers (`GachaService` duplicate refund, `BattleResultService` battle reward). The model no longer drives them from claim, so TLC would not see the race if the sync check skipped them. To see `NoLostUpdate` in TLC, drop `_serial.run` from `spendGems` so `SerializedOps` omits it. The trace is a claim `addReward` racing an unserialized `spendGems` write. Removing `setLimitedEventClaimed(false)` from `LimitedEventService.claim` also exits 2. The known-bad cfg is the model-side version of that break.

A persistThrows break: empty the body of `_restoreSnapshot` (keep the call and `rethrow` in `save()`). `run.sh` exits 2. The old claim that TLC would then fail `FailedOpHasNoEffect` was wrong, because the sync check used to look only for the call. To see `FailedOpHasNoEffect` in TLC, remove `RollbackCoins` / `RollbackGems` from the model.

The known-bad variant sets `RestoreClaimOnFailure = FALSE`. After a thrown `addReward`, the claimed flag stays true, `claimCredits` stays 0, and `unmarkFailed` stays false. `ClaimAllOrNothing` fails. That is the #73 at-most-once-and-lost-on-throw behavior.

## Failed op

`FailedOpHasNoEffect` is an invariant of `CurrencyService.cfg`. `shared_preferences` 2.5.3 `setInt` still updates its in-memory cache *before* the platform write (`_preferenceCache[key] = value; return _store.setValue(...)`). `CurrencyService.save` snapshots `load()`, writes coins then gems, and on any throw restores both keys independently before rethrowing.

## Bounds and assumptions

- Processes: 2 concurrent `LimitedEventService.claim` (reward 1 coin + 1 gem via one `addReward`), 2 `pullSingle` (cost 1 coin), 1 `pullPremium` (cost 1 gem). Start balance is 1 coin / 1 gem, so spends can race into "not enough". At most 1 fault per run (`MaxFaults = 1`), of either kind. Unmark-write failure is extra to that budget.
- One Dart isolate. A single `CurrencyService` instance is shared (`ServiceLocator`).
- `load()` reads the SharedPreferences cache. Disk persistence, app restarts and backup import (`importBackupCode`, which writes the coin keys directly) are not modeled.
- Not covered: roster/inventory grants after a spend, shop/mission bookkeeping, `exchangeCoinsForGems` as its own process, a gem amount that fits in an int, and process counts above the bounds. Unmark-write failure is covered as residual risk: stuck-unclaimable is allowed, double pay is not.
- Deadlock is checked (TLC's default). A hang in `SerialExecutor` after a throw would show up as `Deadlock reached`.

## Updating the model for an intended change

1. Map the changed code to the action in the table above and edit `CurrencyService.tla` so that each action is still exactly the code between two `await`s.
2. Prove that the edited model can still fail: make a scratch break in the Dart code (for example, drop `_serial.run` from `addCoins` or `addGems`, drop `setLimitedEventClaimed(false)` from `claim`, or empty `_restoreSnapshot`), run `run.sh`, see it exit 2, and revert. For the claim restore in the model, run `--expect-fail-no-unmark` and confirm `ClaimAllOrNothing` fails.
3. Run `run.sh` again on the real code.
4. Only then move the sync commit below forward.

## Sync record

- Covered files: `lib/domain/services/currency_service.dart`, `lib/domain/services/serial_executor.dart`, `lib/data/local_storage_service.dart` (saveCoins/getCoins/savePremiumGems/getPremiumGems), `lib/domain/services/limited_event_service.dart` (claim), `lib/domain/services/gacha_service.dart` (pullSingle, pullPremium).
- **Last confirmed in sync at commit `b3848753be910722d8ced6347b9c8601b4742388`.** That is current master (#77). `run.sh` has no `tlc` on PATH in the Cloud Agent image. A temporary TLC2 2026.10.20 jar was used to confirm the counts above. To see whether the model needs another look, run `git diff b3848753be910722d8ced6347b9c8601b4742388 -- <covered files>`.
- Move this commit forward only after you confirm the model describes the code at the new commit and `run.sh` gives the expected result there.
- Mutations: no `_serial.run` on `addCoins`, `addGems`, or `addReward` → exit 2; no `setLimitedEventClaimed(false)` in `claim` → exit 2; no `_serial.run` on `spendGems` → `NoLostUpdate`; no `setLimitedEventClaimed(true)` → `NoDuplicateClaim` / `ClaimAllOrNothing`; no balance check in `spendCoins` → `NoOverspend`; empty `_restoreSnapshot` body → exit 2; `RestoreClaimOnFailure = FALSE` → `ClaimAllOrNothing`. Dropping `_restoreSnapshot` or `rethrow` from `save()` also exits 2 (`MODEL OUT OF SYNC`) before TLC.

## 深掘りメモ

1. A professional would model the real await points and the storage library's failure semantics, not "an atomic increment". They would also prove every invariant can fail.
2. Raw material: `currency_service.dart`, `serial_executor.dart`, `shared_preferences` 2.5.3 `_setValue` source, the claim/gacha callers, and the #72/#73/#77 tests.
3. Method: TLA+ with exhaustive TLC search, ghost ledger variables, fault injection, and mutation checks.
4. External check: TLC's verdict, plus failing runs on real-code breaks and the known-bad cfg.
