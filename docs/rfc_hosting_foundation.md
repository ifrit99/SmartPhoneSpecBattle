# RFC: ホスティング基盤の移行（Cloudflare Pages を第一候補とする）

Created: 2026-09-11
Status: APPROVED（2026-09-11 ユーザー承認。Q3 回答済み。Q1/Q2/Q4/Q5 は §11 の既定値で進める。実装は `docs/plans/hosting-foundation.md` の順序で grok-4.6）
Scope: 要件とアーキテクチャの設計のみ。本RFCはプロダクトコード（Dart/Flutter/ワークフロー）を変更しない。
Related: `docs/phase5_brushup_spec.md`（F1/F2 済、F6 Firebase、F8 Workers 設計メモ）、`docs/feature-notes/share-url.md`、`docs/plans/error-monitoring.md`
Implementation plan: `docs/plans/hosting-foundation.md`（本RFCが正本。計画は薄い順序表のみ）

---

## 0. 現状（master `8e048e8`）

| 項目 | 現状 | 根拠 |
|---|---|---|
| リポジトリ | 公開 `ifrit99/SmartPhoneSpecBattle` | GitHub |
| 配信先 | `https://ifrit99.github.io/SmartPhoneSpecBattle/`（GitHub Pages、project site） | `.github/workflows/deploy.yml` |
| デプロイ | `master` push で `flutter analyze` → `flutter test` → `flutter build web --release --base-href "/SmartPhoneSpecBattle/"` → `actions/upload-pages-artifact@v3` → `actions/deploy-pages@v4` | `.github/workflows/deploy.yml` |
| ビルド時シークレット | `--dart-define=SENTRY_DSN=${{ secrets.SENTRY_DSN }}`、`SENTRY_RELEASE=${{ github.sha }}`。DSN 未設定なら Sentry は no-op | `.github/workflows/deploy.yml:45`、`lib/data/sentry_options.dart`、`lib/data/error_monitoring.dart:59-63` |
| Firebase 設定 | `FIREBASE_API_KEY` 等を `String.fromEnvironment` で受ける入口だけ存在。ワークフローにはまだ `--dart-define` が無い | `lib/data/firebase_options.dart` |
| OGP | `web/index.html` に静的 OGP/Twitter Card。`deploy.yml` の `sed` で `ogp.png` を絶対 URL に書き換え。`og:url` は github.io を直書き | `web/index.html:17`、`.github/workflows/deploy.yml:47-51` |
| X 投稿 | リザルト画面から `https://x.com/intent/tweet?text=` を開く。本文は結果・`#SPECBATTLE`・**サイトルート URL のみ**（`?battle=` は含まない）。URL は `_gameUrl` 定数で github.io を直書き | `lib/presentation/screens/result_screen.dart:188-231` |
| フレンド共有 | `{Uri.base のパス}/?battle={CharacterCodec}`。`baseUrl` が空なら `Uri.base` から生成するので配信ドメインに自動追従する | `lib/domain/services/qr_battle_service.dart:38-51`、`docs/feature-notes/share-url.md` |
| `?battle=` の整合性 | `CharacterCodec` v3。HMAC-SHA256 の先頭4バイトを付与。鍵は `_hmacKey` 定数としてハードコード（カジュアル改ざん検知のみ） | `lib/domain/services/character_codec.dart:26-30` |
| `?battle=` の中身 | キャラ名（UTF-8）・ステータス・スキル・見た目パーツ。ガチャキャラは `deviceName`（架空ブランド名カタログ）も含む | `lib/domain/services/character_codec.dart:144-213`、`lib/domain/data/gacha_device_catalog.dart` |
| Sentry PII 対策 | `beforeSend` で `SPEC-BATTLE-BACKUP*:` と `?battle=` 値を `[REDACTED]`、request URL は query/fragment を落とす | `lib/data/error_monitoring.dart:12-51`、`test/error_monitoring_test.dart` |
| PR ゲート | `ci.yml` が analyze / test / web build。`deploy.yml` と同じ `--base-href` を持つ | `.github/workflows/ci.yml` |
| セキュリティヘッダ | GitHub Pages はカスタムヘッダ（CSP 等）を設定できない。現状ヘッダは未設定 | GitHub Pages 仕様 |

github.io の URL が直書きされている箇所（移行時に必ず触る）: `result_screen.dart:189`、`web/index.html:17`、`deploy.yml:50`、`test/presentation/result_screen_test.dart:170`、`test/error_monitoring_test.dart:45-52`（テストは挙動確認用の固定文字列なので、後者は変更不要の可能性あり。実装時に判断）。

