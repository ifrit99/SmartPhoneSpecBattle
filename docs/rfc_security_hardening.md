# RFC: セキュリティ強化（Firestore ルール・App Check・デプロイの供給網）

Created: 2026-10-12
Status: PLANNING（イフリトさんの判断待ち。§10 に回答が出るまで実装に着手しない）
Scope: 設計のみ。本RFCはプロダクトコード（Dart / Flutter）、`firestore.rules`、`.github/workflows/*`、`pubspec.yaml` を変更しない。
Related: `docs/rfc_hosting_foundation.md`（S-1 / S-2 / S-6 / S-7、T1 / T2 / T8）、`docs/plans/online-ranking.md`（F6 PR-B。ルールの正本は `firestore.rules`）、`docs/phase5_brushup_spec.md` §2-4
Implementation plan: `docs/plans/security-hardening.md`（本RFCが正本。計画は薄い順序表のみ）

---

## 0. このRFCの読み方

master（`79c5697`）を点検して見つかった 3 つの弱点について、「何が怖いのか」「どんな直し方があるのか」「いくらかかるのか（お金・手間・無料枠・匿名ログインとの相性）」を並べて、おすすめを一つ決める文書です。

- 用語はできるだけ平易にし、初出で短く説明します。
- 「実装時に確認」と書いた箇所は、2026-10 時点で公開情報から断定できなかった点です。実装席（grok-4.6）が最初に確かめ、違っていれば本RFCを直してから進めます。
- 値（API キー・トークン・サイトキー）はこの文書にも共有メモにも書きません。所在だけを書きます。

---

## 1. 現状（master `79c5697`）

| 項目 | 現状 | 根拠 |
|---|---|---|
| ランキングの書き込みルール | 本人の uid 配下にだけ書ける。`powerRating` は 0〜278 の整数なら何でも通る。`weekId`（パスの `{weekId}`）は**どんな文字列でも**通る。`expiresAt` は timestamp 型なら**いつでも**通る | `firestore.rules:13-42` |
| 読み取りルール | 匿名でもサインインしていれば全 entry を読める（上位 50 件・件数集計に必要） | `firestore.rules:39` |
| クライアントが書く値 | `weekId`＝端末ローカル日付の月曜 `yyyy-MM-dd`、`expiresAt`＝端末時計＋30 日、`updatedAt`＝サーバー時刻 | `lib/domain/services/ranking_service.dart:481,511`、`lib/data/firestore_ranking_backend.dart:54-61`、`lib/domain/services/local_league_service.dart:116-120` |
| 送信回数の抑制 | ペイロードや週が変わった時だけ送る。1 セッション 5 回まで。**ただしこれはクライアント側の行儀であり、ルールでは強制していない** | `ranking_service.dart:21,489-496` |
| ルールのテスト | Emulator 用の 6 観点（他人 uid 拒否 / 他人 entry 削除拒否 / 自分の削除許可 / 値域外 PWR 拒否 / `expiresAt` 欠落拒否 / 未認証 read 拒否）。ローカル実行のみ、CI 外 | `test/firestore/rules.test.mjs`、`test/firestore/package.json`（lockfile なし） |
| Firebase の料金プラン | Spark（無料。カード紐付けなし）。Cloud Functions は Spark では使えない | `docs/rfc_hosting_foundation.md` §5、`docs/plans/online-ranking.md` 非ゴール |
| App Check | 未導入（`pubspec.yaml` に `firebase_app_check` なし）。RFC hosting の T8 で「F6 着手時に」と予告されたまま | `pubspec.yaml:23-26`、`docs/rfc_hosting_foundation.md:77` |
| Firebase 初期化 | 参加 ON のときだけ `Firebase.initializeApp`（遅延初期化）。未参加者は Firebase JS を読み込まない | `lib/data/firebase_bootstrap.dart` |
| 想定内エラーの扱い | `permission-denied` / `unauthenticated` / `resource-exhausted` などは Sentry に送らず「推定表示」へ戻す | `ranking_service.dart:251-268` |
| CSP | enforce 済み。Firebase JS / Firestore / Identity Toolkit / Secure Token は許可済み。`frame-src` は無い（`default-src 'self'` にフォールバック） | `web/_headers` |
| デプロイ | `master` push → analyze / test / build → `npx --yes wrangler@4 pages deploy`。wrangler の版は **4 系の最新を毎回取りに行く**。lockfile なし | `.github/workflows/deploy.yml:83-91` |
| デプロイトークン | リポジトリ secrets `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID`。権限は RFC hosting S-7 で「Pages: Edit のみ」と**要件化されているが、実際にそうなっているかはダッシュボードでしか確認できない** | `deploy.yml:77-79`、`docs/plans/hosting-foundation.md` 運用メモ |
| Actions の固定 | third-party action は SHA 固定済み。Dependabot は `github-actions` のみ（`npm` / `pub` は未設定） | `.github/dependabot.yml` |
| 固定された公開値 | `CharacterCodec` の HMAC 鍵はリポジトリに平文で入っている（カジュアル改ざん検知用。RFC hosting S-8 で据え置き確定） | `lib/domain/services/character_codec.dart:32` |

---

## 2. 範囲外（このRFCでは扱わない）

