# SPEC BATTLE (スペックバトル)

**あなたのスマホが最強の戦士になる！**

SPEC BATTLEは、スマートフォンのデバイススペック（OSバージョン、メモリ、ストレージ、バッテリー残量など）を解析し、その情報に基づいて世界に1体だけのキャラクターを生成して戦わせる、Flutter製の対戦RPGゲームです。

## 📱 ゲーム概要

お使いの端末のハードウェア情報がキャラクターのステータスや属性に直結します。
ハイスペックな端末ほど強くなるのか？ 古い端末には秘められた力があるのか？
あなたの愛機で最強を目指しましょう。

### スペック反映ロジック
- **OSバージョン**: キャラクターの「属性」を決定（例: 古いOSは炎、最新OSは光など）
- **CPUコア数**: 「攻撃力」に影響
- **RAM容量**: 「HP（体力）」に影響
- **ストレージ空き容量**: 「防御力」に影響
- **バッテリー残量**: 「素早さ」にリアルタイム反映（Phase 2実装予定）

## ✨ 主な機能

- **キャラクター生成**: デバイス情報からドット絵風キャラクターを自動生成
- **オートバトル**: 属性相性とスキルを駆使したターン制オートバトル
- **成長要素**: バトルで経験値を獲得し、レベルアップしてステータス強化
- **戦績記録**: 通算バトル数や勝率をローカルに保存
- **マルチプラットフォーム**: iOS / Android / Web で動作（レスポンシブ対応）

## 🛠 技術スタック

- **Framework**: Flutter 3.41.0 (Dart 3.11.0)
- **State Management**: `setState` + `AnimatedBuilder` (シンプル構成)
- **Local Storage**: `shared_preferences`
- **Device Info**: `device_info_plus` (Native), `package_info_plus`
- **Web Support**: 条件付きインポートによるプラットフォーム差分吸収

## 📂 ディレクトリ構成

```
lib/
├── data/           # データ層 (API, Local Storage)
├── domain/         # ドメイン層 (Model, Enum, Service)
├── presentation/   # プレゼンテーション層 (Screen, Widget)
└── main.dart       # エントリーポイント
```

## 🚀 始め方

1. リポジトリをクローン
```bash
git clone https://github.com/ifrit99/SmartPhoneSpecBattle.git
cd SmartPhoneSpecBattle/spec_battle_game
```

2. 依存パッケージのインストール
```bash
flutter pub get
```

3. アプリの実行
```bash
flutter run
```

## 📝 ライセンス

MIT License