---

## 1. ゴール / 非ゴール

### ゴール
1. **公開エントリ URL は誰でも開ける状態を維持する。** X 投稿からの流入（バイラル導線）は製品の核なので、ランディングを認証で塞がない。
2. **月額ほぼ ¥0。** 無料枠で運用し、有料プランを前提にしない。
3. **セキュリティ姿勢の底上げ。** 具体的には (a) 応答ヘッダ（CSP / frame 制御 / referrer / permissions）を配信側で付けられること、(b) ビルド時シークレットの扱いを明文化すること、(c) 共有 URL ペイロードの最小化・署名の選択肢を整理すること。
4. **Phase5 の基盤構想と矛盾しない。** アプリのバックエンド（分析・ランキング・匿名認証）は Firebase、エッジ処理（動的 OGP・短縮リンク）は Cloudflare Workers、という既存の役割分担（`docs/phase5_brushup_spec.md` §2-1, §2-4, §2-7）をそのまま採用し、二つ目のバックエンド物語を作らない。
5. **CI/CD は GitHub Actions に留める。** analyze / test / build のゲートは現行を維持し、最後の「配置」ステップだけを差し替える。

### 非ゴール（明示）
- **URL を隠すことはセキュリティ目標ではない。** 公開 SPA のため、配信 URL・ビルド成果物・`?battle=` の形式はすべて閲覧者に見える前提で設計する。
- **ランディングページの認証ゲート（auth-wall）は v1 では対象外。** バイラル導線を殺すため。
- リポジトリの private 化は本RFCで判断しない（公開のままでも成立する設計にする）。
- `CharacterCodec` の形式変更・鍵の付け替え・ツイート UI の変更は**今回やらない**（選択肢の整理のみ、§4-4）。
- Firebase Hosting / Firestore / Workers の実装。F6/F8 の着手可否は別計画。
- 有料プラン（Cloudflare Pro、Firebase Blaze の有料域、GitHub Pro）を前提にした設計。
- カスタムドメインの購入判断（本RFCでは「あれば良い」扱い。§10 の質問）。

---

## 2. 脅威モデル

対象は「公開静的 SPA ＋ クライアント生成の共有 URL ＋ 将来の Firebase / Workers エッジ」。**サーバー側に秘密は存在せず、クライアントに渡すものはすべて公開情報**という前提で整理する。

### 2-1. 資産
| 資産 | 価値 | 備考 |
|---|---|---|
| 配信されるビルド成果物（`index.html`, `main.dart.js`, `assets/`） | 改ざんされると全プレイヤーに影響 | 完全性が最優先 |
| プレイヤーのローカルセーブ（`SharedPreferences`） | 個人の進行データ。PII ではないがバックアップコード経由で流出しうる | Sentry スクラブ済み |
| 共有 URL `?battle=` の中身 | キャラ名・ステータス。キャラ名にプレイヤーが任意文字列を入れられる | §4-4 |
| ビルド時シークレット（`SENTRY_DSN`、将来 `FIREBASE_*`） | いずれも**クライアントに埋め込まれる公開値**。秘匿ではなく「乱用制限」で守るもの | §4-1 |
| デプロイ権限（Actions のトークン / Cloudflare API トークン） | 漏れると成果物改ざんに直結 | §4-1 |
| OGP 画像・メタ | 偽装されると SNS 上のブランド毀損 | 静的なので低リスク |

