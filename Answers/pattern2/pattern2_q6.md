# Pattern 2 — 問題6 EIGRP Named Mode (Task 1.6, R61)

## 解答 config（デバイス別）

### R61

```ios
key chain CCIE_MD5
 key 1
  key-string CC!E!nfr4
!
router eigrp ccie
 address-family ipv4 unicast autonomous-system 65006
  af-interface default
   passive-interface
  exit-af-interface
  af-interface GigabitEthernet0/1
   authentication mode md5
   authentication key-chain CCIE_MD5
   no passive-interface
  exit-af-interface
  af-interface GigabitEthernet0/2
   authentication mode md5
   authentication key-chain CCIE_MD5
   no passive-interface
  exit-af-interface
  af-interface GigabitEthernet0/3
   authentication mode md5
   authentication key-chain CCIE_MD5
   no passive-interface
  exit-af-interface
  network 10.0.0.0
 exit-address-family
```

### R62

**重要**: R62 は「Pattern 2 では EIGRP config なし」ではない。`EI_v2.yaml` の R62 初期コンフィグ（CMLラボの起動時点のベース設定）に、R61で追加すべき内容と**ほぼ同一のEIGRP named mode設定がすでに投入済み**。そのため Task 1.6 の差分表では Pattern 1/2 列の `router eigrp ccie` ブロックが空欄（追加不要）に見える。

R62 の初期コンフィグ（EI_v2.yaml、抜粋）:

```ios
router eigrp ccie
 address-family ipv4 unicast autonomous-system 65006
  af-interface default
   passive-interface
  exit-af-interface
  af-interface GigabitEthernet0/1
   authentication mode md5
   authentication key-chain CCIE_MD5
   no passive-interface
  exit-af-interface
  af-interface GigabitEthernet0/2
   authentication mode md5
   authentication key-chain CCIE_MD5
   no passive-interface
  exit-af-interface
  af-interface GigabitEthernet0/3
   authentication mode md5
   authentication key-chain CCIE_MD5
   no passive-interface
  exit-af-interface
  network 10.0.0.0
 exit-address-family
```

ただし `authentication key-chain CCIE_MD5` が参照する **`key chain CCIE_MD5` 自体の定義（key-string）は R62 の初期コンフィグに存在しない**。これが Task 1.6 の解答で R62 に唯一残っている追加項目（Pattern 1/2/3 共通で必要）:

```ios
key chain CCIE_MD5
 key 1
  key-string CC!E!nfr4
```

なお、この `key chain` は **ルーティングプロトコル認証専用の入れ物**であり、同じ R62 に同居している ISAKMP の PSK（`crypto isakmp key cisco address 0.0.0.0`、EI_v2.yaml 3356 行）や R70 の `crypto keyring` とは**コマンド体系も参照関係も完全に別物**（値が同じ `CC!E!nfr4` なだけ）。ラボ全体で key chain を使うのは Task 1.6 の EIGRP のみ。→ `QA/pattern2/2026-08-04_q6_isakmpのPSKとeigrpのkey-chainの関係.md`

**key chain のお手本はラボ内のどこにも無い**（EI_v2.yaml 全文 grep で `key chain` / `key-string` は 0 件、`CCIE_MD5` は R62 の `authentication key-chain CCIE_MD5` 3 行＝3412/3418/3424 行のみ）。R62 は「参照行だけあって参照先が無い」状態で意図的にプリステージされている。また `show run | sec eigrp` では key chain ブロックに `eigrp` の文字が無いため**絶対に表示されない**（確認は `show run | sec key chain` / `show key chain`）。

Pattern 3 のみ、R62 の Tunnel0（DMVPN, NHRP redirect対応）をEIGRPに参加させるための追加network文がある（`network 10.200.0.0 0.0.0.255` 等、`no network 10.0.0.0` で置き換え）。

### SW601 / SW602（L3スイッチ、Branch3のVLANゲートウェイ）

**初期コンフィグに `router eigrp` セクションは一切存在しない**（2026-08-04 に EI_v2.yaml 3711〜3757 行 / 3842〜3888 行を直読して確認。以前ここに「af-interface は投入済みで network 文だけ追加」と書いていたのは誤りだったので訂正）。したがって Task 1.6 では **key chain + EIGRP ブロック丸ごと**が候補者の作業になる（解答 HTML の記載どおり全量）。Branch3 で「差分が key chain 3 行だけ」なのは R62 のみ。

有効化する af-interface は物理ルーテッドポート Gi0/0・Gi0/1・Gi0/2 に加えて **`af-interface vlan 2000` / `af-interface vlan 2001`**（SVI は小文字 `vlan` + 番号で指定）。R61/R62 の設定をコピペ流用する場合はここを差し替える必要がある。

初期コンフィグはGi0/0〜0/2が `no switchport`（ルーテッドポート）、Vlan2000/2001がSVI+HSRP(`standby`)、Gi2/0がトランク、あとは vlan 2000-2001 / pvst / vtp transparent のみ。

