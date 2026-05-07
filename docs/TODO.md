# SPEC BATTLE — TODO

バージョン: 0.1.0
最終更新: 2026-05-05

---

## 🤖 現在の作業状態 (2026-05-05)
- **直近の実装**:
  - 初回オンボーディング・初回バトル後案内をmasterへマージ（PR #9）
  - CLAUDE.md/CONTEXT.md最適化・AGENTS.md追加・product_spec.md整備（PR #10）
  - 共有URL生成修正（`Uri.base` ベース化 + query/fragment除去）（PR #11）
  - デイリーログイン報酬・バトル報酬機能の追加（PR #12）
    - 日付跨ぎ復帰時の再判定、ホーム前面時のみポップアップ表示（保留キュー）、バトル報酬はCPU対戦のみ付与
  - 実在デバイス名を架空ブランド名に置き換え（PR #13）
  - Codexレビュー指摘対応（`fix/review-followups` ブランチ、未マージ・未プッシュ）
    - BattleEngineに50ターン到達時の勝敗判定ロジックを追加
    - BattleResultServiceを新設しResultScreenから経験値・コイン・図鑑・報酬反映を分離
    - QrBattleService.normalizeBattleInput 公開・URL/生コード正規化をドメイン層へ移動
    - テスト+8件、Planner/Generator/Evaluator ワークフロー用テンプレートを `docs/plans/TEMPLATES.md` に追加
    - プレミアム解析ガチャを追加
      - デイリー報酬で獲得するジェムの消費先として、20ジェム/SR以上確定の単発ガチャを追加
      - SSR抽選時に日替わりピックアップSSRが60%で出現する仕組みを追加
      - ピックアップSSRを5回連続で外すと次回確定になる天井を追加
      - ガチャ画面でコインとジェムを同時表示し、不足時メッセージを通貨別に表示
      - ガチャ結果から単発キャラ/10連おすすめキャラを直接装備できる導線を追加
      - 同一レアリティ・同一端末の重複入手を覚醒に変換し、基礎ステータスを最大+5まで強化
  - 編成・インベントリ画面を強化
    - ロスター分析、レアリティフィルタ、Power表示、EXP進捗付き詳細シート、空状態のガチャ導線を追加
  - ホーム画面に次アクションカードを追加
    - バトル報酬、プレミアム解析、編成、ガチャ、図鑑、フレンド対戦から状況に応じた導線を提示
  - CPU敵プレビューの戦術選択を改善
    - バトル解析の推奨戦術を初期選択し、確認なしに推奨と異なる戦術で始まる不一致を解消
  - URL共有画面を強化
    - 共有対象キャラカードを表示し、友達へ送る前にどのキャラのURLか確認可能にした
  - URL受け取り側の導線を強化
    - URL入力画面に貼り付け/読み取り状態を追加し、ゲストプレビューで自分vs相手・相性分析・戦術選択を表示
    - 推奨戦術を初期選択し、フレンド対戦開始時に実際のBattleScreenへ反映
  - バトル画面に再生速度切替を追加
    - 周回時にログ/スキル演出のテンポを `x1 / x1.5 / x2 / x3` で変更可能
    - 敵キャラとBGM/SEボタンの重なりを解消
  - バトル開始時の支援コマンドを追加
    - 支援なし/攻撃支援/防御支援を選択でき、選択内容をBattleEngineの計算とログへ反映
  - Web音声アンロックの失敗時フォールバックを追加
    - 初回タップ時に音声再生が失敗/タイムアウトしてもタイトル画面の進行を止めない
  - リザルト画面に次アクション導線を追加
    - CPU対戦後に「もう一戦」で敵プレビューへ直行、通貨が足りる場合は「ガチャ」へ直行可能
  - デイリーミッションを追加
    - バトル1回、勝利1回、ガチャ1回の進捗を日次リセットで記録し、ホームからコイン/ジェム報酬を個別/一括で受け取れる
    - バトルリザルトから達成済みミッションを通知し、受け取り導線を提示
  - BOSS撃破報酬を追加
    - CPU BOSS勝利時に1日1回だけ+300 Coin / +30 Gemsを自動付与し、高難度挑戦の目的を強化
  - 週次チャレンジを追加
    - CPUのHARD/BOSS勝利を週3回達成すると+600 Coin / +50 Gemsを受け取れる継続目標を追加
  - 週替わり期間イベントを追加
    - CPU勝利を5回積み上げるとイベント別のCoin/Gems報酬を受け取れる継続目標を追加
  - BOSSタイムアタック自己ベストを追加
    - CPU BOSS勝利時の最短ターンを保存し、リザルト・ホーム・履歴で記録更新を確認可能にした
  - リザルト共有テキストコピーを追加
    - 勝敗、ターン、戦術、獲得報酬、BOSS記録をまとめてコピーできる導線を追加
  - 遊び方ヘルプ画面を追加
    - 戦術、支援コマンド、報酬、イベント、フレンド対戦をホームから見返せるようにした
  - 直近バトル履歴を追加
    - CPU/フレンド対戦の勝敗、相手、難易度、戦術、支援、獲得報酬を直近20件まで保存し、コレクション画面とバックアップ復元で見返せるようにした
  - シーズンパス進行トラックを追加
    - バトルごとにシーズンポイントを蓄積し、月替わりの報酬トラックからCoin/Gemsを受け取れる継続目標を追加
  - 期間限定イベント解析ガチャを追加
    - 30 Gems/SR以上確定で、週替わり限定SSRを狙えるイベント専用解析と3回外し後の限定SSR天井を追加
  - 経済バランスの回帰基準を追加
    - 初回セッション、通常CPU周回、7日継続、週替わりイベント、週次チャレンジ、シーズンパス完走の報酬ラインをテストで固定
  - データ保護画面の復元UXを改善
    - 復元コード未入力時は復元ボタンを無効化し、入力後に読み取り準備完了をインライン表示
  - ガチャ画面の通貨不足エラーを改善
    - コイン/ジェム不足時に不足量と入手導線をスナックバーで表示
  - コレクション画面にローカルランクを追加
    - 勝利数、敵発見数、ロスター、限定端末、BOSS最短をランクポイント化し、次ランクまでの進捗を表示
  - コレクション画面にローカルリーグを追加
    - 固定ライバルとの週次順位表を表示し、次に抜く相手と必要RPを提示
  - ホーム画面に解析ロードマップを追加
    - 限定SSR/日替わりSSRの天井までに必要なGems、所持Gemsからの不足量、優先ターゲットを表示
  - 週替わりイベントに専用ライバル戦を追加
    - イベントカードから今週のライバルに直接挑戦でき、勝利時はイベント進捗を2勝分進める
  - 週替わりイベントに段階報酬を追加
    - 2勝/4勝の途中報酬をホームから受け取れるようにし、イベント完走前にも報酬が返る
  - ローカルランクに到達報酬を追加
    - スペックハンター以上の各ランク到達時にCoin/Gemsを一度だけ受け取れる
  - ロスター収集ボーナスを追加
    - 端末種、SSR、限定端末、覚醒合計に応じてCPU戦のCoin報酬倍率が上がり、編成画面で進捗を確認できる
  - 日替わりショップを追加
    - 1日1回ずつ、Coinで装備キャラEXP、Battery回復、Gems交換を購入できる育成/通貨シンクをホームに追加
  - ライバルロードを追加
    - 固定ライバル5戦を順番に突破する常設PvE進行と一度きりのCoin/Gems報酬をホームに追加
    - クリア段階をローカルランクポイントと専用実績へ反映
    - ステージ別の最短ターンを保存し、再戦時の記録更新をリザルト/履歴/ホームで表示
