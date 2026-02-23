import '../enums/effect_type.dart';

/// バフ・デバフなどのステータス効果
class StatusEffect {
  final String id;
  final EffectType type;
  final int duration; // 残りターン数
  final int value;    // 効果量（％または固定値）
  final bool isPermanent; // 永続かどうか

  const StatusEffect({
    required this.id,
    required this.type,
    required this.duration,
    required this.value,
    this.isPermanent = false,
  });

  /// 残りターン数を減らした新しいインスタンスを返す
  StatusEffect decreaseDuration() {
    if (isPermanent) return this;
    return StatusEffect(
      id: id,
      type: type,
      duration: duration - 1,
      value: value,
      isPermanent: isPermanent,
    );
  }

  /// 効果の説明テキスト
  String get description {
    final sign = value >= 0 ? '+' : '';
    return '${type.label} $sign$value% ($durationターン)';
  }
}