SW601 初期コンフィグ（抜粋、EI_v2.yaml）:

```ios
interface Loopback0
 ip address 10.6.255.161 255.255.255.255
interface GigabitEthernet0/0
 no switchport
 ip address 10.6.109.1 255.255.255.252
interface GigabitEthernet0/1
 no switchport
 ip address 10.6.13.2 255.255.255.252
interface GigabitEthernet0/2
 no switchport
 ip address 10.6.10.2 255.255.255.252
interface GigabitEthernet2/0
 switchport trunk encapsulation dot1q
 switchport mode trunk
interface Vlan2000
 ip address 10.6.100.2 255.255.255.0
 standby version 2
 standby 100 ip 10.6.100.1
 standby 100 priority 110
interface Vlan2001
 ip address 10.6.101.2 255.255.255.0
 standby 101 ip 10.6.101.1
```

### SW610（L2アクセススイッチ、EIGRP対象外）

初期コンフィグ（EI_v2.yaml）に `router eigrp` セクション自体が存在しない。理由:

```ios
hostname SW610
vlan 2001
interface GigabitEthernet2/0
 switchport trunk allowed vlan 1,2000
 switchport trunk encapsulation dot1q
 switchport mode trunk
interface GigabitEthernet2/1
 switchport trunk allowed vlan 1,2000
 switchport trunk encapsulation dot1q
 switchport mode trunk
interface Vlan2000
 ip address 10.6.100.10 255.255.255.0
```

- SW601/SW602への2本のアップリンク(Gi2/0, Gi2/1)は両方とも `switchport mode trunk`（純粋なL2トランク）で、`no switchport`のルーテッドポートが1本もない。ルーテッドインターフェースが無いのでEIGRPが乗る場所がそもそも無い。
- 唯一のL3アドレス（Vlan2000 SVI, 10.6.100.10/24）は、SW601/SW602が既に `network 10.0.0.0`（Pattern1/2）または `network 10.6.100.0 0.0.0.255`（Pattern3）でEIGRP広報済みの**同一サブネット**上のホストアドレスに過ぎない。新たに広報すべき別サブネットを持たない。
- L3ゲートウェイ（HSRP VIP 10.6.100.1）はSW601/SW602側にあり、SW610はそこにぶら下がる純粋なアクセス層スイッチ（PC61/PC62収容）。VLAN間ルーティングも行わない（`vlan 2001`の宣言はあるがSVIは無い＝トランクで素通しするだけ）。

## R61 インターフェース対応表（EI_v2.yaml より）

| I/F | IPアドレス | 接続先 | 役割 |
|---|---|---|---|
| Lo0 | 10.6.255.61/32 | 自身 | Router-ID/BGP広報用（`network 10.0.0.0` に含まれるがpassiveのまま） |
| Gi0/0 | 100.5.61.2/30 | R5（SP側） | WANアップリンク（BGP AS10000、10.0.0.0/8外なのでEIGRP対象外） |
| Gi0/1 | 10.6.99.1/30 | R62 | LAN内（ルータ間）→ MD5認証 + no passive |
| Gi0/2 | 10.6.12.1/30 | SW602 | LAN内（スイッチ）→ MD5認証 + no passive |
| Gi0/3 | 10.6.10.1/30 | SW601 | LAN内（スイッチ）→ MD5認証 + no passive |
| Gi0/4 | 200.99.61.2/30 (vrf WAN) | SP_1 | WAN（BGP AS19999、vrf WANなのでEIGRP対象外） |
| Tunnel0 | 10.200.0.61/24 | HQ hub 10.200.0.1 | DMVPN。`network 10.0.0.0` に含まれるが意図的にpassiveのまま |

## 検証コマンド

```ios
show ip eigrp neighbors
show ip protocols
show ip eigrp interfaces
show run | sec eigrp        ! R62 のプリステージ済みブロックをコピペ元にする
show run | sec key chain    ! key chain が定義済みか（初期状態では何も出ない）
show key chain              ! 鍵名・有効期間の確認
```

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` — Task 1.6（939〜1105行目付近、R61/R62/SW601/SW602の3パターン比較）
- `EI_v2.yaml` — R61/R62/SW601/SW610ノードの初期コンフィグ、リンク定義（4665〜4833行目、SW610リンクは4749/4756行目）
- `topology2.png` — Branch3内の配線（R61⇄R62、SW601⇄SW610⇄SW602のクロス、SW610⇄PC61/PC62）
- 関連QA:
  - `QA/pattern2/2026-07-17_q6_R61のpassive-interfaceデフォルト設計理由.md`
  - `QA/pattern2/2026-07-17_q6_R62にEIGRP設定がない理由.md`
  - `QA/pattern2/2026-07-17_q6_SW610にEIGRP設定がない理由.md`

最終更新: 2026-07-17