### 2-2. 脅威と対策の対応
| # | 脅威 | 経路 | 影響 | 対策（要件番号） |
|---|---|---|---|---|
| T1 | サプライチェーン経由の成果物改ざん | Actions のサードパーティ action、`flutter pub` 依存 | 高 | S-6（action のバージョン固定）、S-7（デプロイ権限の最小化） |
| T2 | デプロイトークン漏洩 | Actions ログ・PR からの秘密参照 | 高 | S-7（fork PR で secrets を使わない、`pull_request` では build のみ）。現行 `ci.yml` は `pull_request` で `secrets.SENTRY_DSN` を参照しているため、fork PR では空になる（GitHub の既定動作で安全側）。 |
| T3 | XSS / スクリプト注入 | Flutter Web は DOM を直接組み立てないが、`index.html` と外部 SDK（Sentry、将来 Firebase、`flutter_bootstrap.js`）が読み込み点 | 中 | S-3（CSP。Flutter Web の CanvasKit / WASM 要件と両立する形で `script-src` / `connect-src` を絞る） |
| T4 | クリックジャッキング | 第三者サイトが iframe で埋め込み | 低〜中 | S-3（`frame-ancestors 'none'` または `X-Frame-Options: DENY`） |
| T5 | 共有 URL の改ざん（ステータス最大化） | `?battle=` を手編集 | 低（フレンド対戦は報酬なし。`docs/feature-notes/share-url.md`） | 現状の HMAC で「事故」は防げる。「悪意」は防げないが実害が無いので v1 は据え置き（S-8） |
| T6 | 共有 URL 経由の不快コンテンツ | キャラ名に任意文字列 → 受け手のプレビュー画面に表示 | 中（ブランド） | S-9（受信側表示時のサニタイズ/長さ制限。既存 `_truncateName` はツイート側のみ） |
| T7 | 共有 URL からの個人特定 | `deviceName` は架空ブランドカタログ、実機名は載らない（PR #13 で置換） | 低 | S-9（現状維持を要件として固定） |
| T8 | Sentry / Firebase の公開キー乱用 | DSN・API Key はバンドルに含まれる | 中（クォータ消費） | S-2（Sentry: 許可オリジン設定、レート制限。Firebase: API Key の HTTP リファラ制限、App Check は F6 着手時） |
| T9 | Referer 経由で `?battle=` が第三者へ漏れる | 外部リンク（X intent、Sentry）へ遷移時 | 低 | S-3（`Referrer-Policy: strict-origin-when-cross-origin` 以上）。Sentry 側は既に query を落としている |
| T10 | 旧 URL（github.io）の放置 | 移行後に古い OGP/ツイートが github.io を指し続ける | **無視できる**（2026-09-11 ユーザー判断: まだプレイヤー・既存ツイートが存在しないため保全対象がない） | M-3（GitHub Pages を停止。リダイレクト不要）、M-2（canonical） |
| T11 | ホスティング側の障害・アカウント停止 | ベンダー依存 | 中 | M-5（ロールバック: GitHub Pages を一定期間残す） |

### 2-3. 将来エッジ（F8 Workers）を足したときの追加脅威
- Worker が `?battle=` をデコードして OGP を描く場合、**サーバー側で初めて `CharacterCodec` を解釈する**ことになる。不正 payload による例外・過大サイズ・スクリプト混入（SVG 生成時）を Worker 側で防御する必要がある。→ S-10 として要件だけ置く（実装は F8 計画で）。
- Worker で短縮リンクを発行する場合、KV に対する書き込み乱用（無料枠 1,000 write/日）が DoS 面になる。→ 署名付き短縮のみ・レート制限。F8 で扱う。

---

## 3. 要件の記法
- **MUST**: 移行完了条件。満たさない PR はマージしない。
- **SHOULD**: 移行と同じ PR 列で対応するのが望ましいが、後続でも良い。
- 番号: S = セキュリティ、C = コスト、M = 移行、A = 受け入れ。

---

## 4. セキュリティ要件

### 4-1. シークレット / 公開キーの扱い
| # | 区分 | 要件 |
|---|---|---|
| S-1 | MUST | クライアントに埋め込む値（`SENTRY_DSN`、`FIREBASE_*`）は「公開値」と明記し、秘匿ではなく**プロバイダ側の乱用制限**（許可オリジン・リファラ制限・レート制限）で守る。ドキュメント上「秘密」と呼ばない。 |
| S-2 | SHOULD | Sentry プロジェクトに Allowed Domains（新ドメインのみ。github.io は M-3 で停止するため不要）を設定する。Firebase API Key は F1/F6 の実装時に HTTP リファラ制限を掛ける（本RFCでは要件として先置き）。 |
| S-7 | MUST | デプロイ権限は最小化する。Cloudflare Pages を Actions から配置する場合、API トークンは **Pages: Edit のみ**、対象アカウント限定、GitHub Environment `production` に保存し `master` ブランチのみ参照可にする。`pull_request` トリガーでは配置を行わず、`ci.yml` の build 確認に留める（現行どおり）。 |
| S-6 | SHOULD | `deploy.yml` / `ci.yml` で使う third-party action（`subosito/flutter-action`、Cloudflare の配置 action）は**メジャータグではなくコミット SHA 固定**にする。Dependabot の `github-actions` エコシステムを有効化する。 |

