import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:spec_battle_game/domain/models/player_currency.dart';
import 'package:spec_battle_game/domain/services/currency_service.dart';

import 'support/fault_injecting_storage.dart';

/// 通貨のシード固定プロパティテスト。
///
/// 期待値は本体を写さず、`docs/plans/verification-adoption.md` の参照モデル表だけで決める。
void main() {
  test('シード 0〜199 で参照モデルと一致する', () async {
    for (var seed = 0; seed <= 199; seed++) {
      await _assertSeed(seed);
    }
  });

  // 0〜30 を一様に引くと addReward(0,0)+注入は 200 シードではほぼ出ない。
  // 計画の「保存しない行では注入は起きない」と、早期 return を外すと 4 が落ちることをここで見る。
  test('addReward(0,0) は保存しないので注入も起きない', () async {
    await _assertScenario(
      label: 'addReward(0,0)+inject',
      delaySeed: 1000,
      startCoins: 10,
      startGems: 10,
      ops: const [
        _PlannedOp(
          kind: _OpKind.addReward,
          a: 0,
          b: 0,
          injection: FaultInjection(shouldThrow: true, throwOnCoins: true),
        ),
        _PlannedOp(
          kind: _OpKind.addCoins,
          a: 5,
          b: 0,
          injection: FaultInjection(shouldThrow: false, throwOnCoins: true),
        ),
        _PlannedOp(
          kind: _OpKind.spendGems,
          a: 3,
          b: 0,
          injection: FaultInjection(shouldThrow: true, throwOnCoins: false),
        ),
      ],
    );
  });
}

enum _OpKind {
  addCoins,
  spendCoins,
  addGems,
  spendGems,
  addReward,
  exchange,
}

enum _ResultKind { success, nil, exception }

class _PlannedOp {
  const _PlannedOp({
    required this.kind,
    required this.a,
    required this.b,
    required this.injection,
  });

  final _OpKind kind;
  final int a;
  final int b;
  final FaultInjection injection;

  String describe() {
    final inject = injection.shouldThrow
        ? ', inject=${injection.throwOnCoins ? 'coins' : 'gems'}'
        : '';
    return switch (kind) {
      _OpKind.addCoins => 'addCoins($a$inject)',
      _OpKind.spendCoins => 'spendCoins($a$inject)',
      _OpKind.addGems => 'addGems($a$inject)',
      _OpKind.spendGems => 'spendGems($a$inject)',
      _OpKind.addReward => 'addReward($a,$b$inject)',
      _OpKind.exchange => 'exchange($a→$b$inject)',
    };
  }
}

class _Expected {
  const _Expected({
    required this.kind,
    required this.coins,
    required this.gems,
    required this.injectedSave,
  });

  final _ResultKind kind;
  final int coins;
  final int gems;
  final bool injectedSave;
}

class _Observed {
  const _Observed({required this.kind, this.value});

  final _ResultKind kind;
  final PlayerCurrency? value;
}

class _Model {
  _Model(this.coins, this.gems);

  int coins;
  int gems;
  final List<_Expected> steps = [];

  int get injectedSaveCount => steps.where((step) => step.injectedSave).length;

  void apply(_PlannedOp op) {
    switch (op.kind) {
      case _OpKind.addCoins:
        _applyAdd(op, coinsSetter: (n) => coins += n);
      case _OpKind.addGems:
        _applyAdd(op, coinsSetter: (n) => gems += n);
      case _OpKind.spendCoins:
        _applySpend(op, balance: coins, setter: (n) => coins -= n);
      case _OpKind.spendGems:
        _applySpend(op, balance: gems, setter: (n) => gems -= n);
      case _OpKind.addReward:
        if (op.a == 0 && op.b == 0) {
          _record(_ResultKind.success, injectedSave: false);
          return;
        }
        if (op.injection.shouldThrow) {
          _record(_ResultKind.exception, injectedSave: true);
          return;
        }
        coins += op.a;
        gems += op.b;
        _record(_ResultKind.success, injectedSave: false);
      case _OpKind.exchange:
        if (coins < op.a) {
          _record(_ResultKind.nil, injectedSave: false);
          return;
        }
        if (op.injection.shouldThrow) {
          _record(_ResultKind.exception, injectedSave: true);
          return;
        }
        coins -= op.a;
        gems += op.b;
        _record(_ResultKind.success, injectedSave: false);
    }
  }

  void _applyAdd(_PlannedOp op, {required void Function(int n) coinsSetter}) {
    if (op.injection.shouldThrow) {
      _record(_ResultKind.exception, injectedSave: true);
      return;
    }
    coinsSetter(op.a);
    _record(_ResultKind.success, injectedSave: false);
  }

  void _applySpend(
    _PlannedOp op, {
    required int balance,
    required void Function(int n) setter,
  }) {
    if (balance < op.a) {
      _record(_ResultKind.nil, injectedSave: false);
      return;
    }
    if (op.injection.shouldThrow) {
      _record(_ResultKind.exception, injectedSave: true);
      return;
    }
    setter(op.a);
    _record(_ResultKind.success, injectedSave: false);
  }

