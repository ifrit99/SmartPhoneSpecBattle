# SmartPhoneSpecBattle

## 概要 (What)
スマートフォンのデバイススペック（OSバージョン、メモリ、ストレージ、バッテリー残量など）を解析し、その情報に基づいて一意のステータスを持つキャラクターを生成して戦わせる、対戦型モバイルRPGゲーム。

## 目的とアプローチ (Why)
デバイスの不可視なスペック情報を可視化・キャラクター化することで、「自分のスマホがどんな強さを持つのか？」というユーザーの好奇心を刺激し、他者のデバイス（キャラクター）と競い合わせる新しい遊びを提供する。

## 技術スタック
- **Framework**: Flutter (SDK: >=3.0.0 <4.0.0)
- **Language**: Dart
- **Design System**: Material Design (標準)
- **Game Engine**: 未使用 (標準のFlutter Widget(`Container`, `AnimatedBuilder`等)でリッチなUIとアニメーションを実装)

### 主要パッケージ (Dependencies)
- `shared_preferences` (^2.2.0): キャラクターデータや設定、対戦履歴のローカル永続化
- `battery_plus` (^7.0.0): デバイスのバッテリー残量をリアルタイム取得し、バトル中のキャラクターステータス（素早さ等）に動的反映
- `audioplayers` (^6.1.0): バトル開始時や攻撃・スキル発動時などの効果音（BGM/SE）の再生制御
- `cupertino_icons` (^1.0.8): iOSスタイルの汎用アイコン群