### 4-2. 転送・ヘッダ
| # | 区分 | 要件 |
|---|---|---|
| S-3 | MUST | 配信側で以下を返せること（GitHub Pages では不可能なため、これが移行の主な安全性上の動機）: `Content-Security-Policy`、`X-Content-Type-Options: nosniff`、`Referrer-Policy: strict-origin-when-cross-origin`、`Permissions-Policy`（camera/microphone/geolocation を無効）、`X-Frame-Options: DENY` または CSP `frame-ancestors 'none'`。Cloudflare Pages では `web/_headers` をビルド成果物に含めるだけで良い（Flutter は `web/` 配下をそのままコピーする）。 |
| S-4 | MUST | HTTPS 強制（HTTP → HTTPS リダイレクト）。HSTS は**カスタムドメイン確定後**に短い max-age から段階導入し、`preload` は付けない（戻せなくなるため）。`*.pages.dev` は Cloudflare 側で HSTS 済み。 |
| S-5 | SHOULD | CSP は最初は `Content-Security-Policy-Report-Only` で配信し、Sentry か Cloudflare のレポート先で違反を観測してから enforce に切り替える。Flutter Web（CanvasKit / WASM）は `script-src 'wasm-unsafe-eval'`、`connect-src` に Sentry ingest / Google Fonts（CanvasKit 取得元）/ 将来の Firebase ドメインが必要になる。**`'unsafe-inline'` を `script-src` に許す設計は不採用**（`flutter_bootstrap.js` は外部ファイル読み込みなので不要なはず。実装時に `flutter build web` の生成物で確認）。 |

### 4-3. 共有 URL（`?battle=`）
| # | 区分 | 要件 |
|---|---|---|
| S-8 | MUST（据え置きの明文化） | v1 では `CharacterCodec` と HMAC 鍵を**変更しない**。理由: フレンド対戦は報酬を付与せず（`docs/feature-notes/share-url.md`）、改ざんの実害が無い。鍵をリポジトリ外に出しても、クライアントで検証する限り公開値になる（`share-url.md` 「今後見直しそうな点」と同じ結論）。 |
| S-9 | MUST | ペイロードに**実機の端末識別子・OS 詳細・PII を含めない**現状を要件として固定する。`deviceName` は架空ブランドカタログ由来（`lib/domain/data/gacha_device_catalog.dart`）に限る。受信側でキャラ名を表示する箇所（`qr_guest_preview_screen.dart`）は長さ上限を掛ける（実装は別 PR。本RFCは要件のみ）。 |
| S-10 | SHOULD（F8 前提） | 署名の強化は**サーバー側に検証点ができるときだけ**行う。選択肢: (a) 現状維持（クライアント HMAC、公開鍵相当）、(b) Workers で短縮リンク発行時に Worker の秘密鍵で署名し、KV に本体を置く（URL が短くなり、Worker 側で検証可能。無料枠の KV write が上限）、(c) Firestore にキャラを置いて ID 参照（F7 クラウドセーブと統合。認証が前提）。**推奨は (a) → F8 着手時に (b)**。(c) は F7 と同時に検討。 |

### 4-4. X 投稿とペイロード最小化
- 現状のツイートは**サイトルートのみ**を含み `?battle=` を含まない（`result_screen.dart:215-231`）。これは公開タイムラインにキャラデータを載せない点で望ましく、**維持する**（MUST）。
- ツイート本文の `_gameUrl` は正規 URL（§7 M-2）へ差し替える。ハッシュタグ `#SPECBATTLE` は維持。
- 「ツイートに `?battle=` を載せて直接対戦させる」案は、URL 長・タイムライン上の可読性・T6 のリスクから v1 で採らない。F8（動的 OGP）と短縮リンクが揃った段階で再評価する。

### 4-5. エラー監視
- Sentry の `beforeSend` スクラブ（`lib/data/error_monitoring.dart:33-51`）は移行後も**そのまま有効**。配信ドメインが変わっても正規表現はドメイン非依存なので改修不要。`test/error_monitoring_test.dart` の github.io 文字列は固定入力値であり、変更してもしなくても良い。
- 移行後に `SENTRY_RELEASE=${{ github.sha }}` は据え置き。環境タグ（`environment: production` / `preview`）を `--dart-define` で追加するのは SHOULD（Pages のプレビュー配信と本番の切り分けに使える）。

---

## 5. コスト要件

| # | 区分 | 要件 |
|---|---|---|
| C-1 | MUST | 月額 ¥0 で運用できる構成にする。想定規模（インディー）: 月間 PV 〜10 万、成果物 〜20 MB、デプロイ 〜100 回/月。 |
| C-2 | MUST | 「無料枠を超えると何が起きるか」を選定時に明記し、**自動で有料に転じる構成は避ける**（クレジットカード紐付けが不要な選択肢を優先）。 |
| C-3 | SHOULD | 帯域・ビルド回数・関数実行回数を月次で確認する手順を `docs/plans/hosting-foundation.md` の運用欄に残す。 |