- **HSTS**: 独自ドメインを決めるまで扱わない（RFC hosting S-4 のとおり。`*.pages.dev` は Cloudflare 側で HSTS 済み）。
- `CharacterCodec` の鍵や形式の変更（RFC hosting S-8）。
- ランキングに報酬を付けること（付けない方針が、ズルの実害を小さくしている土台）。
- Cloud Functions / Blaze プランへの移行（§4-3 で比較のために触れるが、採用しない）。
- Sentry 側の設定（Allowed Domains は hosting PR-0 で済み）。

---

## 3. 守りたいもの・怖いこと（脅威の整理）

| # | 怖いこと | 誰が・どうやって | 困る度合い | 対応する課題 |
|---|---|---|---|---|
| T-R1 | **ランキングのズル**: 本当は弱いのに `powerRating: 278` と書いて 1 位になる | 匿名ログイン済みの人が、DevTools や自作スクリプトで Firestore に直接書く | 中（報酬なしなので実害は「見た目」だけ。ただし上位 50 件が偽物で埋まると機能が死ぬ） | 課題1・課題2 |
| T-R2 | **ゴミデータでの詰まらせ**: 好きな `weekId` に好きなだけ書き、`expiresAt` を 100 年後にして TTL でも消えないようにする | 同上 | 中（Spark では**お金は増えない**。代わりに 1 日の書き込み枠 2 万回・保存 1 GiB・読み取り枠 5 万回が食われ、その日のランキングが全員「推定表示」に落ちる。TTL をすり抜けた分は手で消すしかない） | 課題1・課題2 |
| T-R3 | **読み取り枠の枯渇**: 匿名ログインだけして上位一覧を何万回も読む | 同上 | 低〜中（同上。無料枠切れで機能停止、課金はされない） | 課題2 |
| T-R4 | **匿名アカウントの量産**（サイビル）: 1 人が何百 UID も作って N を水増し、上位を独占 | スクリプトで `signInAnonymously` を繰り返す | 低〜中 | 課題2（完全には防げない） |
| T-D1 | **配信物のすり替え**: `wrangler` の新しい版（または依存パッケージ）が悪意ある内容に差し替えられ、デプロイ時に動いてトークンを盗む／別の成果物を配信する | npm サプライチェーン攻撃 | 高（全プレイヤーに配られる。RFC hosting T1 と同じ） | 課題3 |
| T-D2 | **デプロイトークンの漏洩時の被害範囲**: 権限が広いと Pages 以外（DNS・Workers・アカウント設定）まで触られる | ログ流出・設定ミス | 高（権限最小化は「漏れた時の保険」） | 課題3 |

### 3-1. 重要な前提: 「本当の戦闘力」はサーバーに存在しない

対策を選ぶ前に、一つだけ押さえておく事実があります。`powerRating` は、端末のスペックからクライアントが生成したキャラの Lv1 素体ステータスで計算した値です（`PowerRatingService.powerScore`）。**端末スペックそのものをサーバーが確かめる手段はありません。** `characterCode` にステータスは入っていますが、HMAC 鍵が公開値（§1 最終行）なので、最強ステータスの `characterCode` を作って正しい署名を付けることも可能です。

つまり、Cloud Functions や Workers でサーバー側に「検証」を置いても、できるのは「`characterCode` の中身と `powerRating` の計算が一致しているか」「各ステータスが生成器の上限内か」の確認までで、**本物の 278 と偽物の 278 を区別することはできません**。これは §4-3 で「サーバー検証はコストの割に効き目が薄い」と判断する根拠になります。

---

## 4. 課題1【中】: `firestore.rules` の緩さ

### 4-1. 何が起きうるか（§3 の T-R1 / T-R2）
- `powerRating` のズル: 値域 0〜278 の中なら自由。ただし §3-1 のとおり、**ルールでもサーバーでも「本物かどうか」は判定できない**。できるのは「アプリ外からの書き込みを難しくする」こと（課題2）と「報酬を付けない」こと（済み）。
- `weekId` が自由: `rankings/あああ/entries/{自分}` にも書ける。ランキング表示は今週の `weekId` しか読まないので**見た目は壊れない**が、ゴミ文書が増える。
- `expiresAt` が自由: 遠い未来にすると TTL が永久に消さない。過去にすると TTL が即消す（これは害がない）。
- 送信頻度が自由: ルール上は 1 秒に何回でも更新できる（クライアントの 5 回/セッションは紳士協定）。

### 4-2. 直し方の案

