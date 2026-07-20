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
（注: R4 の `ip address 100.255.254.4/32` は Pattern 1/3 のみ差分。Pattern 2 は初期コンフィグ済みで本タスク差分外）

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
show ip ospf interface brief         # network type = P2P
show mpls interfaces                 # 各コア IF で LDP 有効
```

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` 1116〜1292 行（Task 1.7, Pattern 2 列）
- 役割識別: 同 HTML Task 1.8（VRF fabd2 = R3〜R6 のみ）、`topology2.png`
- Loopback/ピア関係: 上記 config の access-list / mpls ldp neighbor 記述

最終更新: 2026-07-20
