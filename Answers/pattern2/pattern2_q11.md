# Pattern 2 — 問題11 DMVPN（ブランチ3/4）/ EIGRP Tunnel

## 解答 config（デバイス別）

### R24（ハブ）

```
crypto isakmp policy 10
hash md5

no crypto isakmp key cisco address 0.0.0.0
crypto isakmp key CC!E!nfr4 address 0.0.0.0

interface Tunnel0
ip nhrp map multicast dynamic
tunnel source GigabitEthernet1
tunnel protection ipsec profile prof

router eigrp ccie
address-family ipv4 unicast autonomous-system 65006
af-interface Tunnel0
no passive-interface
```

> 注: `crypto isakmp policy 10` は R24 の初期コンフィグ（EI_v2.yaml）にプリステージ済み
> （`encr 3des` / `authentication pre-share` / `group 2` 設定済み）。パターン2では
> `hash sha` が明示されていないため `no hash sha` は不要で、`hash md5` を追加するだけでよい
> （パターン1/3は `hash sha` が明示済みのため `no hash sha` の削除が必要）。

### R61（スポーク／ブランチ3, VRF WAN経由）

```
interface GigabitEthernet0/4
vrf forwarding WAN
ip address 200.99.61.2 255.255.255.252

no crypto isakmp key cisco address 0.0.0.0
crypto keyring KR vrf WAN
pre-shared-key address 0.0.0.0 0.0.0.0 key CC!E!nfr4

interface Tunnel0
ip mtu 1440
no ip nhrp redirect
no ip nhrp map multicast 10.2.255.24
no ip nhrp map 10.2.255.24 10.200.0.1
ip nhrp map multicast 200.99.24.2
ip nhrp map 10.200.0.1 200.99.24.2
tunnel source GigabitEthernet0/4
tunnel vrf WAN

router bgp 65006
address-family ipv4 vrf WAN
neighbor 200.99.61.1 remote-as 19999
neighbor 200.99.61.1 activate

router eigrp ccie
address-family ipv4 unicast autonomous-system 65006
af-interface Tunnel0
no passive-interface
```

### R70（スポーク／ブランチ4, VRF WAN経由）

```
interface GigabitEthernet0/1
vrf forwarding WAN
ip address 200.99.70.2 255.255.255.252
no shutdown

crypto keyring KR vrf WAN
no pre-shared-key address 0.0.0.0 0.0.0.0 key cisco
pre-shared-key address 0.0.0.0 0.0.0.0 key CC!E!nfr4

interface Tunnel0
no ip nhrp map multicast 10.2.255.24
no ip nhrp map 10.2.255.24 10.200.0.1
ip nhrp map multicast 200.99.24.2
ip nhrp map 10.200.0.1 200.99.24.2
tunnel source GigabitEthernet0/1
tunnel vrf WAN

router bgp 65007
address-family ipv4 vrf WAN
neighbor 200.99.70.1 remote-as 19999
neighbor 200.99.70.1 activate

router eigrp ccie
address-family ipv4 unicast autonomous-system 65006
af-interface Tunnel0
no passive-interface
```

### R5（EIGRP以外の広報防止）

```
access-list 66 deny 10.2.114.0 0.0.0.3
access-list 66 deny 10.2.214.0 0.0.0.3
access-list 66 deny host 10.2.255.24
access-list 66 permit any

router bgp 10000
address-family ipv4 vrf fabd2
neighbor 100.5.61.2 distribute-list 66 out
neighbor 100.5.61.2 distribute-list 66 in
```

## R5 の ACL がなぜ R5 だけなのか（スポーク 3 台の非対称）

対象 3 プレフィックスは全部 R24 自身のもの。`10.2.114.0/30`（Gi2↔SW211）/
`10.2.214.0/30`（Gi3↔SW212）/ `10.2.255.24/32`（Lo0）。R24 の EIGRP は初期から
`network 10.2.0.0 0.0.255.255` を持つので Tunnel0 経由で流れる。
**問題文の `10.255.5.24/32` は `10.2.255.24/32` の誤記**（解答 ACL が根拠）。

| CE | 対向 PE | PE-CE セッションの所在（CE 側） | Tunnel0/EIGRP | 衝突 |
|---|---|---|---|---|
| **R61** | R5 | `router bgp 65006` **直下＝グローバル**／Gi0/0 100.5.61.2 も global | グローバル | **⚠️ する** |
| R70 | R6 | `af ipv4 vrf WAN`（`neighbor 100.6.70.1`）／**Gi0/0.100 が `vrf forwarding WAN`** | グローバル | ✅ しない |
| R62 | R6 | グローバル直下（衝突しうる） | — | 問題文で**除外** |