### 無料枠の目安（2026-09 時点の各社公開情報に基づく。実装時に再確認すること）
| 項目 | Cloudflare Pages（Free） | GitHub Pages | Firebase Hosting（Spark） |
|---|---|---|---|
| 帯域 | 無制限（静的） | 目安 100 GB/月（ソフトリミット） | 10 GB/月 |
| ストレージ | 無制限に近い（1 サイト 20,000 ファイル / 25 MB per file） | 1 GB | 10 GB |
| ビルド | 500 回/月（Cloudflare 側ビルド利用時。Actions から成果物を push する Direct Upload なら消費しない） | Actions 分数 2,000 分/月（public リポは無制限） | Actions 側で消費 |
| エッジ関数 | Pages Functions = Workers 無料枠 100,000 req/日 | なし | Cloud Functions は **Blaze（従量）必須**。Spark では使えない |
| KV / ストレージ | KV 100,000 read/日、1,000 write/日 | なし | Firestore 5 万 read/日（F6 で使う枝） |
| カスタムドメイン | 無料（DNS を Cloudflare に置く前提が楽） | 無料 | 無料 |
| 有料に転じる条件 | 自動転換なし。無料枠超過で関数がエラーになるだけ（静的配信は継続） | 超過は「連絡が来る」運用 | Spark は自動転換なし。Functions/動的 OGP を Hosting 側でやるには Blaze が必要 |

**結論**: Flutter Web の静的配信だけなら三者とも ¥0。差が出るのは (1) ヘッダ制御、(2) エッジ関数を無料で持てるか、(3) Firebase Hosting で関数を使うと Blaze が必要になる点。Phase5 の F8 が「Workers で動的 OGP」を前提にしている（`docs/phase5_brushup_spec.md:230`）ため、Cloudflare に SPA を置くと F8 が同一ドメイン・同一無料枠で完結する。

---

## 6. 比較表: (A) Cloudflare Pages / (B) GitHub Pages 継続＋強化 / (C) Firebase Hosting

| 観点 | (A) Cloudflare Pages【第一候補】 | (B) GitHub Pages 継続＋強化のみ | (C) Firebase Hosting |
|---|---|---|---|
| 月額（インディー規模） | ¥0。静的帯域無制限 | ¥0。100 GB/月ソフトリミット | ¥0（Spark）。10 GB/月。動的 OGP を Hosting 側関数でやると Blaze 必須 |
| セキュリティヘッダ（CSP 等） | `_headers` ファイルで可（S-3 を満たす） | **不可**。`<meta http-equiv="Content-Security-Policy">` で一部代替できるが `frame-ancestors` / `X-Frame-Options` / `nosniff` / `Referrer-Policy` はメタで効かないか限定的 | `firebase.json` の `headers` で可 |
| HTTPS / HSTS | 強制。`*.pages.dev` は HSTS 済み | 強制（Enforce HTTPS） | 強制 |
| CI/CD との相性 | Actions で build → `wrangler pages deploy`（Direct Upload）。**Cloudflare 側の Flutter ビルドは不要**（Flutter SDK 準備が要るので Actions 継続が楽）。プレビュー配信はブランチ単位で自動 | 現行そのまま。変更ゼロ | Actions で build → `firebase deploy --only hosting`。プレビューチャネルあり |
| 認証情報の管理 | Cloudflare API トークン（Pages: Edit 限定）を Actions secret に。**Firebase とは別のアカウント/コンソールが増える** | 追加なし（`id-token` の OIDC のみ） | Firebase サービスアカウント JSON または Workload Identity。**F1/F6 と同じコンソールで完結** |
| カスタムドメイン | 無料。Cloudflare DNS ならワンクリック | 無料。CNAME ファイルと DNS 設定。**移行時 base-href が `/` になる点は A/C と同じ** | 無料 |
| エッジ関数 | Pages Functions（= Workers）。無料枠内で F8 動的 OGP・短縮リンクを**同一プロジェクト**で持てる | なし。F8 は別途 Workers を立て、github.io と別ドメインになる（OGP の `og:url` が分裂） | Cloud Functions（Blaze 必須）。Workers を別に立てるなら A の B 版と同じ分裂 |
| Phase5 Firebase（F1/F6）との整合 | **整合する**。Firebase は「アプリのバックエンド」（分析・Firestore・匿名認証）、Cloudflare は「配信とエッジ」。SDK は SPA からどのドメインでも呼べる。CORS/認可ドメインに新ドメイン追加が必要（`authorized domains`） | 整合する（現状） | **最も密結合**。Hosting と Auth/Firestore が同一プロジェクト・同一ドメインで、認可ドメイン設定が自動 |
| Phase5 F8 Workers との整合 | **最も自然**。SPA と Worker が同一オリジン | Worker が別オリジンになる | Workers を別オリジンで立てるか、Blaze で Functions に寄せる（F8 の設計メモと食い違う） |
| 移行工数 | 中。`deploy.yml` の配置ステップ差し替え、`--base-href "/"`、`_headers`/`_redirects` 追加、URL 直書き 3 箇所、Sentry 許可ドメイン、GitHub Pages の停止 | 小。CSP は `<meta>` で部分対応、action の SHA 固定、Dependabot | 中。Firebase プロジェクト作成（F1 で必要になるものと共用可）、`firebase.json`、同じ URL 直書き 3 箇所 |
| ロールバック | Pages のデプロイ履歴から即時ロールバック可。GitHub Pages を残せば DNS/リンク戻しも可 | 該当なし | Hosting の release 履歴からロールバック可 |
| リスク | アカウントが 1 つ増える。Cloudflare 独自仕様（`_headers`/`_redirects`）への依存。プレビュー URL（`*.pages.dev` のブランチ別）が公開されるため、未マージ機能が見える（プレビューは Access で保護可、無料枠 50 ユーザー） | **ヘッダ要件 S-3 を満たせない**。F8 で OGP ドメインが割れる | 10 GB/月 の帯域は OGP 画像（1200×630 PNG）と `main.dart.js`（数 MB）で意外と早く到達しうる。関数を Hosting 側でやりたくなると Blaze |
| 公開性（バイラル） | 維持 | 維持 | 維持 |

