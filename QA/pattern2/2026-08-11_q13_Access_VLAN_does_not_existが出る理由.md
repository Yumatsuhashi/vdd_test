# Task 1.13 `% Access VLAN does not exist` が出る理由（`interface vlan` と `vlan` は別物）

## 質問

```
SW700(config-if)#sw acc vla 414
% Access VLAN does
```

初回でSW700の物理インターフェースにsw acc vla 100/114するとこのようなエラーが出る　sh, no shして再起動するとうまくいくんだけどなんでかな　ちなみにint vlan 100,114はすでに作成してある

## 回答

### まず：これはエラーではない

完全なメッセージはこれ:

```
% Access VLAN does not exist. Creating vlan 414
```

**「そのVLANは無かったので、こちらで作っておきました」という通知**。コマンドは成功している。
IOS の拒否メッセージは `Command rejected: ...` という形なので区別がつく。

### 原因：`interface vlan 100` と `vlan 100` は別物

| コマンド | 作られるもの | 確認コマンド |
|---|---|---|
| `vlan 100`（グローバル設定） | **L2 VLAN**（VLAN データベースの実体） | `show vlan brief` |
| `interface vlan 100` | **SVI**（L3 の論理インターフェース） | `show ip interface brief` |

**SVI を作っても L2 VLAN は作られない。** 名前が似ているが別のレイヤの話。

そして**メッセージ自体が動かぬ証拠**になっている。`% Access VLAN does not exist` が出た＝
その瞬間 **VLAN 414 は VLAN データベースに存在していなかった**、と IOS が言っている。

### 正しい手順

```
SW700(config)# vlan 100,414                       ← ★ここは interface を付けない
SW700(config-vlan)# exit
SW700(config)# interface GigabitEthernet0/0
SW700(config-if)# switchport mode access
SW700(config-if)# switchport access vlan 100      ← もうメッセージは出ない
```

先に VLAN を作っておけばメッセージも出ないし shut/no shut も不要。

### ⚠️ 番号は 414（114 ではない）

```
R70 の初期コンフィグ
interface GigabitEthernet0/2.414
 encapsulation dot1Q 414          ← R70 はこのタグでしか受け取らない
 vrf forwarding kiosk
 ip address 172.31.70.1 255.255.255.0
```

VLAN **114** を作って host72 をそこに入れると R70 のサブインターフェースとタグが一致せず、
**疎通もしないし要件も満たさない**。問題文も `VLAN 414`。

### ⚠️ そもそも Task 1.13 で SVI は不要

SW700 は**純粋な L2 スイッチ**として使う。L3（ゲートウェイ）は R70 のサブインターフェースが担当。

```
R70 Gi0/2.100 (dot1q 100, 192.168.0.1)  ─┐
                                          ├─ Gi2/1 [SW700] Gi0/0 ─ host71
R70 Gi0/2.414 (dot1q 414, 172.31.70.1)  ─┘    (trunk)     Gi0/1 ─ host72
                                                  ↑
                                        SW700 は L2 で中継するだけ
                                        SVI も IP も一切要らない
```

解答 config にも `interface Vlan100` は一行も出てこない。作っても害はないが不要な設定。

### shut / no shut で直る理由

```
① VLAN 414 が無い状態で switchport access vlan 414 を実行
        ↓
② ポートが一時的に inactive になる
        ↓
③ IOS が VLAN 414 を自動作成
        ↓
④ ポートを再評価して connected へ ← ここが IOSvL2 では遅れる/こけることがある
```

`shutdown` / `no shutdown` はポートを強制的に再初期化するので ④ をやり直させることになる。
加えて SW700 は `spanning-tree mode pvst` なので、新しい VLAN のインスタンスが
**Listening → Learning → Forwarding** を通るのに約 30 秒かかる。焦って確認すると
「直っていない」ように見える。

shut/no shut は**対症療法**で、根本対策は「VLAN を先に作る」。

### 診断コマンド

**VLAN が本当に存在するかは `show vlan brief` でしか分からない。**

```
SW700# show vlan brief
VLAN Name          Status    Ports
---- ------------- --------- -------------------------------
1    default       active    Gi0/2, Gi0/3, ...
100  VLAN0100      active    Gi0/0          ← ポートが所属していること
414  VLAN0414      active    Gi0/1
```

```
SW700# show interfaces status
Port    Name   Status       Vlan   Duplex  Speed Type
Gi0/0          connected    100    a-full a-1000 ...
Gi0/1          connected    414
```

**`Status` 列の見方**

| 表示 | 意味 |
|---|---|
| `connected` | 正常 |
| **`inactive`** | **割り当て先の VLAN が存在しないか shutdown されている** ← 今回の症状 |
| `notconnect` | 物理リンクが上がっていない |
| `err-disabled` | 違反等で保護停止 |

`inactive` を見たら、まず `show vlan brief` に VLAN があるかを確認する。これが一発診断。

## 参照

- `Questions/pattern2/pattern2_q13.md` — 「HOST71 を VLAN 100 に、HOST72 を **VLAN 414** に所属させること」
- `Answers/pattern2/pattern2_q13.md` — 解答 config 冒頭が `vlan 100,414`（`interface vlan` ではない）。
  SVI は 1 行も無い
- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`
  - 1889行 — `vlan 100,414`（P1/P2 共通）
  - 4059行 — Pattern 2 単体解答ブロックの `vlan 100,414`
- `EI_v2.yaml`
  - SW700 — `node_definition: iosvl2`（4108〜4109行）、初期コンフィグは hostname /
    `spanning-tree mode pvst` / line con のみ。**VLAN もインターフェース設定も皆無**
  - R70 — `interface GigabitEthernet0/2.100 / encapsulation dot1Q 100`、
    `interface GigabitEthernet0/2.414 / encapsulation dot1Q 414`（**414 が正・114 ではない根拠**）
  - links — `SW700-Gi2/1<->R70-Gi0/2`(4763行) / `SW700-Gi0/0<->host71-Ethernet0/0`(4812行) /
    `SW700-Gi0/1<->host72-Ethernet0/0`(4819行)
- 関連 QA:
  - `QA/pattern2/2026-08-11_q13_mac_address_tableが見えるようになる原理.md`
  - `QA/pattern2/2026-08-11_q13_host71と72のMACアドレスをどうやって出すか.md`
