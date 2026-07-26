# Pattern 2 — 問題8（Task 1.8）MP-BGP VPNv4 / VRF fabd2

対象: SP #1 の PE = R3〜R6（AS 10000）。R1/R2 は P なので VRF/BGP なし。
CE: R11(AS 65001, HQ) / R21(AS 65002, DC) / R61・R62(AS 65006) / R70(AS 65007)。

要件の要点: 全 PE の VRF `fabd2` を RT `10000:1` で揃え、PE 間 iBGP VPNv4 を
MD5 認証（`CC!E!nfr4`）で保護。**R3 と R6 はアクティブ BGP ピア 5 本**にする。

## 初期コンフィグの投入状況（重要 — 差分の理由）

| PE | `vrf definition fabd2` | CE 向け I/F の `vrf forwarding` | `router bgp 10000` | 初期 RT |
|---|---|---|---|---|
| **R3** | **なし** | **なし**（Gi1/Gi2 は global に IP 済） | **なし** | — |
| R4 | あり（rd 10000:4） | **なし**（Gi1.100/.414 は global。VRF は定義だけで空） | あり（iBGP VPNv4 のみ。`af ipv4 vrf` なし） | **10000:4** |
| R5 | あり（rd 10000:5） | あり（Gi1） | あり（VRF 内 eBGP まで） | 10000:1 |
| R6 | あり（rd 10000:6） | あり（Gi1, Gi2.100） | あり（VRF 内 eBGP まで） | 10000:1 |

→ **R3 だけゼロから構築**。R4/R5/R6 は RT 揃え + password のみ。
→ RT が既に 10000:1 なのは **R5/R6 の 2 台**。**R4 だけ 10000:4 で孤立**している。

## RT `10000:1` の根拠（どこから出てきた値か）

### 設定先は PE 4 台の `vrf definition fabd2` 配下。R1/R2 には無い

`route-target` は `vrf definition` のサブコマンド。R1/R2 は P ルータで、初期コンフィグに
`vrf` / `route-target` / `router bgp` が **1 行も存在しない**（`router ospf 1` のみ）。
P は VPN 経路を一切見ずラベルスワップだけする（BGP-free core）ので VRF は不要。

### 値の意味（フォーマット）

RT は `ASN:nn` 形式の拡張コミュニティ。

- `10000` = この SP の **AS 番号**（`router bgp 10000`）
- `:1` = SP が運用する **VPN の通し番号 #1**（= fabd2）

→ `10000:1` =「AS10000 が運用する VPN #1」。値自体は運用者が決める任意の識別子で、
同じラボ内の別 VRF は別値を使っている（cEdge21/cEdge22 の `vrf definition 999` は
`rd 1:999` / RT `1:999`。EI_v2.yaml 1854/1960 行）。

### 実機上の直接根拠

**R5 と R6 の初期コンフィグに既に `route-target export/import 10000:1` が入っている**
（EI_v2.yaml 2894-2896 行 / 3028-3030 行）。つまり 10000:1 は「fabd2 VPN で既に
使われている現行値」であり、新規構築の R3 と、10000:4 で孤立している R4 を
**この既存値へ合わせる**のが Task 1.8 の差分。逆向き（全台を 10000:4 に）でも
理屈は通るが、変更が 3 台に増えて最小変更にならない。

### RD と RT の役割の違い（混同注意）

| | 値 | 範囲 | 役割 |
|---|---|---|---|
| **RD** | 10000:3 / :4 / :5 / :6 | **PE ごとに一意** | VPNv4 経路を 12 バイトで一意化する識別子。経路配布の制御には**使わない** |
| **RT** | **10000:1（全 PE 共通）** | **VPN 全体で共通** | どの VRF にインポートするかを決める。VPN のトポロジ（フルメッシュ / ハブ&スポーク）を決定 |

→ R3 が `rd 10000:3` なのに `route-target 10000:1` という一見アンバランスな
組み合わせが**正しい**。RD を揃えたり RT を PE 番号にしたりするのが典型的な誤り。

### 揃えないとどうなるか

BGP セッションは全部 Established のまま、`show ip route vrf fabd2` に他拠点の経路が
入らない。R4 が 10000:4 のままだと R4 の経路は誰もインポートせず、R4 も他を
インポートしない（= VPN から孤立）。切り分けの難しい典型障害。

