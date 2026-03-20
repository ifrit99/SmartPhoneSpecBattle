import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spec_battle_game/data/local_storage_service.dart';
import 'package:spec_battle_game/domain/services/service_locator.dart';
import 'package:spec_battle_game/presentation/screens/home_screen.dart';
import 'package:spec_battle_game/presentation/screens/onboarding_screen.dart';
import 'package:spec_battle_game/presentation/widgets/first_battle_complete_dialog.dart';

/// 画面遷移を記録するNavigatorObserver
class _TestNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> replacedRoutes = [];

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) replacedRoutes.add(newRoute);
  }
}

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

    testWidgets('「スキップ」タップでフラグ保存とHomeScreenへの遷移が行われる', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService().resetForTest();
      await ServiceLocator().init();

      final observer = _TestNavigatorObserver();

      await tester.pumpWidget(
        MaterialApp(
          home: const OnboardingScreen(),
          navigatorObservers: [observer],
        ),
      );

      // フラグが未設定であることを確認
      expect(LocalStorageService().isOnboardingCompleted(), isFalse);

      // スキップをタップ
      await tester.tap(find.text('スキップ'));
      await tester.pump(); // 遷移開始（HomeScreenのアニメーションがrepeatのためpumpAndSettleは不可）
      await tester.pump(const Duration(milliseconds: 500)); // FadeTransition完了

      // フラグが保存されたことを確認
      expect(LocalStorageService().isOnboardingCompleted(), isTrue);

      // HomeScreenへの遷移が行われたことを確認
      expect(observer.replacedRoutes.length, 1);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('「はじめる！」タップでフラグ保存とHomeScreenへの遷移が行われる', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorageService().resetForTest();
      await ServiceLocator().init();

      final observer = _TestNavigatorObserver();

      await tester.pumpWidget(
        MaterialApp(
          home: const OnboardingScreen(),
          navigatorObservers: [observer],
        ),
      );

      // 3ページ目まで進む
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      // フラグが未設定であることを確認
      expect(LocalStorageService().isOnboardingCompleted(), isFalse);

      // 「はじめる！」をタップ
      await tester.tap(find.text('はじめる！'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // フラグが保存されたことを確認
      expect(LocalStorageService().isOnboardingCompleted(), isTrue);

      // HomeScreenへの遷移が行われたことを確認
      expect(observer.replacedRoutes.length, 1);
      expect(find.byType(HomeScreen), findsOneWidget);
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
