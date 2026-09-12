# Plan: F6 オンラインランキング MVP（Firebase 基盤＋週次世界ランキング）
Created: 2026-09-12
Status: PLANNING（設計のみ。ユーザーの方針判断と PR-0 完了後に grok-4.6 が実装）

## 要件
`docs/phase5_brushup_spec.md` §1-4 F6 / §1-5 / §2-4 / §3-3 / §4 / §5 順6 を**唯一の正本**とする。本ファイルは PR の切り方・ユーザー作業・完了条件・検証手順だけを持ち、要件の詳細は仕様書側を参照する。

プレイヤーが「自分のスマホ（戦闘力）が世界で何位・上位何%か」を実数で知れるようにする。参加は任意（デフォルト OFF）、週次リセット、順位報酬なし。未参加・オフライン時は現行の推定表示へ自動フォールバックし、既存機能は一切劣化しない。

## ゴール / 非ゴール

**ゴール**
- ランキング参加 ON で自分の PWR が Firestore に送信され、上位一覧・自分の順位・上位%（分母＝総参加数 N）が表示される
- ホームの `PowerRatingCard` とランキング詳細シートが `isEstimated` に応じてラベルを切り替える（`true`: 「推定上位○%」＋免責文 / `false`: 「世界○位（上位○%）」＋週次リセット表記）
- 参加 OFF で過去週を含む自分の全 entry が即時削除され、表示が推定へ戻る
- Firebase 未設定・オフライン・ルール拒否のいずれでもビルド・テスト・既存機能が壊れない
- 無料枠内（Firestore Spark）で運用できる読み取り回数設計

**非ゴール**
- 順位報酬・称号付与の新設（表示のみ。既存 `PlayerTitleService` の称号を表示に使うだけ）
- F7 クラウドセーブ / F8 Workers OGP の実装（匿名 UID は F7 で再利用できる形にするが、保存機能は作らない）
- `CharacterCodec` の変更（v3 をそのまま `characterCode` に載せる）
- Cloud Functions によるサーバー側スコア再計算（§2-4「不正対策の割り切り」どおり MVP では行わない。データは残す）
- F1 の Analytics 送信実体（`AnalyticsEventSink` は現在 No-op）を Firebase Analytics に差し替えること（§ 未決事項 Q1）
- ニックネーム・アイコンなどプレイヤー入力の識別情報（PII 非収集方針。一覧はアバター＋称号＋PWR のみ）

## 現状の前提（設計判断に影響する事実）
- `pubspec.yaml` に Firebase 系パッケージは**未導入**。F1 は `FirebaseOptionsConfig`（`lib/data/firebase_options.dart`、`--dart-define=FIREBASE_*` 読取）と No-op sink までで出荷済み。CI（`ci.yml` / `deploy.yml`）は `FIREBASE_*` の dart-define を渡していない。→ F6 の PR-A が Firebase SDK を初めて持ち込む。
- `PowerRating.isEstimated` はモデルに存在するが、`lib/presentation/widgets/power_rating_card.dart` は「推定上位○%」と免責文をハードコードしており参照していない。→ PR-C でラベル切替を必須にする。
- ホスティングは Cloudflare Pages `https://smartphonespecbattle.pages.dev/`。`web/_headers` の CSP は **enforce 済み**（hosting PR-3）。現行 `connect-src` / `script-src` に Firebase ドメインは無いため、CSP を更新しない限り本番で Firebase は動かない（§ CSP）。
- 送信する PWR は `PowerRating.score`（`PowerRatingService.powerScore(player.baseStats)`＝Lv1 素体スコア）。レベル・覚醒を含めないため全プレイヤーが同じ土俵になる。
- `weekId` は `LocalLeagueService.currentWeekId`（端末ローカル日付の月曜 `yyyy-MM-dd`）と同一計算を使う（§2-4）。

## PR-0: ユーザー作業チェックリスト（PR なし・実装着手前）
値（API キー等）は共有 Markdown に書かない。所在は GitHub リポジトリ secrets のみ。