## 解答 config（Pattern 2・デバイス別）

### R3（PE。ピア 5 本 = iBGP 3 + eBGP 2）

```
vrf definition fabd2
 rd 10000:3
 route-target export 10000:1
 route-target import 10000:1
 !
 address-family ipv4
!
interface GigabitEthernet1
 vrf forwarding fabd2
 ip address 100.3.11.1 255.255.255.252
!
interface GigabitEthernet2
 vrf forwarding fabd2
 ip address 100.3.21.1 255.255.255.252
!
router bgp 10000
 bgp router-id 100.255.254.3
 no bgp default ipv4-unicast
 neighbor 100.255.254.4 remote-as 10000
 neighbor 100.255.254.4 update-source Loopback0
 neighbor 100.255.254.4 password CC!E!nfr4
 neighbor 100.255.254.5 remote-as 10000
 neighbor 100.255.254.5 update-source Loopback0
 neighbor 100.255.254.5 password CC!E!nfr4
 neighbor 100.255.254.6 remote-as 10000
 neighbor 100.255.254.6 update-source Loopback0
 neighbor 100.255.254.6 password CC!E!nfr4
 !
 address-family vpnv4
  neighbor 100.255.254.4 activate
  neighbor 100.255.254.5 activate
  neighbor 100.255.254.6 activate
 !
 address-family ipv4 vrf fabd2
  redistribute connected
  neighbor 100.3.11.2 remote-as 65001
  neighbor 100.3.11.2 activate
  neighbor 100.3.21.2 remote-as 65002
  neighbor 100.3.21.2 activate
```

**注意**: `vrf forwarding` を入れると IOS が IP アドレスを削除するため、
必ず直後に `ip address` を再入力する（アドレス自体は初期コンフィグと同値）。

### R4（PE。ピア 3 本）

```
vrf definition fabd2
 no route-target both 10000:4
 route-target export 10000:1
 route-target import 10000:1
!
router bgp 10000
 neighbor 100.255.254.3 password CC!E!nfr4
 neighbor 100.255.254.5 password CC!E!nfr4
 neighbor 100.255.254.6 password CC!E!nfr4
```

### R5（PE。ピア 4 本）

```
vrf definition fabd2
 no route-target both 10000:4      ← CML 初期は既に 10000:1。不要な環境あり
 route-target export 10000:1
 route-target import 10000:1
!
router bgp 10000
 neighbor 100.255.254.3 password CC!E!nfr4
 neighbor 100.255.254.4 password CC!E!nfr4
 neighbor 100.255.254.6 password CC!E!nfr4
```

### R6（PE。ピア 5 本 — ただし作業は password のみ）

```
vrf definition fabd2
 no route-target both 10000:4      ← CML 初期は既に 10000:1。不要な環境あり
 route-target export 10000:1
 route-target import 10000:1
!
router bgp 10000
 neighbor 100.255.254.3 password CC!E!nfr4
 neighbor 100.255.254.4 password CC!E!nfr4
 neighbor 100.255.254.5 password CC!E!nfr4
```

## 「アクティブな BGP ピア 5 本」の内訳

### R3

| # | 機器 | 指定 IP | 種別 | AS | AF | 配線 |
|---|---|---|---|---|---|---|
| 1 | R4 | 100.255.254.4 (Lo0) | iBGP | 10000 | vpnv4 | R1/R2 経由 |
| 2 | R5 | 100.255.254.5 (Lo0) | iBGP | 10000 | vpnv4 | R1 経由 |
| 3 | R6 | 100.255.254.6 (Lo0) | iBGP | 10000 | vpnv4 | R1-R2 経由 |
| 4 | R11 (HQ CE) | 100.3.11.2 (直結/30) | eBGP | 65001 | ipv4 vrf fabd2 | R3 Gi1↔R11 Gi0/0 |
| 5 | R21 (DC CE) | 100.3.21.2 (直結/30) | eBGP | 65002 | ipv4 vrf fabd2 | R3 Gi2↔R21 Gi1 |

R3 Gi8 (100.0.13.2) は R1 向けのアンダーレイ = global のまま。BGP ピアではない。

