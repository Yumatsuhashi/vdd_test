# Task 1.9 distribute-list に隠れた事前設定はあるか／Task 1.9 時点の R11・R12 全体像

## 質問

CCIE_train_hub/Questions/pattern2/pattern2_q9.md
この問題を特にあたり本来設定するべき全体像が見たい

質問の意図としては、回答を見た時に distribute-listがいきなり出てきているから、事前設定があるのかと思った

```
ip prefix-list DENY-R22 deny 101.22.0.0/30
ip prefix-list DENY-R22 permit 0.0.0.0/0 le 32

router ospf 1
redistribute bgp 65001 subnets metric-type 1
distribute-list prefix DENY-R22 out bgp 65001
```

## 回答

### 結論

**`distribute-list` に隠れた事前設定はない。** 必要な前提は 3 つで、うち 2 つは同じブロック内に
書いてある。

| 前提 | どこにある | 無いとどうなる |
|---|---|---|
| ① `ip prefix-list DENY-R22` が存在する | **同じブロックの上 2 行** | 存在しない prefix-list を参照した distribute-list は **全 permit 扱い**。エラーも出ず、無言でフィルタが効かない |
| ② `redistribute bgp 65001` が存在する | **同じブロックの 1 行上** | `out bgp 65001` の適用対象がなく、何もフィルタしない |
| ③ `router ospf 1` が存在する | **Task 1.5 で作られている** | `router ospf 1` に入れず、そもそも打てない |

「いきなり出てきた」ように見える正体は ③ で、Task 1.5 の解答が
`interface ... / ip ospf 1 area 0` というインターフェース直付け方式なので、
**`router ospf 1` という行が Task 1.5 の解答に一度も出てこない**（IOS が暗黙にプロセスを作る）。
そのため Task 1.9 で初めて `router ospf 1` が現れ、新規プロセスに見える。

### Task 1.9 終了時点の R11 の全体像（積み上げ）

```ios
!===== 初期コンフィグ（EI_v2.yaml。触らない）=====
interface Loopback0
 ip address 10.1.255.11 255.255.255.255
interface GigabitEthernet0/0            ! → R3(PE) Gi1。SP #1 向き
 ip address 100.3.11.2 255.255.255.252
interface GigabitEthernet0/1            ! → R12 Gi0/1
 ip address 10.1.99.1 255.255.255.252
interface GigabitEthernet0/2            ! → SW102 Gi0/1
 ip address 10.1.13.1 255.255.255.252
interface GigabitEthernet0/3            ! → SW101 Gi0/0
 ip address 10.1.10.1 255.255.255.252
!
router bgp 65001                        ! ★eBGP は初期投入済み。Task 1.9 では触らない
 no bgp default ipv4-unicast
 neighbor 100.3.11.1 remote-as 10000
 address-family ipv4
  neighbor 100.3.11.1 activate

!===== Task 1.5 で追加（OSPF）=====
interface Loopback0
 ip ospf 1 area 0                       ! ★この行が router ospf 1 を暗黙生成
interface range GigabitEthernet0/1-3
 ip ospf 1 area 0
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 CC!E!nfr4
!                                       ! Gi0/0 は SP 向きなので OSPF に入れない

!===== Task 1.7 / 1.8（SP 側。R11 では作業なし）=====
!  R3 の vrf fabd2 + eBGP が上がって初めて R11 の BGP テーブルに経路が入る

!===== Task 1.9 で追加（ここが解答）=====
ip prefix-list DENY-R22 deny 101.22.0.0/30
ip prefix-list DENY-R22 permit 0.0.0.0/0 le 32
!
router ospf 1
 redistribute bgp 65001 subnets metric-type 1
 distribute-list prefix DENY-R22 out bgp 65001
```

### Task 1.9 終了時点の R12 の全体像

