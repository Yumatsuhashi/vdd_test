# Pattern 2 — 問題9 再配送（IGP）／ OSPF 再配布・フィルタ

Task 1.9。HQ の CE ルータ（R11 / R12）で、SP から学習したルートを HQ 内 OSPF へ再配布する。

## 解答 config（デバイス別）

### R11（SP #1 向け CE。Gi0/0 = 100.3.11.2/30 ↔ R3(PE) 100.3.11.1、eBGP 65001↔10000）

```
ip prefix-list DENY-R22 deny 101.22.0.0/30
ip prefix-list DENY-R22 permit 0.0.0.0/0 le 32
!
router ospf 1
 redistribute bgp 65001 subnets metric-type 1
 distribute-list prefix DENY-R22 out bgp 65001
```

### R12（別 ISP 向け CE。Gi0/0 = 200.99.12.2/30 が ISP 接続 I/F）

```
route-map CIO permit 10
 match interface GigabitEthernet0/0
!
router ospf 1
 redistribute connected subnets metric-type 1 route-map CIO
```

## 要件 → コマンド対応

| 問題文の要件 | 満たすコマンド／キーワード |
|---|---|
| BGP を使用しないこと | HQ 内は OSPF へ再配布（HQ 内に iBGP を張らない） |
| HQ 内部リンクの帯域幅が考慮されること | `metric-type 1`（E1 = 外部メトリック + 内部 OSPF コスト） |
| クラスフルな状態で広報されないこと | **`subnets`** |
| R12 の ISP 接続 I/F を OSPF へ再配送 | `redistribute connected subnets metric-type 1 route-map CIO`（`match interface GigabitEthernet0/0`） |
| R11 が R22 の WAN ネットワークを広報しない | `ip prefix-list DENY-R22 deny 101.22.0.0/30` + `distribute-list prefix DENY-R22 out bgp 65001` |
| route-map を使用しないこと | R11 のフィルタを route-map ではなく `distribute-list prefix ... out bgp 65001` で実装 |

## Pattern 別の差分（同 Task の他パターン）

| デバイス | Pattern 1 | Pattern 2 | Pattern 3 |
|---|---|---|---|
| R11 | `route-map DENY-R22 permit 10` / `match ip address prefix-list DENY-R22` / `redistribute bgp 65001 subnets metric-type 1 route-map DENY-R22` | `redistribute bgp 65001 subnets metric-type 1` + `distribute-list prefix DENY-R22 out bgp 65001` | Pattern 2 と同じ |
| R12 | `redistribute connected metric-type 1 subnets`（route-map なし） | `route-map CIO` + `redistribute connected subnets metric-type 1 route-map CIO` | Pattern 2 と同じ + `timers throttle lsa 0 4000 4000` |
| SW101/102/201/202 | — | — | Pattern 3 のみ OSPF MD5 認証追加 |

## 前提設定（Task 1.9 で「打たないが必要」なもの）

解答ブロックは差分のみ。以下は既に入っている前提。

| 前提 | 出どころ | 無いとどうなる |
|---|---|---|
| `router ospf 1` プロセス | **Task 1.5** の `ip ospf 1 area 0`（インターフェース直付け方式が暗黙生成） | Task 1.9 の `router ospf 1` に入れない。**Task 1.5 の解答に `router ospf 1` の行が無い**ため、Task 1.9 で初めて現れて新規プロセスに見える |
| R11 の `router bgp 65001` / `neighbor 100.3.11.1 remote-as 10000` / af ipv4 activate | **初期コンフィグ（EI_v2.yaml）** | 再配布元が無い |
| R3(PE) の `vrf fabd2` + `address-family ipv4 vrf fabd2` | **Task 1.8** | R11 の BGP テーブルが空 → Type-5 LSA が 1 本も生成されず、Task 1.9 の結果を目視できない |
| `ip prefix-list DENY-R22` | **Task 1.9 の同ブロック上 2 行** | 存在しない prefix-list を参照した distribute-list は **エラーなしで全 permit 扱い**（無言でフィルタが効かない） |

