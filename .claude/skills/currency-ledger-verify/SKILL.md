---
name: currency-ledger-verify
description: Model-check (TLA+/TLC) that concurrent coin/gem updates in CurrencyService never lose, duplicate, or overspend currency, that a reward claim credits at most once, and that a throwing currency call leaves no balance change. Use when a change touches lib/domain/services/currency_service.dart, serial_executor.dart, LocalStorageService.saveCoins/savePremiumGems, or any reward-claim / gacha / shop code that calls addCoins/addGems/spendCoins/spendGems.
---

# Currency ledger verification (TLA+)

**Property:** however earn, spend and claim calls overlap, including calls that throw, the stored coins and gems always equal the starting balance plus every change that was actually written; nothing goes negative, one reward is never credited twice, and a throwing call leaves the balance as it was before the call.
**Harm if broken:** players silently lose or gain gems/coins, or get free gacha pulls. This is the bug fixed in #72, where `addCoins` and `addGems` ran in parallel and one overwrote the other. A later persist-throw left a deducted balance with no character granted; `CurrencyService.save` now restores the pre-call snapshot before rethrowing.

## Run

From the repo root:

```
bash .claude/skills/currency-ledger-verify/run.sh
```

It takes about 10s and ~1.3M states. It needs `tlc` on PATH (TLC2 2026.10.15 rev 932d35e, Java 21). It does not use flutter.

| Output | Meaning | Exit |
| --- | --- | --- |
| `PASS  NoLostUpdate, NoDuplicateClaim, NoOverspend, FailedOpHasNoEffect` plus `PASS  FailedOpHasNoEffect (CONSTANTS match main cfg)` | Expected today. | 0 |
| `FAIL  main check` or `FAIL  FailedOpHasNoEffect check` and a trace | Real bug or modeling error. See below. | 1 |
| `MODEL OUT OF SYNC` | A CurrencyService method was renamed or removed. Update the model. | 2 |

`run.sh` reads `SerializedOps` (which of `addCoins/spendCoins/addGems/spendGems` call `_serial.run`) from `currency_service.dart` on every run, so removing `_serial.run` there is checked with no model edit. Every other change needs the model updated by hand.

## Does my change touch this?

Yes if it changes any of these:

| Code | Modeled as |
| --- | --- |
| `CurrencyService.addCoins/spendCoins/addGems/spendGems` (`lib/domain/services/currency_service.dart`) | `CallOp`, `ActionStart` (load, check, `saveCoins`), `WriteGems` (`savePremiumGems`), `RollbackCoins` / `RollbackGems` (restore snapshot), `Finally` |
| `CurrencyService.save` writing coins then gems, each with `await`; on throw, restore both keys independently then rethrow | the two write steps plus two rollback steps; each writes the *whole* value, not a delta |
| `SerialExecutor.run` (`lib/domain/services/serial_executor.dart`) | `chain`, `prev`, `completed`, token reset in `Finally`/`ClaimExit` |
| `LocalStorageService.saveCoins/savePremiumGems` (`lib/data/local_storage_service.dart`) | the cache write happens synchronously, then the `await` can throw (`persistThrows`) |
| `LimitedEventService.claim` (`lib/domain/services/limited_event_service.dart`) | `ClaimEnter`, `ClaimCheck` (check + `setLimitedEventClaimed(true)`), `ClaimCallCoins`, `ClaimAwaitCoins`, `ClaimAwaitGems`; two concurrent calls c1, c2 |
| `GachaService.pullSingle` / `pullPremium` (`lib/domain/services/gacha_service.dart`) | `PullStart` (precheck `load()` and spend call), `PullAwait`; g1, g2, p |
| `ThrowingCurrencyService` (test/domain/support) fault style | `callThrows`: the method throws before `run()` |

The other claimers (`DailyRewardService`, `BossBountyService`, `WeeklyChallengeService`, `SeasonPassService`, `PlayerRankService`, `AchievementService`, `DailyMissionService`, `RivalRoadService`, `LimitedEventService.claimAvailableMilestones`, `BattleResultService`, `DailyShopService.purchase`) use the same shape: mark claimed, then `await` add calls. `LimitedEventService.claim` stands in for all of them. If you add a claimer that credits *before* marking claimed, or that has no executor and an `await` between its check and its mark, model it explicitly as a new process.

## Reading a failure

TLC prints a numbered trace. Each `State n: <Action("proc") ...>` line is one uninterrupted stretch of Dart between two `await`s. Translate it like this:

