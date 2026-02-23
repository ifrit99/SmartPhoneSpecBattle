# アーキテクチャと設計方針

## 全体アーキテクチャ
ドメイン駆動設計(DDD)やClean Architectureの概念を軽量に取り入れた、**3層レイヤー構造**（`data`, `domain`, `presentation`）を採用。これにより、UIとビジネスロジック、外部API/デバイス機能へのアクセスを明確に分離している。

### ディレクトリ構成
- `lib/data/`: データ取得層
  - デバイス情報取得（`device_info_service.dart`）: Native/Webのプラットフォーム差分を吸収する条件付きインポートを利用。
  - ローカルストレージ管理（`local_storage_service.dart`）
  - サウンド再生制御（`sound_service.dart`）
- `lib/domain/`: ドメイン層（ビジネスロジックの中核）
  - **Models**: `character.dart` (キャラデータとステータス計算), `skill.dart`, `status_effect.dart` (バフ・デバフ), `experience.dart` (経験値・レベル計算)
  - **Enums**: `element_type.dart` (属性相性), `effect_type.dart` (状態異常の種類)
  - **Services**: `battle_engine.dart` (純粋なDartコードによる自動バトル計算ロジック。UI非依存), `character_generator.dart` (スペックからのキャラ生成), `enemy_generator.dart`
- `lib/presentation/`: プレゼンテーション層（UI）
  - **Screens**: 画面単位のWidget（`home_screen.dart`, `battle_screen.dart`, `result_screen.dart`等）
  - **Widgets**: 再利用可能なUIコンポーネント（`pixel_character.dart`, `stat_bar.dart`, `damage_popup.dart`, `skill_effect_overlay.dart`等）

## 状態管理とイベント駆動
サードパーティの大規模状態管理ライブラリ（RiverpodやProviderなど）は使用せず、Flutter標準の機能でシンプルに構成。
- **基本方針**: `StatefulWidget`の`setState`で画面全体の更新を管理。
- **アニメーション最適化**: ピクセルキャラクターのダメージ時の揺れ（Shake）など、高頻度で更新が必要な部分は`AnimatedBuilder`と`AnimationController`を使用して、リビルド範囲を最小限に抑えている。
- **データフロー**: `BattleScreen`では`BattleEngine`で事前計算された`BattleResult`（全ターンのログ配列）を受け取り、タイマー（`Future.delayed`等）を使って1エントリずつUIに順次反映させる「再生型」のイベント駆動を採用。

## Widgetの分割基準
1. **再利用性**: 複数の画面で使われる要素（HPバー=`stat_bar.dart`、キャラ画像=`pixel_character.dart`）は独立したWidgetとして切り出す。
2. **アニメーションの分離**: `damage_popup.dart`や`skill_effect_overlay.dart`など、自身で独立したアニメーションライフサイクル（フェードイン・アウト、移動）を持つ要素は、親の`setState`に巻き込まれないようStatefulWidgetとして分離。
3. **責務の単一化**: `BattleScreen`のような複雑な画面では、UIツリーの構築メソッド（`_buildBattleLog()`, `_buildActionButtons()`）とロジック（`_showNextLog()`, `_addDamagePopup()`）を適切にメソッド分割し、可読性を維持。