- [ ] Firebase プロジェクト作成（Spark＝無料。Google Analytics 連携は任意。有効にしても F6 は使わない）
- [ ] Web アプリを追加し、Web 設定値 `apiKey` / `appId` / `messagingSenderId` / `projectId` を取得。既存 `FirebaseOptionsConfig` の 4 キーに対応する
- [ ] GitHub リポジトリ secrets に `FIREBASE_API_KEY` / `FIREBASE_APP_ID` / `FIREBASE_MESSAGING_SENDER_ID` / `FIREBASE_PROJECT_ID` を登録（Web の Firebase API キーは公開前提の識別子だが、運用統一のため secrets 経由で `--dart-define` に渡す。hosting-foundation と同じく Environment `production` は使わない）
- [ ] Authentication → Sign-in method で **匿名（Anonymous）** を有効化。「匿名アカウントの自動クリーンアップ」があれば有効化（30 日以上未使用の匿名ユーザーを自動削除。孤児 entry は Firestore TTL 側で消す）
- [ ] Authentication → Settings → **承認済みドメイン** に `smartphonespecbattle.pages.dev` と `localhost` を追加（`firebaseapp.com` / `web.app` の既定は残す）
- [ ] Firestore Database 作成（**本番モード**＝全拒否ルールで開始。リージョンは `asia-northeast1` を既定案。Q3）
- [ ] Firestore → **TTL ポリシー**: コレクショングループ `entries`、フィールド `expiresAt` で有効化（無料。削除は数十時間遅延し得るが保険用途なので可）
- [ ] Firestore → インデックス → **単一フィールドの除外設定**: コレクショングループ `entries`、フィールド `uid`、「コレクショングループ」スコープの昇順インデックスを有効化（`collectionGroup('entries').where('uid', ==)` に必須。既定ではコレクショングループスコープの単一フィールドインデックスは作られない）
- [ ] PR-B マージ後: リポジトリの `firestore.rules` を Firestore コンソールの「ルール」に貼り付けて公開（`firebase deploy --only firestore:rules` でも可。CI からは行わない）
- [ ] Sentry の Allowed Domains は pages.dev 済み（hosting PR-0）。追加作業なし

## PR スライス（各 PR は Codex レビュー → ユーザーがマージ判断。実装席は grok-4.6）

| 順 | ブランチ（案） | 内容 | 規模 |
|----|---|---|---|
| PR-A | `feature/ranking-firebase-bootstrap` | Firebase SDK 導入＋遅延初期化＋`RankingService` インターフェース（No-op/推定フォールバック実装）。UI 変更なし | 中 |
| PR-A' | `feature/hosting-csp-firebase` | `web/_headers` の CSP に Firebase ドメイン追加（§ CSP）。**PR-B の本番検証前に必須**。ドキュメントのみの本計画では実装しない | 小 |
| PR-B | `feature/ranking-firestore` | `firestore.rules` / インデックス定義＋Firestore 実装（送信・順位取得・参加解除削除）＋参加トグル（シート内、最小 UI）＋`ranking_opt_in` イベント | 大 |
| PR-C | `feature/ranking-ui` | `PowerRatingCard` / `PowerRankingSheet` の `isEstimated` 切替、世界ランキング上位一覧・自分の行ハイライト、Widget/ユニットテスト拡充 | 中 |

### PR-A: Firebase bootstrap ＋ RankingService 骨格
- `pubspec.yaml`: `firebase_core` / `firebase_auth` / `cloud_firestore` を追加（Flutter 3.44 / Web 対応の安定版。`firebase_analytics` は追加しない）。
- `lib/data/firebase_options.dart`: 既存 `FirebaseOptionsConfig` から `FirebaseOptions` を組み立てる getter を追加（`authDomain` は匿名認証のみのため不要。必要になれば `--dart-define` を 1 つ足す）。
- `lib/data/firebase_bootstrap.dart`（新規）: `Future<bool> ensureFirebaseInitialized()`。`hasConfig == false` なら何もせず `false`。**起動時には呼ばない**。ランキング参加 ON（保存済みフラグ含む）で初めて `Firebase.initializeApp` を実行する遅延初期化にし、未参加者に Firebase JS SDK のダウンロードとネットワーク接続を発生させない。`firebase_core_web` が JS SDK を `initializeApp` 時にロードすることを実装時に確認し、起動時ロードされる場合は Generator ログに計測値を残す。
- `lib/domain/services/ranking_service.dart`（新規）:
  - `RankingSnapshot`（`entries` / `myRank` / `participantCount` / `myPercentile` / `weekId` / `isEstimated`）。推定時は `PowerRating` から生成し、`isEstimated=true`。
  - 抽象 `RankingService`: `bool get isOptedIn` / `Future<void> setOptIn(bool)` / `Future<RankingSnapshot> loadMyStanding(PowerRating local)`（順位・N のみ、上位一覧なし）/ `Future<RankingSnapshot> loadLeaderboard(PowerRating local)`（上位 50 件込み）/ `Future<void> submitIfNeeded(...)`。
  - `EstimatedRankingService`（No-op 実装）: 常に推定を返す。テスト・Firebase 未設定時の既定。
  - フォールバックは `RankingService` 内で完結させ、UI はサーバー/ローカルの経路を意識しない（§2-4）。