---

## 7. 決定

### 推奨: (A) Cloudflare Pages を第一候補とする
理由（優先順）:
1. **S-3（応答ヘッダ）を無料で満たせる**唯一の選択肢が A と C で、そのうち F8「Workers で動的 OGP」（`docs/phase5_brushup_spec.md:230`）と同一オリジンで完結するのは A だけ。
2. 静的帯域が無制限で、C-2（無料枠超過で有料に転じない）を最も安全に満たす。
3. CI/CD は GitHub Actions のまま、最後の配置ステップだけ差し替えれば済む。analyze / test のゲートは無変更。
4. Firebase との役割分担が明確になる: **Cloudflare = 配信＋エッジ、Firebase = アプリのバックエンド（分析・Firestore・匿名認証）**。Phase5 の技術選定を変更せずに済む。

### (B) が勝つ条件
- ユーザーが「アカウントを増やしたくない」「移行そのものに時間を使いたくない」場合。S-3 は満たせないが、`<meta http-equiv="Content-Security-Policy">` による部分 CSP、action の SHA 固定、Dependabot 有効化だけでも T1/T3 は下げられる。**B を選んでも本RFCの S-6/S-7/S-8/S-9 はそのまま適用できる。**
- F8（動的 OGP）を将来もやらないと決めた場合、A の最大の利点が消える。

### (C) が勝つ条件
- F1（Firebase Analytics）と F6（Firestore ランキング）の実装を**先に**始めることが確定し、コンソールを一つに集約したい場合。
- F8 を Workers ではなく Cloud Functions で書き直す方針に変える場合（Blaze へのカード紐付けが必要になり、C-2 と衝突する点は要注意）。
- 帯域 10 GB/月 が当面十分と判断できる規模のうち。

### 却下しない設計原則（A/B/C 共通）
- ホスティング（配信）とアプリバックエンド（Firebase）は**別レイヤーとして扱う**。どちらを選んでも Firebase SDK の呼び出し先は変わらない。
- `Uri.base` からの共有 URL 生成（`qr_battle_service.dart:38-51`）は配信ドメインに自動追従するので、**ホスティング変更で `CharacterCodec` や `QrBattleService` を触る必要はない**。

---

## 8. 目標アーキテクチャ（スケッチ）