| 案 | 内容 | 防げること | 防げないこと | お金 | 手間 | 無料枠・匿名ログインとの相性 |
|---|---|---|---|---|---|---|
| R-0 現状維持 | 何もしない | — | T-R1 / T-R2 すべて | ¥0 | 0 | 問題なし |
| **R-1 ルールを締める** | `weekId` を「`yyyy-MM-dd` の月曜、かつ今週（±端末の時差）」に限定。`expiresAt` を「今より後、かつ今＋31 日以内」に限定 | T-R2 のほぼ全部（1 UID あたり書ける文書が今週＋週替わり直後の前週の最大 2 件になる。TTL すり抜けが消える） | T-R1（値域内のズル）、T-R3、T-R4 | ¥0 | 小（`firestore.rules` とルールテストだけ。Dart 変更なし） | 問題なし。クライアントの書き方は既にこの範囲に収まっている |
| R-2 R-1＋更新間隔の下限 | 同じ文書の `update` は前回 `updatedAt` から 30 秒以上空いていないと拒否 | 同一 UID からの連打（枠食い） | 新規 UID を作っての連打（T-R4） | ¥0 | 小（ルール 1 行＋テスト 2 観点） | 問題なし。クライアントは `permission-denied` を想定内として推定表示に戻し、次回ロードで再送する（`ranking_service.dart:257,489-496`）ので壊れない |
| R-3 Cloud Functions で検証 | 書き込みを Functions 経由にし、`characterCode` を復号して `powerRating` を再計算 | 「コードと PWR の不一致」だけ | **本物の 278 と偽物の 278 の区別**（§3-1）、T-R3 | **Blaze 必須＝カード紐付け**。RFC hosting C-2 と衝突 | 大（Functions の TypeScript へ `CharacterCodec` を移植、サービスアカウント運用） | 無料枠方針と**合わない** |
| R-4 Cloudflare Workers で検証 | 同上を Workers（無料 10 万 req/日）で行い、サービスアカウントで Firestore REST に書く | R-3 と同じ | R-3 と同じ。加えて Worker に**サービスアカウント鍵という本物の秘密**を持つことになる | ¥0（枠内） | 大（Dart の codec を JS に移植、ID トークン検証、鍵管理） | 枠内だが、守れるものに対して複雑すぎる |

### 4-3. おすすめ: **R-1 を必ず。R-2 は任意（Q2）**

理由:
1. T-R2（ゴミ・TTL すり抜け）は R-1 で**ほぼ完全に**止まる。費用ゼロ、Dart 変更なし。
2. T-R1（値域内ズル）はルールでもサーバーでも止められない（§3-1）。R-3 / R-4 は「大きな手間とカード紐付け（R-3）または本物の秘密の運用（R-4）」を払って、ほぼ何も増えない。**不採用**。ズルへの現実的な対策は「アプリ外からの書き込みを難しくする」課題2（App Check）と、既に決まっている「報酬なし」。
3. R-2 は枠食いへの保険として安価だが、週替わり直後やテストで引っかかる場面が増える。最初の運用で枠が食われる兆候が出てからでも遅くない。