- `lib/domain/services/service_locator.dart`: `rankingService` を登録。`hasConfig == false` なら `EstimatedRankingService`。
- CI: `ci.yml` / `deploy.yml` の `flutter build web` に `--dart-define=FIREBASE_API_KEY=... FIREBASE_APP_ID=... FIREBASE_MESSAGING_SENDER_ID=... FIREBASE_PROJECT_ID=...` を追加（secrets 未設定でも空文字→`hasConfig=false`→No-op でビルド成功）。`deploy-github-pages.yml`（ロールバック用）は触らない。
- 計測: `flutter build web --release` の `main.dart.js` サイズを導入前後で PR 本文に記録（§4-4 +15% 目安。超過時は Q2）。

### PR-B: Firestore ルール＋クライアント読み書き＋参加トグル
- リポジトリ直下に `firebase.json` / `firestore.rules` / `firestore.indexes.json` を追加（Emulator でのルールテスト用。CI デプロイはしない）。
- `lib/data/firestore_ranking_backend.dart`（新規、data 層）: 匿名サインイン、`rankings/{weekId}/entries/{uid}` への `set`、上位 50 件 `orderBy('powerRating', desc).limit(50)`、`where('powerRating', '>', mine).count()`、`entries` 全体の `count()`、`collectionGroup('entries').where('uid', '==', uid)` の全件取得→バッチ削除。Firestore 依存はこのファイルに閉じる。
- `lib/domain/services/ranking_service.dart`: `FirestoreRankingService`（抽象 `RankingBackend` に依存し、テストでは Fake を注入）。
  - ON: `ensureFirebaseInitialized()` → `signInAnonymously()`（既にサインイン済みなら再利用）→ 即時送信 → `ranking_opt_in {enabled: true}`。
  - OFF: 全週 entry 削除 → `signOut()`（匿名アカウント自体は残るが紐づくデータは無い）→ ローカルの送信キャッシュを消去 → `ranking_opt_in {enabled: false}` → 推定へ戻す。削除が途中失敗した場合はフラグを OFF にせずエラーを返し、再試行できるようにする（「OFF＝サーバーからデータが消える」を守る）。
  - 送信条件: `lastSentWeekId` / `powerRating` / `characterCode` / `title` のいずれかが変化。**weekId 変化時は PWR 同一でも必ず再送**。1 セッション上限（例: 5 回）でデバウンス。
  - 読み取り設計（無料枠対策）: ホーム表示時は `loadMyStanding`（count 2 回＝読み取り 2）だけ。上位 50 件（読み取り 50）はシートを開いた時のみ取得し、同一セッション・同一 weekId・自分の PWR 不変ならキャッシュを返す。
  - 失敗の扱い: ネットワーク・権限・未初期化は**想定内**として推定へフォールバックし Sentry に送らない（`FirebaseException` の code で判別）。想定外の例外のみ従来どおり伝播。
  - ローカル保存キー（`LocalStorageService`）: `ranking_opt_in` / `ranking_last_sent_week_id` / `ranking_last_sent_payload_hash`。**バックアップ対象外**（匿名 UID はブラウザ単位のため、復元先で別 UID になる。`analytics_consent` と同じ扱い）。