- **次に取り組むべきタスク**:
  - `fix/review-followups` のコミット整形 → プッシュ → PR作成 → Codexレビュー → マージ
  - GitHub Pages デプロイの確認
  - デプロイ後の最終動作確認（OGPプレビュー、URL対戦フロー、ログイン報酬/バトル報酬）

---

## 状態サマリー
- **完了済み**:
  - Phase 1 MVP (ドメインモデル、各種画面UI、バトルエンジン本実装)
  - Phase 2 (各種UX演出：ダメージポップアップ、クリティカル、バッテリー連携によるSPD補正、効果音)
  - Phase 3-1 (CPU敵キャラ自動生成: `enemy_generator.dart`)
  - Phase 3-2 (キャラクター図鑑・対戦履歴: `CollectionScreen`)
  - Phase 3-3 (タイトル画面: `title_screen.dart`)
  - セキュリティ強化・環境分離のためのDocker開発環境（Dockerfile, docker-compose.yml等）の構築
  - 重大なバグ修正、及びユニットテスト群の追加
  - Phase 4-1 エミュレートガチャ（ガチャロジック・UI・ブラウザテスト）
  - Phase 4-2 QR/URL対戦 ロジック層（チェックサム検証・QrBattleService・テスト）
  - **Phase 4-2 Web MVP対応**（QR→URL共有専用に改修、`flutter build web` 通過）
  - Web版SE再生の安定化（HTML5 Audio API直接使用 → document.createElement方式）
  - BGM/SE個別ミュート機能
  - Web版バッテリーゲージ削除（Web環境では不要のため除去）
  - 初回オンボーディング・初回バトル後案内（PR #9）
  - 共有URL生成修正（PR #11）
  - デイリーログイン報酬・バトル報酬機能（PR #12）
  - 実在デバイス名を架空ブランド名に置き換え（PR #13）
  - CLAUDE.md/AGENTS.md整備、product_spec.md追加（PR #10）
