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