- 上位一覧の他プレイヤー `characterCode` は `CharacterCodec.decode` でチェックサム検証し、失敗した行はアバターを汎用アイコンにして一覧を落とさない。
- UI（最小）: `PowerRankingSheet` に「🌏 世界ランキング（今週）」ヘッダと参加トグルだけ追加。OFF 時は「参加して実際の順位を見る」ボタン。ラベル切替・一覧描画は PR-C。
- `ranking_opt_in` は F1 で予約済みのイベント名（§2-1）。既存 `AnalyticsService` 経由で送る（同意なしなら破棄される）。

### PR-C: 表示切替＋一覧＋テスト
- `lib/presentation/widgets/power_rating_card.dart`: `PowerRatingCard` / `PowerRankingSheet` を `RankingSnapshot`（または `isEstimated` を反映した `PowerRating`）で描画。
  - `isEstimated=true`: 現行どおり「推定上位○%」「全○端末中 ○位」＋ローカル比較の免責文。
  - `isEstimated=false`: 「世界○位（上位○%）」「参加 N 人中」＋「毎週月曜リセット / 順位報酬はありません」。免責文は非表示。
- シート: §3-3 のレイアウト（上位 50 一覧＝アバター・称号・PWR、自分の行ハイライト、51 位以下でも自分の行を末尾に表示）。
- `home_screen.dart`: `_powerRating` の取得を `rankingService.loadMyStanding(estimate)` 経由に変更。取得中・失敗中は推定を表示し続ける（スピナーで隠さない）。
- テスト（§4-1 / §4-2 の写し）:
  - ユニット `test/ranking_service_test.dart`: 送信デバウンス / 週替わりで PWR 不変でも再送 / オフライン（Fake backend が throw）で推定フォールバック / 順位・上位%の分母が N（参加 51 人以上ケース含む）/ OFF で全週 entry 削除→推定へ / weekId が `LocalLeagueService.currentWeekId` と一致。
  - Widget `test/power_rating_card_test.dart`: `isEstimated` 両値でのラベル切替 / 自分の行ハイライト / 未参加時の推定表示＋参加ボタン / トグル操作で `setOptIn` が呼ばれる。
  - 既存 `economy_balance_test.dart` 無変更でパス。

## セキュリティルール要約（§2-4 / §4-4 の写し。正本は PR-B の `firestore.rules`）
- `rankings/{weekId}/entries/{uid}`:
  - `create` / `update`: `request.auth != null && request.auth.uid == uid && request.resource.data.uid == uid`。
  - 値域: `powerRating` は int で `0 <= powerRating <= MAX_PWR`（Lv1 素体スコアの理論上限から算出する定数。Q4）。`characterCode` は string で長さ上限（v3 の実長＋余裕。実装時に定数化）。`title` は string で長さ上限。`updatedAt == request.time`。`expiresAt` は timestamp 必須（欠落は拒否）。それ以外のフィールドは拒否（`keys().hasOnly`）。
  - `read`: `request.auth != null`（上位一覧・count 集計に必要。未参加者は匿名サインインしないため到達しない）。
  - `delete`: `request.auth.uid == resource.data.uid`。
- `match /{path=**}/entries/{entryId}`（collectionGroup 用）: `read, delete` を `request.auth != null && resource.data.uid == request.auth.uid` に限定。クエリ側は必ず `where('uid', '==', 自分の uid)` を付ける。
- ルールテスト（Firebase Emulator Suite、ローカル実行・CI 外）: 他人 uid への書き込み拒否 / 他人 entry の削除拒否・自分の削除許可 / 値域外 `powerRating` 拒否 / `expiresAt` 欠落拒否 / 未認証の read 拒否。

## CSP（hosting との整合。本計画では実装しない）
`web/_headers` の CSP は enforce 済みのため、Firebase を有効化するには **PR-A'（別 PR、`web/_headers` のみ）** が必要。追加候補:
- `script-src`: `https://www.gstatic.com/firebasejs/`（`firebase_core_web` が JS SDK をここから注入する場合）
- `connect-src`: `https://firestore.googleapis.com` `https://identitytoolkit.googleapis.com` `https://securetoken.googleapis.com`（Firestore Listen/Write/RunAggregationQuery、匿名サインイン、トークン更新）
- `frame-src` は匿名認証のみなら不要（popup/redirect 認証を使わないため）
実際に必要なドメインは PR-B のローカル確認（DevTools Console の CSP violation）で確定し、PR-A' に反映する。PR-A' が未マージの間は本番で ON にしてもフォールバックで推定表示になるだけで壊れないが、**PR-B の本番検証は PR-A' マージ後に行う**。

