---
name: cml-ops
description: CML (10.71.157.93) の MCP ツールでラボを操作するとき（ノードの状態確認・show コマンド実行・config 投入・起動停止・ラボ作成削除・パケットキャプチャ）に使用。特に CCIE 学習用ラボ EI_v2 を触る前に必ず読む。承認が必要な操作の判定基準、EI_v2.yaml とラボの正本関係、検証結果の記録先を定める。
---

# CML 実機操作ルール

CML の MCP ツール (`mcp__cml__*`) を使う際の運用ルール。**このスキルはユーザーの学習環境を壊さないことを最優先に設計されている。**

## 大原則: ユーザーの明示指示があるまで CML の状態を変更しない

**読み取りは自由。書き込みは全て都度承認。** 例外はない。

「効率的だから」「どうせ戻せるから」「確認のために一度だけ」といった理由で
書き込み系ツールを先回りで実行してはならない。承認なしの実行は、たとえ結果が
無害でもルール違反として扱う。

## ツール分類

### 承認不要（read-only）— そのまま実行してよい

| 分類 | ツール |
|---|---|
| システム情報 | `get_cml_information`, `get_cml_status`, `get_cml_statistics`, `get_cml_licensing_details` |
| ラボ情報 | `get_cml_labs`, `get_cml_lab_by_title`, `get_nodes_for_cml_lab`, `get_all_links_for_lab`, `get_annotations_for_cml_lab` |
| ノード情報 | `get_interfaces_for_node`, `get_console_log`, `get_cml_node_definitions`, `get_node_definition_detail` |
| ユーザー/グループ | `get_cml_users`, `get_cml_groups` |
| キャプチャ参照 | `check_packet_capture_status`, `get_captured_packet_overview`, `get_packet_capture_data` |
| トポロジ取得 | `download_lab_topology`（※下記の注意あり） |

### 承認必須（write）— 提案 → 承認 → 実行

| 危険度 | ツール | 備考 |
|---|---|---|
| **最高** | `wipe_cml_lab`, `wipe_cml_node`, `delete_cml_lab`, `delete_cml_node` | ディスク/定義の破棄。学習成果が消える |
| **高** | `configure_cml_node`, `send_cli_command`（config 系） | 実機コンフィグの変更 |
| **高** | `delete_cml_user`, `delete_cml_group`, `create_cml_user`, `create_cml_group` | CML 全体の権限に影響 |
| 中 | `start_cml_lab`, `stop_cml_lab`, `start_cml_node`, `stop_cml_node` | 未保存の running-config が飛ぶ |
| 中 | `start_cml_link`, `stop_cml_link`, `apply_link_conditioning` | 疎通・収束状態が変わる |
| 中 | `modify_cml_lab`, `add_node_to_cml_lab`, `add_interface_to_node`, `connect_two_nodes` | トポロジ変更 |
| 低 | `create_empty_lab`, `create_full_lab_topology`, `clone_cml_lab` | 新規作成でも承認を取る（ラボ一覧が増える） |
| 低 | `add_annotation_to_cml_lab`, `delete_annotation_from_lab` | 図の注記 |
| 低 | `start_packet_capture`, `stop_packet_capture` | キャプチャの開始/停止 |

### `send_cli_command` は中身で判定する（要注意）

単一ツールで読み書き両方できてしまうため、**投入する文字列で判断する**。

- **承認不要**: `show ...`, `ping ...`, `traceroute ...`, `dir`, `more ...`, `terminal length 0`
- **承認必須**:
  - `configure terminal` 以降のすべて
  - `clear ...`（`clear ip ospf process` 等は再収束を起こす。カウンタクリアも含め全て承認対象）
  - `reload`, `write memory`, `copy running-config ...`, `erase ...`
  - `debug ...`（コンソール負荷でノードが不安定になり得る）

判断に迷うコマンドは**承認側に倒す**。

### `download_lab_topology` の注意

read-only だが、EI_v2 は約 4,800 行あり**そのまま出力するとコンテキストを食い潰す**。
使うときは必ずファイルへ落としてから grep / diff で必要箇所だけ見る。会話に全文を出さない。

## 承認の取り方（テンプレート）

書き込み系を提案するときは、以下 5 点を必ず提示してから承認を求める。

```
【CML 変更の承認依頼】
対象      : ラボ EI_v2 (5d87eb31-...) / ノード R21
実行内容  : configure_cml_node で OSPF area 0 に Gi0/1 を追加
影響範囲  : R21-R22 間の隣接が張り直る。他ノードへの波及は無し
戻し方    : no router ospf 1 ... / または wipe_cml_node で初期化
正本との差: EI_v2.yaml の R21 初期 config には該当行なし（新規追加）
```

承認は**操作単位**で取る。1 回の承認を後続の別操作に流用しない。
連続作業でまとめて承認が要る場合は、**手順を全部列挙して一括承認**を取る。