- **R61 だけ MPLS 学習経路と EIGRP 経路が同じグローバル RIB に載る** → R5 が唯一のフィルタ地点。
- 打たないと **eBGP(AD 20) が EIGRP internal(AD 90) に勝ち**、DC 宛が Gi0/0（MPLS・非暗号）へ流れて
  「EIGRP で広報」「インターネット通過は全暗号化」の 2 要件に違反する。

**注意（誤解しやすい点）**:

- **EIGRP は SP の中には無い**。動くのは DMVPN トンネルの中だけ（R24 ↔ R61/R70、AS 65006）。
  「同じ RIB」とは R61 という 1 台の中で 2 つの経路源が同じテーブルに入るという意味。
- **VRF ＝ 独立した別のルーティングテーブル（別の箱）**。箱が違えば同じプレフィックスでも比較されない。
  R70 は BGP 経路が VRF WAN の箱・EIGRP 経路がグローバルの箱なので、そもそも競合が発生しない。
- **`tunnel vrf WAN` は「箱」を変える設定ではない**。外側の封筒（GRE/IPsec の宛先 200.99.24.2）を
  どのテーブルで引くかを決めるだけ。Tunnel0 に `vrf forwarding` が無い以上、
  **トンネル経由で学ぶ EIGRP 経路は R61 も R70 もグローバル**に入る。違うのは BGP 経路の行き先だけ。

### なぜ interface 適用ではダメか

- `ip access-group` は**データプレーン**。BGP UPDATE の NLRI は TCP 179 のペイロードで、
  パケットの src/dst は `100.5.61.x`。標準 ACL には一切マッチせず素通りする。
- I/F に貼ると経路は RIB に残ったままパケットだけ落ちる → **ブラックホール**。
  DMVPN 経由に切り替わらない。**経路を消さないと最適経路は変わらない**。
- `neighbor <ip> distribute-list <acl> out` は ACL を「プレフィックスのマッチ条件」として使う
  （標準 ACL の source をネットワークアドレスとして解釈。マスク長は見ない）。
- `access-list 66 permit any` は**暗黙 deny any**の打ち消し。無いと R61 との全経路が落ちる。
- `af ipv4 vrf fabd2` に降りる理由は Task 1.10 と同じ（neighbor 100.5.61.2 は VRF 内にしか存在しない）。

**補足**: Task 1.5 の R21 に `no bgp redistribute-internal` があり R21 は DC LAN を VPN へ注入していない。
実機で `show ip bgp vpnv4 vrf fabd2` に 10.2.114.0/30 が出ない可能性があるが、問題文の
「**必要に応じて**」がこれに対応する。予防フィルタとして 3 パターン共通で入れる（省略しない）。

## トポロジ整理（命名の罠と経路の流れ）

### 「SP_1」は 2 つある — CML ノードと問題文の呼称は別物

| 呼び名 | 実体 | AS | 役割 |
|---|---|---|---|
| **Global SP #1**（問題文） | R1・R2（P）＋ R3・R4・R5・R6（PE） | **10000** | MPLS L3VPN（プライベート経路） |
| **SP_1 ノード**（CML、hostname `SP1`） | ルータ **1 台** | **19999** | インターネット ISP（DMVPN の下回り） |
| **SP_2 ノード**（hostname `SP2`） | 1 台。`Eth0/0 101.22.0.1/30` のみ・BGP なし | — | R22 の WAN 対向専用。**Pattern 2 では出番なし** |

SP1 は `ip route 0.0.0.0 0.0.0.0 Null0` + `redistribute static` + `default-information originate` で
**全ブランチにデフォルトルートを配る**（問題文「BGP 経由でデフォルトルートを受信」の実体）。
eBGP 相手は R24(65002) / R61(65006) / R62(65006) / R70(65007)。**R12 向け neighbor は無い**。

### CE と PE の対応（CE 1 台につき PE 1 台）

| CE | 物理リンク | 対向 PE |
|---|---|---|
| R11 (HQ) / R21 (DC) | Gi0/0↔R3 Gi1 / Gi1↔R3 Gi2 | R3 |
| **R61** | **Gi0/0 ↔ R5 Gi1** | **R5** ← ACL 66 はここ |
| R62 | Gi0/0 ↔ R6 Gi1 | R6（問題文で除外） |
| R70 | Gi0/0.100 ↔ R6 Gi2.100 | R6（VRF WAN で隔離） |

