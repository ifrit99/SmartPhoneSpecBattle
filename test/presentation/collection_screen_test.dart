import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/service_locator.dart';
import 'package:spec_battle_game/presentation/screens/collection_screen.dart';

void main() {
  group('CollectionScreen rank', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService().resetForTest();
      await ServiceLocator().init();
      await LocalStorageService().resetForTest();
    });

    testWidgets('プレイヤー履歴にランク進捗を表示する', (tester) async {
      final storage = LocalStorageService();
      for (var i = 0; i < 8; i++) {
        await storage.incrementBattleCount();
      }
      for (var i = 0; i < 5; i++) {
        await storage.incrementWinCount();
      }
      await storage.saveDefeatedEnemy('easy_01');
      await storage.saveDefeatedEnemy('normal_01');

      await tester.pumpWidget(
        const MaterialApp(
          home: CollectionScreen(initialTabIndex: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('スペックハンター'), findsWidgets);
      expect(find.textContaining('RP'), findsWidgets);
      expect(find.textContaining('次:'), findsOneWidget);
      expect(find.text('勝利 5'), findsOneWidget);
      expect(find.text('発見 2種'), findsOneWidget);
      expect(find.text('ランク到達報酬'), findsOneWidget);
      expect(find.textContaining('スペックハンター +300 Coin'), findsOneWidget);
      expect(find.text('ローカルリーグ'), findsOneWidget);
      expect(find.text('YOU'), findsOneWidget);
      expect(find.textContaining('次の相手:'), findsOneWidget);
    });

    testWidgets('到達済みランク報酬を受け取れる', (tester) async {
      final storage = LocalStorageService();
      for (var i = 0; i < 8; i++) {
        await storage.incrementBattleCount();
      }
      for (var i = 0; i < 5; i++) {
        await storage.incrementWinCount();
      }
      await storage.saveDefeatedEnemy('easy_01');
      await storage.saveDefeatedEnemy('normal_01');

      await tester.pumpWidget(
        const MaterialApp(
          home: CollectionScreen(initialTabIndex: 1),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('1件受取'));
      await tester.tap(find.text('1件受取'));
      await tester.pumpAndSettle();

      expect(storage.getCoins(), 300);
      expect(storage.getPremiumGems(), 10);
      expect(storage.getClaimedRankRewards(), ['hunter']);
      expect(
          find.textContaining('300 Coin / 10 Gems を受け取りました'), findsOneWidget);
    });
  });
}
