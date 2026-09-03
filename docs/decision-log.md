# 設計判断ログ（Decision Log）

設計・方針レベルの判断を時系列で残す。実装詳細ではなく「なぜその選択をしたか」を中心に記録する。

---

## テンプレート

```
## YYYY-MM-DD: <タイトル>

- **Context**: どういう状況・制約・前提があったか
- **Decision**: 何を決めたか
- **Why**: なぜそれを選んだか（代替案と比較）
- **Consequence**: その判断による良い影響・副作用・将来のリスク
```

---

## 2026-03頃: AndroidリリースからWeb版MVPへ方針転換

- **Context**: 当初はAndroid版MVPリリースを目指していたが、MacBookのディスク容量不足で `flutter build appbundle --release` が困難、VPS（960MB RAM）ではGradle/Kotlinビルドがメモリ不足、Android実機も確保困難。
- **Decision**: WebビルドをターゲットにしたMVPへ切り替え、QR機能はURL共有に置き換える。
- **Why**: Web版なら開発機1台で完結し、GitHub Pagesで配信可能。QRカメラ機能（`mobile_scanner`）はWeb未対応のため、URLコピー/共有で十分代替可能。
- **Consequence**: `mobile_scanner` / `qr_flutter` / `share_plus` / `app_links` を除去し、`QrBattleService` のURL生成パスに集約。将来モバイル再対応時はDeep Link対応が必要。

---

## 2026-04頃: バトル結果処理を ResultScreen から BattleResultService へ分離

- **Context**: `ResultScreen` 内に経験値・コイン・図鑑・初回バトル/デイリー報酬の反映が混在し、責務が肥大化していた（Codexレビュー指摘）。
- **Decision**: `lib/domain/services/battle_result_service.dart` を新設し、結果反映ロジックをドメイン層に集約。`ResultScreen` は描画と呼び出しのみに絞る。
- **Why**: UI層にビジネスロジックを置かないという3層構造のルールに整合させ、テスト容易性を向上させる。
- **Consequence**: `battle_result_service_test.dart` を追加（全ルート網羅）。ResultScreenの変更時にロジック側が壊れにくくなった。一方、`ServiceLocator` 経由の依存が1つ増えた。

---

## 2026-09-03: キャラクターグラフィックを擬人化・成人女性キャラのイラストへ刷新

- **Context**: バトル背景（PR #32）とタイトル/OGP（PR #31）が入り、12×12 プロシージャルドット絵のキャラだけが見劣りする状態になった。背景は承認済みで維持する必要があり、戦場をうるさくしてはいけない。
- **Decision**: 「6属性 × 4アーキタイプ = 24 ペルソナ」の固定ロスターをイラストで用意し、ポートレートIDは `element` と `seed.abs() % 4`（名前接頭語と同じ式）から表示時に導出する。ドット絵はミニアイコン兼フォールバックとして残す。詳細は `docs/rfc_character_art.md`。
- **Why**: 表示時導出にすれば `Character` / `CharacterCodec` v3 / ガチャJSON を一切変えずに URL 対戦の相手も同じ画像になる。レイヤー合成は生成画像の位置合わせが困難、スペック単位の固有画像は枚数が発散するため不採用。
- **Consequence**: 既存ユーザーの見た目が変わる（意図的）。Avatar Studio の 7 スロットはミニアイコンにのみ効く。将来ポートレートを選べるようにする場合は codec v4（+1 byte）が必要。
- **追記（同日）**: 画風は『ブルーアーカイブ』のイラスト言語（クリーンな2Dアニメ立ち絵・細線・ツヤ髪・鮮やかなシルエット）を参照するが、派生物にはしない。ヘイロー・学園エンブレム・制服構成・銃火器主武装は禁止する。成人であることは設定（子ども・学生コードの不在）で担保し、顔で年齢を読ませるために写実に寄せない（RFC §2-2 / §2-4 / §2-5）。
- **承認（同日）**: プロトタイプ確認のうえアート方針を承認。バトルフィールドは立ち絵の bust ではなく、同ペルソナの SFC『FF6』風・約3頭身デフォルメピクセルスプライト（48×48 等倍・最近傍拡大）を使う。12×12 CustomPaint はミニアイコンとフォールバックのみ（RFC §2-6 / §4）。