R61↔R62 は Gi0/1 同士で直結（10.6.99.0/30）し R62 側は EIGRP 有効だが、
**R62 に BGP→EIGRP 再配布が無い**ので裏道からの漏れもない。

### R61 → R24（DMVPN 経路）のパケットの流れ

```
① [R61 global]   10.2.114.0/30 宛 → D via 10.200.0.1, Tunnel0（EIGRP）
② [Tunnel0]      GRE + IPsec(3DES/MD5) でカプセル化
                 外側ヘッダ: src 200.99.61.2 → dst 200.99.24.2
                 ↓ tunnel vrf WAN ＝ 外側ヘッダは VRF WAN のテーブルで引く
③ [R61 VRF WAN] 0.0.0.0/0 via 200.99.61.1（SP1 から BGP 学習）→ Gi0/4 送出
④ [SP1/AS19999] Eth0/3 → Eth0/1
⑤ [R24 Gi1]     IPsec 復号 → GRE 解除
⑥ [R24 global]  10.2.114.0/30 は Gi2 直結 → SW211
```

**②③＝外側の袋（VRF WAN）／①⑥＝中身（global）**。R70 も同じで SP1 の出入口が Eth1/0 に変わるだけ。

### ⚠️ ラボの穴：R61 の EIGRP に `network` 文がない

R70 は `network 10.200.0.0 0.0.0.255`（Tunnel0 を含む）を持つが、**R61 は network 文が 1 行もない**。
解答資料も R61 には `af-interface Tunnel0 / no passive-interface` しか追加しないため、
このままでは R61 の EIGRP 隣接が上がらない可能性がある。
`show ip eigrp neighbors` が空なら `network 10.200.0.0 0.0.0.255` を追加する（R70 と同形）。

## NHRP map の IP 一覧（どれが誰のものか）

`ip nhrp map <オーバーレイのIP> <NBMAのIP>` の **2 つとも R24（ハブ）のもの**。同じ 1 台の「2 つの顔」を結ぶ。

| IP | 誰の何 | 層 |
|---|---|---|
| **10.200.0.1** | R24 Tunnel0 | オーバーレイ（＝`ip nhrp nhs` の値と同一） |
| **200.99.24.2** | R24 Gi1 | アンダーレイ NBMA（新） |
| 10.2.255.24 | R24 Lo0 | **旧** NBMA。降板して EIGRP 広報対象の経路になる |
| 10.200.0.61 / 10.200.0.70 | R61 / R70 Tunnel0 | オーバーレイ（自分） |
| 200.99.61.2 / 200.99.70.2 | R61 Gi0/4 / R70 Gi0/1 | 自分の NBMA（新 `tunnel source`） |

**本番での値の拾い方（2 系統）**:

| 値 | 出どころ | コマンド |
|---|---|---|
| `10.200.0.1` | **R61 の既存 config**（`ip nhrp nhs` の値がそのまま第1引数） | `show run interface Tunnel0` |
| `200.99.24.2` | **R24 の物理 I/F**（問題文が Gi1 と名指し） | R24 で `show ip interface brief` |

`200.99.24.2` は **R61 のルーティングテーブルからは絶対に分からない**（SP_1 は connected を広報せず
`0.0.0.0/0` しか来ない）。CDP も隣は SP_1 で R24 は 2 ホップ先。R24 に直接見に行くしかない。
`topology2.png` は I/F 名のみで IP の記載なし。

**⚠️ 初期コンフィグの `ip nhrp map 10.2.255.24 10.200.0.1` は引数の順序が逆**
（正しくは `10.200.0.1 10.2.255.24`）。解答の `ip nhrp map 10.200.0.1 200.99.24.2` は
宛先の付け替えと同時に順序も直している。消す行と入れる行で並びが違うのはタイプミスではない。

**ハブ側に map が無い理由**: スポークが `ip nhrp nhs` を頼りに自分から登録しに来るのでハブは
動的に覚える。足すのは `ip nhrp map multicast dynamic`（登録済み全スポークへ EIGRP Hello を複製）だけ。

**R24 の初期 `tunnel source Ethernet0/3` は存在しない I/F**（R24 の物理は Gi1〜Gi4 のみ）。
問題文が「GigabitEthernet1 を使用すること」と名指しするのはこのため。

## SP_1（ISP / AS 19999）の I/F 対応と初期コンフィグ

