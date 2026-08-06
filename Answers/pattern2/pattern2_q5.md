# Pattern 2 — 問題5 OSPF (Task 1.5)

## 解答 config（デバイス別）

### SW101

```ios
interface range vlan 2000-2001
 ip ospf 1 area 0
interface range GigabitEthernet0/0-1
 ip ospf 1 area 0
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 CC!E!nfr4
```

### SW102

```ios
interface range vlan 2000-2001
 ip ospf 1 area 0
interface range GigabitEthernet0/0-1
 ip ospf 1 area 0
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 CC!E!nfr4
```

### R11

```ios
interface Loopback0
 ip ospf 1 area 0
interface range GigabitEthernet0/1-3
 ip ospf 1 area 0
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 CC!E!nfr4
```

### R12

```ios
interface Loopback0
 ip ospf 1 area 0
interface range GigabitEthernet0/1-3
 ip ospf 1 area 0
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 CC!E!nfr4
```

### R21

```ios
interface range GigabitEthernet2-4, Loopback0
 ip ospf 1 area 0
router ospf 1
 redistribute bgp 65002 metric-type 1 subnets
```

### R22

```ios
interface range GigabitEthernet2-4, Loopback0
 ip ospf 1 area 0
```

### R23

```ios
router ospf 1
 router-id 10.2.255.23
interface range GigabitEthernet2-3, Loopback0
 ip ospf 1 area 0
```

### R24

```ios
router ospf 1
 router-id 10.2.255.24
interface range GigabitEthernet2-3, Loopback0
 ip ospf 1 area 0
```

## 検証コマンド

```ios
show ip ospf neighbor
show ip ospf interface
show ip ospf interface | include authentication   ! SW101/SW102, R11/R12 で message-digest が有効か確認
```

### 「どのI/Fに設定が必要か」を洗い出す2コマンド

```ios
show ip interface brief | exclude unassigned   ! IP を持つ（＝L3 の）インターフェース一覧
show ip ospf interface brief                   ! OSPF が有効なインターフェース一覧
```

**前者にあって後者に無いもの = 設定が必要なインターフェース**。SW101 ではこの差分が
Vlan2000/Vlan2001 の 2 本だけになる。SW201/SW202/SW211/SW212 では差分ゼロ（＝設定不要）。

### 要件 → 確認コマンドの割り当て（brief だけでは足りない）

| 問題文の要件 | 確認コマンド | brief で見えるか |
|---|---|---|
| すべての I/F で OSPF 有効化 | `sh ip int b \| ex unassigned` と `sh ip ospf int b` の差分 | ✅ |
| すべての OSPF ネイバーを確立 | `sh ip ospf neighbor` / brief の **Nbrs F/C 列** | ✅ |
| **R11/R12 は MD5 認証** | `sh ip ospf int <if>` / `sh run int <if>` | ❌ **見えない** |
| R21 で BGP を再配布 | `sh ip protocols` / `sh run \| sec router ospf` | ❌ |

**`show ip ospf interface brief` に認証欄はない**。SW101 の `interface range Gi0/0-1` が解答にあるのは
OSPF 有効化のためではなく **MD5 認証のため**（`ip ospf 1 area 0` は既存の再入力で冗長）。
認証の一括監査は `show ip ospf interface | include is up|Message digest|authentication`
（未設定なら `Message digest authentication enabled` の行がそもそも出ない）。

**`Nbrs F/C` の読み方**: Full 状態のネイバー数 / 検出したネイバー総数。設定前の SW101 実機出力では
Gi0/2（→SW201）が `1/1`、Gi0/0（→R11）と Gi0/1（→R12）が `0/0`。R11/R12 は初期コンフィグに OSPF が
一切ないため。**0/0 は「対向機器が未設定」のサイン**で、要件「すべてのネイバーを確立」の違反を示す。

**罠**: 本ラボは `network` 文ではなくインターフェース直付け方式（`ip ospf 1 area 0`）のため、
`show run | section router ospf` は中身が空。これを見て「未設定」と誤判定しないこと。
`show ip protocols` の "Routing on Interfaces Configured Explicitly (Area 0)" には一覧が出る。
MD5 認証の有無は `show ip ospf interface brief` には出ないので `show ip ospf interface <if>`
（`Message digest authentication enabled` / `Youngest key id is 1`）で確認する。

## 初期コンフィグ（EI_v2.yaml）での OSPF 設定状況

### SW101 / SW102