```ios
!===== 初期コンフィグ =====
interface GigabitEthernet0/0            ! → SP_1 ノード Eth0/2。別 ISP 接続 I/F
 ip address 200.99.12.2 255.255.255.252
interface GigabitEthernet0/1            ! → R11
 ip address 10.1.99.2 255.255.255.252
interface GigabitEthernet0/2            ! → SW101
 ip address 10.1.12.1 255.255.255.252
interface GigabitEthernet0/3            ! → SW102
 ip address 10.1.11.1 255.255.255.252
!
router bgp 65001                        ! ★neighbor が 1 本もない = BGP は実質動いていない
 no bgp default ipv4-unicast

!===== Task 1.5 で追加 =====
interface Loopback0
 ip ospf 1 area 0
interface range GigabitEthernet0/1-3
 ip ospf 1 area 0
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 CC!E!nfr4

!===== Task 1.9 で追加 =====
route-map CIO permit 10
 match interface GigabitEthernet0/0
!
router ospf 1
 redistribute connected subnets metric-type 1 route-map CIO
```

**R12 だけ `redistribute connected` な理由**: R12 の `router bgp 65001` には neighbor が 1 本もない
（初期コンフィグ時点で空箱）。BGP で学習した経路が存在しないので、ISP 接続 I/F を OSPF に載せる
手段は connected 再配布しかない。問題文が「R12 の ISP 接続 I/F を OSPF へ再配送」とわざわざ
別要件で書いているのはこのため。

### `distribute-list ... out <protocol>` の文法と OSPF での特殊性

```
distribute-list prefix <prefix-list名> out <元プロトコル> [<プロセスID/AS>]
```

- **OSPF の `out` は再配布フィルタ専用**。ASBR が Type-5 LSA を作る直前に落とす。
  OSPF はリンクステートなので、OSPF→OSPF の広報（LSA フラッディング）は distribute-list では
  止められない。ディスタンスベクタ（EIGRP/RIP）の `distribute-list out <interface>` とは別物。
- `out bgp 65001` は「**BGP 65001 から再配布する経路にだけ適用**」というスコープ指定。
  省略すると全再配布元に適用される。R12 の connected 再配布まで巻き込まないための限定。
- 打つ順番は **prefix-list が先**。空の prefix-list を参照しても IOS はエラーを出さない。

### `permit 0.0.0.0/0 le 32` が要る理由（一番の落とし穴）

prefix-list には **暗黙の deny any** がある。

```ios
ip prefix-list DENY-R22 deny 101.22.0.0/30       ! seq 5
ip prefix-list DENY-R22 permit 0.0.0.0/0 le 32   ! seq 10 ← これが無いと全経路が落ちる
                                                 ! （暗黙 deny any）
```

`le 32` を落として `permit 0.0.0.0/0` だけにすると **デフォルトルートしか許可されない**。
`0.0.0.0/0 le 32` = 「任意のプレフィックス長の任意の経路」。

### Pattern 1（route-map 方式）との対比

同じ prefix-list を、route-map 経由で参照するか直接参照するかの違いしかない。

```ios
! Pattern 1
route-map DENY-R22 permit 10
 match ip address prefix-list DENY-R22
router ospf 1
 redistribute bgp 65001 subnets metric-type 1 route-map DENY-R22

! Pattern 2 / 3（問題文「route-map を使用しないこと」に対応）
router ospf 1
 redistribute bgp 65001 subnets metric-type 1
 distribute-list prefix DENY-R22 out bgp 65001
```

### 経路の流れ（Task 1.9 が担う区間）

```
      他拠点 PE（R5 / R6）
            │ MP-BGP VPNv4          ← Task 1.8
      R3（PE）vrf fabd2 / redistribute connected
            │ eBGP AS10000 ↔ AS65001（100.3.11.1 ↔ 100.3.11.2）
            │                        ← 初期コンフィグ（R11 側は既設）
      R11（HQ CE）BGP テーブル
            │ ★Task 1.9
            │   redistribute bgp 65001 subnets metric-type 1
            │   distribute-list prefix DENY-R22 out bgp 65001
            ▼
      OSPF area 0（Type-5 LSA / E1）
            │
      SW101 / SW102 / R12 →（SW201 経由で DC 側へ）
```

**Task 1.7 / 1.8 が終わっていないと Task 1.9 の結果は目視できない**。R3 の vrf/eBGP が
未設定だと R11 の BGP テーブルが空なので、再配布しても Type-5 LSA が 1 本も生成されない。

### 要件 → コマンド対応（なぜそのキーワードか）