| SP_1 I/F | IP | 対向 |
|---|---|---|
| Eth0/0 | 200.99.23.1/30 | R23 |
| **Eth0/1** | **200.99.24.1/30** | **R24 Gi1（ハブの公開側）** |
| Eth0/2 | 200.99.12.1/30 | R12 |
| **Eth0/3** | **200.99.61.1/30** | **R61 Gi0/4** |
| **Eth1/0** | **200.99.70.1/30** | **R70 Gi0/1** |
| Eth1/1 | 200.99.62.1/30 | R62（問題文で除外） |

```
router bgp 19999
 redistribute static
 neighbor 200.99.24.2 remote-as 65002
 neighbor 200.99.61.2 remote-as 65006
 neighbor 200.99.62.2 remote-as 65006
 neighbor 200.99.70.2 remote-as 65007
 default-information originate
!
ip route 0.0.0.0 0.0.0.0 Null0
```

## スポークの ISP 向け BGP（アンダーレイ）がなぜ必須か

スポークとハブは**直接繋がっていない**（間に SP_1 が 1 台挟まる）。この BGP は
「ハブの公開 IP `200.99.24.2` に届く足場」を作るためだけの配線であり、**業務経路は一切運ばない**。

1. `tunnel vrf WAN` により **外側 GRE/IPsec ヘッダの宛先 `200.99.24.2` は VRF WAN のテーブルで引かれる**。
   VRF WAN には connected の `/30` しかない → 再帰ルックアップ失敗 → `%TUN-5-RECURDOWN` → IKE すら飛ばず DMVPN 全滅。
2. その経路（`0.0.0.0/0`）の供給源は SP_1 との eBGP だけ（上記 `ip route ... Null0` ＋ `default-information originate`）。
3. 問題文が「専用の VRF を使用して ISP へ接続し、**BGP 経由で**デフォルトルートを受信」と明示。static default は要件違反。

**neighbor が物理 I/F の対向 IP である理由**: eBGP 直結は TTL 1 で、`update-source` を弄らなければ
ソースは出力 I/F の IP。SP_1 が `neighbor 200.99.61.2` を決め打ちしているのでズレると拒否される。
Loopback ピアには `ebgp-multihop` ＋相互の Loopback 経路が必要で ISP は持たない。そもそも
**R61 の Lo0（10.6.255.61）はグローバル所属で VRF WAN に Loopback は 0 本**＝選択肢が存在しない。

**`af ipv4 vrf WAN` 配下に置く理由**: `200.99.61.1` は VRF WAN のテーブルにしか存在しない。
グローバル直下に打つと別人格の neighbor が無言で作られ Idle 放置（Task 1.10 と同じ構図）。

| 層 | プロトコル | テーブル | 運ぶもの |
|---|---|---|---|
| アンダーレイ（外側の封筒） | BGP（対 AS 19999） | VRF WAN | `0.0.0.0/0` のみ |
| オーバーレイ（中身） | EIGRP AS 65006 | グローバル | `10.2.114.0/30` 等の業務経路 |

検証: `show ip bgp vpnv4 vrf WAN summary` / `show ip route vrf WAN 0.0.0.0` /
**`show ip cef vrf WAN 200.99.24.2`（★トンネルの生死はここ）**

## R24 初期コンフィグ（EI_v2.yaml 抜粋）

```
crypto isakmp policy 10
 encr 3des
 authentication pre-share
 group 2
crypto isakmp key cisco address 0.0.0.0
!
crypto ipsec transform-set trans esp-3des esp-md5-hmac
```

## R61 / R70 の「VRF WAN」プリステージ状況（重要・非対称）

`vrf forwarding WAN` は Task 1.11 の解答表にのみ登場するが、**すべて候補者が新規に打つ行というわけではない**。
EI_v2.yaml の初期コンフィグを確認すると、デバイスによって既存状況が異なる：

### R61（初期コンフィグに既に存在＝入力不要）

```
vrf definition WAN
 rd 65006:61
!
interface GigabitEthernet0/4
 vrf forwarding WAN          ← 既にある
 ip address 200.99.61.2 255.255.255.252
!
router bgp 65006
 address-family ipv4 vrf WAN
  neighbor 200.99.61.1 remote-as 19999
  neighbor 200.99.61.1 activate
```
（tunnel source は初期状態では `Loopback0`。Task 1.11 で `GigabitEthernet0/4` に変更する）

### R70（初期コンフィグでは ISP 向け I/F に未適用＝新規入力が必要）

