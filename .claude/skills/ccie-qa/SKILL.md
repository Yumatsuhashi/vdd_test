---
name: ccie-qa
description: CCIE EI ラボ問題（パターン1〜4）について「なぜこの設計なのか」「なぜこの config を打つのか」「パターンNの問題Xについて教えて」等の質問を受けたときに使用。トポロジ画像・CML ラボ (EI_v2.yaml)・original/ の解答資料を突き合わせて回答し、Q&A を QA/ 配下に必ず蓄積する。
---

# CCIE 問題 Q&A スキル

CCIE EI の学習中の質問（設計意図・config の理由・トポロジの役割など）に対して、
リポジトリ内の一次資料を突き合わせて回答し、その Q&A を `QA/` に蓄積する。

## 参照ソース（優先順）

| ソース | 内容 | 使い方 |
|---|---|---|
| `Answers/patternN/patternN_qX.md` | 抽出済み解答 config のキャッシュ | **最初に存在チェック**。ヒットしたら EI_v2.yaml / original/*.html の照合を省略してよい（トークン節約） |
| `Questions/patternN/patternN_qX.md` | 問題文 | まず読む。**空 (0 byte) / 存在しない場合はユーザーに問題文の貼り付けを依頼**（現状ほぼ未投入） |
| `topology1.png` | HQ/DC 周辺のトポロジ画像 | Read で画像として読む |
| `topology2.png` | SP/Branch 周辺のトポロジ画像 | Read で画像として読む |
| `EI_v2.yaml` | CML ラボ（33ノード/63リンク、初期コンフィグ内蔵） | **全読み禁止（約4,800行）**。下記の抽出方法を使う |
| `original/*.html` | 解答の正本 | パターン・タスクに応じて grep で照合 |

### EI_v2.yaml からのデバイス config 抽出

ノードブロックは `- boot_disk_size` で始まり、初期コンフィグの**後**に `label: <デバイス名>` が来る。
次の awk で該当デバイスのブロックだけを抽出する（`R21` を対象デバイス名に置換）:

```bash
awk '/^  - boot_disk_size/{buf=""} {buf=buf $0 "\n"} /^    label: R21$/{print buf; exit}' EI_v2.yaml
```

リンク配線は `links:` セクション（4392行目以降）を `grep "R21-"` 等で確認できる
（例: `label: R11-GigabitEthernet0/3<->SW101-GigabitEthernet0/0`）。

### original/ の解答資料の対応関係

- **Pattern 2 の RS config（Task 1.2〜1.14）の正本**: `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`
- Design 問題: `original/*Design*.html`、SDN: `original/*SDN*.html`、Automation: `original/CCIE Automation Section 3*.html`

## 注意事項（既知の罠）

- `original/Pattern 4 — 予想コマンド＆知識チートシート.html` は**予想問題**であり、Pattern 2 の実際の解答ではない。機器名やエリア設計が実トポロジと食い違うことがある（例: R21/R22 の直結先は SW201/SW202 であり SW101/SW102 ではない）。予想 HTML の機器名を鵜呑みにしない。
- CML ラボ (`EI_v2.yaml`) と問題トポロジ画像には多少の相違があるが、**無視してよい**（ユーザー了承済み）。
- 解答資料は「差分のみ」を示すことが多い。**解答に機器名がない = その機器で該当プロトコルを使わない、ではない**。初期コンフィグ（EI_v2.yaml）で設定済みの可能性を必ず確認する。
- 推測だけで断定しない。必ず上記ソースと突き合わせてから回答する。

## ワークフロー

1. **問題の特定**: 質問から パターンN・問題X を特定し、`Questions/patternN/patternN_qX.md` を読む。空なら問題文の貼り付けを依頼する。
2. **キャッシュ確認**: `Answers/patternN/patternN_qX.md` があればそれを読み、手順 3 のソース収集を省略してよい（トポロジ画像は必要に応じて参照）。ユーザーが内容に疑義を示した場合、またはキャッシュに質問への答えが足りない場合のみ original/ を再照合し、結果をキャッシュに反映する。
3. **ソース収集（キャッシュ miss 時のみ）**: 質問に関係するデバイスを特定し、トポロジ画像 → EI_v2.yaml の該当ノード → original/ の解答資料の順で照合する。
4. **回答**: 設計意図・config の理由を、トポロジ上の役割（HQ / DC / SP / Branch3 / Branch4）と紐付けて説明する。「何を打つか」だけでなく「なぜ打つか」「打たないとどうなるか」を含める。
5. **QA 蓄積（回答のたび必須）**: 下記ルールに従い新規ファイルを作成し、索引を更新する。
6. **Answers 蓄積（キャッシュ miss だった場合必須）**: 抽出・検証済みの config を下記ルールに従い `Answers/` に保存する。

## QA 蓄積ルール

- 保存先: `QA/patternN/YYYY-MM-DD_qX_<概要>.md`
  - 日付は日本時間（Asia/Tokyo）。`date +%Y-%m-%d` で取得する
  - `<概要>` はファイル一覧だけで内容が判別できる短い日本語（`/` 等の使用不可文字は避ける）
  - 例: `QA/pattern2/2026-07-17_q5_OSPF設計と設定理由.md`
  - パターン・問題番号が特定できない一般的な質問は `QA/general/YYYY-MM-DD_<概要>.md`
- **既存 QA ファイルの上書き・削除・改名は禁止**。1 質問 = 1 新規ファイル。同じテーマの続きでも、別のチャット質問なら別ファイルにする（同日同問なら概要を変える）
- ファイル構成テンプレート:

```markdown
# <タイトル>

## 質問

<ユーザーの質問原文>

## 回答

<回答本文>

## 参照

- <照合したファイルパスと該当箇所>
```

- 保存後、`QA/README.md` の該当パターンのセクションに 1 行追記する:
  `- [タイトル](patternN/ファイル名.md) — YYYY-MM-DD`

## Answers 蓄積ルール（解答 config キャッシュ）

- 保存先: `Answers/patternN/patternN_qX.md`（`Questions/` の命名をミラー。特定できない一般質問は `Answers/general/<概要>.md`）
- 目的: 次回同じ問題への質問時に original/*.html（56KB〜748KB）の grep を省略するためのキャッシュ
- QA と異なり**上書き更新可**（1 問題 = 1 ファイルを育てる）。ただし正本は `original/`。矛盾を見つけたら original を再確認してキャッシュ側を直す
- ファイルテンプレート:

```markdown
# Pattern N — 問題X <トピック>

## 解答 config（デバイス別）

### <デバイス名>

（config ブロック）

## 検証コマンド

（show コマンド等。なければセクションごと省略可）

## 出典

- <original/ のファイル名と該当セクション>
- <EI_v2.yaml の該当ノード等>

最終更新: YYYY-MM-DD
```

## 発動時の宣言

スキル発動時、回答の冒頭で対象（パターンN・問題X）と参照するソース（Answers キャッシュ hit / miss を含む）を一言で宣言し、
回答の末尾で保存した QA ファイルのパス（キャッシュ miss 時は Answers ファイルのパスも）を報告する。
