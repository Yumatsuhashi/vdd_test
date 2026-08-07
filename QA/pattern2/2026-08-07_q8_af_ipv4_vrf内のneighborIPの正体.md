# Task 1.8 `address-family ipv4 vrf fabd2` の neighbor IP（100.3.11.2 / 100.3.21.2）は何か（＝CE 側の直結 I/F。vpnv4 の Loopback 指定との使い分け／`.1`=PE・`.2`=CE の命名規則／CE 側は初期設定済み／P2 のみ maximum-prefix）

## 質問

```
address-family ipv4 vrf fabd2
  redistribute connected
  neighbor 100.3.11.2 remote-as 65001
  neighbor 100.3.11.2 activate
  neighbor 100.3.21.2 remote-as 65002
  neighbor 100.3.21.2 activate
　neighbor 100.3.21.2 maximum-prefix 100000 90 restart 5
```

ここで指定しているIPは何？

## 回答

### 結論: PE-CE リンクの「CE 側」のインターフェイス IP

対象は R3（PE, AS 10000）の VRF `fabd2` 内 eBGP。

| 指定 IP | 正体 | 機器 | AS | 拠点 |
|---|---|---|---|---|
| `100.3.11.2` | **R11 の Gi0/0** | R11（CE） | 65001 | HQ |
| `100.3.21.2` | **R21 の Gi1** | R21（CE） | 65002 | DC |

R3 側の対向は `100.3.11.1`（Gi1）/ `100.3.21.1`（Gi2）で、それぞれ **/30 の直結リンク**。

```
        R11 (AS 65001, HQ)                    R21 (AS 65002, DC)
         Gi0/0 100.3.11.2                      Gi1 100.3.21.2
              │                                      │
              │ /30 直結                             │ /30 直結
              │                                      │
         Gi1 100.3.11.1                        Gi2 100.3.21.1
        ┌─────┴──────────────────────────────────────┴─────┐
        │              R3 (PE, AS 10000)                   │
        │              VRF fabd2                           │
        └──────────────────┬───────────────────────────────┘
                     Gi8 100.0.13.2  ← global（アンダーレイ。BGP ピアではない）
```

---

### 同じ config 内の 2 種類の neighbor IP を見分ける

R3 の `router bgp 10000` には性格の違う IP が混在する。**どちらを指定するかは AF で決まる。**

| AF | 指定する IP | 何のアドレスか | 種別 |
|---|---|---|---|
| `address-family vpnv4` | `100.255.254.4/.5/.6` | **PE の Loopback0** | iBGP（マルチホップ） |
| `address-family ipv4 vrf fabd2` | `100.3.11.2` / `100.3.21.2` | **CE の直結物理 I/F** | eBGP（1 ホップ） |

- **iBGP に Loopback を使う理由**: PE 間はコアを何ホップも越える。物理 1 本落ちても OSPF が迂回すればセッション維持。
  VPNv4 の next-hop も Loopback になり LDP ラベルと整合する。
- **eBGP に直結 /30 を使う理由**: CE とは直結 1 ホップ。Loopback を使うと `ebgp-multihop` +
  相互の Loopback 経路が別途必要になり無駄。

---

### アドレスの命名規則（暗記不要・導出できる）

このラボの PE-CE リンクは `100.<PE番号>.<CE番号>.x` という規則。

| リンク | サブネット | PE 側（.1） | CE 側（.2） | CE の AS |
|---|---|---|---|---|
| R3 ↔ R11 | 100.3.11.0/30 | R3 Gi1 | **R11** | 65001 |
| R3 ↔ R21 | 100.3.21.0/30 | R3 Gi2 | **R21** | 65002 |
| R5 ↔ R61 | 100.5.61.0/30 | R5 Gi1 | R61 | 65006 |
| R6 ↔ R62 | 100.6.62.0/30 | R6 Gi1 | R62 | 65006 |
| R6 ↔ R70 | 100.6.70.0/30 | R6 Gi2.100 | R70 | 65007 |

