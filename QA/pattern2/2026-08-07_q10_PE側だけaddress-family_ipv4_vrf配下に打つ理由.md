# Task 1.10 で `router bgp 10000 / address-family ipv4 vrf fabd2` に降りる理由（PE 側だけ AF 配下・CE 側はグローバルの非対称）

## 質問

CCIE_train_hub/Questions/pattern2/pattern2_q10.md
task10で
router bgp 10000
address-family ipv4 vrf fabd2

これを入れているのはなぜ？

## 回答

### 結論：R5/R6 では **その neighbor が VRF fabd2 の中にしか存在しない**から

R5 の初期コンフィグ（`EI_v2.yaml`）を見ると一目瞭然。

```ios
router bgp 10000
 bgp router-id 100.255.254.5
 no bgp default ipv4-unicast
 neighbor 100.255.254.3 remote-as 10000      ← iBGP はグローバル直下
 neighbor 100.255.254.4 remote-as 10000
 neighbor 100.255.254.6 remote-as 10000
 !
 address-family vpnv4
  neighbor 100.255.254.3 activate            ← 同じ neighbor が AF にも登場
  neighbor 100.255.254.3 send-community extended
  （以下略）
 !
 address-family ipv4 vrf fabd2
  redistribute connected
  neighbor 100.5.61.2 remote-as 65006        ← ★R61 はここにしか存在しない
  neighbor 100.5.61.2 activate
 exit-address-family
```

`fall-over bfd` / `ttl-security hops 1` / `password` はすべて **neighbor サブコマンド**。
neighbor が定義されている文脈でしか適用できないので、`address-family ipv4 vrf fabd2` に降りる必要がある。

R6 も同じ構造（`address-family ipv4 vrf fabd2` に `neighbor 100.6.62.2 remote-as 65006` /
`neighbor 100.6.70.2 remote-as 65007`）。

### グローバル直下で打つとどうなるか（一番危険なパターン）

```ios
R5(config-router)# neighbor 100.5.61.2 fall-over bfd
% Specify remote-as or peer-group commands first
```

エラーで弾かれるので、つい `remote-as` から打ってしまう。すると:

**グローバル AF に別人格の neighbor 100.5.61.2 が新規作成される。**
VRF 内の本物のセッションには一切効かず、しかも `no bgp default ipv4-unicast` があるので
activate もされず Idle のまま放置される。**エラーが出ないので気づけない**。
VRF 側の要件（BFD 連動 / GTSM / MD5）は未達のまま採点される。

### CE 側（R61/R62）は AF に降りない — 非対称なのがポイント

```ios
! R61 の初期コンフィグ
router bgp 65006
 bgp log-neighbor-changes
 network 10.6.255.61 mask 255.255.255.255
 neighbor 100.5.61.1 remote-as 10000      ← ★グローバル直下（R5 向け）
 !
 address-family ipv4 vrf WAN
  neighbor 200.99.61.1 remote-as 19999    ← これは Branch 側の別セッション。無関係
  neighbor 200.99.61.1 activate
 exit-address-family
```

R61 にも `address-family ipv4 vrf WAN` はあるが、**R5 向けのセッションはグローバル**。
だから解答も `router bgp 65006` 直下でそのまま打っている。

**同じ 1 本の eBGP セッションでも、PE 側は AF 配下・CE 側はグローバル**という非対称になる。
R62 も同様（`neighbor 100.6.62.1 remote-as 10000` がグローバル直下、`vrf WAN` は空箱）。

| 機器 | 役割 | 対向 | neighbor の所在 | Task 1.10 で入る context |
|---|---|---|---|---|
| R5 | PE | R61 (100.5.61.2) | `address-family ipv4 vrf fabd2` | **AF に降りる** |
| R6 | PE | R62 (100.6.62.2) | `address-family ipv4 vrf fabd2` | **AF に降りる** |
| R61 | CE | R5 (100.5.61.1) | グローバル直下 | そのまま |
| R62 | CE | R6 (100.6.62.1) | グローバル直下 | そのまま |

### `address-family vpnv4` と `address-family ipv4 vrf` の決定的な違い

Task 1.8 と Task 1.10 で **同じ `neighbor … password CC!E!nfr4` の置き場所が違う**のはこのため。

| | neighbor の実体 | `remote-as` / `password` / `ttl-security` の場所 |
|---|---|---|
| `address-family vpnv4`（iBGP・Task 1.8） | **グローバルにも存在**。AF には `activate` / `send-community` だけ | **グローバル直下** |
| `address-family ipv4 vrf fabd2`（PE-CE eBGP・Task 1.10） | **VRF 専用。グローバルには存在しない** | **AF の中に全部** |