| 要件 | コマンド | 打たないとどうなる |
|---|---|---|
| BGP を使用しない | HQ 内は OSPF 再配布（iBGP を張らない） | — |
| HQ 内部リンクの帯域幅を考慮 | `metric-type 1` | E2（既定）は内部コストを無視し、外部メトリックだけで比較する。HQ 内のどのリンクを通っても等コストになり、帯域が反映されない |
| クラスフルで広報しない | `subnets` | クラスフル境界に一致する経路しか Type-5 にならない。100.3.11.0/30 は 100.0.0.0/8 のサブネットなので落ちる |
| R12 の ISP 接続 I/F を再配送 | `redistribute connected subnets metric-type 1 route-map CIO`（`match interface Gi0/0`） | route-map なしだと Lo0・Gi0/1-3 まで connected として二重に載る |
| R11 が R22 の WAN を広報しない | prefix-list + `distribute-list prefix ... out bgp 65001` | Type-5 LSA に 101.22.0.0/30 が載る |
| route-map を使用しない | R11 側を distribute-list で実装 | — |

### 101.22.0.0/30 はどこから来るのか（Pattern 2 では経路源が無い）

調べた結果、**Pattern 2 のラボ構成では R11 の BGP テーブルに 101.22.0.0/30 は現れない**。

- R22 Gi1 = `101.22.0.2/30`（→ SP_2 ノード）。初期コンフィグでは
  この I/F は **OSPF にも BGP にも入っていない**。
- R22 の初期 BGP は `network 10.2.255.22/32` と R21 への iBGP のみ。
- R22 が SP #2 と eBGP を張り、経路を注入するのは **Pattern 3 の Task 2.1**
  （`neighbor 101.22.0.1 remote-as 10001` / `redistribute ospf 1` / `route-map C2O match interface Gi1`）。
  ここで初めて 101.22.0.0/30 → DC OSPF → R22 BGP → R21 → R3 → R11 の経路ができる。

つまり Pattern 2 では **要件充足のための予防フィルタ**。`show ip bgp` に出てこなくても設定は正しい。
試験では要件に書かれた通り打つのが正解で、「経路が無いから不要」と判断してはいけない。

なお問題文の `101.2.2.0/30` は誤記で、ラボ上の実値は `101.22.0.0/30`（解答資料も同じ）。

### 検証手順

```ios
! R11
show ip bgp                                  ! SP から何を学習しているか（フィルタ対象の有無）
show ip protocols                            ! "Redistributing: bgp 65001" と Outgoing filter の行
show ip prefix-list DENY-R22                 ! ヒットカウント
show ip ospf database external               ! 生成した Type-5 LSA 一覧
show ip ospf database external 101.22.0.0    ! ヒットしないこと = フィルタが効いている

! SW101 / SW102 側
show ip route ospf | include E1              ! E1 で入っていること（E2 なら metric-type 抜け）
```

## 参照

- `Questions/pattern2/pattern2_q9.md` — 問題文（6 要件）
- `Answers/pattern2/pattern2_q9.md` — 解答 config キャッシュ
- `Answers/pattern2/pattern2_q5.md` — Task 1.5 の R11/R12 OSPF（インターフェース直付け方式の根拠）
- `Answers/pattern2/pattern2_q8.md` — R3(PE) の `vrf fabd2` / `address-family ipv4 vrf fabd2`（R11 が経路を受け取る前提）
- `EI_v2.yaml` — R11（Gi0/0 100.3.11.2/30、`router bgp 65001` neighbor 100.3.11.1 remote-as 10000）、
  R12（Gi0/0 200.99.12.2/30、`router bgp 65001` に neighbor なし）、
  R22（Gi1 101.22.0.2/30、`network 10.2.255.22/32` + R21 への iBGP のみ）
- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`
  - 1430〜1470 行付近 — Task 1.9 の R11 / R12 パターン比較（SW101/102/201/202 は Pattern 3 のみ）
  - 2114 行付近 — Task 2.1（Pattern 3 のみ）R22 の `neighbor 101.22.0.1 remote-as 10001` / `redistribute ospf 1`
  - 5338 行付近 — Task 1.9 検証コマンド