| インターフェース（SW101） | 種別 | 初期コンフィグの OSPF | Task 1.5 で必要な作業 |
|---|---|---|---|
| Loopback0 (10.1.255.101) | L3 | `ip ospf 1 area 0` 済 | なし |
| Gi0/0 (10.1.10.2) → R11 Gi0/3 | L3 | `ip ospf 1 area 0` 済 | **MD5 認証のみ追加** |
| Gi0/1 (10.1.12.2) → R12 Gi0/2 | L3 | `ip ospf 1 area 0` 済 | **MD5 認証のみ追加** |
| Gi0/2 (10.2.241.2) → SW201 Gi1/2 | L3 | `ip ospf 1 area 0` 済 | なし（対向が R11/R12 でないため認証不要） |
| Vlan2000 (10.1.100.2) | L3 | **なし** | **`ip ospf 1 area 0` 追加** |
| Vlan2001 (10.1.101.2) | L3 | **なし** | **`ip ospf 1 area 0` 追加** |
| Gi1/2, Gi1/3, Gi2/0, Gi2/1, Po1, Po3 | L2 trunk | — | 対象外（IP なし） |

→ 解答の `interface range Gi0/0-1` に含まれる `ip ospf 1 area 0` は**既に入っており冗長**（無害）。
このrangeの本来の目的は **MD5 認証の追加**。

### R11 / R12

初期コンフィグに OSPF 設定が**一切ない**。そのため解答では Loopback0 と Gi0/1-3 を明示している
（Gi0/0 は SP 向き 100.3.11.2 で問題文の除外リスト対象）。

### R21 / R22 / R23 / R24

| 機器 | 初期コンフィグの OSPF | 解答での実質的な追加 |
|---|---|---|
| R21 | Lo0 / Gi2 / Gi3 / Gi4 すべて `ip ospf 1 area 0` 済（`router ospf 1` あり・中身は空） | **`redistribute bgp 65002 metric-type 1 subnets` のみ**（interface 行は再入力で冗長） |
| R22 | `router ospf 1` の箱だけ。インターフェース側は未設定 | Lo0 + Gi2-4 を area 0 へ |
| R23 / R24 | **何もなし** | router-id 明示 + Lo0 + Gi2-3 |

### SW201 / SW202 / SW211 / SW212（設定不要の根拠）

**全 L3 インターフェースに `ip ospf 1 area 0` が投入済み**。差分ゼロのため解答に登場しない。

SW201: Lo0 / Gi0/0 / Gi0/1 / Gi0/3 / Gi1/0 / Gi1/1 / Gi1/2 / Vlan3999 / Vlan4000（計9本）
SW202: Lo0 / Gi0/0 / Gi0/1 / Gi0/3 / Gi1/0 / Gi1/1 / Gi1/2 / Vlan3999 / Vlan4000（計9本）
SW211: Lo0 / Gi0/0-3 / Gi1/0-3（計9本）
SW212: Lo0 / Gi0/0-3 / Gi1/0-2（計8本）

SW201/SW202 に残る Gi0/2・Gi1/3 は trunk（native vlan 4000）で IP を持たない。この 2 本の接続先は
**cEdge21 / cEdge22（SD-WAN ルータ）**であり、問題文の「非 SD-WAN ルータ間」という限定に対応する:

```
SW201-Gi0/2 <-> cEdge22-Eth0/0 (4518行)   SW201-Gi1/3 <-> cEdge21-Eth0/0 (4532行)
SW202-Gi0/2 <-> cEdge21-Eth0/1 (4525行)   SW202-Gi1/3 <-> cEdge22-Eth0/1 (4539行)
```

MD5 も不要（要件は R11/R12 の隣接に限定。SW201 の隣接相手は R21/R22/SW211/SW212/SW101/SW202）。

### 一覧（Task 1.5 で「実際に手を動かす」のはどこか）

| 機器 | 初期 OSPF | 実質的な作業 |
|---|---|---|
| R11 / R12 | なし | Lo0 + Gi0/1-3 を area 0 ＋ MD5 認証 |
| R21 | 全 L3 済 | redistribute bgp のみ |
| R22 | プロセスのみ | Lo0 + Gi2-4 |
| R23 / R24 | なし | router-id + Lo0 + Gi2-3 |
| SW101 / SW102 | Vlan2000/2001 のみ未 | Vlan2000/2001 ＋ Gi0/0-1 に MD5 |
| SW201 / SW202 / SW211 / SW212 | 全 L3 済 | **なし** |

**読み方の原則**: 「解答に無い = 使わない」ではなく「解答に無い = 既に入っている」。

## 補足（設計上の注意）

- SW201/SW202/SW211/SW212 が解答に出てこないのは、EI_v2.yaml の初期コンフィグで OSPF process 1 / area 0 が設定済みのため（追加要件なし）
- SP 向きインターフェース（R11/R12 の Gi0/0、R21/R22 の Gi1、R23/R24 の Gi1）は BGP 用のため OSPF に入れない
- 設計意図・機器ごとの理由の詳細は `QA/pattern2/2026-07-17_q5_OSPF設計と設定理由.md` を参照

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` — 「Pattern 2」タブ内 Task 1.5 — OSPF（3348行付近）、「検証コマンド」タブ Task 1.5（5307行付近）
- `EI_v2.yaml` — SW201/SW202/SW211/SW212 の初期コンフィグ（OSPF 設定済みの根拠）
- 関連 QA: `QA/pattern2/2026-07-17_q5_OSPF設計と設定理由.md`

最終更新: 2026-07-17
