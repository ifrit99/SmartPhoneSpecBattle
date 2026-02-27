import 'package:flutter/material.dart';
import '../../domain/enums/element_type.dart';
import '../../domain/enums/rarity.dart';

/// アプリ全体で使用するカラー定数
class AppColors {
  AppColors._();

  static const background = Color(0xFF0D1B2A);
  static const cardBackground = Color(0xFF1B2838);
  static const primary = Color(0xFF6C5CE7);
  static const accent = Color(0xFF00B894);
  static const gold = Color(0xFFFFD700);
  static const premium = Color(0xFFE056FD);
}

/// 属性に対応するUIカラー
Color elementColor(ElementType type) {
  return switch (type) {
    ElementType.fire  => const Color(0xFFFF6B6B),
    ElementType.water => const Color(0xFF74B9FF),
    ElementType.earth => const Color(0xFFFDCB6E),
    ElementType.wind  => const Color(0xFF55EFC4),
    ElementType.light => const Color(0xFFFFF176),
    ElementType.dark  => const Color(0xFFAB47BC),
  };
}

/// レアリティに対応するUIカラー
Color rarityColor(Rarity rarity) {
  return switch (rarity) {
    Rarity.n   => Colors.grey,
    Rarity.r   => Colors.blueAccent,
    Rarity.sr  => const Color(0xFFFFD700),
    Rarity.ssr => const Color(0xFFE056FD),
  };
}
