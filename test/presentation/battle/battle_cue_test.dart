import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/services/battle_engine.dart';
import 'package:spec_battle_game/presentation/battle/battle_cue.dart';

void main() {
  group('resolve RFC §3-1', () {
    test('attack → lunge / hit / slash', () {
      final cue = resolve(
        const BattleLogEntry(
          actorName: '自',
          actionType: BattleActionType.attack,
          damage: 12,
        ),
        isPlayerActor: true,
      );
      expect(cue.actorState, SpriteState.attack);
      expect(cue.targetState, SpriteState.hit);
      expect(cue.vfxKinds, [VfxKind.slash]);
      expect(cue.beatMs, 300);
    });

    test('skill && damage > 0 → cast / hit / flash+burst', () {
      final cue = resolve(
        const BattleLogEntry(
          actorName: '自',
          actionType: BattleActionType.skill,
          actionName: 'フレア',
          damage: 20,
        ),
        isPlayerActor: true,
      );
      expect(cue.actorState, SpriteState.cast);
      expect(cue.targetState, SpriteState.hit);
      expect(cue.vfxKinds, [VfxKind.flash, VfxKind.burst]);
      expect(cue.beatMs, 360);
    });

    test('skill && damage == 0 && healing > 0 → cast / heal / flash+sparkle',
        () {
      final cue = resolve(
        const BattleLogEntry(
          actorName: '自',
          actionType: BattleActionType.skill,
          actionName: 'ヒール',
          healing: 15,
        ),
        isPlayerActor: true,
      );
      expect(cue.actorState, SpriteState.cast);
      expect(cue.targetState, SpriteState.heal);
      expect(cue.vfxKinds, [VfxKind.flash, VfxKind.sparkle]);
      expect(cue.beatMs, 360);
    });

    test('skill && damage == 0 && healing == 0 → cast / flash+ring', () {
      final cue = resolve(
        const BattleLogEntry(
          actorName: '自',
          actionType: BattleActionType.skill,
          actionName: 'バリア',
        ),
        isPlayerActor: true,
      );
      expect(cue.actorState, SpriteState.cast);
      expect(cue.targetState, isNull);
      expect(cue.vfxKinds, [VfxKind.flash, VfxKind.ring]);
      expect(cue.beatMs, 360);
    });

    test('defend && healing > 0 → cast / heal / sparkle', () {
      final cue = resolve(
        const BattleLogEntry(
          actorName: '自',
          actionType: BattleActionType.defend,
          healing: 8,
        ),
        isPlayerActor: true,
      );
      expect(cue.actorState, SpriteState.cast);
      expect(cue.targetState, SpriteState.heal);
      expect(cue.vfxKinds, [VfxKind.sparkle]);
      expect(cue.beatMs, 300);
    });

    test('defend && healing == 0 → guard / ring', () {
      final cue = resolve(
        const BattleLogEntry(
          actorName: '自',
          actionType: BattleActionType.defend,
        ),
        isPlayerActor: true,
      );
      expect(cue.actorState, SpriteState.guard);
      expect(cue.targetState, isNull);
      expect(cue.vfxKinds, [VfxKind.ring]);
      expect(cue.beatMs, 300);
    });

    test('actionType == null → 演出なし', () {
      final cue = resolve(
        const BattleLogEntry(
          actorName: 'システム',
          message: '--- ターン 1 ---',
        ),
        isPlayerActor: false,
      );
      expect(cue.actorState, isNull);
      expect(cue.targetState, isNull);
      expect(cue.vfxKinds, isEmpty);
      expect(cue.beatMs, 0);
    });

    test('actionType == null && damage > 0 → hit のみ（継続ダメージ）', () {
      final cue = resolve(
        const BattleLogEntry(
          actorName: '自',
          damage: 5,
          message: '毒で 5 ダメージを受けた！',
        ),
        isPlayerActor: true,
      );
      expect(cue.actorState, isNull);
      expect(cue.targetState, SpriteState.hit);
      expect(cue.vfxKinds, isEmpty);
      expect(cue.beatMs, 0);
    });

    test('isCritical の attack は slash+crit', () {
      final cue = resolve(
        const BattleLogEntry(
          actorName: '自',
          actionType: BattleActionType.attack,
          damage: 30,
          isCritical: true,
        ),
        isPlayerActor: true,
      );
      expect(cue.vfxKinds, [VfxKind.slash, VfxKind.crit]);
      expect(cue.actorState, SpriteState.attack);
      expect(cue.targetState, SpriteState.hit);
    });

    test('isCritical の攻撃スキルは flash+burst+crit', () {
      final cue = resolve(
        const BattleLogEntry(
          actorName: '敵',
          actionType: BattleActionType.skill,
          damage: 40,
          isCritical: true,
        ),
        isPlayerActor: false,
      );
      expect(cue.vfxKinds, [VfxKind.flash, VfxKind.burst, VfxKind.crit]);
    });
  });

  test('scaleDurationMs は /speed、下限は 40%', () {
    expect(scaleDurationMs(300, 1.0), 300);
    expect(scaleDurationMs(300, 3.0), 120);
    expect(scaleDurationMs(0, 3.0), 0);
  });
}
