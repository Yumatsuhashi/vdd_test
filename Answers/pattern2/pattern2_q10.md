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

## config context の理由（PE 側だけ AF 配下・CE 側はグローバル）

| 機器 | 役割 | neighbor の所在（初期コンフィグ） | Task 1.10 で入る context |
|---|---|---|---|
| R5 / R6 | PE | `address-family ipv4 vrf fabd2` 内（VRF 専用。グローバルには存在しない） | **AF に降りる** |
| R61 / R62 | CE | `router bgp 65006` 直下（`af ipv4 vrf WAN` は Branch 側の別セッション） | そのまま |

- `fall-over bfd` / `ttl-security hops 1` / `password` は全て **neighbor サブコマンド**。
  neighbor が定義されている文脈でしか適用できない。
- **グローバル直下で打つと `% Specify remote-as or peer-group commands first`**。
  そこで remote-as から打つと**別人格の neighbor が新規作成**され、VRF の本物のセッションには
  効かず、`no bgp default ipv4-unicast` で activate もされず Idle 放置。**エラーが出ないので危険**。
- `address-family vpnv4` の neighbor は**グローバルにも存在する**ため、Task 1.8 の iBGP password は
  `router bgp 10000` 直下。`address-family ipv4 vrf` の neighbor は VRF 専用なので Task 1.10 の
  eBGP password は AF の中。**同じコマンドで置き場所が違う理由がこれ**。
- `bfd interval` が interface 側なのは、BFD が BGP とは別プロトコルのリンク単位ハローだから。
  I/F = タイマー（333ms×3）、BGP neighbor の `fall-over bfd` = BFD クライアント登録。
  片方だけでは動かない（`bfd interval` のみ → BGP 無反応でホールドタイム 180 秒待ち／
  `fall-over bfd` のみ → BFD セッションが張られない）。
- 打つ前の確認は `show run | section router bgp` で neighbor の所在を見るのが確実。

## 事前設定の有無

- BFD・GTSM（`ttl-security hops`）・パスワードとも、R5/R6/R61/R62 のいずれの初期コンフィグにも存在しない（`EI_v2.yaml` に該当行なし）。
- **完全新規設定**。Task 1.8 のようにVRF/RTが部分的に投入済みという事情もなく、丸ごと追加。

## 検証コマンド

```
show run | section router bgp                     ! ★打つ前に neighbor の所在（context）を確認
show bfd neighbors
show bfd neighbors details                        ! Rx/Tx interval 333000 us, mult 3
show ip bgp vpnv4 vrf fabd2 neighbors 100.5.61.2  ! vrf 指定が要る = VRF neighbor の証拠
show ip bgp neighbors 100.5.61.2                  ! ← 何も返らない（グローバルに居ない）
```

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` — Task 1.10 セクション（パターン2単体解答 3848〜3905行付近、検証コマンド 5345〜5349行付近）
- `EI_v2.yaml` — R5/R6/R61/R62 各ノードの初期コンフィグ
  - R5: `Gi1 vrf forwarding fabd2 / 100.5.61.1/30`、`af ipv4 vrf fabd2 / neighbor 100.5.61.2 remote-as 65006`
  - R6: `Gi1 vrf forwarding fabd2 / 100.6.62.1/30`、`af ipv4 vrf fabd2 / neighbor 100.6.62.2`・`100.6.70.2`
  - R61: `router bgp 65006 / neighbor 100.5.61.1 remote-as 10000`（**グローバル直下**）＋ `af ipv4 vrf WAN`（別セッション）
  - R62: `router bgp 65006 / neighbor 100.6.62.1 remote-as 10000`（グローバル直下）＋ `vrf WAN` は空
  - BFD / ttl-security / password は 4 台とも該当行なし（完全新規）
- 関連 QA: `QA/pattern2/2026-08-07_q10_PE側だけaddress-family_ipv4_vrf配下に打つ理由.md`

最終更新: 2026-08-07
