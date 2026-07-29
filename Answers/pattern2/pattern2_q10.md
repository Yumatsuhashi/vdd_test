# Pattern 2 — 問題10（Task 1.10）BFD + BGP Security

## 解答 config（デバイス別）

### R5（PE。R61とのeBGPをBFD+GTSM+MD5で保護）

```
interface GigabitEthernet1
bfd interval 333 min_rx 333 multiplier 3

router bgp 10000
address-family ipv4 vrf fabd2
neighbor 100.5.61.2 fall-over bfd
neighbor 100.5.61.2 ttl-security hops 1
neighbor 100.5.61.2 password CC!E!nfr4
```

### R6（PE。R62とのeBGPをBFD+GTSMのみで保護。パスワードなし）

```
interface GigabitEthernet1
bfd interval 333 min_rx 333 multiplier 3

router bgp 10000
address-family ipv4 vrf fabd2
neighbor 100.6.62.2 fall-over bfd
neighbor 100.6.62.2 ttl-security hops 1
```

### R61（CE。R5とのeBGPをBFD+GTSM+MD5で保護）

```
interface GigabitEthernet0/0
bfd interval 333 min_rx 333 multiplier 3

router bgp 65006
neighbor 100.5.61.1 fall-over bfd
neighbor 100.5.61.1 ttl-security hops 1
neighbor 100.5.61.1 password CC!E!nfr4
```

### R62（CE。R6とのeBGPをBFD+GTSMのみで保護。パスワードなし）

```
interface GigabitEthernet0/0
bfd interval 333 min_rx 333 multiplier 3

router bgp 65006
neighbor 100.6.62.1 fall-over bfd
neighbor 100.6.62.1 ttl-security hops 1
```

## 問題文とパスワード設定の対応（重要）

問題文（`Questions/pattern2/pattern2_q10.md`）は次の2ペアを区別している。

- 「R5–R61間**および**R6–R62間」→ BFD（333ms/3回）と `ttl-security hops 1`（偽装IPパケット/CPU攻撃対策 = GTSM）は**両ペア共通**。
- 「R5–R61間のBGPピアリングで使用されるTCPセッションには、MD5フラグを付与」→ **MD5パスワードはR5–R61間のみ**。R6–R62間には要求されていない。

問題文は MD5 の**値そのものは明示していない**（「MD5フラグを付与」としか書かれていない）が、解答は Task 1.8 で既に使われている値
**`CC!E!nfr4`**（表記は `CCIE!nfr4`）をそのまま再利用している。ラボ全体で MD5/PSK 系の値は基本的にこの1つに統一されているため、
値の指定がない場合はこの共通パスワードを使うのが解答の前提になっている。

## 事前設定の有無

- BFD・GTSM（`ttl-security hops`）・パスワードとも、R5/R6/R61/R62 のいずれの初期コンフィグにも存在しない（`EI_v2.yaml` に該当行なし）。
- **完全新規設定**。Task 1.8 のようにVRF/RTが部分的に投入済みという事情もなく、丸ごと追加。

## 検証コマンド

```
show bfd neighbors
show bfd neighbors details
show ip bgp vpnv4 vrf fabd2 neighbors 100.5.61.2
```

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` — Task 1.10 セクション（パターン2単体解答 3848〜3905行付近、検証コマンド 5345〜5349行付近）
- `EI_v2.yaml` — R5/R6/R61/R62 各ノードの初期コンフィグ（該当行なしを確認）

最終更新: 2026-07-30
