--------------------------- MODULE CurrencyService ---------------------------
(***************************************************************************)
(* Model of gem/coin updates in SmartPhoneSpecBattle.                      *)
(*                                                                         *)
(* Dart runs one isolate: a task only yields at `await`. Each action below *)
(* is the code between two awaits. Code references:                        *)
(*   CurrencyService  lib/domain/services/currency_service.dart            *)
(*     addCoins/spendCoins/addGems/spendGems: _serial.run(load ->          *)
(*     check -> await saveCoins -> await savePremiumGems)                  *)
(*   SerialExecutor   lib/domain/services/serial_executor.dart             *)
(*   LocalStorageService.saveCoins/savePremiumGems                         *)
(*     lib/data/local_storage_service.dart: SharedPreferences.setInt       *)
(*     writes its in-memory cache synchronously, then awaits the platform  *)
(*     write. load() reads that cache.                                     *)
(*   Claimers c1,c2   LimitedEventService.claim()  (two concurrent taps)   *)
(*     lib/domain/services/limited_event_service.dart: own _serial; marks  *)
(*     claimed, then await addCoins, then await addGems.                   *)
(*   Pullers g1,g2    GachaService.pullSingle() (precheck load, spendCoins)*)
(*   Premium p        GachaService.pullPremium() (precheck load, spendGems)*)
(*     lib/domain/services/gacha_service.dart (no executor of its own)     *)
(***************************************************************************)
EXTENDS Integers, FiniteSets

CONSTANTS InitCoins, InitGems,
          EventRewardCoins, EventRewardGems,
          SinglePullCost, PremiumPullCost,
          SerializedOps,   \* CurrencyService methods wrapped in _serial.run
          Faults,          \* subset of {"callThrows", "persistThrows"}
          MaxFaults

Claimers == {"c1", "c2"}
Pullers  == {"g1", "g2"}
Premiums == {"p"}
Procs    == Claimers \cup Pullers \cup Premiums
Execs    == {"currency", "event"}   \* CurrencyService._serial, LimitedEventService._serial
None     == <<"none", "none", 0>>   \* SerialExecutor._chain == null (token-shaped)
OpPhases == {"idle", "wait", "gems", "rollbackCoins", "rollbackGems", "fin", "done"}

VARIABLES
  coins, gems,        \* SharedPreferences cache: storage.getCoins()/getPremiumGems()
  eventClaimed,       \* storage.isLimitedEventClaimed()
  chain,              \* [Execs -> token]  SerialExecutor._chain
  completed,          \* tokens whose Completer has completed
  runs,               \* [Procs -> [Execs -> Nat]] makes tokens unique
  prev,               \* [Procs -> [Execs -> token]] `previous` captured in run()
  pc,                 \* caller position
  op,                 \* CurrencyService method in flight for this task
  opPhase,
  upd,                \* `updated` computed from load()
  preCall,
  wroteGems,
  opResult,           \* "pending" | "ok" | "null" | "throw"
  opApplied,          \* ghost: this op already wrote a nonzero delta
  effCoins, effGems,  \* ghost: Init + sum of deltas whose write reached the cache
  claimCoinCredits, claimGemCredits,  \* ghost: event reward credits written
  failedWithEffect,   \* ghost: some op threw after its delta was written
  faults

storeVars == <<coins, gems, eventClaimed>>
execVars  == <<chain, completed, runs, prev>>
opVars    == <<op, opPhase, upd, preCall, wroteGems, opResult, opApplied>>
ghostVars == <<effCoins, effGems, claimCoinCredits, claimGemCredits, failedWithEffect>>
vars      == <<storeVars, execVars, pc, opVars, ghostVars, faults>>

Amount(k) == CASE k = "addCoins"   -> EventRewardCoins
               [] k = "addGems"    -> EventRewardGems
               [] k = "spendCoins" -> SinglePullCost
               [] k = "spendGems"  -> PremiumPullCost
CDelta(k) == CASE k = "addCoins" -> Amount(k) [] k = "spendCoins" -> -Amount(k) [] OTHER -> 0
GDelta(k) == CASE k = "addGems"  -> Amount(k) [] k = "spendGems"  -> -Amount(k) [] OTHER -> 0

CurTok(p) == <<p, "currency", runs[p]["currency"]>>
EvTok(p)  == <<p, "event", runs[p]["event"]>>
Done(t)   == t = None \/ t \in completed

CanFault(kind) == kind \in Faults /\ faults < MaxFaults
PersistChoices == IF CanFault("persistThrows") THEN {FALSE, TRUE} ELSE {FALSE}