### 4-4. R-1 のルール案（実装 PR で `firestore.rules` に反映する）

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // MAX_PWR = 278（根拠は現行コメントのまま）
    // TTL_MAX_DAYS = 31: クライアントの rankingEntryTtlDays(30) ＋ 端末時計ずれ 1 日分
    function isSignedIn() {
      return request.auth != null;
    }

    // weekId は「月曜の日付」yyyy-MM-dd。形式→実在日→月曜→今週の順に確かめる。
    function weekStart(weekId) {
      return timestamp.date(int(weekId[0:4]), int(weekId[5:7]), int(weekId[8:10]));
    }

    function isValidWeekId(weekId) {
      return weekId.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
        && weekStart(weekId).dayOfWeek() == 1
        // 端末ローカル日付の月曜なので、UTC の今より最大 1 日先行し得る。
        // 週替わり直後の端末差で前週に書くことも許す（今から 8 日前まで）。
        && weekStart(weekId) <= request.time + duration.value(1, 'd')
        && weekStart(weekId) >= request.time - duration.value(8, 'd');
    }

    function isValidExpiresAt(expiresAt) {
      return expiresAt is timestamp
        && expiresAt > request.time
        && expiresAt <= request.time + duration.value(31, 'd');
    }

    function isValidRankingEntry(uid, weekId) {
      let d = request.resource.data;
      return isSignedIn()
        && request.auth.uid == uid
        && isValidWeekId(weekId)
        && d.uid == uid
        && d.keys().hasOnly(['uid', 'powerRating', 'characterCode', 'title', 'updatedAt', 'expiresAt'])
        && d.uid is string
        && d.powerRating is int
        && d.powerRating >= 0
        && d.powerRating <= 278
        && d.characterCode is string
        && d.characterCode.size() <= 256
        && d.title is string
        && d.title.size() <= 32
        && d.updatedAt == request.time
        && isValidExpiresAt(d.expiresAt);
    }

    match /rankings/{weekId}/entries/{uid} {
      allow read: if isSignedIn();
      allow create: if isValidRankingEntry(uid, weekId);
      allow update: if isValidRankingEntry(uid, weekId);
      // R-2 を採る場合は update を次に差し替える:
      //   && request.time >= resource.data.updatedAt + duration.value(30, 's')
      allow delete: if isSignedIn() && request.auth.uid == resource.data.uid;
    }

    match /{path=**}/entries/{entryId} {
      allow read, delete: if isSignedIn()
        && resource.data.uid == request.auth.uid;
    }
  }
}
```

実装時に確認する点:
- `int('08')` のように先頭 0 付きの文字列を `int()` が受けるか。受けない場合は `weekId[5:6] == '0' ? int(weekId[6:7]) : int(weekId[5:7])` の形に逃がす（日も同様）。
- 実在しない日付（`2026-02-30`）で `timestamp.date()` がエラーになる場合、ルール評価のエラーは**拒否**として扱われるので目的どおり。テストで 1 観点入れる。
- 窓の幅（−8 日 / ＋1 日）は端末の時差（UTC−12〜＋14）を含めて今週の月曜が必ず入る値。前週の月曜は「新しい週に入って最初の 1 日だけ」通る。これは `docs/plans/online-ranking.md` 既知の制約「週境界付近のタイムゾーン差を許容」と整合する。
- 既存テスト `rules.test.mjs` の固定 `weekId`（`2026-05-04`）は過去日になるため、**テスト実行日の月曜を計算して使う**ヘルパーに差し替える。

クライアント（Dart）の変更は不要。`expiresAt` は端末時計＋30 日で、ルールの上限は 31 日なので、端末時計が 1 日以上進んでいる場合だけ拒否される（→ 推定表示に戻るだけ。壊れない）。ルールと Dart の定数の対応は `firestore.rules` のコメントに `rankingEntryTtlDays` を明記して残す。

---

## 5. 課題2【中】: App Check が入っていない

### 5-1. App Check とは・何が防げて何が防げないか
App Check は「この Firestore へのリクエストは、**本物のアプリ（本物のサイト）から、本物のブラウザで**送られたものか」を Google 側で確かめる仕組みです。Web では reCAPTCHA v3 がブラウザを見て「人間らしさ」を点数化し、合格すると短命のトークンが出ます。Firestore は「App Check を強制」にすると、トークンの無いリクエストを**ルール以前に**蹴ります。

- 防げる: 自作スクリプト・curl・別サイトからの直接書き込み／読み取り（T-R1 の大半、T-R2 / T-R3 / T-R4 の自動化された分）。
- 防げない: 本物のサイトを開いた状態で DevTools から SDK を操作するズル（トークンはそのページに正当に発行されているため）。**App Check は「ズルを面倒にする」道具であって、「不可能にする」道具ではありません。**
- App Check 自体は無料。reCAPTCHA の評価回数に無料枠がある（§5-2）。

### 5-2. 直し方の案

| 案 | 内容 | 防げること | お金 | 手間 | 無料枠・匿名ログインとの相性 |
|---|---|---|---|---|---|
| A-0 入れない | 現状維持。ルール（課題1）だけで守る | — | ¥0 | 0 | 問題なし |
| **A-1 reCAPTCHA v3（従来型）で段階導入** | `firebase_app_check` を追加し、参加 ON の遅延初期化の直後に `activate`。Firebase コンソールでまず**監視モード**（蹴らずに「正規トークン付きの割合」だけ見る）、割合がほぼ 100% と確認できたら Firestore だけ**強制**に切替 | §5-1「防げる」の全部 | **¥0 の見込み**。App Check は無料。reCAPTCHA v3 の無料評価回数は 2026-10 時点で要確認（以前は月 100 万回、近年「月 1 万回まで無料・超過は有料」への改定が案内されている）。トークン寿命を既定（1 日。実装時に確認）にすれば 1 参加者 1 日 1 回程度＝月 1 万回には余裕 | 中（pubspec・`firebase_bootstrap.dart`・`--dart-define=RECAPTCHA_SITE_KEY`・`web/_headers` の CSP・テスト。コンソール作業あり） | 匿名ログインとは独立に動く（Auth 側の強制は Identity Platform 化が必要なので**やらない**。Firestore だけ強制で目的は足りる）。参加 ON のときだけ reCAPTCHA を読む設計にすれば「未参加者は Google に何も送らない」を保てる |
| A-2 reCAPTCHA Enterprise | A-1 の提供元を Enterprise に | A-1 と同じ＋細かい分析 | 月 1 万評価まで無料、超過は有料。GCP の請求先設定が要る場合がある | A-1 と同じ＋GCP 設定 | ¥0 方針と相性が悪い。A-1 の従来型キーが作れなくなった場合の代替 |
| A-3 Web API キーの参照元制限だけ | GCP コンソールで Firebase の Web API キーに「HTTP リファラー＝pages.dev と localhost」「API＝Firestore / Identity Toolkit / Token Service（＋App Check を入れるなら Firebase App Check API / Installations API）」の制限を掛ける | 雑なスクリプト（Referer を偽装しない相手） | ¥0 | 小（コンソールのみ、コード変更なし） | 問題なし。ただし制限を間違えると**本番の匿名ログインが全部落ちる**ので、設定直後に pages.dev で参加 ON→順位表示を必ず確認する |

### 5-3. おすすめ: **A-1 を段階導入（監視→強制）。A-3 は A-1 と独立にコンソール作業として実施（Q7）**

理由:
1. 課題1（R-1）で「ゴミと TTL すり抜け」は止まるが、「値域内のズル」と「枠食い」はアプリ外からの直接アクセスを難しくするしか手がない（§3-1）。それができる無料の道具が App Check。
2. 遅延初期化（参加 ON のときだけ Firebase を読む）と相性が良く、**未参加者の体験・通信量・プライバシーは変わらない**。
3. 監視モードから始めれば、誤って本物のプレイヤーを蹴る事故を避けられる。強制の ON/OFF はコンソールのトグルだけで、デプロイ無しで戻せる。
4. 強制後に蹴られたリクエストは `permission-denied` になり、既存の想定内エラー処理（§1）で「推定表示」に戻る。Sentry にも流れない。

A-1 の設計上の要点（実装 PR で守ること）:
- `activate` は `ensureFirebaseInitialized()` の中で `Firebase.initializeApp` の**直後、Firestore / Auth を使う前**に 1 回だけ呼ぶ。起動時には呼ばない（現行の遅延初期化の原則そのまま）。
- サイトキーは公開値（RFC hosting S-1 の扱い）。`--dart-define=RECAPTCHA_SITE_KEY` で渡し、空なら `activate` を**しない**（secrets 未設定・ローカル・CI で No-op）。
- CSP（`web/_headers`）に追加が要る見込み: `script-src` に `https://www.google.com/recaptcha/` `https://www.gstatic.com/recaptcha/`、**新設の `frame-src`** に `https://www.google.com/recaptcha/` `https://recaptcha.google.com/recaptcha/`、`connect-src` に `https://firebaseappcheck.googleapis.com`。実際に必要なドメインは PR-A' と同じく DevTools の CSP violation で確定する。`frame-ancestors 'none'` はそのまま（これは「埋め込まれない」側の設定で無関係）。
- ローカル開発（`flutter run -d chrome`）: reCAPTCHA のサイトキーに `localhost` を登録するか、App Check のデバッグトークンをコンソールに登録する。`web/index.html` にデバッグフラグを**書き込まない**（本番成果物に混ざるため）。
- 強制の順番: Firestore のみ。Authentication の強制は Identity Platform へのアップグレードが要るので対象外。Storage / Functions は未使用。
- プライバシー: reCAPTCHA は Google にブラウザ情報を送る。参加 ON のときだけ読み込むので「ランキング参加＝Google への送信に同意」とみなせるが、遊び方ヘルプまたは参加トグル付近の一文に「参加中は Google reCAPTCHA を使う」と書くかはイフリトさんの判断（Q3）。