```
vrf definition WAN
 rd 65006:70
!
interface Loopback0
 vrf forwarding WAN           ← 別I/Fには既にある
 ip address 10.7.255.70 255.255.255.255
!
interface GigabitEthernet0/1
 ip address 200.99.70.2 255.255.255.252   ← vrf forwarding WAN が無い
 no shutdown
!
router bgp 65007
 address-family ipv4 vrf WAN
  network 10.7.255.70 mask 255.255.255.255
  neighbor 100.6.70.1 remote-as 10000     ← これはISP向けではなくDC向け(AS10000)
```

R70 は ISP 向け実体験（AS 19999 / `200.99.70.1`）用の `neighbor` が初期コンフィグに存在せず、
`interface GigabitEthernet0/1` も VRF 未所属。したがって Task 1.11 の解答で
`interface GigabitEthernet0/1` に `vrf forwarding WAN` を追加し、`router bgp 65007` の
`address-family ipv4 vrf WAN` に `neighbor 200.99.70.1 remote-as 19999` を新規追加する必要がある。

### 結論

- 対応する問題文の指示: 「ブランチルータは、専用のVRFを使用してISPへ接続し、BGP経由でデフォルトルートを受信すること」
- R61 はこの要件が初期コンフィグで概ね満たされているため EIGRP/DMVPN 側の変更（tunnel source 変更・NHRP 等）が中心
- R70 は ISP 向け I/F（Gi0/1）が VRF 未所属のままなので、`vrf forwarding WAN` の追加自体が Task 1.11 で必要な作業
- `tunnel vrf WAN`（Tunnel0 配下）は両機種で新規必須。トンネルインターフェースはデフォルトでグローバルVRF所属なので、
  ソースIF が VRF WAN にある場合は明示的に紐付けないと `%TUN-5-RECURDOWN` 等でトンネルが上がらない

## 検証コマンド

```
! R5
show run | section router bgp                              ! neighbor の所在（context）確認
show ip bgp vpnv4 vrf fabd2 neighbors 100.5.61.2 advertised-routes | include 10.2.
                                                           ! ← 何も出ないこと
show ip access-lists 66                                    ! ヒットカウント

! R61（判定はここ一発）
show ip route 10.2.114.0     ! ★"D ... via 10.200.0.1, Tunnel0" なら成功／"B ... via 100.5.61.1" なら失敗
show ip eigrp topology 10.2.114.0/30
show ip bgp 10.2.114.0                                     ! BGP テーブルに無いこと
show dmvpn / show crypto isakmp sa / show ip nhrp
```

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`
  - Task 1.11 セクション（比較表: 1627〜1660行付近、パターン2単体解答: 2887〜2990行付近、R5 ブロック: 2978〜2986行）
  - 1741〜1749行 — ACL 66 と distribute-list in/out が 3 パターン共通（`row-common`）
  - 2401〜2410行 — Task 1.5 Pattern 2 の R21（`no bgp redistribute-internal`）
- `EI_v2.yaml`
  - R24 — `Lo0 10.2.255.24/32` / `Gi2 10.2.114.1/30` / `Gi3 10.2.214.1/30` / `Gi1 200.99.24.2/30`、
    `router eigrp ccie / network 10.2.0.0 0.0.255.255`、`crypto isakmp policy 10`
  - R61 — `Gi0/0 100.5.61.2/30`（global）、`router bgp 65006 / neighbor 100.5.61.1 remote-as 10000`（**グローバル直下**）
  - R70 — `Gi0/0.100 vrf forwarding WAN / 100.6.70.2/30`、`af ipv4 vrf WAN / neighbor 100.6.70.1 remote-as 10000`
    （**MPLS 側が VRF に隔離＝衝突しない根拠**）
  - R62 — `router bgp 65006 / neighbor 100.6.62.1 remote-as 10000`（グローバル直下だが問題文で除外）
  - R5 — `af ipv4 vrf fabd2 / neighbor 100.5.61.2 remote-as 65006`（グローバルには存在しない）
- 関連 QA: `QA/pattern2/2026-08-09_q11_R5にACLを置く理由とint適用ではダメな理由.md`、
  `QA/pattern2/2026-08-07_q10_PE側だけaddress-family_ipv4_vrf配下に打つ理由.md`

最終更新: 2026-08-11（SP_1 の I/F 対応表・アンダーレイ BGP が必須である理由・NHRP map の IP 一覧と引数順序の罠を追記）
