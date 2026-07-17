# CLAUDE.md

このファイルは、本リポジトリでコードを記述する際の Claude Code (claude.ai/code) へのガイドラインです。

## プロジェクト概要 <!-- CUSTOMIZE -->

CCIE 学習用の静的 Web アプリ「CCIE Study Hub」の再現プロジェクト。
元は Cloudflare Worker (`delicate-pine-6fa3.yxnatakeuchi.workers.dev`) で公開されていた
PWA を、ローカルの HTML エクスポート (`original/`) から完全再現し、Cloudflare Pages に
デプロイすることを目的とする。

アプリはアプリシェル（ハブ）とコンテンツページで構成される：
- **ハブ** (`index.html`): 12 枚のカードを持つホーム画面。カードをタップすると
  各コンテンツ HTML を iframe ビューアで表示する。設定（フォントサイズ・テーマ）を
  postMessage で iframe に伝達し、最後に開いたページを localStorage に保存する。
- **コンテンツページ**: Design 問題集 / SDN / RS コンフィグ / Programmability の
  各カテゴリの学習資料 HTML（自己完結型）。

## リポジトリ構成 <!-- CUSTOMIZE -->

```
CCIE_train_hub/
├── original/            # 元サイトの HTML エクスポート（再現の入力。読み取り専用）
├── public/              # 再現した公開用サイト（Cloudflare Pages のデプロイ対象）
│   ├── index.html       # アプリシェル（ハブ）
│   ├── manifest.json    # PWA マニフェスト
│   ├── icon-192.png     # PWA アイコン
│   ├── design/          # Design 問題集（Design_S2+.html 等）
│   ├── sdn/             # SDN（visual map / 穴埋め / policy guide）
│   ├── RS/              # RS コンフィグ（config_comparison / pattern4_cheatsheet）
│   └── Programmability/ # Automation 回答集 / コマンドチートシート
├── .claude/             # VDD Framework 設定（フック・スキル・仕様）
└── process/             # VDD/RDD プロセス仕様
```

## コマンド <!-- CUSTOMIZE -->

```bash
python3 -m http.server 8000 --directory public   # ローカル開発サーバー起動 → http://localhost:8000
npx wrangler pages deploy public                 # Cloudflare Pages へデプロイ
```

静的サイトのためビルド工程はなし（`public/` をそのまま配信）。

## プッシュ前のチェック

静的サイトのため自動テストはなし。プッシュ前は以下を手動確認する：

```bash
# ローカルサーバを起動し、ブラウザで全カードの遷移・iframe 表示・戻る・設定を確認
python3 -m http.server 8000 --directory public
```

## Claude Code Hooks <!-- FRAMEWORK: DO NOT MODIFY -->

CLAUDE.md のルールを技術的に強制するフック群。`.claude/hooks/` に配置。設定は `.claude/settings.json` の `hooks` セクションで定義。

### 強制レベル定義

| レベル | ラベル | 意味 |
|--------|--------|------|
| L5 | フック強制 | フックが `deny` で技術的にブロック。回避不可 |
| L4 | フック警告 | フックが `ask` / `block` でユーザー確認を要求 |
| L3 | コンテキスト注入 | SubagentStart で `additionalContext` として自動注入 |
| L2 | プロンプト内ルール | CLAUDE.md に記載のみ。技術的強制なし |

### フック一覧

