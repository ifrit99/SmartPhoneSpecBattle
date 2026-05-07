import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/enums/element_type.dart';
import 'package:spec_battle_game/domain/models/character.dart';
import 'package:spec_battle_game/domain/models/stats.dart';
import 'package:spec_battle_game/domain/services/battle_engine.dart';
import 'package:spec_battle_game/domain/services/battle_result_service.dart';
import 'package:spec_battle_game/domain/services/boss_bounty_service.dart';
import 'package:spec_battle_game/domain/services/daily_reward_service.dart';
import 'package:spec_battle_game/domain/services/enemy_generator.dart';
import 'package:spec_battle_game/domain/services/service_locator.dart';
import 'package:spec_battle_game/presentation/screens/result_screen.dart';

void main() {
  group('ResultScreen next actions', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService().resetForTest();
      await ServiceLocator().init();
      await LocalStorageService().resetForTest();
    });

    testWidgets('CPU対戦後に「もう一戦」をタップすると battle を返す', (tester) async {
      await _prepareStorage(firstBattleCompleted: false);
      final results = <String?>[];

      await _pumpResultLauncher(tester, results: results);
      await tester.ensureVisible(find.text('もう一戦'));
      await tester.tap(find.text('もう一戦'));
      await tester.pumpAndSettle();

      expect(results, ['battle']);
      expect(find.text('はじめてのバトル完了！'), findsNothing);
    });

    testWidgets('ガチャ可能な通貨がある場合は「ガチャ」導線で gacha を返す', (tester) async {
      await _prepareStorage(coins: 100);
      final results = <String?>[];

      await _pumpResultLauncher(tester, results: results);
      final gachaButton = find.widgetWithText(OutlinedButton, 'ガチャ');

      expect(find.text('シーズンポイント'), findsOneWidget);
      expect(find.text('+70 SP'), findsOneWidget);
      expect(gachaButton, findsOneWidget);

      await tester.ensureVisible(gachaButton);
      await tester.tap(gachaButton);
      await tester.pumpAndSettle();

      expect(results, ['gacha']);
    });

    testWidgets('CPU対戦以外では「もう一戦」を表示しない', (tester) async {
      await _prepareStorage();
      final results = <String?>[];

      await _pumpResultLauncher(
        tester,
        results: results,
        isCpuBattle: false,
      );

      expect(find.text('もう一戦'), findsNothing);
    });

    testWidgets('受け取り可能な実績がある場合は実績導線で achievements を返す', (tester) async {
      await _prepareStorage();
      final results = <String?>[];

      await _pumpResultLauncher(tester, results: results);

      expect(find.text('実績達成！'), findsOneWidget);
      expect(find.text('2件の報酬を受け取れます'), findsOneWidget);

      await tester.ensureVisible(find.text('開く'));
      await tester.tap(find.text('開く'));
      await tester.pumpAndSettle();

      expect(results, ['achievements']);
    });

    testWidgets('CPUのBOSS勝利時はBOSS撃破報酬を表示する', (tester) async {
      await _prepareStorage();
      final results = <String?>[];

      await _pumpResultLauncher(
        tester,
        results: results,
        enemyDifficulty: EnemyDifficulty.boss,
        enemyDeviceId: 'boss_01',
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('BOSS撃破報酬'), findsOneWidget);
      expect(
        find.text(
          '+${BossBountyService.dailyBossCoins} Coin / +${BossBountyService.dailyBossGems} Gems',
        ),
        findsOneWidget,
      );
      expect(find.text('BOSS最短更新'), findsOneWidget);
      expect(find.text('3ターン'), findsOneWidget);
    });

    testWidgets('未撃破の敵に勝利した場合は初回撃破ボーナスを表示する', (tester) async {
      await _prepareStorage();
      final results = <String?>[];

      await _pumpResultLauncher(
        tester,
        results: results,
        enemyDifficulty: EnemyDifficulty.hard,
        enemyDeviceId: 'hard_01',
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('初回撃破ボーナス'), findsOneWidget);
      expect(
        find.text(
          '+${BattleResultService.firstDefeatBonusCoins} Coin / +${BattleResultService.firstDefeatBonusGems} Gems',
        ),
        findsOneWidget,
      );
    });

    testWidgets('結果をコピーすると共有用サマリーがクリップボードに入る', (tester) async {
      await _prepareStorage();
      final results = <String?>[];
      String? clipboardText;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final data = call.arguments as Map<Object?, Object?>;
          clipboardText = data['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, Object?>{'text': clipboardText};
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await _pumpResultLauncher(
        tester,
        results: results,
        enemyDifficulty: EnemyDifficulty.boss,
        enemyDeviceId: 'boss_01',
      );
      await tester.pump(const Duration(seconds: 1));

      await tester.ensureVisible(find.text('結果をコピー'));
      await tester.tap(find.text('結果をコピー'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(clipboardText, contains('SPEC BATTLE'));
      expect(clipboardText, contains('勝利: Player vs Enemy'));
      expect(clipboardText, contains('シーズンポイント'));
      expect(clipboardText, contains('BOSS撃破報酬'));
      expect(clipboardText, contains('BOSS自己ベスト'));
      expect(find.text('バトル結果をコピーしました'), findsOneWidget);
    });

    testWidgets('デイリーミッション達成時はミッション導線で missions を返す', (tester) async {
      await _prepareStorage();
      final results = <String?>[];

      await _pumpResultLauncher(tester, results: results);

      expect(find.text('ミッション達成！'), findsOneWidget);
      expect(find.text('2件のデイリー報酬を受け取れます'), findsOneWidget);

      await tester.ensureVisible(find.text('受取へ'));
      await tester.tap(find.text('受取へ'));
      await tester.pumpAndSettle();

      expect(results, ['missions']);
    });
  });
}

Future<void> _prepareStorage({
  int coins = 0,
  int gems = 0,
  bool firstBattleCompleted = true,
}) async {
  final storage = LocalStorageService();
  await storage.saveCoins(coins);
  await storage.savePremiumGems(gems);
  await storage.setLastBattleRewardDate(DailyRewardService.todayString());
  if (firstBattleCompleted) {
    await storage.setFirstBattleCompleted();
  }
}

Future<void> _pumpResultLauncher(
  WidgetTester tester, {
  required List<String?> results,
  bool isCpuBattle = true,
  EnemyDifficulty enemyDifficulty = EnemyDifficulty.normal,
  String? enemyDeviceId,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final result = await Navigator.of(context).push<String?>(
              MaterialPageRoute(
                builder: (_) => ResultScreen(
                  result: const BattleResult(
                    playerWon: true,
                    turnsPlayed: 3,
                    expGained: 50,
                    finalPlayerHp: 80,
                    finalEnemyHp: 0,
                  ),
                  player: _character('Player'),
                  enemy: _character('Enemy'),
                  enemyDeviceId: enemyDeviceId ?? 'easy_01',
                  enemyDifficulty: enemyDifficulty,
                  isCpuBattle: isCpuBattle,
                ),
              ),
            );
            results.add(result);
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Character _character(String name) {
  const stats = Stats(hp: 100, maxHp: 100, atk: 20, def: 12, spd: 10);
  return Character(
    name: name,
    element: ElementType.fire,
    baseStats: stats,
    currentStats: stats,
    skills: const [],
  );
}
