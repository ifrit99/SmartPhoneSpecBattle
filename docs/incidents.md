# 失敗パターンログ

## 追加ルール
- 想定外の動作をしたら、そのパターンをここに追記して`coding_rules.md`に1行ルール化する。

| 日付 | パターン | 追加ルール |
|---|---|---|
| 2026-10-22 | Firebase が書くインラインスクリプトを CSP が止め、本番でランキング参加が失敗した（#58 のあと見つかり #82） | `script-src` に `'unsafe-inline'` は足さない。ハッシュで許す。firebase の版やサービスを変えたら `web/_headers` のハッシュとテストも変える |
| 2026-11-02 | #82 の 6 ハッシュは本番に載ったが、iPhone Safari は参加 ON でまだ失敗する。Chrome は同じハッシュでインライン注入が通る。匿名 Auth・Firestore 読み取りは生きている | Safari は動的インラインの CSP ハッシュを信用しない。参加時に `web/firebase_js_preload.js` から gstatic を `import` して `window.firebase_*` を先に置く |
