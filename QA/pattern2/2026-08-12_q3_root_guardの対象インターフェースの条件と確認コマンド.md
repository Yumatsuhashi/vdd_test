# Task 1.3 root guard を掛けるインターフェースの条件と、その確認コマンド

## 質問

root gurd しているのはどんなインターフェース？
またそれを確認する方法はどのコマンド？

## 回答

### 1. root guard を掛ける「インターフェースの条件」

条件は2つの **AND**。

| # | 条件 | 満たさないと |
|---|---|---|
| **①** | **L2 ポートであること**（`switchport`。STP が動く） | `no switchport` の L3 ポートは STP 自体が無く BPDU を受け取る口がないので掛ける意味がない |
| **②** | **そのスイッチにとって「ルートブリッジへ向かう方向」ではないこと** | 正当なルートポートを `root-inconsistent` でブロックし、自分の正しいルートパスを塞ぐ |

**この2条件だけで HQ 3台の違いが全部説明できる。**

| 機器 | STP 上の役割 | ルートへ向かう方向 | root guard の範囲 |
|---|---|---|---|
| **SW101** | 真のルート（priority 0） | **存在しない**（自分がルート） | **全 L2 ポート**: `Gi0/3, Gi1/0-3, Gi2/0-1` + `Po1, Po3` |
| **SW102** | セカンダリルート（4096） | **Po3（Gi2/0-1）→ SW101** | **Po3 を除いた全 L2 ポート**: `Gi0/3, Gi1/0-3` + `Po2` |
| **SW110** | 非ルート | **Po1 も Po2 もなり得る** | **一切掛けない**（解答に `guard root` の行が無い） |

ルートブリッジには定義上ルートポートが存在しないので、SW101 は条件②を自動的に全ポートで満たす
→ 全 L2 ポートに掛けられる。
SW110 は逆に、どちらのアップリンクも正当なルートポート候補なので**掛けられるポートがゼロ**。

補足: `Gi2/2-3` は L2 ポートなので条件を満たすが、解答の範囲からは漏れている（実害なし）。

---

### 2. 確認コマンド（目的別に3段階）

#### ① 掛ける範囲を決める（設定する前）

```
show interfaces status
```

Vlan 列で条件①を仕分け:

| 表示 | 判定 |
|---|---|
| `routed` | L3 → **対象外** |
| 数字（`1` 等） | L2 アクセス → 対象 |
| `trunk` | L2 トランク → 対象（本命） |

```
show spanning-tree vlan 2000
```

条件②の判定。**`Root ID` が自分（`This bridge is the root`）なら全ポートに掛けてよい**。
自分でなければ `Role` 列が **`Root`** になっているポートが「ルートへ向かう方向」＝**そこだけ除外**する。

```
show etherchannel summary
```

Po とメンバー物理ポートの対応（Po にも打つ必要があるため）。

#### ② 掛かっているか確認する（設定した後）

```
show running-config | include ^interface|guard root
```

`interface` 行と `spanning-tree guard root` 行だけを抜き出すので、
**どのインターフェースに付いているかの一覧**になる。適用漏れの洗い出しはこれが一番速い。

```
show spanning-tree interface GigabitEthernet0/3 detail
```

1ポートずつの確定確認。出力中に **`Root guard is enabled on the port`** の行が出れば有効。

> **`show spanning-tree summary` には root guard は出ない。**
> BPDU guard / BPDU filter / loop guard と違い、root guard には
> **グローバルデフォルトの設定が存在しない**（必ずポート単位）ため。

#### ③ 発動しているか確認する（運用・障害時）

```
show spanning-tree inconsistentports
```

**今まさに root guard でブロックされているポートの一覧**。正常時は空。

```
show spanning-tree vlan 2000
```

発動中のポートは Sts 列が **`BKN*`**、Type 列に **`*ROOT_Inc`** と表示される:

```
Gi1/2   Desg BKN*4   128.14  P2p *ROOT_Inc
```

ログにも出る:

```
%SPANTREE-2-ROOTGUARD_BLOCK: Root guard blocking port GigabitEthernet1/2 on VLAN2000.
%SPANTREE-2-ROOTGUARD_UNBLOCK: Root guard unblocking port GigabitEthernet1/2 on VLAN2000.
```

**設定はポート単位だが、ブロック状態は VLAN 単位で管理される**
（VLAN 2000 だけ `root-inconsistent`、VLAN 2001 は正常、ということが起こり得る）。
superior BPDU が止まれば自動復旧する。

---

### 3. 今回の解答での期待される出力

設定後、SW101 で `show spanning-tree inconsistentports` が**空**であることが正解。
ここに Po3 や Gi2/0-1 が出てきたら、SW101 より優先度の高いスイッチが HQ に存在する
＝`spanning-tree vlan 1,2000,2001 priority 0` が効いていない、ということ。

逆に SW102 で Po3 に root guard を掛けてしまうと、SW101（priority 0）からの**正当な** superior BPDU で
Po3 が `*ROOT_Inc` に落ち、`show spanning-tree inconsistentports` に Po3 が現れる。
これが「掛けてはいけないポートに掛けた」ときの典型的な症状。

## 参照

- `Questions/pattern2/pattern2_q3.md`（STP 要件文「本社内の他のスイッチから受信する、より優先度の高いBPDU」「より優先度の高いBPDUを受信している間は、その受信ポートでトラフィックを転送してはいけません」）
- `Answers/pattern2/pattern2_q3.md`（SW101/SW102/SW110 の解答 config、ポート棚卸し表、root-guard 適用範囲の設計ロジック、`show interfaces status` による範囲導出）
- `QA/pattern2/2026-08-12_q3_root_guardの基準は未使用ポートではなくL2ポート.md`（選定基準の誤解是正）
- `QA/pattern2/2026-08-03_q3_root_guardのポート範囲とGi0-3の理由.md`（Gi0/3 の正体、SW102 での Po3 除外理由、BPDU guard との違い）
- `QA/pattern2/2026-07-31_q3_spanning-tree_guard_rootの適用範囲と役割.md`（どの要件を満たすか）
