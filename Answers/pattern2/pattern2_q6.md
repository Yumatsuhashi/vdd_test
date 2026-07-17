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

Pattern 3 のみ、R62 の Tunnel0（DMVPN, NHRP redirect対応）をEIGRPに参加させるための追加network文がある（`network 10.200.0.0 0.0.0.255` 等、`no network 10.0.0.0` で置き換え）。

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
```

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` — Task 1.6（939〜1013行目付近、R61/R62の3パターン比較）
- `EI_v2.yaml` — R61/R62ノードの初期コンフィグ、リンク定義（4665〜4833行目）
- `topology2.png` — Branch3内のR61/R62配線
- 関連QA:
  - `QA/pattern2/2026-07-17_q6_R61のpassive-interfaceデフォルト設計理由.md`
  - `QA/pattern2/2026-07-17_q6_R62にEIGRP設定がない理由.md`

最終更新: 2026-07-17