```
[GitHub: ifrit99/SmartPhoneSpecBattle (public)]
   │  push master
   ▼
[GitHub Actions: deploy.yml]
   analyze → test → flutter build web --release --base-href "/"
     --dart-define=SENTRY_DSN=...(公開値) --dart-define=SENTRY_RELEASE=<sha>
     (将来) --dart-define=FIREBASE_*=...(公開値)
   → build/web に web/_headers, web/_redirects が同梱される
   → wrangler pages deploy build/web   (Cloudflare API token: Pages Edit のみ)
   ▼
[Cloudflare Pages]  https://<project>.pages.dev  /  https://<custom-domain>/   ← 正規 URL
   ├─ 静的 SPA（Flutter Web、CanvasKit/WASM）
   ├─ _headers: CSP / nosniff / Referrer-Policy / Permissions-Policy / frame-ancestors
   ├─ _redirects: SPA fallback は不要（単一 index.html、?battle= は query なのでパスは "/" のまま）
   └─ (F8 で追加) Pages Functions /og?battle=... → 動的 OGP、 /s/<id> → 署名付き短縮リンク (KV)

[GitHub Pages]  https://ifrit99.github.io/SmartPhoneSpecBattle/   ← Cloudflare Pages 稼働後に停止
   └─ リダイレクトスタブは置かない（既存プレイヤー・ツイートなし。§9 M-3）
      旧 deploy ワークフローはロールバック用に一定期間だけファイルとして残す（§9 M-5）

[Firebase (Phase5 F1/F6/F7)]   ← アプリバックエンド。ホスティングとは無関係
   ├─ Analytics（同意後のみ）
   ├─ Firestore + Anonymous Auth（ランキング、将来クラウドセーブ）
   └─ authorized domains に pages.dev / custom-domain を追加（F1/F6 着手時）

[Sentry]   ← DSN は公開値。Allowed Domains に新ドメインを設定
[X intent] ← ツイート本文は結果 + #SPECBATTLE + 正規 URL（ルートのみ、?battle= なし）
```

要点:
- **配信レイヤー（Cloudflare）とアプリバックエンド（Firebase）を分離する。** Firebase Hosting を使わないことで、Firebase は「データと認証」に専念し、Blaze への転換圧力を受けない。
- F8 のエッジ関数は Pages Functions として同一オリジンに置く。`og:url` と実際の配信 URL が一致するので Twitter Card の検証が単純になる。
- `web/` 配下に `_headers` / `_redirects` を置くだけで Flutter のビルドがそのまま成果物に含める（実装は別 PR）。

---

## 9. 移行要件

| # | 区分 | 要件 |
|---|---|---|
| M-1 | MUST | `--base-href` を `"/SmartPhoneSpecBattle/"` から `"/"` に変える（`deploy.yml:45`、`ci.yml:42` の両方）。**プロジェクトサイトのサブパスが消えるため、これ以外に `index.html` の相対パス修正は不要**。`web/index.html` の `$FLUTTER_BASE_HREF` はビルド時に置換される。 |
| M-2 | MUST | **正規 URL を 1 箇所に決める**（`*.pages.dev` かカスタムドメイン。§10 Q1）。以下を正規 URL に揃える: `result_screen.dart:189` の `_gameUrl`、`web/index.html:17` の `og:url`、`deploy.yml:50` の `SITE_URL`。`_gameUrl` は `--dart-define=SITE_URL` から読む形にして直書きを解消するのが SHOULD（ただし `Uri.base` に頼ると X 投稿がプレビュー URL を指す事故が起きるので、**ツイート用 URL は定数/dart-define のまま**にする）。 |
| M-3 | MUST（内容変更） | **github.io からのリダイレクトは不要（2026-09-11 ユーザー判断: まだプレイヤーも既存ツイートも存在せず、保全すべき導線がない）。** Cloudflare Pages が稼働し M-8 の確認が通ったら、GitHub Pages への配置を止める（リポジトリ設定で Pages を無効化するか、配置ワークフローを実行しないだけでも良い）。リダイレクト専用 `index.html` や 90 日の保持要件は置かない。将来プレイヤーが付いた後に再度ドメインを変える場合は、その時点で別途リダイレクト要件を起こす。 |
| M-4 | MUST | Actions の secrets 構成: `CLOUDFLARE_API_TOKEN`（Pages Edit 限定）、`CLOUDFLARE_ACCOUNT_ID`。GitHub Environment `production` に置き、`deploy.yml` の deploy ジョブだけが参照する。`SENTRY_DSN` は現状どおり。`pull_request` からは配置しない。 |
| M-5 | MUST | ロールバック手順を計画に記載: (1) Cloudflare Pages のデプロイ履歴から前回成果物へ即時ロールバック、(2) それでも駄目なら `deploy.yml` を GitHub Pages 配置に戻す（移行期間中は旧ワークフローをファイル名を変えて残す）。 |
| M-6 | SHOULD | 移行完了の判定: M-8 の手動確認が全項目通り、Cloudflare Pages 上で Sentry にイベントが到達することを確認した時点で完了とする。GitHub Pages を無効化し、ロールバック用に残した旧ワークフローは次の通常 PR で削除する（流入観測に基づく段階停止は不要になった）。 |
| M-7 | SHOULD | Cloudflare Pages のブランチプレビューは `master` 以外を **Cloudflare Access で保護**するか、プレビュー配信自体を無効化する（未マージ機能の露出を防ぐ）。無料枠で可能。 |
| M-8 | MUST | 移行 PR には以下の手動確認を含める: 正規 URL でタイトル → ホーム → フレンド共有 → 別タブで `?battle=` を開いてゲストプレビューまで遷移、X intent の本文が正規 URL を含む、OGP デバッガ（X Card Validator 相当）で画像と `og:url` が正規 URL、`curl -I` で S-3 のヘッダが返る、GitHub Pages への配置が止まっている（旧 URL が更新されないこと）。 |

