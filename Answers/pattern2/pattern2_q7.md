# Pattern 2 — 問題7（Task 1.7）MPLS アンダーレイ（OSPF + LDP + LDP認証）

対象: Global SP #1 = R1〜R6（すべてプロバイダ側）。
役割: R1/R2 = P（コア/ハブ, VRFなし, LDPピア3台）、R3〜R6 = PE（VRF fabd2 あり, LDPピア1台）。CE は対象外。
Loopback0: R1=100.255.254.1 / R2=.2 / R3=.3 / R4=.4 / R5=.5 / R6=.6

注意: 問題文のパスワードは `CCIE!nfr4` だが original の解答 config は `CC!E!nfr4` 表記。

## 解答 config（Pattern 2・デバイス別）

### R1（P / ハブ。ピア=R2,R3,R5）

```
mpls ldp router-id Loopback0 force
!
access-list 11 permit 100.255.254.2
access-list 11 permit 100.255.254.3
access-list 11 permit 100.255.254.5
mpls ldp password option 1 for 11 CC!E!nfr4
mpls ldp password required for 11
!
router ospf 1
 prefix-suppression
 mpls ldp autoconfig area 0
!
interface Loopback0
 ip ospf 1 area 0
!
interface range GigabitEthernet0/0-2
 ip ospf 1 area 0
 ip ospf network point-to-point
 mpls ip
```

### R2（P / ハブ。ピア=R1,R4,R6）

```
mpls ldp router-id Loopback0 force
!
access-list 11 permit 100.255.254.1
access-list 11 permit 100.255.254.4
access-list 11 permit 100.255.254.6
mpls ldp password option 1 for 11 CC!E!nfr4
mpls ldp password required for 11
!
router ospf 1
 prefix-suppression
 mpls ldp autoconfig area 0
!
interface Loopback0
 ip ospf 1 area 0
!
interface range GigabitEthernet0/0-2
 ip ospf 1 area 0
 ip ospf network point-to-point
 mpls ip
```

### R3（PE。ピア=R1）

```
mpls ldp router-id Loopback0 force
mpls ldp neighbor 100.255.254.1 password CC!E!nfr4
!
interface Loopback0
 ip ospf 1 area 0
!
router ospf 1
 prefix-suppression
 mpls ldp autoconfig area 0
!
interface GigabitEthernet8
 ip ospf 1 area 0
 ip ospf network point-to-point
 mpls ip
```

### R4（PE。ピア=R2）

```
mpls ldp router-id Loopback0 force
mpls ldp neighbor 100.255.254.2 password CC!E!nfr4
!
interface Loopback0
 ip ospf 1 area 0
!
router ospf 1
 prefix-suppression
 mpls ldp autoconfig area 0
!
interface GigabitEthernet8
 ip ospf 1 area 0
 ip ospf network point-to-point
 mpls ip
```
（注: R4 の `ip address 100.255.254.4/32` は original 上 Pattern 1/3 のみ差分。ただし **EI_v2.yaml の R4 初期コンフィグは `100.255.254.4 255.255.255.254`（/31）**であり /32 ではない。/32 前提の LDP router-id・BGP update-source と噛み合わないため、実機で LDP/iBGP が上がらない場合はここを疑う）

### R5（PE。ピア=R1）

```
mpls ldp router-id Loopback0 force
mpls ldp neighbor 100.255.254.1 password CC!E!nfr4
!
interface Loopback0
 ip ospf 1 area 0
!
router ospf 1
 prefix-suppression
 mpls ldp autoconfig area 0
!
interface GigabitEthernet8
 ip ospf 1 area 0
 ip ospf network point-to-point
 mpls ip
```

### R6（PE。ピア=R2）

```
mpls ldp router-id Loopback0 force
mpls ldp neighbor 100.255.254.2 password CC!E!nfr4
!
interface Loopback0
 ip ospf 1 area 0
!
router ospf 1
 prefix-suppression
 mpls ldp autoconfig area 0
!
interface GigabitEthernet8
 ip ospf 1 area 0
 ip ospf network point-to-point
 mpls ip
```

## 初期コンフィグの OSPF 状態（EI_v2.yaml 実測）

**重要: 事前設定で OSPF ネイバーは一部すでに上がっている。**ただし「隣接が上がっている」≠「要件を満たす」。

| 機器 | `router ospf 1` | Lo0 | コア I/F | 本タスクで実際に不足している分 |
|---|---|---|---|---|
| R1 | ✅ | ✅ | Gi0/0 ✅ Gi0/1 ✅ Gi0/2 ✅ | **P2P のみ**（`ip ospf area 0` は冪等） |
| R2 | ✅ | ✅ | Gi0/0 ✅ Gi0/1 ✅ Gi0/2 ✅ | **P2P のみ** |
| R3 | ✅ | ❌ | Gi8 ✅ | **Lo0 + P2P** |
| R4 | ✅ | ✅ (mask /31) | Gi8 ✅ | **P2P のみ** |
| R5 | ❌ | ❌ | Gi8 ❌ | **全部（`router ospf 1` すら無い）** |
| R6 | ✅ | ✅ | Gi8 ✅ | **P2P のみ** |

- 未設定時の `R1#sh ip ospf nei` は **2行しか出ない**（Gi0/0↔R2、Gi0/1↔R3）。
  Gi0/2↔R5 が出ないのは R5 側が OSPF 皆無だから。要件「すべての内部リンクでネイバー確立」の未達サイン。
- 状態が `FULL/**DR**` なのは network type が broadcast のまま = **Type 2 LSA が生成されている** = 要件違反。
  P2P 化で `FULL/  -` になり Type 2 が消える。ネットワークタイプは Hello に含まれないため
  **片側だけ P2P にしても隣接は上がるが Type 2 は消えない** → 6台全 I/F に打つ。