`permit 0.0.0.0/0 le 32` は prefix-list の**暗黙 deny any** を打ち消すため。
`le 32` を落とすとデフォルトルートしか通らない。

`distribute-list prefix <name> out <protocol>` の `out` は、OSPF では **再配布フィルタ専用**
（ASBR が Type-5 LSA を作る直前に落とす）。OSPF→OSPF の LSA フラッディングは止められない。
`out bgp 65001` の source protocol 指定は、R12 側の connected 再配布を巻き込まないためのスコープ限定。

**R12 だけ `redistribute connected` な理由**: R12 の初期 `router bgp 65001` には neighbor が
1 本もない（空箱）。BGP 学習経路が存在しないため、ISP 接続 I/F を OSPF に載せる手段は connected のみ。

## 101.22.0.0/30 の経路源（Pattern 2 には存在しない）

- R22 Gi1 = `101.22.0.2/30`（→ SP_2 ノード）。初期コンフィグでは **OSPF にも BGP にも入っていない**。
  R22 の初期 BGP は `network 10.2.255.22/32` + R21 への iBGP のみ。
- この経路を注入するのは **Pattern 3 の Task 2.1**（R22）:
  `router bgp 65002 / neighbor 101.22.0.1 remote-as 10001 / redistribute ospf 1` ＋
  `route-map C2O match interface Gi1` を使った `router ospf 1 / redistribute connected ... route-map C2O`。
- したがって **Pattern 2 では `show ip bgp` に 101.22.0.0/30 は出てこない＝予防フィルタ**。
  経路が無いことを理由に設定を省いてはいけない（要件充足が採点対象）。

## 検証コマンド

```
show ip bgp                             ! R11 が SP から何を学習しているか（フィルタ対象の有無）
show ip prefix-list DENY-R22            ! ヒットカウント
show ip ospf database external          ! Type 5 LSA に SP 由来ルートが載っているか
show ip route ospf | include E1         ! E1 で入っているか（E2 なら metric-type 抜け）
show ip ospf database external 101.22.0.0   ! ヒットしなければ distribute-list が効いている
show ip protocols                       ! Redistributing / Outgoing filter を確認
```

`subnets` を書き忘れた場合、IOS が `% Only classful networks will be redistributed`
相当の挙動になり、100.3.11.0/30・101.22.0.0/30・200.99.12.0/30 が Type 5 LSA に一切現れない。

## 既知の差異

- 問題文は R22 の WAN を `101.2.2.0/30` と記載するが、CML ラボの R22 Gi1 は `101.22.0.2/30`。
  解答資料の prefix-list も `101.22.0.0/30`。**ラボ上は `101.22.0.0/30` が正**。
- 「route-map を使用しないこと」に対し Pattern 2 の R12 は `route-map CIO` を使っており厳密には矛盾。
  資料上 route-map を完全排除した組み合わせは存在しない（Pattern 1 は R11 側で route-map 使用）。
  制約は実質「R11 のフィルタに route-map を使うな」の意味と解釈するのが妥当。

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` — `Task 1.9 — OSPF再配布 / フィルタ`（`<div id="t19">`）、R11 / R12 の Pattern 2 列
- `EI_v2.yaml` — R11（Gi0/0 100.3.11.2/30、router bgp 65001 neighbor 100.3.11.1 remote-as 10000）、R12（Gi0/0 200.99.12.2/30）、R22（Gi1 101.22.0.2/30）
- `Questions/pattern2/pattern2_q9.md` — 問題文
- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` 2114 行付近 — Task 2.1（Pattern 3 のみ）R22 の
  `neighbor 101.22.0.1 remote-as 10001` / `redistribute ospf 1`（101.22.0.0/30 の唯一の経路源）
- `Answers/pattern2/pattern2_q5.md` — Task 1.5 の R11/R12 OSPF（`router ospf 1` 暗黙生成の根拠）
- `Answers/pattern2/pattern2_q8.md` — R3(PE) の vrf fabd2 / eBGP（R11 が経路を受け取る前提）
- 関連 QA: `QA/pattern2/2026-08-07_q9_distribute-listの前提設定とTask1.9時点の全体像.md`

最終更新: 2026-08-07