---

## 10. RFC 自体の受け入れ基準（人間が実装前に確認すること）

- [ ] A-1: §1 のゴール/非ゴール（特に「URL を隠さない」「auth-wall を v1 でやらない」）に同意する。
- [ ] A-2: §7 の決定（Cloudflare Pages 第一候補）に同意する。B または C を選ぶ場合はその理由を §7 に追記して Status を更新する。
- [ ] A-3: §4 の MUST（S-1, S-3, S-4, S-7, S-8, S-9）を移行 PR の完了条件として採用する。
- [ ] A-4: §5 の C-1/C-2（¥0、自動有料転換なし）を守れる構成であることを確認した。カード紐付けが必要な選択肢を含まない。
- [ ] A-5: §9 の M-1、M-2、M-4、M-5、M-8 を移行 PR の完了条件として採用する（M-3 は「GitHub Pages 停止のみ、リダイレクトなし」で確定済み）。
- [ ] A-6: §11 の未決事項に回答した（少なくとも Q1〜Q2。Q3 は回答済み）。
- [ ] A-7: 実装担当（grok-4.6）が着手する前に `docs/plans/hosting-foundation.md` の PR 順序をユーザーが承認した。

---

## 11. ユーザーへの未決事項（最大 5）

| # | 質問 | 既定（無回答時） | 影響 |
|---|---|---|---|
| Q1 | 正規 URL は `*.pages.dev` のままにするか、カスタムドメインを取るか（取るなら候補ドメイン）。 | `*.pages.dev`（¥0 を優先） | M-2 の差し替え値、S-4 の HSTS 段階導入の有無、OGP `og:url` |
| Q2 | Cloudflare アカウントは既存のものを使うか、本プロジェクト用に新規作成するか。 | 新規作成（権限分離） | M-4 のトークン発行元、将来 F8 の Workers/KV の所属 |
| Q3 | ~~github.io のリダイレクトページを残す期間。~~ **回答済み（2026-09-11）: リダイレクト不要。** 理由: まだプレイヤー・既存ツイートがなく保全対象がない。 | — | M-3 を「GitHub Pages 停止のみ」に確定。T10 は無視できるリスクへ格下げ |
| Q4 | ブランチプレビュー配信を「Access 保護で残す」か「無効化」するか。 | 無効化（最小構成） | M-7。レビュー時に実機で触れる URL があるかどうか |
| Q5 | 移行と同時に S-6（action の SHA 固定＋Dependabot）を入れるか、別 PR にするか。 | 別 PR（移行 PR を配置差し替えに限定） | PR 数と Codex レビューの粒度 |

---

## 12. 参照
- `.github/workflows/deploy.yml`、`.github/workflows/ci.yml` — 現行ビルド・配置
- `lib/presentation/screens/result_screen.dart:188-231` — X 投稿本文と `_gameUrl`
- `lib/domain/services/qr_battle_service.dart:38-51` — 共有 URL 生成（`Uri.base` 追従）
- `lib/domain/services/character_codec.dart:26-30` — HMAC 鍵と v3 形式
- `lib/data/error_monitoring.dart`、`lib/data/sentry_options.dart` — Sentry no-op と PII スクラブ
- `lib/data/firebase_options.dart` — Firebase 設定の `--dart-define` 入口
- `web/index.html` — 静的 OGP / Twitter Card
- `docs/feature-notes/share-url.md` — 共有 URL の現状と見直し点
- `docs/phase5_brushup_spec.md` §2-1（F1 Firebase Analytics）、§2-4（F6 Firestore）、§2-7（F8 Workers 動的 OGP）、§6（リスク）
- `docs/plans/error-monitoring.md` — Sentry 導入時の `--dart-define` 方針
