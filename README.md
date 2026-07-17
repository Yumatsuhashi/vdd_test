# CCIE Study Hub（再現版）

CCIE EI Lab 学習用の静的 Web アプリ「CCIE Study Hub」の再現プロジェクト。
元は Cloudflare Worker で公開されていた PWA を、HTML エクスポート（`original/`）から
完全再現し、**Cloudflare Pages** にデプロイできる形にしたもの。

開発プロセスには [VDD Framework](https://github.com/shuhei0866/vdd-framework)（Level 2）を採用。

## 構成

```
.
├── original/     元サイトの HTML エクスポート（再現の入力。編集しない）
├── assets/       新規に手書きしたファイル（manifest / icon / sw / Policy プレースホルダー）
├── scripts/
│   └── build.sh  original/ + assets/ から public/ を生成するビルドスクリプト
├── public/       ← 公開ディレクトリ（Cloudflare Pages のデプロイ対象。生成物）
│   ├── index.html            アプリシェル（12 枚のカードを持つホーム）
│   ├── manifest.json / icon-192.png / sw.js   PWA アセット
│   ├── design/               Design 問題集（S2+ / S2++ / S2+++）
│   ├── sdn/                  SDN（Visual Map ×2 / 穴埋め ×2 / Policy ガイド）
│   ├── RS/                   RS コンフィグ（config 比較 / Pattern4 チートシート）
│   └── Programmability/      Automation 回答集 / コマンドチートシート
├── .claude/      VDD Framework 設定（ガードレール・リリース仕様）
└── process/      VDD/RDD プロセス仕様
```

## ローカルで動かす（テスト環境）

```bash
python3 -m http.server 8000 --directory public
# → ブラウザで http://localhost:8000 を開く
```

カードをタップすると各コンテンツページへ遷移し、ページ右下の「🏠 Hub」ボタンで
ホームに戻れる。

## Podman / Docker で実行

依存関係のインストールなしで、どの環境でも `public/` を配信できる。

```bash
podman build -t ccie-train-hub -f Containerfile .
podman run -d --name ccie-train-hub -p 8080:80 ccie-train-hub
# → http://localhost:8080

# Docker でも同じ Containerfile を -f 指定で利用可能:
# docker build -t ccie-train-hub -f Containerfile .
```

`original/` や `assets/` を変更したときは、従来どおりホスト側で `bash scripts/build.sh`
を実行して `public/` を再生成・コミットしてからイメージを再ビルドする
（イメージ内では再ビルドしない）。

## 再ビルド（original/ や assets/ を変更したとき）

```bash
bash scripts/build.sh
```

`public/` を作り直し、元 Worker の絶対 URL をルート絶対パスへ相対化し、保存時に
ブラウザ拡張が注入した不要要素を除去する。

## Cloudflare Pages へのデプロイ

### 方法 A: Wrangler で直接アップロード（手早い）

```bash
npm install -g wrangler   # 未導入なら
wrangler login
wrangler pages deploy public --project-name ccie-study-hub
```

### 方法 B: GitHub 連携（自動デプロイ）

1. Cloudflare ダッシュボード → **Workers & Pages** → **Create** → **Pages** →
   **Connect to Git** で本リポジトリ（`Yumatsuhashi/vdd_test`）を選択
2. ビルド設定:
   - **Framework preset**: `None`
   - **Build command**: （空欄。静的サイトのためビルド不要）
   - **Build output directory**: `public`
3. `main` ブランチへの push で自動デプロイされる

## 既知の制約

- カード「**Policy 判定ガイド**」は元エクスポートに HTML が含まれていなかったため、
  `assets/sdn_policy_guide.html` の暫定プレースホルダー（準備中）を表示している。
  元 HTML が入手できたら差し替えて `bash scripts/build.sh` で再ビルドする。
- 元サイトの Service Worker（`sw.js`）はエクスポートに含まれず、PWA 登録の 404 を
  避けるための最小構成を用意している（オフラインキャッシュは未実装）。