**`.1` が PE、`.2` が CE** で一貫している。
本番では `show ip int brief` で自分側（.1）を見れば、対向は `.2` と即座に導ける。

対して **アンダーレイ（PE-P）は `100.0.<x><y>.0/30`**（例: R3-R1 = 100.0.13.0/30）で第2オクテットが `0`。
第2オクテットが `0` かどうかで「コア向け global」か「顧客向け VRF」かが一目で分かる。

---

### CE 側は初期コンフィグで設定済み（R3 側だけでセッションが上がる）

R11 / R21 の初期コンフィグには**すでに R3 向けの eBGP が入っている**。

```
# R11（EI_v2.yaml 初期コンフィグ）
router bgp 65001
 neighbor 100.3.11.1 remote-as 10000      ← R3 側を指している
  neighbor 100.3.11.1 activate

# R21
router bgp 65002
 network 10.2.255.21 mask 255.255.255.255
 neighbor 10.2.255.22 remote-as 65002     ← R22 との DC 内 iBGP
 neighbor 100.3.21.1 remote-as 10000      ← R3 側を指している
```

→ **R3 側さえ設定すれば両端が揃ってセッションが上がる。CE 側を触る必要はない。**

---

### 補足: `maximum-prefix` の行（Pattern 2 のみ）

```
neighbor 100.3.21.2 maximum-prefix 100000 90 restart 5
                                   ↑      ↑  ↑
                                   │      │  └─ 超過で落とした後 5 分で自動復旧
                                   │      └─ 90%（= 90,000 本）で警告ログ
                                   └─ 受信上限 100,000 プレフィックス
```

- **Pattern 2 だけの追加要件**（Pattern 1 にはなし。Pattern 3 は代わりに R3↔R11 に `timer 30 90`）。
- **R21 向けにだけ**付いている。DC 側 CE の誤設定で経路が溢れても PE を守る保護。
- 検証: `show ip bgp neighbors 100.3.21.2 | include prefix`

> **コピペ注意**: 解答 HTML のこの行は先頭が **全角スペース（U+3000）**。
> 実機に貼ると構文エラーになるので行頭を打ち直すこと。

---

### キャッシュの修正

`Answers/pattern2/pattern2_q8.md` の R3 config に `maximum-prefix` 行が**抜けていた**。
original 1346 行（Pattern 2 列）に存在するのでキャッシュ側を修正した。

## 参照

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` 1320〜1346 行（Task 1.8 R3 の Pattern 1/2/3 横並び）
- 同 1346 行（`maximum-prefix 100000 90 restart 5` = Pattern 2 列のみ・行頭が全角スペース）
- 同 1342 行 / 5334 行（`timer 30 90` = **Pattern 3 のみ**。検証表に「Pattern 3 追加（BGP timers） P3のみ」と明記）
- 同 5333 行（検証表「Pattern 2 追加（maximum-prefix） P2のみ / `show ip bgp neighbors 100.3.21.2 | include prefix`」）
- `EI_v2.yaml` R11 ノード（Gi0/0 = 100.3.11.2、`router bgp 65001` / `neighbor 100.3.11.1 remote-as 10000`）
- `EI_v2.yaml` R21 ノード（Gi1 = 100.3.21.2、`router bgp 65002` / `neighbor 100.3.21.1 remote-as 10000` / R22 と iBGP）
- `EI_v2.yaml` R3 ノード（Gi1 = 100.3.11.1、Gi2 = 100.3.21.1、Gi8 = 100.0.13.2）
- `EI_v2.yaml` links 4469 行 `R11-Gi0/0<->R3-Gi1` / 4476 行 `R21-Gi1<->R3-Gi2`
- `Answers/pattern2/pattern2_q8.md`（アクティブ BGP ピア 5 本の内訳表）
