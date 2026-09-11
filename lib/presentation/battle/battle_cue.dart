import '../../domain/services/battle_engine.dart';

/// スプライトの排他ステート（RFC §2-1）。
enum SpriteState {
  idle,
  attack,
  cast,
  hit,
  guard,
  heal,
  victory,
  defeat,
}

/// VFX の種類（RFC §2-2）。
enum VfxKind {
  flash,
  slash,
  burst,
  ring,
  sparkle,
  crit,
}

/// ログ1件から決まる演出キュー（RFC §3-1）。
class BattleCue {
  final SpriteState? actorState;
  final SpriteState? targetState;
  final List<VfxKind> vfxKinds;
  final int beatMs;

  const BattleCue({
    this.actorState,
    this.targetState,
    this.vfxKinds = const [],
    required this.beatMs,
  });
}

/// 通常攻撃のビート長（RFC §3）。
const int attackBeatMs = 300;

/// スキルのビート長（RFC §3）。
const int skillBeatMs = 360;

/// 防御のビート長（RFC §3）。
const int defendBeatMs = 300;

/// 演出時間を再生速度でスケールする。下限は元の 40%（RFC §3）。
int scaleDurationMs(int milliseconds, double speed) {
  if (milliseconds <= 0) {
    return 0;
  }
  if (speed <= 0) {
    return milliseconds;
  }
  final scaled = milliseconds / speed;
  final floor = milliseconds * 0.4;
  return (scaled < floor ? floor : scaled).round();
}

/// [entry] から RFC §3-1 の演出を返す。
///
/// [isPlayerActor] は現行の名前一致結果を受け取る（RFC §9-2）。
/// キュー自体のステート割当は actionType / damage / healing のみで決まる。
BattleCue resolve(BattleLogEntry entry, {required bool isPlayerActor}) {
  final crit = entry.isCritical ? const [VfxKind.crit] : const <VfxKind>[];

  switch (entry.actionType) {
    case BattleActionType.attack:
      return BattleCue(
        actorState: SpriteState.attack,
        targetState: SpriteState.hit,
        vfxKinds: [VfxKind.slash, ...crit],
        beatMs: attackBeatMs,
      );
    case BattleActionType.skill:
      if (entry.damage > 0) {
        return BattleCue(
          actorState: SpriteState.cast,
          targetState: SpriteState.hit,
          vfxKinds: [VfxKind.flash, VfxKind.burst, ...crit],
          beatMs: skillBeatMs,
        );
      }
      if (entry.healing > 0) {
        return BattleCue(
          actorState: SpriteState.cast,
          targetState: SpriteState.heal,
          vfxKinds: const [VfxKind.flash, VfxKind.sparkle],
          beatMs: skillBeatMs,
        );
      }
      return const BattleCue(
        actorState: SpriteState.cast,
        vfxKinds: [VfxKind.flash, VfxKind.ring],
        beatMs: skillBeatMs,
      );
    case BattleActionType.defend:
      if (entry.healing > 0) {
        return const BattleCue(
          actorState: SpriteState.cast,
          targetState: SpriteState.heal,
          vfxKinds: [VfxKind.sparkle],
          beatMs: defendBeatMs,
        );
      }
      return const BattleCue(
        actorState: SpriteState.guard,
        vfxKinds: [VfxKind.ring],
        beatMs: defendBeatMs,
      );
    case null:
      if (entry.damage > 0) {
        return const BattleCue(
          targetState: SpriteState.hit,
          beatMs: 0,
        );
      }
      return const BattleCue(beatMs: 0);
  }
}