Init ==
  /\ coins = InitCoins /\ gems = InitGems /\ eventClaimed = FALSE
  /\ chain = [e \in Execs |-> None] /\ completed = {}
  /\ runs = [p \in Procs |-> [e \in Execs |-> 0]]
  /\ prev = [p \in Procs |-> [e \in Execs |-> None]]
  /\ pc = [p \in Procs |-> "start"]
  /\ op = [p \in Procs |-> "none"] /\ opPhase = [p \in Procs |-> "idle"]
  /\ upd = [p \in Procs |-> [c |-> 0, g |-> 0]]
  /\ preCall = [p \in Procs |-> [c |-> 0, g |-> 0]]
  /\ wroteGems = [p \in Procs |-> FALSE]
  /\ opResult = [p \in Procs |-> "pending"] /\ opApplied = [p \in Procs |-> FALSE]
  /\ effCoins = InitCoins /\ effGems = InitGems
  /\ claimCoinCredits = 0 /\ claimGemCredits = 0
  /\ failedWithEffect = FALSE /\ faults = 0

-----------------------------------------------------------------------------
(* CurrencyService method body                                             *)

\* Call: SerialExecutor.run sync part (previous = _chain; _chain = mine).
\* Unserialized methods skip the executor. The action start is a separate
\* step; that only adds interleavings (sound for invariants).
CallOp(p, k, next) ==
  /\ pc' = [pc EXCEPT ![p] = next]
  /\ op' = [op EXCEPT ![p] = k]
  /\ opPhase' = [opPhase EXCEPT ![p] = "wait"]
  /\ opResult' = [opResult EXCEPT ![p] = "pending"]
  /\ opApplied' = [opApplied EXCEPT ![p] = FALSE]
  /\ wroteGems' = [wroteGems EXCEPT ![p] = FALSE]
  /\ IF k \in SerializedOps
       THEN /\ runs' = [runs EXCEPT ![p]["currency"] = @ + 1]
            /\ prev' = [prev EXCEPT ![p]["currency"] = chain["currency"]]
            /\ chain' = [chain EXCEPT !["currency"] =
                           <<p, "currency", runs[p]["currency"] + 1>>]
       ELSE /\ prev' = [prev EXCEPT ![p]["currency"] = None]
            /\ UNCHANGED <<runs, chain>>
  /\ UNCHANGED <<storeVars, completed, upd, preCall, ghostVars, faults>>

\* After `await previous`: load(); insufficiency check; compute `updated`;
\* saveCoins -> setInt writes the cache, then awaits (may throw after write).
ActionStart(p) ==
  /\ opPhase[p] = "wait"
  /\ Done(prev[p]["currency"])
  /\ LET k == op[p]
         insufficient == \/ (k = "spendCoins" /\ coins < Amount(k))
                         \/ (k = "spendGems"  /\ gems  < Amount(k))
     IN IF insufficient
        THEN /\ opPhase' = [opPhase EXCEPT ![p] = "fin"]
             /\ opResult' = [opResult EXCEPT ![p] = "null"]
             /\ UNCHANGED <<coins, upd, preCall, opApplied, effCoins, claimCoinCredits, faults>>
        ELSE \E f \in PersistChoices :
             /\ preCall' = [preCall EXCEPT ![p] = [c |-> coins, g |-> gems]]
             /\ coins' = coins + CDelta(k)
             /\ upd' = [upd EXCEPT ![p] = [c |-> coins + CDelta(k), g |-> gems + GDelta(k)]]
             /\ effCoins' = effCoins + CDelta(k)
             /\ claimCoinCredits' = IF p \in Claimers /\ k = "addCoins"
                                      THEN claimCoinCredits + 1 ELSE claimCoinCredits
             /\ opApplied' = [opApplied EXCEPT ![p] = CDelta(k) # 0]
             /\ faults' = IF f THEN faults + 1 ELSE faults
             /\ opPhase' = [opPhase EXCEPT ![p] = IF f THEN "rollbackCoins" ELSE "gems"]
             /\ opResult' = [opResult EXCEPT ![p] = IF f THEN "throw" ELSE "pending"]
  /\ UNCHANGED <<gems, eventClaimed, execVars, pc, op, wroteGems,
                 effGems, claimGemCredits, failedWithEffect>>