### R6

| # | 機器 | 指定 IP | 種別 | AS | AF | 配線 |
|---|---|---|---|---|---|---|
| 1 | R3 | 100.255.254.3 (Lo0) | iBGP | 10000 | vpnv4 | — |
| 2 | R4 | 100.255.254.4 (Lo0) | iBGP | 10000 | vpnv4 | — |
| 3 | R5 | 100.255.254.5 (Lo0) | iBGP | 10000 | vpnv4 | — |
| 4 | R62 | 100.6.62.2 (直結/30) | eBGP | 65006 | ipv4 vrf fabd2 | R6 Gi1↔R62 Gi0/0 |
| 5 | R70 | 100.6.70.2 (直結/30) | eBGP | 65007 | ipv4 vrf fabd2 | R6 Gi2.100↔R70 Gi0/0.100 |

（参考: R5 は iBGP 3 + eBGP 1（100.5.61.2 / AS 65006）= 4 本、R4 は iBGP 3 本のみ）

## 設計の考え方（なぜこの config なのか）

### PE-CE リンクを VRF に入れる理由
- MPLS L3VPN の原則: **PE-CE = 顧客 VRF / PE-P = global**。
- global のままだと (1) `address-family ipv4 vrf fabd2` の neighbor が VRF の RIB から
  対向 /30 を引けず eBGP が Idle、(2) `redistribute connected` が VRF connected を
  拾えず VPNv4 に載らない、(3) 顧客経路が global に漏れてテナント分離が崩れる。

### `vrf forwarding` で IP が消える仕様
```
% Interface GigabitEthernet1 IPv4 disabled and address(es) removed due to enabling VRF fabd2
```
ルーティングインスタンスを移す操作なので IOS が旧 L3 設定を破棄する。
**必ず `vrf forwarding` → `ip address` の順**。逆順・打ち忘れは典型的な減点。

### iBGP は Loopback / eBGP は直結
- iBGP: `update-source Loopback0`。PE 間はマルチホップで、物理 1 本落ちても OSPF が
  迂回すればセッション維持。VPNv4 の next-hop も Loopback → LDP ラベルと整合。
- eBGP: 直結 1 ホップなので /30 の対向を直指定。Loopback を使うなら
  `ebgp-multihop` + 相互 Loopback 経路が別途必要になり無駄。

### `no bgp default ipv4-unicast` と `activate`
neighbor 行だけではどの AF でも有効化されない。VPNv4 で 3 本、`ipv4 vrf fabd2` で
2 本を `activate` して初めて 5 セッションが Established になる。
「アクティブなピア 5 つ」= activate 済み × Established の 5 本。

### RD と RT の使い分け
- RD は PE ごとに一意（10000:3 / :4 / :5 / :6）— 経路の一意識別用。
- RT は **全 PE で 10000:1 に統一** — 全 PE 相互インポート＝フルメッシュ VPN。
- RT がバラバラだと「BGP は全部 Established なのに `show ip route vrf fabd2` に
  他拠点の経路が入らない」という切り分けの難しい障害になる。

## 検証コマンド

```
show bgp all summary                       # 5 セッションが Established（R3/R6）
show bgp vpnv4 unicast all summary         # iBGP 3 本
show bgp vpnv4 unicast vrf fabd2 summary   # eBGP 2 本
show ip vrf interfaces                     # Gi1/Gi2 が fabd2 に所属
show ip route vrf fabd2                    # 他拠点の B 経路が入っている
show vrf detail fabd2                      # RD / import・export RT の確認
show bgp vpnv4 unicast all neighbors <ip> | inc MD5   # password 適用確認
```

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` 1298〜1432 行（Task 1.8 比較表）
- 同 HTML 2710〜2800 行（Task 1.8 Pattern 2 単独表示）
- `EI_v2.yaml` node n15(R3) / n20(R4) / n21(R5) / n22(R6) 初期コンフィグ
- `EI_v2.yaml` links 4469 / 4476 / 4658 / 4672 / 4679 行
- `EI_v2.yaml` R11 / R21 / R62 / R70 の `router bgp`（AS 65001 / 65002 / 65006 / 65007）

最終更新: 2026-07-26