## 完了条件
- [ ] `flutter analyze` エラー 0 / `flutter test` 全パス（PR ごと。Firebase 未設定＝No-op 状態でも通る）
- [ ] `flutter build web --release --base-href "/"` 成功。`main.dart.js` サイズ差分を PR-A 本文に記録（+15% 目安）
- [ ] 参加 OFF（既定）で Firebase への通信が 1 件も発生しない（DevTools Network）
- [ ] 参加 ON → Firestore コンソールに `rankings/{今週の月曜}/entries/{uid}` が `expiresAt` 付きで作成される
- [ ] ホームカードが「世界○位（上位○%）」に切り替わり、免責文が消える。シートに上位一覧と自分の行ハイライト、週次リセット表記が出る
- [ ] 参加 OFF → 全週の自分の entry が消え、表示が推定へ戻る
- [ ] Firestore ルールテスト（Emulator）の 5 観点がパス（結果を PR-B 本文に添付）
- [ ] 既存 `economy_balance_test.dart` 無変更でパス

## pages.dev での検証手順（PR-B / PR-C マージ＋デプロイ後、ユーザーまたは Grok が手動）
1. `https://smartphonespecbattle.pages.dev/` を新規プロファイルで開く → DevTools Console に CSP violation が無いこと、Network に `googleapis.com` への通信が無いこと（OFF 既定）
2. ホーム → 戦闘力カードをタップ → 参加 ON → Network に `identitytoolkit`（匿名サインイン）と `firestore.googleapis.com` が出る → カードが「世界○位」表記になる
3. 別プロファイル（または別ブラウザ）でも参加 ON → 双方のシートに相手が載り、N が 2 増える
4. 一方を OFF → もう一方のシートから即時消え、N が減る。Firestore コンソールで entry が消えている
5. DevTools で Offline 化 → リロード → ホーム・バトル・ガチャが動き、カードが「推定上位○%」に戻る。Sentry に新規イベントが増えていない
6. 週替わり確認は端末時刻変更ではなく、Fake backend のユニットテスト（週替わり再送）で担保する

## 未決事項（ユーザー判断。既定値で進めて良い）
| # | 質問 | 既定値 |
|---|------|--------|
| Q1 | F1 の No-op Analytics sink をこの機会に Firebase Analytics 実体へ差し替えるか | **しない**。F6 は Firestore/Auth のみ。差し替えは別計画（同意→`initializeApp` のタイミング設計が必要） |
| Q2 | `main.dart.js` が +15% を超えた場合 | 遅延初期化（PR-A 設計）で起動時ロードを避けているため**そのまま進め、実測値を記録して再判断** |
| Q3 | Firestore リージョン | `asia-northeast1`（東京）。単一リージョン・Spark |
| Q4 | `powerRating` の上限定数の根拠 | 仕様書は「Lv 上限×覚醒+5」だが、送信値は Lv1 素体スコアのため**`CharacterGenerator` の Lv1 基礎値上限から算出＋余裕 10%**（ルールを厳しくできる）。仕様書 §2-4 の文言はマージ時に追記修正 |
| Q5 | ブラウザデータ消去などで匿名 UID が変わった場合の旧 entry | **TTL（30 日）と匿名アカウント自動クリーンアップに任せる**。手動の「別端末の entry 削除」導線は作らない |

## 既知の制約
- `weekId` は端末ローカル日付の月曜（ローカルリーグと同一）。週境界付近ではタイムゾーン差で別週に登録され得る。カジュアル方針として許容し、UTC 統一はしない。
- PWR はクライアント計算のため改ざん可能（§2-4 割り切り）。値域クランプ＋報酬なしで実害を限定。
- 匿名 UID はブラウザ（IndexedDB）単位。バックアップコード復元では引き継がれない（`ranking_opt_in` をバックアップ対象外にする理由）。

---
## Generator ログ
（grok-4.6 が実装時に追記）

---
## 評価
（検証結果を追記）
