import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/data/local_storage_service.dart';

/// 1操作に対する失敗注入。戻し（`_restoreSnapshot`）の書き込みでは投げない。
class FaultInjection {
  const FaultInjection({
    required this.shouldThrow,
    required this.throwOnCoins,
  });

  /// その操作の保存で投げるか（保存しない行では実際には起きない）。
  final bool shouldThrow;

  /// true ならコイン書き込み、false ならジェム書き込みで投げる。
  final bool throwOnCoins;
}

class _OpContext {
  _OpContext(this.injection, this.delayRandom);

  final FaultInjection injection;
  final Random delayRandom;
  bool hasThrown = false;
}

/// キャッシュを先に書き、そのあと `await` で投げることがある偽ストレージ。
///
/// `test/domain/currency_test.dart` の `_ThrowAfterCacheStorage` と同じ形。
/// 操作との対応は [runOp] の Zone で持つ（直列実行でも重なり実行でも書き込み元がずれない）。
class FaultInjectingStorage extends Fake implements LocalStorageService {
  FaultInjectingStorage({
    required this.coins,
    required this.gems,
  });

  static const Object _zoneKey = #faultInjectingOp;

  int coins;
  int gems;
  int throwCount = 0;

  /// [body] 内の書き込みを [injection] に紐づける。
  static Future<T> runOp<T>({
    required FaultInjection injection,
    required Random delayRandom,
    required Future<T> Function() body,
  }) {
    return runZoned(
      body,
      zoneValues: {_zoneKey: _OpContext(injection, delayRandom)},
    );
  }

  _OpContext? get _op => Zone.current[_zoneKey] as _OpContext?;

  @override
  Future<void> saveCoins(int value) async {
    coins = value;
    await _delay();
    _maybeThrow(onCoins: true);
  }

  @override
  Future<void> savePremiumGems(int value) async {
    gems = value;
    await _delay();
    _maybeThrow(onCoins: false);
  }

  @override
  int getCoins() => coins;

  @override
  int getPremiumGems() => gems;

  Future<void> _delay() async {
    final op = _op;
    if (op == null) return;
    final n = op.delayRandom.nextInt(4);
    for (var i = 0; i < n; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void _maybeThrow({required bool onCoins}) {
    final op = _op;
    if (op == null || op.hasThrown || !op.injection.shouldThrow) {
      return;
    }
    if (op.injection.throwOnCoins != onCoins) {
      return;
    }
    op.hasThrown = true;
    throwCount++;
    throw StateError('platform write failed');
  }
}