- 解答の `interface range Gi0/0-2` / `int lo0` は 6台共通のテンプレート。R1/R2 では `ip ospf area 0` 部分が冪等。

## コマンドと要件の対応（要点）

- `mpls ldp router-id Loopback0 force` → Loopback0 を LDP ルータ ID に。
- `ip ospf network point-to-point` → DR/BDR なし = **Type 2 LSA を排除**。
- `prefix-suppression` → **トランジットリンクのプレフィックスを LSA から抑制**（Loopback は広告）。
- `mpls ldp autoconfig area 0` + IF の `mpls ip` → コアでラベルスイッチング有効化。
- R1/R2（P, ピア多数）: `access-list 11` + `mpls ldp password option 1 for 11 …` + `mpls ldp password required for 11` = **グループ/グローバル MD5 認証 + 必須化**。
- R3〜R6（PE, ピア1台）: `mpls ldp neighbor <ip> password …` = **ピア単位 MD5 認証**。
- 認証全体で「未承認 LDP ピア防止＋偽装 TCP ブロック」を実現。

## 設計の考え方（なぜこの config なのか）

### ACL（access-list 11）の考え方
- パケットフィルタではなく、**LDP パスワードを適用するピア集合（グループ）を定義するリスト**。標準 ACL でマッチ対象は **LDP ピアのルータ ID（= 相手の Loopback0）**。
- R1 は直接 LDP を張る R2/R3/R5、R2 は R1/R4/R6 の Loopback を列挙。「認証したい直接 LDP ネイバーの LDP-ID を全部並べる」発想。
- `for 11` でこの集合に一括適用 → ピアが多いハブ（R1/R2）でも1コマンドで全ピアに同じポリシー。これが「グループ/グローバル設定」の実体。

### トランジット情報を LSA に含めないメリット（prefix-suppression）
- LSDB/RIB の縮小（コア間 /30 が全ルータに載らない）→ メモリ・SPF 負荷減。
- インフラ隠蔽（コアのリンクアドレスが OSPF ドメイン/再配布先に漏れない → 攻撃対象化しにくい）。
- MPLS では中継リンクの IP 到達性は不要（転送はラベル、次ホップは Loopback で解決）→ 配る意味がないものを配らない。
- 不要プレフィックス減で収束・安定性が向上。

### なぜ autoconfig（mpls ldp autoconfig area 0）か
- OSPF area 0 の全 IF で LDP を自動有効化 → `mpls ip` の打ち忘れ防止、「IGP が通る範囲 = ラベルが通る範囲」を自動一致。
- ラベル未張り区間による MPLS ブラックホールを防ぐ（IGP と LDP の整合保証）。
- 新コアリンクを OSPF に足せば自動で LDP も有効 → 運用が楽。
- 本解答は保険で各 IF に `mpls ip` も明示。厳密には autoconfig があれば `mpls ip` は必須でない。

### R1 の `interface range GigabitEthernet0/0-2` は3本すべて
- range は **Gi0/0・Gi0/1・Gi0/2 の3本すべて**に `ip ospf 1 area 0` / P2P / `mpls ip` を一括適用（Gi0/2 だけではない。**Gi0/1 にも OSPF は入っている**）。
- 配線: R1 Gi0/0↔R2、Gi0/1↔R3、Gi0/2↔R5（EI_v2.yaml links 4651/4658/4686 行）。3本ともコア内リンクなので全てで OSPF ネイバーが必要。

### PE で `password required for` が不要な理由
- R1/R2 は `password option … for 11`（グループにパスワード用意）だけだと optional（無いピアとも繋がりうる）。要件「全ピア必須」を満たすため `required for 11` で未認証を明示禁止。
- PE の `mpls ldp neighbor <ip> password` は特定1ピアへの直接指定。TCP MD5 は両端一致が前提で、鍵が無ければセッション自体不成立 = そのピアには「必須」がコマンドに内包。
- 要件上も PE は「ピア単位認証」のみで「全ピア必須化」は R1/R2 だけ。PE は ACL グループが無いので `required for <acl>` を使う場面がない。

## 検証コマンド

```
show mpls ldp neighbor detail        # password option + required の適用確認
show mpls ldp parameters             # LDP パラメータ（router-id/password）
show ip ospf database                # Type 2 LSA が無いこと / transit prefix が無いこと
show ip ospf database network        # Type 2 LSA 不在の直接証明（空になること）
show ip ospf database router         # transit link の /30 が消えていること（prefix-suppression）
show ip ospf interface brief         # network type = P2P（Type 列が BCST なら未達）
show ip ospf neighbor                # FULL/DR が残っていないか（全て FULL/ - が正）。行数=リンク数か確認
show ip protocols                    # R5 で OSPF プロセスが無いことの確認
show mpls interfaces                 # 各コア IF で LDP 有効
```

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` 1116〜1292 行（Task 1.7, Pattern 2 列）
- 役割識別: 同 HTML Task 1.8（VRF fabd2 = R3〜R6 のみ）、`topology2.png`
- Loopback/ピア関係: 上記 config の access-list / mpls ldp neighbor 記述
- 初期 OSPF 状態: `EI_v2.yaml` R1〜R6 各ノードの ios_config.txt / iosxe_config.txt（2026-08-06 実測）
- 配線: `EI_v2.yaml` links 4651 行 `R1-Gi0/0<->R2-Gi0/0` / 4658 行 `R3-Gi8<->R1-Gi0/1` / 4686 行 `R5-Gi8<->R1-Gi0/2`

最終更新: 2026-08-06