- **進行中**:
  - Codexレビュー指摘対応（`fix/review-followups`：50ターン決着ロジック・BattleResultService分離・テスト拡充・ドキュメント整備）— プッシュ/PR作成待ち
- **現在の位置づけ**: **Web版MVPリリース直前**。`fix/review-followups` のマージ → デプロイ確認が残タスク。

---

## Web MVP 残タスク

### ✅ 完了: ビルド基盤 + UI改修（`feature/web-mvp` ブランチ）

| 項目 | 状態 |
|------|------|
| `flutter build web` 通過 | ✅ |
| `flutter analyze` エラー0 | ✅ |
| `flutter test` 全140件パス | ✅ |
| QRスキャン画面 → URL入力画面（`UrlInputScreen`）に改修 | ✅ |
| QR表示画面 → URL共有画面（`ShareScreen`）に改修 | ✅ |
| QRメニュー → フレンド対戦メニュー（`FriendBattleMenuScreen`）に改修 | ✅ |
| ゲストプレビュー画面の `UnimplementedError` 解消 | ✅ |
| `main.dart` で `Uri.base` パースによるURL起動対戦対応 | ✅ |
| `ServiceLocator` に `qrBattleService` 登録 | ✅ |
| ホーム画面に「Friend」ボタン追加 | ✅ |
| 不要パッケージ除去（`qr_flutter`, `mobile_scanner`, `share_plus`, `app_links`） | ✅ |

### ✅ 完了: ブラウザ結合テスト

- [x] `flutter run -d chrome` で全画面フローを確認
  - タイトル → ホーム → Friend → URLシェア → URL入力 → プレビュー → バトル
  - `?battle=<encoded>` 付きURLで直接開いて対戦遷移するか確認（Base64 padding問題修正済・確認済）
- [x] audioplayers のWeb動作確認（BGM・SE再生）
  - Web AutoPlayポリシー対応: `unlockAudio()` メカニズム追加、タイトルBGM自動再生を条件分岐
  - `flutter build web` でサウンドアセット9種の正常バンドルを確認済み
- [x] バグ修正（AutoPlayポリシー対応で完了）

### ✅ 完了: Web版サウンド安定化（PR #2〜#8）