---

## 6. 課題3【低〜中】: `deploy.yml` の `npx --yes wrangler@4`（版が浮いている）とトークン権限

### 6-1. 何が起きうるか（§3 の T-D1 / T-D2）
- `wrangler@4` は「4 系の最新」を**毎回 npm から**取ってくる。lockfile が無いので wrangler 本体だけでなく、その下の数百個の依存パッケージも毎回最新が解決される。どれか一つが乗っ取られると、デプロイジョブの中で `CLOUDFLARE_API_TOKEN` を持った状態で動く。GitHub Actions 本体は SHA 固定済みなのに、ここだけ穴が残っている。
- トークンの権限が広いと、漏れたときに Pages 以外も触られる。現状は要件（S-7）だけで、実物の権限は未確認。

### 6-2. 直し方の案

| 案 | 内容 | 防げること | お金 | 手間 | 自動追従（Dependabot） |
|---|---|---|---|---|---|
| D-0 現状維持 | `wrangler@4` | — | ¥0 | 0 | — |
| D-1 版だけ固定 | `npx --yes wrangler@4.x.y` と完全な版を書く | wrangler 本体の勝手な更新 | ¥0 | 最小 | **できない**（Dependabot は yml の中の npx 文字列を追えない）。更新を忘れて古いまま化しやすい。依存パッケージは固定されない |
| **D-2 lockfile で固定** | `tool/deploy/package.json`（`wrangler` を完全版で devDependency）＋ `package-lock.json` を置き、`npm ci --prefix tool/deploy` → `npx --prefix tool/deploy wrangler ...`。`.github/dependabot.yml` に `npm`（`/tool/deploy`）を追加 | wrangler 本体と**依存パッケージ全部**の勝手な更新（lockfile の整合性ハッシュで中身も検証される） | ¥0 | 小（ファイル 2 つ＋ yml の数行） | **できる**。週次で PR が来る。GitHub Actions の SHA 固定と同じ運用に揃う |
| D-3 `cloudflare/wrangler-action` | 公式 action を SHA 固定で使う | action 自体は固定。ただし action が内部で `npm install wrangler@<版>` を実行時に行うため、依存パッケージは固定されない | ¥0 | 小 | action の SHA は Dependabot が追う。wrangler の版は action 側の既定に依存 |

### 6-3. おすすめ: **D-2**。トークンは「Pages: Edit だけ・対象アカウント限定・有効期限あり」で**発行し直す**

理由: D-2 だけが「依存パッケージまで含めて固定」と「Dependabot で自動追従」を両立する。D-3 は見た目は簡単だが、固定の効き目は D-1 と変わらない。

実装 PR で守ること:
- `npm ci`（`npm install` ではなく）。lockfile と違う内容は失敗させる。`--ignore-scripts` を付けて install スクリプトの実行を止める（`wrangler pages deploy` は `workerd` を使わないので動くはず。動かなければ外して理由を PR 本文に書く）。
- ステップの先頭で `npx --prefix tool/deploy wrangler --version` をログに出し、固定した版が使われていることを確認できるようにする。
- `test/firestore/package.json` にも lockfile を追加し、同じく Dependabot の対象にする（ついで。別 PR でも可）。
- 任意（スコープ外だが 1 行で直せる）: `grep -F "${CF_PAGES_PROJECT}"` は部分一致なので `smartphonespecbattle-xxx` という別プロジェクトがあっても「存在する」と誤判定する。`pages project list` の出力を見て行頭一致にする。

トークンの最小化（コンソール作業。コード変更なし。PR-S2 の検証と同時に行う）:
1. Cloudflare → My Profile → API Tokens → Create Custom Token。Permissions は **Account / Cloudflare Pages / Edit** の 1 行だけ。Account Resources は **Include / 本プロジェクトのアカウントのみ**。TTL（有効期限）を付ける（Q6。既定は 1 年）。Client IP filtering は GitHub Actions の IP が広すぎるので使わない。
2. 新トークンを GitHub secrets `CLOUDFLARE_API_TOKEN` に上書き → `deploy.yml` を `workflow_dispatch` で手動実行 → `pages project list` と `pages deploy` が通ることを確認。
3. 通ったら**旧トークンを失効**。失敗したら旧に戻し、足りない権限を 1 つずつ足す（`CLOUDFLARE_ACCOUNT_ID` を渡しているので Memberships / User Details は不要の見込み。実装時に確認）。

