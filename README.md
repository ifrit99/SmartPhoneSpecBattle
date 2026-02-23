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

## Docker環境での開発・検証
セキュリティの担保や独立した開発環境の構築を目的として、Docker環境を利用できます。

### 起動手順
DockerおよびDocker Composeがインストールされているローカル環境で、プロジェクトのルートディレクトリにて以下のコマンドを実行してください。

```bash
docker compose up -d --build
```

### コンテナ内での操作（静的解析・テスト）
コンテナが起動したら、以下のコマンドでコンテナ内に入り、Flutterのコマンドを実行できます。
※ ローカルマシンにて `objective_c` のビルドエラー等が発生する場合でも、分離されたLinux環境でテスト検証が可能です。

```bash
# コンテナ内でbashを起動
docker compose exec flutter-dev bash

# 以下はコンテナ内でのコマンド実行例
flutter analyze
flutter test
```

### 終了手順
作業が完了したら、コンテナを停止・削除します。
```bash
docker compose down
```