| 項目 | 状態 |
|------|------|
| Web版バッテリーゲージ削除（PR #2） | ✅ |
| Web版SE再生修正・バトルBGM対応（PR #3, #4） | ✅ |
| SE再生のplay()リソース枯渇問題の解消（PR #5） | ✅ |
| BGM/SE個別ミュート機能の追加（PR #6） | ✅ |
| BGM/SEミュート設定の永続化・バックアップ対象化 | ✅ |
| Web SE再生をHTML5 Audio API直接使用に変更（PR #7） | ✅ |
| Web SE再生をdocument.createElement方式に最終修正（PR #8） | ✅ |

### ✅ 完了: オンボーディング（PR #9）

| 項目 | 状態 |
|------|------|
| 初回起動時3ページガイドUI（`OnboardingScreen`） | ✅ |
| ホーム画面に初回限定「はじめてのバトル！」CTAバナー | ✅ |
| 初回バトル完了後の次アクション案内ダイアログ | ✅ |
| SharedPreferencesフラグ管理（onboarding_completed / first_battle_completed） | ✅ |
| ユニットテスト5件＋ウィジェットテスト7件＝計12件 | ✅ |
| `feature/onboarding` → `master` マージ | ✅ |

### ✅ 完了: デイリーログイン報酬・バトル報酬（PR #12）

| 項目 | 状態 |
|------|------|
| デイリーログイン報酬ロジック | ✅ |
| 7日サイクルの連続ログインストリーク（3日目/7日目ボーナス） | ✅ |
| 日付跨ぎ復帰時の再判定（`WidgetsBindingObserver`） | ✅ |
| ホーム前面時のみポップアップ表示（保留キュー + `RouteAware`） | ✅ |
| バトル報酬（CPU対戦のみ付与、QR/フレンド対戦では付与しない） | ✅ |

### 🔶 進行中: Codexレビュー指摘対応（`fix/review-followups`）

| 項目 | 状態 |
|------|------|
| BattleEngineの50ターン決着ロジック（HP割合→絶対値→敵勝利） | ✅ |
| BattleResultService新設、ResultScreenから報酬反映処理を分離 | ✅ |
| ガチャ装備時の成長排他ロジック整理、コイン計算の基準統一 | ✅ |
| `QrBattleService.normalizeBattleInput` 公開（URL/生コード正規化をドメイン層へ） | ✅ |
| テスト追加: battle_engine / battle_result_service / qr_battle_service（+8件） | ✅ |
| SPECIFICATION.mdアーカイブ化、product_spec.md「要確認」項目の明文化 | ✅ |
| `docs/plans/TEMPLATES.md` 追加、CLAUDE.mdにPlanner/Generator/Evaluator案内 | ✅ |
| プレミアム解析ガチャ（20ジェム / SR以上確定） | ✅ |
| プレミアム解析の日替わりSSRピックアップ | ✅ |
| プレミアム解析のピックアップ天井 | ✅ |
| ガチャ結果からの直接装備導線 | ✅ |
| 重複ガチャの覚醒変換（最大+5） | ✅ |
| 覚醒上限後の重複コイン補填 | ✅ |
| 編成画面のロスター分析・フィルタ・Power表示・空状態CTA | ✅ |
| ホーム画面の次アクションカード | ✅ |
| URL共有画面の共有対象キャラカード | ✅ |
| URL入力/ゲストプレビューの受け取り体験強化（戦術反映含む） | ✅ |
| データ保護画面（バックアップコードのコピー/復元） | ✅ |
| コレクション画面の実績タブ・達成報酬受取 | ✅ |
| Home/リザルトから未受取実績報酬への導線 | ✅ |
| ホーム画面の高難度チャレンジ（HARD/BOSS選択） | ✅ |
| デイリーミッション（バトル/勝利/ガチャ） | ✅ |
| BOSS撃破報酬（1日1回の専用報酬） | ✅ |
| 週次チャレンジ（HARD/BOSS勝利の週目標） | ✅ |
| 初回撃破ボーナス（未撃破CPU敵への初勝利報酬） | ✅ |
| 週替わり期間イベント（CPU勝利の期間限定目標） | ✅ |
| BOSSタイムアタック自己ベスト | ✅ |
| リザルト共有テキストコピー | ✅ |
| 遊び方ヘルプ画面 | ✅ |
| 直近バトル履歴（コレクション表示・バックアップ対象） | ✅ |
| シーズンパス進行トラック（月替わり報酬） | ✅ |
| 期間限定イベント解析ガチャ（週替わり限定SSR・天井） | ✅ |
| 経済バランス回帰テスト（初回/週次/月次報酬ライン） | ✅ |
| データ保護画面の復元空状態・入力状態表示 | ✅ |
| ガチャ画面の通貨不足エラー改善（不足量・入手導線） | ✅ |
| コレクション画面のローカルランク進捗 | ✅ |
| コレクション画面のローカルリーグ順位表 | ✅ |
| ホーム画面の解析ロードマップ（限定/日替わりSSRの天井不足量） | ✅ |
| 週替わりイベントの専用ライバル戦 | ✅ |
| 週替わりイベントの段階報酬 | ✅ |
| ローカルランク到達報酬 | ✅ |
| ロスター収集ボーナス（CPU戦Coin倍率） | ✅ |
| 日替わりショップ（育成/充電/Gems交換） | ✅ |
| ライバルロード（常設PvE進行） | ✅ |
| バトル画面の再生速度切替 | ✅ |
| バトル開始時の支援コマンド選択 | ✅ |
| リザルト画面のもう一戦/ガチャ導線 | ✅ |
| プッシュ → PR作成 → Codexレビュー → マージ | 🔶 |