  void _record(_ResultKind kind, {required bool injectedSave}) {
    if (coins < 0 || gems < 0) {
      throw StateError('参照モデルの残高が負: coins=$coins gems=$gems');
    }
    steps.add(
      _Expected(
        kind: kind,
        coins: coins,
        gems: gems,
        injectedSave: injectedSave,
      ),
    );
  }
}

List<_PlannedOp> _generateOps(Random rng) {
  final count = 3 + rng.nextInt(6);
  return [
    for (var i = 0; i < count; i++) _generateOp(rng),
  ];
}

_PlannedOp _generateOp(Random rng) {
  final kind = _OpKind.values[rng.nextInt(_OpKind.values.length)];
  final a = rng.nextInt(31);
  final needsB = kind == _OpKind.addReward || kind == _OpKind.exchange;
  final b = needsB ? rng.nextInt(31) : 0;
  return _PlannedOp(
    kind: kind,
    a: a,
    b: b,
    injection: FaultInjection(
      shouldThrow: rng.nextDouble() < 0.2,
      throwOnCoins: rng.nextBool(),
    ),
  );
}

Future<void> _assertSeed(int seed) async {
  final rng = Random(seed);
  await _assertScenario(
    label: 'seed=$seed',
    delaySeed: seed,
    startCoins: rng.nextInt(51),
    startGems: rng.nextInt(51),
    ops: _generateOps(rng),
  );
}

Future<void> _assertScenario({
  required String label,
  required int delaySeed,
  required int startCoins,
  required int startGems,
  required List<_PlannedOp> ops,
}) async {
  final model = _Model(startCoins, startGems);
  for (final op in ops) {
    model.apply(op);
  }

  final storage = FaultInjectingStorage(coins: startCoins, gems: startGems);
  final service = CurrencyService(storage);

  final running = <Future<_Observed>>[
    for (var i = 0; i < ops.length; i++)
      _runObserved(
        delaySeed: delaySeed,
        index: i,
        op: ops[i],
        service: service,
      ),
  ];
  final observed = await Future.wait(running);

  var firstDiff = -1;
  String? reason;
  for (var i = 0; i < ops.length; i++) {
    final want = model.steps[i];
    final got = observed[i];
    if (got.kind != want.kind) {
      firstDiff = i;
      reason = '結果の種類: expected ${want.kind.name}, actual ${got.kind.name}';
      break;
    }
    if (got.kind == _ResultKind.success) {
      final value = got.value!;
      if (value.coins != want.coins || value.premiumGems != want.gems) {
        firstDiff = i;
        reason = '成功時の残高: expected (${want.coins}, ${want.gems}), '
            'actual (${value.coins}, ${value.premiumGems})';
        break;
      }
      if (value.coins < 0 || value.premiumGems < 0) {
        firstDiff = i;
        reason = '成功時の残高が負: (${value.coins}, ${value.premiumGems})';
        break;
      }
    }
  }

  final loaded = service.load();
  if (firstDiff < 0) {
    if (loaded.coins != model.coins || loaded.premiumGems != model.gems) {
      firstDiff = ops.length;
      reason = '最終 load(): expected (${model.coins}, ${model.gems}), '
          'actual (${loaded.coins}, ${loaded.premiumGems})';
    } else if (storage.throwCount != model.injectedSaveCount) {
      firstDiff = ops.length;
      reason = '注入で投げた回数: expected ${model.injectedSaveCount}, '
          'actual ${storage.throwCount}';
    } else if (loaded.coins < 0 || loaded.premiumGems < 0) {
      firstDiff = ops.length;
      reason = '最終残高が負: (${loaded.coins}, ${loaded.premiumGems})';
    }
  }

  if (firstDiff >= 0) {
    fail(
      '$label firstDiff=$firstDiff $reason\n'
      'throws expected ${model.injectedSaveCount} actual ${storage.throwCount}\n'
      'ops=${ops.map((op) => op.describe()).join(', ')}',
    );
  }
}

Future<_Observed> _runObserved({
  required int delaySeed,
  required int index,
  required _PlannedOp op,
  required CurrencyService service,
}) {
  return FaultInjectingStorage.runOp(
    injection: op.injection,
    delayRandom: Random(delaySeed * 10007 + index * 17 + 1),
    body: () async {
      try {
        final value = await _dispatch(service, op);
        if (value == null) {
          return const _Observed(kind: _ResultKind.nil);
        }
        return _Observed(kind: _ResultKind.success, value: value);
      } catch (_) {
        return const _Observed(kind: _ResultKind.exception);
      }
    },
  );
}

Future<PlayerCurrency?> _dispatch(CurrencyService service, _PlannedOp op) {
  return switch (op.kind) {
    _OpKind.addCoins => service.addCoins(op.a),
    _OpKind.spendCoins => service.spendCoins(op.a),
    _OpKind.addGems => service.addGems(op.a),
    _OpKind.spendGems => service.spendGems(op.a),
    _OpKind.addReward => service.addReward(coins: op.a, gems: op.b),
    _OpKind.exchange => service.exchangeCoinsForGems(coins: op.a, gems: op.b),
  };
}