---

## 7. 確認方法を決めておくもの（人が画面で見る前提）

結果は値を書かず「確認日・OK/NG・直した内容」だけを Mac 側の共有 `STATUS.md` の当該タスク欄に 1 行で残す（AGENTS.md の運用どおり。本リポには残さない）。

### 7-1. 本番 Firebase の設定（Firebase コンソール / GCP コンソール）
| 見る場所 | 期待する状態 |
|---|---|
| 料金プラン | **Spark** のまま。カード紐付けなし |
| Authentication → Sign-in method | **匿名のみ** ON。他プロバイダは OFF |
| Authentication → Settings → 承認済みドメイン | `smartphonespecbattle.pages.dev` と `localhost`（＋Firebase 既定の 2 つ）。それ以外が無い |
| Authentication → Settings → ユーザー アクション | 匿名アカウントの自動クリーンアップ ON |
| Firestore → ルール | **リポジトリの `firestore.rules` と同一**（公開日時が PR-S1 マージ後）。差分があれば貼り直す |
| Firestore → TTL | コレクショングループ `entries` / フィールド `expiresAt` のポリシーが **Active**（`docs/plans/online-ranking.md` PR-0 の項目。未設定なら今回設定する） |
| Firestore → インデックス | コレクショングループ `entries` の `uid` 単一フィールド（コレクショングループ スコープ）が有効 |
| Firestore → 使用状況 | 読み取り / 書き込み / 削除の日次がそれぞれ無料枠（目安 5 万 / 2 万 / 2 万）に対し十分余裕。急な山が無い |
| Firestore → データ | `rankings/` 直下に `yyyy-MM-dd` 以外の文書が無い（PR-S1 以前に入ったゴミがあれば手で消す） |
| App Check（A-1 採用時） | Web アプリに reCAPTCHA v3 が登録、Firestore の状態が「監視中」→（判断後）「強制」。「未検証リクエスト」の割合がほぼ 0% |
| GCP → API とサービス → 認証情報 → Web API キー | A-3 の参照元制限と API 制限が掛かっている（設定直後に pages.dev で参加 ON → 順位表示まで動くことを確認） |

### 7-2. 本番 Cloudflare の設定（Cloudflare ダッシュボード）
| 見る場所 | 期待する状態 |
|---|---|
| Workers & Pages → `smartphonespecbattle` | Production branch `master`。Git 連携なし。プレビュー配信なし。カスタムドメインなし（HSTS は範囲外） |
| 直近デプロイのソース | GitHub Actions の `master` SHA と一致（手でアップロードした跡が無い） |
| My Profile → API Tokens | デプロイ用トークンが **1 本だけ**、権限 Pages: Edit のみ、アカウント限定、有効期限あり。使っていないトークンが無い |
| アカウント → Members / 2FA | メンバーは本人のみ。2 要素認証 ON |
| 監査ログ（Audit Log） | トークンの利用が Actions の実行時刻以外に無い |

### 7-3. GitHub 側
| 見る場所 | 期待する状態 |
|---|---|
| Settings → Secrets and variables → Actions | 名前が `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` / `SENTRY_DSN` / `FIREBASE_*`（4 つ）／A-1 採用後は `RECAPTCHA_SITE_KEY`。不要な名前が無い。値は見ない |
| Settings → Branches | `master` に直接 push できない保護がある（AGENTS.md の運用と一致） |
| Settings → Code security | Dependabot alerts / security updates ON。**secret scanning alerts** ON（公開リポは無料）。`pub` エコシステムがアラート対象かをここで確認（§7-4） |

### 7-4. 依存部品の既知の弱点（脆弱性）
- **一次手段**: GitHub の Dependabot alerts（§7-3）。`pub` が対象として表示されるならそれを信頼する。表示されない場合は次の手段。
- **二次手段（どちらも無料、ローカルで実行して画面で見る）**: `osv-scanner --lockfile pubspec.lock`（Dart も Node も読める）。Node 側は `npm audit --prefix tool/deploy` と `--prefix test/firestore`（lockfile 追加後）。
- Flutter 側の更新候補は `flutter pub outdated`。Dependabot の **`pub` 版更新**（version updates）を `.github/dependabot.yml` に足すかは Q9。
- 頻度: 月 1 回＋Dependabot アラート到着時。結果は §7 冒頭のとおり 1 行だけ残す。

### 7-5. git 履歴に秘密情報がないか
- 道具: `gitleaks git .`（または `gitleaks detect --source . --log-opts=--all`）と `trufflehog git file://. --only-verified` をローカルで実行し、**出力は画面で見るだけ**（ファイルや共有メモに貼らない）。
- 先に「公開値・意図的な平文」を分かっておく（検出されても慌てない）: `CharacterCodec` の HMAC 鍵（`character_codec.dart:32`。S-8 で据え置き確定）、`SITE_URL` / プロジェクト名、Sentry DSN（値はリポに無いが、あっても公開値）。Firebase 設定値はリポに無い（dart-define 経由）。
- 履歴にだけ残っているファイルの点検対象: `.claude/settings.local.json`（`ec40f27`〜`c8b0dd9` の間に存在。ローカル権限設定で、トークンではなくパスが入っている見込み。中身を一度見て確認）。
- **本物の秘密が見つかった場合**: まず**失効・再発行**（公開リポなので「もう漏れた」前提）。履歴の書き換えは効果が薄く他の作業者のクローンも壊すので、原則やらない（Q8）。