```ios
! Task 1.8 の R5（iBGP のパスワード）
router bgp 10000
 neighbor 100.255.254.3 password CC!E!nfr4        ← グローバル直下

! Task 1.10 の R5（eBGP のパスワード）
router bgp 10000
 address-family ipv4 vrf fabd2
  neighbor 100.5.61.2 password CC!E!nfr4          ← AF の中
```

通常 `password` や `ttl-security` は「TCP セッション属性＝グローバルに書くもの」だが、
**VRF 内の neighbor はセッション自体が VRF に属する**ため、`address-family ipv4 vrf` の中が
その neighbor にとっての「グローバル相当」になる。これが `address-family ipv4 vrf` の特殊性。

一般則としての住み分け:

| 種類 | 例 | 書く場所 |
|---|---|---|
| セッション属性（TCP 単位） | `remote-as` `update-source` `password` `ttl-security` `ebgp-multihop` `timers` `fall-over` | グローバル直下。**ただし VRF neighbor は `af ipv4 vrf` の中** |
| AF 属性（経路単位） | `activate` `route-map` `next-hop-self` `send-community` `soft-reconfiguration` `maximum-prefix` | 該当 AF |

### `bfd interval` だけインターフェースにある理由

```ios
interface GigabitEthernet1        ! R5 Gi1 = vrf forwarding fabd2 / 100.5.61.1/30
 bfd interval 333 min_rx 333 multiplier 3
```

BFD は BGP とは**別プロトコル**のリンク単位ハローで、VRF 文脈は関係ない。役割分担:

| どこ | 何を決めるか |
|---|---|
| `interface Gi1` の `bfd interval 333 min_rx 333 multiplier 3` | BFD セッションのタイマー（333ms × 3 = 約 1 秒で障害検出）＝問題文の「333ms ごと / 3 回連続失敗」 |
| BGP neighbor の `fall-over bfd` | 「BFD が落ちたら即 BGP を落とす」という **BFD クライアント登録**＝問題文の「BGP ピアをダウン状態に」 |

片方だけでは動かない:

- `bfd interval` のみ → BFD セッションは張るが BGP は無反応。ホールドタイム 180 秒を待つ
- `fall-over bfd` のみ → BFD セッションがそもそも張られない

### 本番での判断基準

打つ前に **`show run | section router bgp` でその neighbor がどの文脈に書かれているか**を確認する。
これだけで context を間違えない。

```ios
show run | section router bgp                          ! ★打つ前に必ず。neighbor の所在確認
show ip bgp vpnv4 vrf fabd2 neighbors 100.5.61.2       ! vrf 指定が要る = VRF neighbor の証拠
show ip bgp neighbors 100.5.61.2                       ! ← 何も返らない（グローバルに居ない）
show bgp vpnv4 unicast vrf fabd2 summary               ! セッション状態
show bfd neighbors details                             ! Rx/Tx interval 333000 us, mult 3
```

`show ip bgp vpnv4 vrf fabd2 neighbors …` に **`vrf fabd2` を書かないと引けない**こと自体が、
「この neighbor は VRF の中にいる」ことの証明になる。

## 参照

- `Questions/pattern2/pattern2_q10.md` — 問題文（BFD 333ms×3 / GTSM / MD5 は R5-R61 のみ）
- `Answers/pattern2/pattern2_q10.md` — 解答 config キャッシュ
- `Answers/pattern2/pattern2_q8.md` 209〜235 行 — Task 1.8 の R5/R6（iBGP の password が
  `router bgp 10000` **直下**にある比較対象）
- `EI_v2.yaml`
  - R5 — `interface GigabitEthernet1 / vrf forwarding fabd2 / ip address 100.5.61.1 255.255.255.252`、
    `address-family ipv4 vrf fabd2 / neighbor 100.5.61.2 remote-as 65006 / activate`
  - R6 — `interface GigabitEthernet1 / vrf forwarding fabd2 / 100.6.62.1/30`、
    `address-family ipv4 vrf fabd2 / neighbor 100.6.62.2 remote-as 65006 / neighbor 100.6.70.2 remote-as 65007`
  - R61 — `router bgp 65006 / neighbor 100.5.61.1 remote-as 10000`（**グローバル直下**）＋
    `address-family ipv4 vrf WAN / neighbor 200.99.61.1 remote-as 19999`（別セッション）
  - R62 — `router bgp 65006 / neighbor 100.6.62.1 remote-as 10000`（グローバル直下）＋ `vrf WAN` は空
- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`
  - 3848〜3880 行付近 — Task 1.10 の Pattern 2 単体解答（R5/R6 に `address-family ipv4 vrf fabd2` あり、
    R61/R62 にはなし）
  - 5345〜5349 行付近 — Task 1.10 検証コマンド（全パターン同一設定）