\* After `await saveCoins`: savePremiumGems writes `updated.premiumGems`.
WriteGems(p) ==
  /\ opPhase[p] = "gems"
  /\ \E f \in PersistChoices :
       /\ gems' = upd[p].g
       /\ effGems' = effGems + GDelta(op[p])
       /\ claimGemCredits' = IF p \in Claimers /\ op[p] = "addGems"
                               THEN claimGemCredits + 1 ELSE claimGemCredits
       /\ opApplied' = [opApplied EXCEPT ![p] = @ \/ GDelta(op[p]) # 0]
       /\ wroteGems' = [wroteGems EXCEPT ![p] = TRUE]
       /\ faults' = IF f THEN faults + 1 ELSE faults
       /\ opPhase' = [opPhase EXCEPT ![p] = IF f THEN "rollbackCoins" ELSE "fin"]
       /\ opResult' = [opResult EXCEPT ![p] = IF f THEN "throw" ELSE "ok"]
  /\ UNCHANGED <<coins, eventClaimed, execVars, pc, op, upd, preCall,
                 effCoins, claimCoinCredits, failedWithEffect>>

RollbackCoins(p) ==
  /\ opPhase[p] = "rollbackCoins"
  /\ coins' = preCall[p].c
  /\ effCoins' = effCoins - CDelta(op[p])
  /\ claimCoinCredits' = IF p \in Claimers /\ op[p] = "addCoins"
                           THEN claimCoinCredits - 1 ELSE claimCoinCredits
  /\ opPhase' = [opPhase EXCEPT ![p] = "rollbackGems"]
  /\ UNCHANGED <<gems, eventClaimed, execVars, pc, op, upd, preCall, wroteGems,
                 opResult, opApplied, effGems, claimGemCredits,
                 failedWithEffect, faults>>

RollbackGems(p) ==
  /\ opPhase[p] = "rollbackGems"
  /\ gems' = preCall[p].g
  /\ IF wroteGems[p]
       THEN /\ effGems' = effGems - GDelta(op[p])
            /\ claimGemCredits' = IF p \in Claimers /\ op[p] = "addGems"
                                    THEN claimGemCredits - 1 ELSE claimGemCredits
       ELSE UNCHANGED <<effGems, claimGemCredits>>
  /\ opApplied' = [opApplied EXCEPT ![p] = FALSE]
  /\ opPhase' = [opPhase EXCEPT ![p] = "fin"]
  /\ UNCHANGED <<coins, eventClaimed, execVars, pc, op, upd, preCall, wroteGems,
                 opResult, effCoins, claimCoinCredits, failedWithEffect, faults>>

\* SerialExecutor.run finally: completer.complete(); reset _chain if mine.
Finally(p) ==
  /\ opPhase[p] = "fin"
  /\ opPhase' = [opPhase EXCEPT ![p] = "done"]
  /\ failedWithEffect' = (failedWithEffect \/ (opResult[p] = "throw" /\ opApplied[p]))
  /\ IF op[p] \in SerializedOps
       THEN /\ completed' = completed \cup {CurTok(p)}
            /\ chain' = [chain EXCEPT !["currency"] = IF @ = CurTok(p) THEN None ELSE @]
       ELSE UNCHANGED <<completed, chain>>
  /\ UNCHANGED <<storeVars, runs, prev, pc, op, upd, preCall, wroteGems, opResult, opApplied,
                 effCoins, effGems, claimCoinCredits, claimGemCredits, faults>>

-----------------------------------------------------------------------------
(* Callers                                                                 *)

ClearOp(p) == /\ op' = [op EXCEPT ![p] = "none"]
              /\ opPhase' = [opPhase EXCEPT ![p] = "idle"]

\* LimitedEventService.claim finally (event executor), task ends.
ClaimExit(p) ==
  /\ pc' = [pc EXCEPT ![p] = "done"]
  /\ completed' = completed \cup {EvTok(p)}
  /\ chain' = [chain EXCEPT !["event"] = IF @ = EvTok(p) THEN None ELSE @]

\* ThrowingCurrencyService (test/domain/support): method throws before run().
CallThrows == CanFault("callThrows") /\ faults' = faults + 1

\* claim(): _serial.run sync part, then `await _ensureCurrentWeek()`.
ClaimEnter(p) ==
  /\ p \in Claimers /\ pc[p] = "start"
  /\ runs' = [runs EXCEPT ![p]["event"] = @ + 1]
  /\ prev' = [prev EXCEPT ![p]["event"] = chain["event"]]
  /\ chain' = [chain EXCEPT !["event"] = <<p, "event", runs[p]["event"] + 1>>]
  /\ pc' = [pc EXCEPT ![p] = "check"]
  /\ UNCHANGED <<storeVars, completed, opVars, ghostVars, faults>>