- `ActionStart("c1")` with `op.c1 = "addGems"`: c1 ran `load()` and wrote coins. `upd.c1` is the `updated` value it will write. `snap.c1` is the pre-call balance.
- `WriteGems("p")`: p's `savePremiumGems(updated.premiumGems)` hit the cache.
- `RollbackCoins("p")` / `RollbackGems("p")`: persistThrows fired; save restores both keys to `snap`.
- `NoLostUpdate` violated: `coins`/`gems` differ from `effCoins`/`effGems`. A write based on a stale `load()` overwrote another call's change.
- `NoDuplicateClaim`: `claimCoinCredits` or `claimGemCredits` is greater than 1.
- `NoOverspend`: a balance went negative.
- `FailedOpHasNoEffect`: a throwing op left a nonzero delta in the cache (`failedWithEffect`).

**Real bug or modeling error?** Open the code at each step of the trace and ask whether Dart can really reach that order. Two things in the model are coarser than the code: (1) entering `run()` and starting the action are split into two steps even when `_chain` was null, and (2) a few async-return hops are merged. Both only add or remove orderings that cannot change a balance. If the trace depends on something else the code cannot do, fix the model. Never weaken an invariant to get a pass.

Reference break, checked 2026-10-19: remove `_serial.run` from `addGems`. The trace: claim c1's `addCoins` finishes, then c1 calls `addGems`, which loads gems=1 and computes 2. `pullPremium` (p) runs `spendGems`, loads gems=1 and computes 0. p writes gems=0, then c1 writes gems=2. The 1-gem pull is erased: stored 2, expected 1.

A persistThrows break: drop the restore in `save()`. `FailedOpHasNoEffect` fails. Trace: p `spendGems` writes gems=0, throws, and the cache stays at 0.

## Failed op (CurrencyServiceFailedOp.cfg)

`FailedOpHasNoEffect` is an invariant of both configs. `shared_preferences` 2.5.3 `setInt` still updates its in-memory cache *before* the platform write (`_preferenceCache[key] = value; return _store.setValue(...)`). `CurrencyService.save` snapshots `load()`, writes coins then gems, and on any throw restores both keys independently before rethrowing. CONSTANTS in the two cfgs must stay identical.

## Bounds and assumptions

- Processes: 2 concurrent `LimitedEventService.claim` (reward 1 coin + 1 gem), 2 `pullSingle` (cost 1 coin), 1 `pullPremium` (cost 1 gem). Start balance is 1 coin / 1 gem, so spends can race into "not enough". At most 1 fault per run (`MaxFaults = 1`), of either kind.
- One Dart isolate. A single `CurrencyService` instance is shared (`ServiceLocator`).
- `load()` reads the SharedPreferences cache. Disk persistence, app restarts and backup import (`importBackupCode`, which writes the coin keys directly) are not modeled.
- Not covered: whether claimed rewards are lost when the credit throws. That is intentional: #73 pins at-most-once. Also not covered: roster/inventory grants after a spend, shop/mission bookkeeping, a gem amount that fits in an int, and process counts above the bounds.
- Deadlock is checked (TLC's default). A hang in `SerialExecutor` after a throw would show up as `Deadlock reached`.

## Updating the model for an intended change

1. Map the changed code to the action in the table above and edit `CurrencyService.tla` so that each action is still exactly the code between two `await`s.
2. Keep the CONSTANTS in `CurrencyService.cfg` and `CurrencyServiceFailedOp.cfg` identical.
3. Prove that the edited model can still fail: make a scratch break in the Dart code (for example, drop `_serial.run` from one method, or drop the snapshot restore in `save()` and make the matching model edit), run `run.sh`, see it fail, and revert.
4. Run `run.sh` again on the real code.
5. Only then move the sync commit below forward.

## Sync record

- Covered files: `lib/domain/services/currency_service.dart`, `lib/domain/services/serial_executor.dart`, `lib/data/local_storage_service.dart` (saveCoins/getCoins/savePremiumGems/getPremiumGems), `lib/domain/services/limited_event_service.dart` (claim), `lib/domain/services/gacha_service.dart` (pullSingle, pullPremium).
- **Last confirmed in sync at commit `81c0faeb364b4aef0cc188064b34d62fa121a93d`.** To see whether the model needs another look, run `git diff 81c0faeb364b4aef0cc188064b34d62fa121a93d -- <covered files>`.
- Move this commit forward only after you confirm the model describes the code at the new commit and `run.sh` gives the expected result there.
- Mutations seen failing on 2026-10-19: no `_serial.run` on `addGems` → `NoLostUpdate`; no `setLimitedEventClaimed(true)` → `NoDuplicateClaim`; no balance check in `spendCoins` → `NoOverspend`; no snapshot restore in `save()` → `FailedOpHasNoEffect`.

## 深掘りメモ

1. A professional would model the real await points and the storage library's failure semantics, not "an atomic increment". They would also prove every invariant can fail.
2. Raw material: `currency_service.dart`, `serial_executor.dart`, `shared_preferences` 2.5.3 `_setValue` source, the claim/gacha callers, and the #72/#73 tests.
3. Method: TLA+ with exhaustive TLC search, ghost ledger variables, fault injection, and mutation checks.
4. External check: TLC's verdict, plus failing runs on real-code breaks.
