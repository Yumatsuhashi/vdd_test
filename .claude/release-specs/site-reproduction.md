# リリース仕様: CCIE Study Hub 完全再現 & Cloudflare Pages 対応

## 基本情報

- ブランチ: `release/site-reproduction`
- 作成日: 2026-07-14

## リリース分類

- 変更の性質: feature（元サイトの再現）
- 対象: user-facing
- バージョンタグ: minor（初回の動作する成果物）

### 判断基準チェック

- [x] ユーザーに見える動作変更を含む -> user-facing + バージョンタグ対象
- [ ] 開発者のみに影響する変更 -> developer-only、タグは任意

## ブランチ戦略

- ベースブランチ: develop
- マージ先: develop（main への直接マージは禁止）
- サブタスク分解: なし
- リモートプッシュ: 不要（テスト環境。将来 GitHub 連携時に PR）

## VDD 入力（参照）

- VISION 参照: なし（L2 のため VISION.md 未導入）
- DECISIONS 参照: なし
- 今回のリリースに効いている意思決定:
  - ユーザー選択: 専用リポジトリ化 / Policy 判定ガイドはプレースホルダー / デプロイ先 Cloudflare Pages

## サマリー

元 Cloudflare Worker で公開されていた学習 PWA「CCIE Study Hub」を、`original/` の HTML
エクスポートからローカルで完全再現する。全カードが相対パスで各コンテンツ HTML を iframe
表示し、`python3 -m http.server` で動作確認でき、`public/` を Cloudflare Pages にそのまま
デプロイできる状態にする。

## 期待される動作（受け入れ基準 / テストファースト）

> 実挙動メモ: 元サイトはカードが `<a href>` の**直接ページ遷移**方式（iframe ビューアは
> 「最後に開いたページ」機能でのみ使う休眠コード）。忠実再現のためこの挙動を維持する。
> 各コンテンツページの右下「🏠 Hub」ボタンでハブに戻る。

自動検証（`curl` によるルート/配信確認）— 完了:

- [x] 全 16 ルート（ハブ / 12 コンテンツ / manifest / icon / sw）が HTTP 200 を返す
- [x] ハブに 12 枚のカード（`card-title`）が存在する
- [x] 各ページが正しい `<title>` で配信される（穴埋めは URL エンコードのまま解決）
- [x] SDN「Policy 判定ガイド」はプレースホルダーページ（準備中）を配信する
- [x] 生成物のどのファイルにも Worker 絶対 URL が残っていない（相対化済み）
- [x] 保存時にブラウザ拡張が注入した不要要素（SciSpace/Toastify/chrome-extension）を全除去

ブラウザでの手動確認（人間 QA）— 未実施:

- [ ] ホーム画面のロゴ・統計・カードが元と同じ見た目で表示される
- [ ] 各カードのタップで対応コンテンツへ遷移し、🏠 Hub ボタンでホームに戻れる
- [ ] コンソールに 404 / CORS エラーが出ない
- [ ] 設定タブの「最後に開いたページ」「リセット」が動作する

## スコープ外

- コンテンツ HTML 自体の内容修正・レイアウト改善（元のまま流用）
- 欠落している「Policy 判定ガイド」の本来のコンテンツ作成（プレースホルダーで代替）
- GitHub リモートへの push / PR 作成（本リリースはローカルテスト環境まで）
- 実際の Cloudflare Pages へのデプロイ実行（設定・手順の整備までを含み、実デプロイは人間トリガー）
- PWA の Service Worker 実装（元エクスポートに sw.js が含まれないため、manifest のみ再現）

## 設計判断

### 方針

1. `public/` を公開ルートとし、元 Worker のパス構造（`design/`, `sdn/`, `RS/`,
   `Programmability/`）を再現してコンテンツ HTML を配置する。
2. ハブ `index.html` 内の Worker 絶対 URL（`https://delicate-pine-6fa3...workers.dev/...`）を
   相対パスに一括置換する。manifest / apple-touch-icon / theme-color もローカル生成物に差し替え。
3. 欠落する `sdn/sdn_policy_guide.html` は「準備中」プレースホルダーを新規作成し、カードは残す。
4. PWA アセット（`manifest.json`, `icon-192.png`）を新規生成する。
5. デプロイは Cloudflare Pages（`public/` を直接配信、ビルド不要）。手順を README に記載。

### 理由

- 元サイトはパス構造に依存（カードの href が固定パス）しているため、構造を維持するのが
  最も忠実かつ低リスク。
- 相対パス化により、ローカル http.server でも Cloudflare Pages でも同一挙動になる。
- Policy ガイドはソースが存在しないため、リンク切れを避けつつ後日差し替え可能な形にする。

## リスク要因

- [ ] DBマイグレーション: なし
- [ ] 認証フロー変更: なし
- [ ] API 契約変更: なし
- [ ] 外部 API 依存: なし（Worker 絶対 URL を排除するため、むしろ外部依存を除去する）
- 留意: コンテンツ HTML が内部で Worker 絶対 URL の追加リソースを参照している可能性 →
  実装時に grep で全ファイルを確認し、必要なら相対化する。