### 🔶 進行中: デプロイ

- [x] `feature/web-mvp` → `master` ブランチへマージ（済み）
- [x] `feature/onboarding` → `master` マージ（PR #9）
- [ ] `fix/review-followups` → `master` マージ
- [ ] GitHub Pages デプロイの確認（GitHub Actions ワークフロー `deploy.yml` は設定済み）
- [x] `QrBattleService.baseUrl` にデプロイ先URLを設定（`Uri.base` フォールバック実装済み・PR #11で修正）
- [x] OGPメタタグ・favicon設定（SNS共有時のプレビュー表示用）— 設定済み
- [ ] 最終動作確認（デプロイ後にOGPプレビュー・URL対戦フロー・ログイン報酬/バトル報酬をチェック）

---

## 方針変更の経緯

Android版MVPリリースを目指していたが、以下の理由でWeb版に方針転換:
- MacBookのディスク容量不足で `flutter build appbundle --release` が困難
- VPS（960MB RAM）ではGradle/Kotlinビルドがメモリ不足で不可
- Android実機の確保が困難

**除外したタスク**:
- QRコードカメラ読み取り（`mobile_scanner` — Web非対応）
- QRコード画像表示（`qr_flutter` — URLコピー/共有で代替）
- Androidリリースビルド・Play Store公開
- Deep Link対応（`app_links` — MVP後に検討）

---

## ~~Phase 3 後半~~ ✅ 全完了

### ~~1. キャラクター図鑑・対戦履歴 (Phase 3-2)~~ ✅ 完了
- `CollectionScreen` の実装
- 過去に遭遇・撃破した架空の端末（敵キャラクター）のリスト表示
- `shared_preferences` で対戦成績（勝利数・遭遇リスト等）をデータ永続化

### ~~2. タイトル画面の追加 (Phase 3-3)~~ ✅ 完了
- `title_screen.dart` を新設し、アプリ起動時の演出を強化。

---

## ~~Phase 4~~ 進行中

### ~~1. エミュレートガチャ（仮想スペック生成システム）~~ ✅ 完了
- ゲーム内通貨を用いてランダムなスペックキャラを生成するガチャ機能。