| フック | イベント | 強制レベル | 説明 |
|--------|----------|-----------|------|
| `guardrails/worktree-guard.sh` | PreToolUse (Write\|Edit) | L5: deny | メインワークツリーでのファイル編集をブロック |
| `guardrails/commit-guard.sh` | PreToolUse (Bash) | L5: deny | メインWT での保護ブランチ直接コミット、--no-verify、force push、checkout/switch/stash をブロック |
| `guardrails/gh-guard.sh` | PreToolUse (Bash) | L5: deny | main 向け PR の approve/merge をブロック。クラウド環境では全 approve をブロック |
| `subagent-rules/inject.sh` | SubagentStart | L3: inject | agent_type 別に必須ルールを自動注入 |
| `review-enforcement/check.sh` | Stop | L4: block | release/* ブランチでレビュー未実行時にブロック |
| `rdd-reminder/remind.sh` | UserPromptSubmit | L2: remind | main ブランチで実装リクエスト検出時に RDD リマインド |
| `conversation-logger/log.sh` | SessionEnd | -- | 対話ログを `.local-docs/sessions/` に自動保存 |

## プロセス仕様のレイヤー

- ツール非依存の正本:
  - `process/RDD.md`
  - `process/VDD.md`
- この `CLAUDE.md`:
  - Claude Code で運用するための具体設定（フック、スキル、強制ルール）
  - リポジトリ内での実装パスや運用手順

## リリース駆動開発 (RDD) <!-- FRAMEWORK with {{placeholders}} -->

本プロジェクトではリリース駆動開発を採用する。人間の役割は「要件定義」「設計対話への参加」「QA」の3つ。
実装・テスト・レビューは AI が自律的に完遂する。

### 言語ルール

<!-- CUSTOMIZE: 日本語/英語/その他を指定 -->
RDD の全成果物は**日本語**で記述すること。これは以下を含む：

- PR description（タイトル・本文・図解の説明文）
- レビュー結果・PR コメント
- リリース仕様書（`.claude/release-specs/{release-name}.md`）
- コミットメッセージの本文（件名は英語可）

### RDD の原則

1. **リリースが作業単位**: コミットやPRではなく、リリース可能な動作変更が作業の単位
2. **要件と QA は人間主導**: 何を作るか（要件定義）とQA（検証）は人間の責務。設計対話では AI と協働する
3. **コードではなく動作を見る**: レビューはコードではなく、動作の変更を確認する
4. **TDD は RDD の一部**: 自動テストはリリース品質検証の機械化可能な部分を担う

### リリースの粒度ルール

- 1 リリース = 1 つの独立したデプロイ可能な変更
- ロールバック可能であること
- 他のリリースとの依存関係がないこと

### リリース分類（2層モデル）

RDDリリースは2層で管理する：

#### レイヤー1: RDDリリース（全 `release/*` ブランチ）

全ての `release/*` ブランチのマージがRDDリリース。タグなしも含む。

#### レイヤー2: バージョンタグ付きリリース（選択的）

| 分類 | 対象 | バージョンタグ | GitHub Release |
|------|------|---------------|----------------|
| developer-only | リファクタ、CI、ドキュメント、内部改善 | なし | なし |
| user-facing (bugfix) | ユーザーに見えるバグ修正 | patch | 作成 |
| user-facing (feature) | 新機能追加 | minor | 作成 |
| user-facing (breaking) | 破壊的変更 / メジャーマイルストーン | major | 作成 |

### ワークフロー

#### Phase 0: 要件定義（人間）
- 「何をしたいのか」の本質的な目的を述べる
- ユーザーストーリー、達成したいゴール、制約条件の明示
- この段階では実装方針は含まない

#### Phase 1: 設計対話（人間 + AI）
- 要件に基づき、実装方針を AI と議論する
- 対話中にリリース分割が発生したら、リリースツリーを出力して構造を可視化する
- 対話ログは `.local-docs/sessions/` に自動保存される（フック）
- 成果物: リリース仕様書（`.claude/release-specs/{release-name}.md`）

### リリースツリー

設計対話（Phase 1）の中で、要件が複数リリースに分割される場合がある。その構造を対話中に可視化するため、テキストベースのリリースツリーを使用する。

#### フォーマット

```
[R1] release/<name>
|    <概要（1行）>
|
|--- [R2] release/<name>
|         <概要>
|
+--- [R3] release/<name>
          <概要>
```

#### ルール

- **番号は時間軸**: R1 -> R2 -> R3 の順にリリースする
- **分岐はサフィックス**: R3 から分岐 -> R3a, R3b（並列実行可能）
- **矢印は依存関係**: 矢印の先が後続リリース
- **直列**: 親から子が1本の線（R1 -> R2 -> R3）
- **並列**: 同じ親から複数の子（R1 -> R2, R1 -> R3）

#### Phase 2: 自律実装（AI・YOLO モード）
- リリースブランチ `release/<name>` を作成（worktree で作業）
- リリース仕様書を `.claude/release-specs/{release-name}.md` としてコミット
- TDD サイクルで実装
- リリース仕様書の範囲外の変更をしない

#### Phase 3: 自己評価 + 独立レビュー（AI） `[L4: フック強制]`
- `/release-ready` を実行
- 問題があれば修正し、再度 `/release-ready`
- `/review-now` を実行（独立コンテキストレビュー）
- 指摘があれば修正し、再度通す
- PR を作成。レビュー結果 + 開発洞察を PR description に含める
- **注意**: `review-enforcement/check.sh` (Stop フック) が release/* ブランチでレビュー未実行を検出すると block する

#### Phase 4: develop マージ + QA（人間）
- PR のマージ先は `develop`（main への直接マージは禁止）
- レビュアーの approve 確認後にマージを実行する
- `develop -> main` の昇格は人間がトリガー

### AI への指示（自律実装時）

- リリース仕様書を常に参照し、スコープ外の変更をしない
- 実装エージェント自身がレビューまで実行する
- 仕様に曖昧さがあれば人間に確認する。それ以外は確認不要
- 対話ログは自動保存されるため、明示的な保存操作は不要
- 実装中に発見した洞察・気づきは親エージェントに報告する

### 情報の三層構造

- **完全性**: `.local-docs/sessions/` に全対話ログを原文保存（ローカル、gitignore）
- **理解可能性**: PR description に AI が設計経緯の要約を記載（GitHub、永続）
- **開発洞察**: 実装中に発見した洞察・知見を PR description の `## Insights` セクションに記録する

### プランファイル（`.claude/plans/`）のコミット

プランファイルは過去の設計経緯を辿るために git 管理対象とする。コミット時に `.claude/plans/` 内のファイルがあれば積極的に含めること。

### PR description の図解（必須）

リリース PR の description には必ず図解を含めること。AI はレビュアーの認知特性プロファイル（`.claude/reviewer-profile.md`）を参照し、最適な表現方法を選択する。

- Mermaid チャート、フローチャート、状態遷移図、アーキテクチャ図等
- 変更の before/after を視覚的に示す
- レビュアーが「コードを読まずに動作変更を理解できる」ことが基準

## テスト駆動開発 (TDD)（必須） `[L3: コンテキスト注入]` <!-- FRAMEWORK with {{placeholders}} -->

> TDD は RDD（リリース駆動開発）の実装フェーズにおける手法である。
>
> TDD ルールは `subagent-rules/inject.sh` (SubagentStart フック) により implementer/general-purpose エージェントに自動注入される。

**本プロジェクトでは TDD（テスト駆動開発）を必須とする。実装コードより先にテストを書くこと。**

これは推奨ではなく必須ルールである。テストなしで機能実装やバグ修正を行ってはならない。

### 原則

1. **テストファースト（厳守）**: 新機能・バグ修正では、**必ず**実装コードより先にテストを書く。テストを書かずに実装を始めることは禁止
2. **Red -> Green -> Refactor**: 失敗するテストを書く -> テストを通す -> リファクタリング
3. **テストなしのコードは原則マージ不可**: CI でテストが必須化されている

### テストファイルの配置 <!-- CUSTOMIZE -->

本プロジェクトは純粋な静的サイトのため、自動テストのフレームワークは導入していない。
TDD の「先に期待動作を定義する」原則は、**リリース仕様書に受け入れ基準（動作チェックリスト）を
先に書き、実装後にローカルサーバで手動検証する**ことで代替する。

### テストの書き方

```bash
python3 -m http.server 8000 --directory public   # ローカルサーバでブラウザ手動検証
```

### AI への指示

**新機能を実装する場合:**
1. まずテストファイルを作成し、期待する振る舞いをテストとして記述
2. テストが失敗することを確認
3. テストを通す最小限の実装を行う
4. 必要に応じてリファクタリング

**バグ修正の場合:**
1. バグを再現するテストを先に書く
2. テストが失敗することを確認（バグの存在を証明）
3. バグを修正してテストを通す

## 技術スタック <!-- CUSTOMIZE -->

- 純粋な静的 HTML / CSS / JavaScript（フレームワーク・ビルドツールなし）
- PWA（manifest.json + apple-touch-icon + theme-color）
- ホスティング: Cloudflare Pages（`public/` を直接配信）
- ローカル開発: `python3 -m http.server`

## アーキテクチャ <!-- CUSTOMIZE -->

- **アプリシェル + iframe ビューア方式**: `index.html` が単一ページアプリのシェル。
  カードの `href` は `public/` 配下の相対パス（例: `./design/Design_S2+.html`）。
  カードタップで該当 HTML を `#viewerFrame` (iframe) に読み込み、CSS トランジションで
  ホーム↔ビューアを切り替える。
- **設定の伝達**: フォントスケール・テーマ（light/dark/auto）を localStorage に保存し、
  iframe ロード後に postMessage でコンテンツ側へ送る。
- **元サイトとの差分**: 元は全リンクが Worker の絶対 URL だったが、再現版では相対パスに
  書き換えている。PWA アセット（manifest.json / icon）も元 Worker の絶対 URL 参照を
  ローカル生成物に差し替える。
- **既知の欠落**: カード「Policy 判定ガイド」(`sdn/sdn_policy_guide.html`) の元 HTML が
  エクスポートに含まれないため、プレースホルダーページで代替している。

## ワークツリー必須ルール（最重要） `[L5: フック強制]` <!-- FRAMEWORK -->

**コードの変更は必ず git worktree 上で行うこと。メインワークツリー（リポジトリルート）では絶対にファイルを編集しない。**

> `worktree-guard.sh` (PreToolUse フック) がメインワークツリーでの Write/Edit を deny でブロックする。
> `commit-guard.sh` (PreToolUse フック) がメインワークツリーでの checkout/switch/stash pop を deny でブロックする。

- メインワークツリーでのブランチ切り替え（`git checkout`）禁止
- メインワークツリーでの `git checkout -- <file>`（変更の破棄）禁止
- メインワークツリーでの `git stash pop`（stash の適用）禁止
- コード変更が必要な場合は、まず `git worktree add .worktrees/<name> <branch>` でワークツリーを作成し、そのワークツリー内で作業する
- メインワークツリーは読み取り専用として扱い、調査・閲覧のみ行う

**理由:** メインワークツリーには他のブランチの未コミット作業が残っている場合があり、ブランチ切り替えや変更の破棄で未コミットの作業を消失させるリスクがある。

### コミット衛生 `[L5: フック強制]`

> `commit-guard.sh` (PreToolUse フック) が以下を deny でブロックする。

- `--no-verify` によるフックスキップは禁止
- `main` / `master` への `--force` push は禁止

### ブランチ戦略（簡略化 GitFlow） `[L5: フック強制]` <!-- FRAMEWORK -->

> `commit-guard.sh` (PreToolUse フック) が `release/*` -> main 直接マージと develop 削除を deny でブロックする。

**3層構造:**

```
main (production)     <- 人間が昇格トリガー
  |
develop (integration) <- レビュアー approve 後に実装エージェントがマージ
  |
release/* (作業)      <- worktree で TDD 実装
```

**ルール:**
- `release/*` -> `develop` にマージ（レビュー approve 後に実装エージェントが実行）
- `develop` -> `main` に昇格（人間トリガー）
- `release/*` -> `main` への直接マージは禁止（フック強制）
- `develop` ブランチの削除は禁止（フック強制）
- 昇格後は `develop` を `main` にリベースして同期

## サブエージェント運用ルール `[L3: コンテキスト注入]` <!-- FRAMEWORK -->

Task tool でサブエージェントを起動する際は、以下のルールに従うこと。

> `subagent-rules/inject.sh` (SubagentStart フック) が agent_type に応じた必須ルールを自動注入する。

- **モデル**: `model: "opus"` を常に指定
- **タスク分割**: 変更の競合を避けるため、ファイル/ディレクトリ単位で独立性の高いタスクに分割
- **ワークツリー**: 機能実装はワークツリーを作成してから作業
- **TDD の引き継ぎ**: SubagentStart フックで自動注入されるが、プロンプトでも明示すること（二重安全）
- **メモリ変更のコミット（必須）**: サブエージェントがエージェントメモリ（`.claude/agent-memory/`）を更新した場合、その変更を必ずコミットに含めること
- **レビュー組み込みルール** `[L4: フック強制]`: `release/*` ブランチで作業するサブエージェントには、実装完了後に以下を自身で実行するようプロンプトに含めること：
  1. `` で型チェック・lint・テストを通す
  2. `/release-ready` を実行（自己評価）
  3. `/review-now` を実行（独立レビュー）
  4. 指摘があれば修正してコミット
  5. エージェントメモリに変更があればコミットに含める
  6. 結果を親エージェントに報告
  7. PR を作成（develop 向け）
  - **注意**: `review-enforcement/check.sh` (Stop フック) が release/* ブランチでレビュー未実行を検出すると block する

### 権限設定（YOLO モード）

リリースブランチのワークツリー内で作業するサブエージェントには、`allowed_tools` で広めの権限を付与し、承認待ちで止まらないようにする。

- **付与する権限**: `Bash()`, `Bash(git add/commit/diff/status/log/merge/rebase *)`, `Read`, `Write`, `Edit`, `Glob`, `Grep`
- **禁止**: `Bash(git push *)`, `Bash(git checkout *)`, `Bash(rm -rf *)`

### 並列実行時の注意

複数のサブエージェントを並列実行する場合：

1. 各エージェントが編集するファイルが重複しないよう設計
2. 共有リソース（DB スキーマ、共通型定義など）の変更は単一エージェントに集約
3. 依存関係がある場合は `blockedBy` で順序を明示

## ローカル専用ドキュメント

`.local-docs/` はリポジトリにコミットされないローカル専用のドキュメント置き場です。

**用途:**

- PRレビュー結果のサマリー
- 個人的な作業メモ
- 一時的な分析結果
- チームで共有不要なドキュメント

このディレクトリは `.gitignore` に含まれているため、各開発者が自由に使用できます。

## CLAUDE.md 自己改善

セッション中に以下を発見した場合、このファイルの適切なセクションに追記すること：

- プロジェクト固有の再発パターン（ビルド失敗、テスト不安定、デプロイ問題など）
- ユーザーに指摘されたプロジェクト固有のミス
- 新しいスキル・コマンド・ワークフローの追加時のドキュメント反映
- 技術スタック変更時の更新（依存関係のアップグレード等）

## 追加された学習資料と QA

既存の静的 Web アプリ用ファイルに加えて、CCIE ラボの構成確認と学習中の疑問を記録するため、以下のファイル・ディレクトリを使用する。

```text
CCIE_train_hub/
├── EI_v2.yaml       # CML ラボのノード、リンク、インターフェース、初期コンフィグ
├── topology1.png    # HQ/DC 周辺のトポロジ画像
├── topology2.png    # SP/Branch 周辺のトポロジ画像
├── questions.md     # 問題文や確認対象となる設問の参照ファイル
└── QA/              # LLM への質問と回答を質問単位で保存する Markdown 文書
```

### QA 文書の運用ルール

- 学習中の質問とその回答は `QA/` 配下へ保存する。
- **LLM とのチャットでユーザーが質問するたびに、1 回の質問につき新しい Markdown ファイルを 1 つ作成する。**
- 同じテーマの続きであっても、別のチャット質問として受け取った場合は既存ファイルへ追記せず、新しいファイルを作成する。
- ファイル名は `YYYY-MM-DD_QA_<どんな質問かわかる概要>.md` とする。日付は質問を受けた時点の日本時間（Asia/Tokyo）を使用する。
- `<どんな質問かわかる概要>` は、ファイル一覧だけで内容を判別できる短い名称にする。`/` などファイル名に使えない文字は使用しない。
- 例: `2026-07-17_QA_OSPF設定対象の理由.md`
- 各ファイルには、少なくとも「質問」と「回答」を明記する。必要に応じて、前提、参照ファイル、確認した設定、注意事項も記載する。
- 回答を作成するときは、`questions.md`、`EI_v2.yaml`、`topology1.png`、`topology2.png`、`original/` 配下の解答資料を必要に応じて突き合わせ、推測だけで断定しない。
- 既存の QA ファイルは上書き、削除、改名しない。過去の質問と回答を保持したまま、新しいファイルを追加する。
