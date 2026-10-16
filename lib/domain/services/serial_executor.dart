import 'dart:async';

/// 同一インスタンス上の非同期処理を1本のチェーンに直列化する。
class SerialExecutor {
  Future<void>? _chain;

  Future<T> run<T>(Future<T> Function() action) async {
    final previous = _chain;
    final completer = Completer<void>();
    _chain = completer.future;
    try {
      if (previous != null) {
        await previous;
      }
      return await action();
    } finally {
      completer.complete();
      // 完了済み Future を次のテストゾーンから await すると widget test が止まる。
      if (identical(_chain, completer.future)) {
        _chain = null;
      }
    }
  }
}
