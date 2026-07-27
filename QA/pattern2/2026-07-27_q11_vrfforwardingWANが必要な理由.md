# Task 1.11 DMVPN — `vrf forwarding WAN` が Task 1.11 で初めて出てくる理由

## 質問

vrf forwarding WANというのはtask11で初めて出てくるけどこれはなぜ？問題文のどの指示でこれを作る必要があるか？

## 回答

対応する指示は次の一文です。

> ブランチルータは、専用のVRFを使用してISPへ接続し、BGP経由でデフォルトルートを受信すること。

（`Questions/pattern2/pattern2_q11.md`）。これが「専用のVRF」＝ `WAN` という名前の VRF を使って ISP と接続する、という要件そのものです。

ただし重要な点として、**`vrf forwarding WAN` という行がすべて Task 1.11 で候補者が新規に入力するもの、というわけではありません**。`EI_v2.yaml`（CMLラボの初期コンフィグ）を確認すると、R61 と R70 で状況が非対称になっています。

### R61: すでに初期コンフィグに存在（入力不要）

```
vrf definition WAN
 rd 65006:61
!
interface GigabitEthernet0/4
 vrf forwarding WAN
 ip address 200.99.61.2 255.255.255.252
!
router bgp 65006
 address-family ipv4 vrf WAN
  neighbor 200.99.61.1 remote-as 19999
  neighbor 200.99.61.1 activate
```

ISP 向けの物理インターフェース `GigabitEthernet0/4` にはすでに `vrf forwarding WAN` が適用済みで、BGP も VRF WAN の address-family で ISP（AS 19999）との eBGP ネイバーがすでに構成されています。つまり R61 に関しては「専用VRFでISP接続」という要件はラボの初期状態ですでに満たされていて、候補者が新規に打つ必要はありません。

### R70: ISP向けI/Fにはまだ適用されていない（新規入力が必要）

```
vrf definition WAN
 rd 65006:70
!
interface Loopback0
 vrf forwarding WAN            ← 別インターフェースには既にある
 ip address 10.7.255.70 255.255.255.255
!
interface GigabitEthernet0/1
 ip address 200.99.70.2 255.255.255.252     ← vrf forwarding WAN が無い！
 no shutdown
!
router bgp 65007
 address-family ipv4 vrf WAN
  network 10.7.255.70 mask 255.255.255.255
  neighbor 100.6.70.1 remote-as 10000        ← これは DC 向け(AS10000)の既存ネイバー
```

R70 では `vrf definition WAN` 自体は存在し、Loopback0 や他のサブインターフェースにはすでに VRF が適用されていますが、**ISP 向けの `GigabitEthernet0/1`（200.99.70.2）には VRF が付いていません**。また ISP（AS 19999, `200.99.70.1`）向けの BGP ネイバーも初期コンフィグにありません。したがって Task 1.11 の解答では

```
interface GigabitEthernet0/1
vrf forwarding WAN
ip address 200.99.70.2 255.255.255.252
no shutdown

router bgp 65007
 address-family ipv4 vrf WAN
  neighbor 200.99.70.1 remote-as 19999
  neighbor 200.99.70.1 activate
```

を新規に追加する必要があります。これが「Task 1.11 で初めて `vrf forwarding WAN` が出てくる」ように見える理由の一つです（R70 では実際に新規追加が必要なコマンドだからです）。

### なぜ Task 1.11 なのか（DMVPNのループバック禁止要件との関係）

もう一つの理由は、Task 1.11 が「トンネルソースをループバックから ISP 向け物理インターフェースへ変更する」タスクだからです。問題文には

> ハブとスポーク間でDMVPNを確立する際に、**ループバックインターフェイスのIPアドレスを使用しない**こと。

とあります。初期コンフィグでは R61/R70 とも `tunnel source Loopback0` でした。これを ISP 向けインターフェース（R61: Gi0/4、R70: Gi0/1）に変更すると、そのインターフェースが VRF WAN に所属している（またはさせる必要がある）ため、

- インターフェース側: `vrf forwarding WAN`（R70 は新規追加、R61 は既存）
- トンネル側: `tunnel vrf WAN`（**両機種とも新規必須**。Tunnel インターフェースはデフォルトでグローバルVRF所属のため、ソースIFがVRFにある場合は明示的に紐付けないとトンネルが確立しない）
- ISAKMP側: グローバルの `crypto isakmp key` ではVRF内の対向とは鍵交換できないため、`crypto keyring KR vrf WAN` ＋ `pre-shared-key` に置き換える必要がある（R61/R70 とも新規）

という一連の変更が芋づる式に必要になり、その中の一部（VRFへのインターフェース割り当て）がたまたま R70 では新規、R61 ではすでに完了していた、という構図です。

## 参照

- `Questions/pattern2/pattern2_q11.md` — 「専用のVRFを使用してISPへ接続」「ループバックIPを使用しない」の各要件
- `EI_v2.yaml` — R61 ノードブロック（`vrf forwarding WAN` が Gi0/4 に既存）/ R70 ノードブロック（Gi0/1 には無く、Loopback0 のみに既存）
- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` — Task 1.11 比較表（R61: 1658〜1698行付近、R70: 1700〜1730行付近）
- `Answers/pattern2/pattern2_q11.md`（今回更新したキャッシュ、VRF非対称性のセクションを追記）