## EI_v2 の正本関係（最重要）

```
リポジトリ EI_v2.yaml  ←── 正本（＝問題の初期状態の基準）
        │
        │ インポート（過去に実施済み）
        ▼
CML ラボ EI_v2 (5d87eb31-50c9-4416-829e-5e84da081dc9)
  33 ノード / 63 リンク / 現在 STARTED
        │
        └── ユーザーが学習中に config を打つ = 意図的なドリフト
```

### ルール

1. **`EI_v2.yaml` は「問題の初期状態」の基準**であり、**原則書き換えない**。
   CML 上で学習して config が変わっても yaml には反映しない。
   yaml を更新するのは、ユーザーが「ラボの初期状態そのものを変えた」と
   明示した場合だけ（そのときも指示があってから）。

2. **CML 側のドリフトは「汚れ」として扱う**。
   実機の状態が yaml と違っていても、それが学習作業の結果なら正常。
   ただし「なぜこの config になっているのか」を答えるときは、
   **yaml の初期 config を基準に、実機の差分を学習成果として説明する**。

3. **ドリフトを見つけたら報告するだけ**。勝手に同期しない。
   - yaml → CML の反映（初期化）も承認必須
   - CML → yaml の書き戻し（再エクスポート）も承認必須

4. **ラボを初期状態に戻したいと言われたら**、`wipe_cml_node` の挙動を先に説明する。
   wipe が復元するのは **CML が保持しているノードの config** であって、
   リポジトリの yaml ではない。CML 側の保存 config 自体が編集されていれば
   wipe しても yaml の状態には戻らない。完全に yaml へ戻すには
   yaml からのラボ再インポートが必要（＝既存ラボの削除を伴うので慎重に）。

### EI_v2.yaml から初期 config を読む方法

**全読み禁止（約 4,800 行）。** ノード単位で抽出する（`R21` を対象名に置換）:

```bash
awk '/^  - boot_disk_size/{buf=""} {buf=buf $0 "\n"} /^    label: R21$/{print buf; exit}' EI_v2.yaml
```

配線は `links:` セクションを grep:

```bash
grep -n "R21-" EI_v2.yaml
```

詳細は `ccie-qa` スキルの「参照ソース」節と共通。

## 実機検証の進め方

1. **まず資料で答えを出す**（`Answers/` → `Questions/` → `EI_v2.yaml` → `original/`）。
   実機に触るのは、資料だけでは確定できない挙動を確かめるときだけ。
2. **read-only で現状を観測**（`get_nodes_for_cml_lab`, `send_cli_command` の show 系）。
3. 状態変更が必要なら**承認テンプレートで依頼**。
4. 検証後、結果を `QA/patternN/` に記録（下記）。

### ノード名 → CML ノード ID の引き方

`configure_cml_node` 等は node id (`n21` 形式) を要求する。ラベルからは
`get_nodes_for_cml_lab` で引く。**ラベルの推測で id を決め打ちしない**
（yaml の `n<数字>` と、デバイス名の数字は一致しない）。

## 検証結果の記録先

実機で確認した結果は、既存の Q&A 蓄積に統合する。**新しいディレクトリは作らない。**

- 保存先: `QA/patternN/YYYY-MM-DD_qX_<概要>.md`（`ccie-qa` スキルの規約に従う）
- 実機検証を含む場合、その Q&A ファイル内に次の節を追加する:

```markdown
## CML 実機での確認

- 対象: ラボ EI_v2 / ノード R21, R22
- 実行日: 2026-08-12
- 実行コマンド: `show ip ospf neighbor`
- 結果:
  ```
  （show 出力を貼る。長い場合は判断に必要な行だけ）
  ```
- 結論: （資料の説明と一致したか／差異があればその理由）
```

- 状態を変更した場合は、**何を変えて何で戻したか**も併記する。
  戻していない場合は「CML 上に変更が残っている」と明記する（次回セッションへの引き継ぎ）。
- `QA/` はメインワークツリーから直接書き込める（worktree-guard の除外パス）。

## その他のラボ

CML には EI_v2 以外にも学習用ラボがある（DMVPN 系、VRF & EIGRP、DHCP IP SLA & NetFlow、IS-IS 等）。
**これらにも同じ「書き込みは都度承認」ルールを適用する。** EI_v2 だけが特別ではない。

`MCP test`（MCP 接続確認用に作成した 2 ノードのラボ）は不要になれば削除できるが、
削除も `delete_cml_lab` なので承認が必要。勝手に片付けない。

## MCP 接続設定そのものの変更

`~/.claude.json` / `~/.cursor/mcp.json` の CML 接続設定は、
**ユーザーの明示指示なしに変更しない**。接続できない場合は原因を報告するに留める。
設定内容と既知の罠は `CLAUDE.md` の「CML MCP サーバー」節を参照。