### ~~2. QR/URLフレンドスキャン対戦 (Phase 4-2) — ロジック層~~ ✅ 完了
- `CharacterCodec` v2: HMAC-SHA256ベースの4バイトチェックサム付与による改ざん検知
- `QrBattleService`: エンコード/デコード、ゲスト敵生成、Web共有URL生成
- `IntegrityException`: 不正データ検知用の専用例外クラス
- v1後方互換性を維持（チェックサムなしの旧データもデコード可能）
- ユニットテスト: CharacterCodec 25件 + QrBattleService 12件 = 計37件

### ~~3. Phase 4-2 UI層 — Web MVP対応~~ ✅ 完了
- QR系4画面をURL共有専用に改修（カメラ/QR表示を除去）
- `main.dart` で `Uri.base` パースによるURL起動対戦対応（`kIsWeb`）
- `web/index.html`, `web/manifest.json` 追加

### ~~4. Web版サウンド安定化~~ ✅ 完了
- Web SE再生を段階的に改善（プレイヤープール → HTML5 Audio API → document.createElement方式）
- BGM/SE個別ミュート機能の追加
- Web版からバッテリーゲージ機能を削除（Web環境では取得不可のため）

### ~~5. 初回オンボーディング~~ ✅ 完了（PR #9）
- 初回起動時3ページガイドUI（`OnboardingScreen`）
- ホーム画面に初回限定「はじめてのバトル！」CTAバナー
- 初回バトル完了後の次アクション案内ダイアログ（ガチャ/フレンド共有）
- SharedPreferencesでフラグ管理
- テスト計12件（ユニット5件＋ウィジェット7件）

### ~~6. デイリーログイン報酬・バトル報酬~~ ✅ 完了（PR #12）
- デイリーログイン報酬機能（日付跨ぎ復帰時再判定・ホーム前面時のみ保留ポップアップ表示）
- バトル報酬はCPU対戦時のみ付与（QR/フレンド対戦では付与しない）

### 7. 50ターン決着・バトル結果処理の責務分離 🔶 マージ待ち（`fix/review-followups`）
- BattleEngineに50ターン到達時の勝敗判定（HP割合→絶対値→敵勝利）を追加
- BattleResultService新設によりResultScreenから経験値・コイン・図鑑・報酬反映を分離
- QrBattleService.normalizeBattleInput 公開（ドメイン層に入力正規化を集約）
- テスト拡充（+8件）・SPECIFICATION.mdアーカイブ化・Planner/Generator/Evaluatorワークフロー導入

---

## 主要ファイル一覧

### ロジック層
- `lib/domain/services/qr_battle_service.dart` — URL対戦サービス（エンコード/デコード/URL生成、`normalizeBattleInput` 公開）
- `lib/domain/services/character_codec.dart` — キャラクターバイナリコーデック（v2チェックサム付き）
- `lib/domain/services/battle_engine.dart` — バトルエンジン（50ターン決着判定を含む）
- `lib/domain/services/battle_result_service.dart` — バトル結果処理（経験値・コイン・図鑑・報酬反映）
- `lib/domain/models/decoded_character.dart` — デコード結果ラッパー

### UI層（Web MVP）
- `lib/presentation/screens/qr_menu_screen.dart` — フレンド対戦メニュー（`FriendBattleMenuScreen`）
- `lib/presentation/screens/qr_display_screen.dart` — URL共有画面（`ShareScreen`）
- `lib/presentation/screens/qr_scan_screen.dart` — URL入力画面（`UrlInputScreen`）
- `lib/presentation/screens/qr_guest_preview_screen.dart` — ゲストプレビュー画面

### オンボーディング
- `lib/presentation/screens/onboarding_screen.dart` — 初回起動ガイドUI（3ページ）
- `lib/presentation/widgets/first_battle_complete_dialog.dart` — 初回バトル完了後案内ダイアログ

### サウンド（Web対応）
- `lib/data/web_se_player_web.dart` — Web SE再生（document.createElement方式）

---

## 既知の問題・課題
- **ユニットテスト環境構築エラー（Mac）**: `flutter test` 実行時に `objective_c` パッケージのネイティブビルドが失敗する場合がある（Xcode Command Line Tools のアーキテクチャ不一致問題）。Docker環境では問題なし。
