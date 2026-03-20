import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/presentation/screens/onboarding_screen.dart';
import 'package:spec_battle_game/presentation/widgets/first_battle_complete_dialog.dart';

void main() {
  group('LocalStorageService - オンボーディングフラグ', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService().resetForTest();
    });

    test('初期状態ではオンボーディング未完了', () {
      expect(LocalStorageService().isOnboardingCompleted(), isFalse);
    });

    test('setOnboardingCompleted 後は完了状態になる', () async {
      await LocalStorageService().setOnboardingCompleted();
      expect(LocalStorageService().isOnboardingCompleted(), isTrue);
    });

    test('初期状態では初回バトル未完了', () {
      expect(LocalStorageService().isFirstBattleCompleted(), isFalse);
    });

    test('setFirstBattleCompleted 後は完了状態になる', () async {
      await LocalStorageService().setFirstBattleCompleted();
      expect(LocalStorageService().isFirstBattleCompleted(), isTrue);
    });

    test('clearAll でフラグがリセットされる', () async {
      await LocalStorageService().setOnboardingCompleted();
      await LocalStorageService().setFirstBattleCompleted();
      await LocalStorageService().clearAll();
      expect(LocalStorageService().isOnboardingCompleted(), isFalse);
      expect(LocalStorageService().isFirstBattleCompleted(), isFalse);
    });
  });

  group('OnboardingScreen', () {
    testWidgets('3ページのガイドが表示される', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService().resetForTest();

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      // 1ページ目が表示されている
      expect(find.text('あなたのスマホが\nキャラクターに！'), findsOneWidget);
      expect(find.text('次へ'), findsOneWidget);
      expect(find.text('スキップ'), findsOneWidget);
    });

    testWidgets('「次へ」で2ページ目に遷移する', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService().resetForTest();

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      // 1ページ目を確認
      expect(find.text('あなたのスマホが\nキャラクターに！'), findsOneWidget);

      // 「次へ」をタップ
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      // 2ページ目が表示される
      expect(find.text('スペックが\n能力値に変わる'), findsOneWidget);
    });

    testWidgets('3ページ目では「はじめる！」ボタンが表示される', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService().resetForTest();

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      // 1ページ目→2ページ目
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      // 2ページ目→3ページ目
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      // 3ページ目のテキストとボタンを確認
      expect(find.text('まずは1回\nバトルしてみよう！'), findsOneWidget);
      expect(find.text('はじめる！'), findsOneWidget);
    });

    testWidgets('「スキップ」タップでスキップボタンが存在し動作する', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService().resetForTest();

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      // 1ページ目でスキップボタンが表示されている
      final skipButton = find.text('スキップ');
      expect(skipButton, findsOneWidget);

      // スキップボタンはタップ可能（onPressed != null）
      final textButton = tester.widget<TextButton>(
        find.ancestor(of: skipButton, matching: find.byType(TextButton)),
      );
      expect(textButton.onPressed, isNotNull);
    });

    testWidgets('2ページ目でもスキップボタンが表示される', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService().resetForTest();

      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      // 2ページ目でもスキップボタンが存在する
      expect(find.text('スキップ'), findsOneWidget);
    });
  });

  group('FirstBattleCompleteDialog', () {
    testWidgets('ダイアログに必要な要素が表示される', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => FirstBattleCompleteDialog.show(context),
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('はじめてのバトル完了！'), findsOneWidget);
      expect(find.text('次はこんなことができます'), findsOneWidget);
      expect(find.text('ガチャを引く'), findsOneWidget);
      expect(find.text('フレンドに共有'), findsOneWidget);
      expect(find.text('あとで'), findsOneWidget);
    });

    testWidgets('ガチャをタップすると "gacha" を返す', (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await FirstBattleCompleteDialog.show(context);
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ガチャを引く'));
      await tester.pumpAndSettle();

      expect(result, equals('gacha'));
    });

    testWidgets('フレンドに共有をタップすると "friend" を返す', (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await FirstBattleCompleteDialog.show(context);
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('フレンドに共有'));
      await tester.pumpAndSettle();

      expect(result, equals('friend'));
    });

    testWidgets('「あとで」をタップすると null を返す', (tester) async {
      String? result = 'not-null';

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await FirstBattleCompleteDialog.show(context);
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('あとで'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}
