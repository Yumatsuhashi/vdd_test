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

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` — Task 1.11 セクション（比較表: 1627〜1660行付近、パターン2単体解答: 2887〜2990行付近）
- `EI_v2.yaml` — R24 ノードブロック（`label: R24` 直前の初期コンフィグ, `crypto isakmp policy 10` 行）

最終更新: 2026-07-27（VRF WAN プリステージ状況の非対称性を追記）