---

## 8. 実装 PR の分け方と順番

各 PR は実装席 grok-4.6 → レビュー（Plus 無しのため thermos + grok-4.6 high）→ イフリトさんがマージ判断。同時編集者は 1 人なので順に進める。PR-S1 と PR-S2 は互いに独立。PR-S3 は Q3 の回答が「導入する」のときだけ。

| 順 | ブランチ（案） | 触るもの | 内容 | 規模 | 前提 |
|----|---|---|---|---|---|
| PR-0 | （イフリトさんの作業。PR なし） | コンソール | §7-1 / §7-2 / §7-3 の確認。TTL ポリシー未設定なら設定。A-1 採用なら reCAPTCHA v3 サイトキーを作成し GitHub secrets `RECAPTCHA_SITE_KEY` に登録（サイトキーのドメインに pages.dev と localhost）。§7-5 の履歴点検 | — | §10 の回答 |
| PR-S1 | `feature/firestore-rules-hardening` | `firestore.rules`、`test/firestore/rules.test.mjs`、（任意）`test/firestore/package-lock.json` | §4-4 の R-1（Q2 が Yes なら R-2 も）。既存 6 観点を残し、§9-1 の観点を追加。固定 `weekId` を「実行日の月曜」に差し替え | 小 | Q1 |
| PR-S1 後 | （イフリトさんの作業） | Firebase コンソール | 新しい `firestore.rules` を貼り付けて公開（従来どおり CI からはやらない。Q10）。pages.dev で参加 ON → 順位表示を確認 | — | PR-S1 マージ |
| PR-S2 | `feature/deploy-wrangler-pin` | `tool/deploy/package.json`、`tool/deploy/package-lock.json`、`.github/workflows/deploy.yml`、`.github/dependabot.yml` | §6-3 の D-2。`workflow_dispatch` で検証 | 小 | Q5 |
| PR-S2 後 | （イフリトさんの作業） | Cloudflare / GitHub | §6-3 の手順でトークンを最小権限で発行し直し、旧を失効 | — | PR-S2 マージ |
| PR-S3 | `feature/app-check-recaptcha` | `pubspec.yaml`、`lib/data/firebase_bootstrap.dart`、`.github/workflows/ci.yml` / `deploy.yml`（`--dart-define=RECAPTCHA_SITE_KEY`）、`web/_headers`、`test/` | §5-3 の A-1。監視モードで本番確認。CSP の追加分を PR-A' の前例どおり別 PR にするかは実装席の判断（キーが空なら No-op なので、どちらの順でも壊れない） | 中 | Q3 / Q4、PR-0 のサイトキー |
| PR-S3 後 | （イフリトさんの作業） | Firebase コンソール | App Check の指標を数日見て「未検証」がほぼ 0% なら Firestore を**強制**に切替。問題が出たらトグルで戻す | — | PR-S3 マージ＋デプロイ |

本RFCの文書と `docs/plans/security-hardening.md` は本 PR（docs のみ）。`docs/plans/online-ranking.md` の「セキュリティルール要約」「既知の制約」は PR-S1 マージ時に実装席が追記修正する（本 PR では触らない）。

---

## 9. 受け入れ基準とテスト方法

### 9-1. PR-S1（ルール）
ルールテスト（`cd test/firestore && npm ci && npm test`。Emulator ローカル実行。結果を PR 本文に貼る）:

| # | 観点 | 期待 |
|---|---|---|
| 既存 1〜6 | 他人 uid 書き込み / 他人 entry 削除 / 自分の削除 / 値域外 PWR / `expiresAt` 欠落 / 未認証 read | 従来どおり |
| 7 | `weekId` が今週の月曜（テスト実行日から計算） | 許可 |
| 8 | `weekId` が形式違い（`abc`、`2026-5-4`、`2026/05/04`） | 拒否 |
| 9 | `weekId` が月曜以外（今週の火曜） | 拒否 |
| 10 | `weekId` が実在しない日（`2026-02-30`） | 拒否 |
| 11 | `weekId` が 3 週間前の月曜 / 2 週間後の月曜 | 拒否（前週の月曜は実行曜日で結果が変わるので**テストしない**） |
| 12 | `expiresAt` が今＋30 日 | 許可 |
| 13 | `expiresAt` が今＋40 日 / 今より過去 / 文字列 | 拒否 |
| 14（R-2 時） | 作成直後の同一文書 `update` | 拒否。削除→再作成は許可 |

その他:
- Dart 変更なし。`flutter analyze` / `flutter test` は未変更で通ることを確認（実行はする）。
- `firestore.rules` のコメントに「31 日 = `rankingEntryTtlDays`(30) ＋ 1 日」と「窓 −8 日 / ＋1 日の理由」を残す。
- 本番公開後（イフリトさん）: pages.dev で参加 ON → 「世界○位」表示 → OFF → 推定表示へ戻る。Firestore コンソールで文書が今週の `weekId` にだけある。