\* loadEvent().claimable check; `await setLimitedEventClaimed(true)` writes cache.
ClaimCheck(p) ==
  /\ p \in Claimers /\ pc[p] = "check" /\ Done(prev[p]["event"])
  /\ IF eventClaimed
       THEN /\ ClaimExit(p) /\ UNCHANGED eventClaimed
       ELSE /\ eventClaimed' = TRUE /\ pc' = [pc EXCEPT ![p] = "callCoins"]
            /\ UNCHANGED <<completed, chain>>
  /\ UNCHANGED <<coins, gems, runs, prev, opVars, ghostVars, faults>>

ClaimCallCoins(p) ==
  /\ p \in Claimers /\ pc[p] = "callCoins"
  /\ \/ CallOp(p, "addCoins", "awaitCoins")
     \/ /\ CallThrows /\ ClaimExit(p)
        /\ UNCHANGED <<storeVars, runs, prev, opVars, ghostVars>>

\* Resume after `await addCoins`; on success call addGems.
ClaimAwaitCoins(p) ==
  /\ p \in Claimers /\ pc[p] = "awaitCoins" /\ opPhase[p] = "done"
  /\ IF opResult[p] = "throw"
       THEN /\ ClaimExit(p) /\ ClearOp(p)
            /\ UNCHANGED <<storeVars, runs, prev, upd, preCall, wroteGems, opResult, opApplied, ghostVars, faults>>
       ELSE \/ CallOp(p, "addGems", "awaitGems")
            \/ /\ CallThrows /\ ClaimExit(p) /\ ClearOp(p)
               /\ UNCHANGED <<storeVars, runs, prev, upd, preCall, wroteGems, opResult, opApplied, ghostVars>>

ClaimAwaitGems(p) ==
  /\ p \in Claimers /\ pc[p] = "awaitGems" /\ opPhase[p] = "done"
  /\ ClaimExit(p) /\ ClearOp(p)
  /\ UNCHANGED <<storeVars, runs, prev, upd, preCall, wroteGems, opResult, opApplied, ghostVars, faults>>

\* pullSingle / pullPremium: precheck load(), then call spend (same sync step).
PullStart(p) ==
  /\ p \in Pullers \cup Premiums /\ pc[p] = "start"
  /\ LET k == IF p \in Pullers THEN "spendCoins" ELSE "spendGems"
         affordable == IF p \in Pullers THEN coins >= SinglePullCost
                                        ELSE gems >= PremiumPullCost
     IN IF ~affordable
          THEN /\ pc' = [pc EXCEPT ![p] = "done"]
               /\ UNCHANGED <<storeVars, execVars, opVars, ghostVars, faults>>
          ELSE \/ CallOp(p, k, "await")
               \/ /\ CallThrows /\ pc' = [pc EXCEPT ![p] = "done"]
                  /\ UNCHANGED <<storeVars, execVars, opVars, ghostVars>>

\* Resume after `await spendX` (roster grant not modeled).
PullAwait(p) ==
  /\ p \in Pullers \cup Premiums /\ pc[p] = "await" /\ opPhase[p] = "done"
  /\ pc' = [pc EXCEPT ![p] = "done"] /\ ClearOp(p)
  /\ UNCHANGED <<storeVars, execVars, upd, preCall, wroteGems, opResult, opApplied, ghostVars, faults>>

AllDone == \A p \in Procs : pc[p] = "done"

Next ==
  \/ \E p \in Procs :
       \/ ActionStart(p) \/ WriteGems(p)
       \/ RollbackCoins(p) \/ RollbackGems(p) \/ Finally(p)
       \/ ClaimEnter(p) \/ ClaimCheck(p) \/ ClaimCallCoins(p)
       \/ ClaimAwaitCoins(p) \/ ClaimAwaitGems(p)
       \/ PullStart(p) \/ PullAwait(p)
  \/ (AllDone /\ UNCHANGED vars)   \* finished; any other stuck state is a deadlock

Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
(* Properties                                                              *)

\* No lost or duplicated update: the stored balance always equals the start
\* balance plus every delta that was actually written.
NoLostUpdate == coins = effCoins /\ gems = effGems

\* The event reward is credited at most once (#69). At-least-once is NOT
\* promised: claim marks claimed before crediting (#73 pins this).
NoDuplicateClaim == claimCoinCredits <= 1 /\ claimGemCredits <= 1

NoOverspend == coins >= 0 /\ gems >= 0

\* A currency call that throws left the balance untouched.
FailedOpHasNoEffect == ~failedWithEffect

TypeOK == opPhase \in [Procs -> OpPhases]
=============================================================================