### 9-2. PR-S2（デプロイ固定）
- `tool/deploy/package-lock.json` が存在し、`wrangler` が完全版で固定されている。
- `workflow_dispatch` の実行ログで `wrangler --version` が lockfile の版と一致し、`pages deploy` が成功。pages.dev が更新される。
- Dependabot が `/tool/deploy` の `npm` を対象にしている（設定後 1 週間以内に wrangler の更新 PR が来るか、または「最新です」の表示）。
- トークン差し替え後（イフリトさん）: 新トークンだけで `workflow_dispatch` が成功。Cloudflare のトークン一覧に旧トークンが無い。

### 9-3. PR-S3（App Check）
- `flutter analyze` エラー 0 / `flutter test` 全パス。`firebase_bootstrap` のテストに「サイトキー空なら `activate` を呼ばない」「`initializeApp` の後に 1 回だけ呼ぶ」を追加。
- `flutter build web --release` の `main.dart.js` サイズ差分を PR 本文に記録（PR-A と同じ流儀）。
- DevTools（pages.dev、新規プロファイル）:
  - 参加 OFF: `recaptcha` / `firebaseappcheck` への通信が **0 件**。
  - 参加 ON: `firebaseappcheck.googleapis.com` への通信が出て、Console に CSP violation が無い。順位が表示される。
- Firebase コンソール App Check → Firestore の指標で「検証済み」がほぼ 100%。
- 強制 ON 後（イフリトさん）: アプリは従来どおり動く。ブラウザ外から Firestore REST に匿名 ID トークンだけで読もうとすると拒否される（人が 1 回だけ試す。手順は PR 本文に書く）。
- 強制で蹴られた場合でもアプリは「推定表示」に戻り、Sentry に新規イベントが増えない。

---

## 10. イフリトさんに判断してもらう点

無回答の場合は「既定」で進めて良い項目と、回答が要る項目を分けています。

| # | 質問 | 既定 | 影響 |
|---|---|---|---|
| Q1 | 課題1 を R-1（`weekId` 形式・今週限定、`expiresAt` 31 日以内）で締めてよいか | **Yes** | PR-S1 の内容。費用ゼロ・Dart 変更なし |
| Q2 | R-2（同一文書の更新は 30 秒空ける）も入れるか | **No**（枠食いの兆候が出てから） | ルール 1 行＋テスト 2 観点 |
| Q3 | App Check を今入れるか、PR-C（ランキング UI）で参加者が付くまで待つか。入れる場合、参加トグル付近に「参加中は Google reCAPTCHA を使う」の一文を出すか | **今入れる（監視モード）。強制は指標を見てから。一文は出す** | PR-S3 の有無と内容。未参加者には影響なし |
| Q4 | reCAPTCHA は従来型 v3 を使う。作れない／無料枠が月 1 万回未満だった場合は Enterprise にせず**一旦見送る**でよいか | **Yes（見送り）** | ¥0 方針の維持 |
| Q5 | wrangler の固定は D-2（`tool/deploy/` に lockfile）でよいか。置き場所はリポ直下ではなく `tool/deploy/` | **Yes** | PR-S2。Dependabot の `npm` 追加 |
| Q6 | Cloudflare トークンの有効期限 | **1 年。期限 1 か月前にカレンダー通知** | 年 1 回の差し替え作業（§6-3 の 3 手順） |
| Q7 | Firebase Web API キーの参照元・API 制限（A-3）をコンソールで掛けるか | **Yes**（設定直後に pages.dev で参加 ON→順位表示を確認する条件付き） | 間違えると匿名ログインが全部落ちる。戻すのもコンソールのみ |
| Q8 | 履歴点検（§7-5）で本物の秘密が見つかった場合、失効・再発行だけで済ませ、履歴書き換えはしない | **Yes** | 公開リポの現実に合わせる |
| Q9 | Dependabot に `pub` の版更新も足すか（週次で Flutter パッケージの PR が来る） | **No**（月 1 回の `flutter pub outdated` と OSV-Scanner で足りる。PR が増えすぎる） | レビュー負荷 |
| Q10 | `firestore.rules` の公開は従来どおりコンソール貼り付け（CI からは配備しない） | **Yes** | CI にサービスアカウントの秘密を持ち込まない |

---

## 11. 参照
- `firestore.rules` — 現行ルール（§1、§4）
- `test/firestore/rules.test.mjs`、`test/firestore/package.json` — 現行ルールテスト
- `lib/domain/services/ranking_service.dart` — 送信条件・TTL 定数・想定内エラー判定
- `lib/data/firestore_ranking_backend.dart` — 書き込む項目
- `lib/data/firebase_bootstrap.dart` — 遅延初期化（App Check の差し込み点）
- `lib/domain/services/local_league_service.dart:116-120` — `weekId` の計算
- `lib/domain/services/character_codec.dart:32` — 公開の HMAC 鍵（§3-1、§7-5）
- `web/_headers` — CSP（App Check で追加が要る箇所）
- `.github/workflows/deploy.yml:76-91` — wrangler 実行箇所
- `.github/dependabot.yml` — 現状 `github-actions` のみ
- `docs/rfc_hosting_foundation.md` §2-2（T1 / T2 / T8）、§4-1（S-1 / S-2 / S-6 / S-7）、§5（無料枠）
- `docs/plans/online-ranking.md` — F6 の PR-0 チェックリスト（TTL・インデックス・承認済みドメイン）、セキュリティルール要約、既知の制約
- `docs/phase5_brushup_spec.md` §2-4 — データモデルと「不正対策の割り切り」
