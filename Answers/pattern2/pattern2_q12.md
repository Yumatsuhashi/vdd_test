# Pattern 2 — 問題12 NATおよびTelnetアクセス

## 解答 config（デバイス別）

### R23

```
ip http server

interface range GigabitEthernet2-3
ip nat inside

interface GigabitEthernet1
ip nat outside

ip access-list standard CCIENAT
permit 10.0.0.0 0.255.255.255

ip nat inside source list CCIENAT interface GigabitEthernet1 overload
ip nat inside source static tcp 10.2.255.23 80 200.99.23.2 2002 extendable

ip access-list extended CCIETELNET
deny tcp any any eq 23
permit tcp any any eq 3003

username ccieuser password CC!E!nfr4

line vty 0 15
login local
access-class CCIETELNET in
rotary 3
transport input telnet
```

補足:
- `10.2.255.23` は R23 の Loopback0（`EI_v2.yaml` で確認済み）。
- `ip http server` は、静的PATの変換先であるポート80に実体のあるサービス（IOS内蔵HTTPサーバー）を用意するために設定されている（NATルール自体の動作要件ではない）。
- Telnetアクセスはポート3003のみ許可（`CCIETELNET` ACLで標準の23番を拒否）。ログイン認証はローカルデータベース（AAA不使用）。

## `CCIENAT` の ACL について（誤記ではない）

`permit 10.0.0.0 0.255.255.255` は **ワイルドカードマスク**であり正しい（原本 HTML 1826/3010/4026 行で確認）。
ACL はサブネットマスクを使わない。`255.0.0.0`（サブネット）⇔ `0.255.255.255`（ワイルドカード）でビット反転。

| プレフィックス | サブネット | ワイルドカード |
|---|---|---|
| /8 | 255.0.0.0 | **0.255.255.255** |
| /16 | 255.255.0.0 | 0.0.255.255 |
| /24 | 255.255.255.0 | 0.0.0.255 |
| /30 | 255.255.255.252 | 0.0.0.3 |

**⚠️ 逆に `permit 10.0.0.0 255.0.0.0` と書いても IOS はエラーを出さない**が、意味は
「第1オクテットは任意／残り3オクテットは 0.0.0 と完全一致」＝ `x.0.0.0` しかマッチせず NAT が無言で不発になる。

`10.0.0.0/8` と広く取っても安全な理由: ①`ip nat inside` を付けた Gi2/Gi3 から入った通信しか ACL を見ない
②inside→outside を跨ぐときだけ変換される（Gi2↔Gi3 の内部通信は対象外）。**I/F 指定で二重に絞られている。**
`ip nat inside source list` は送信元しか見ないので**標準 ACL で十分**
（`CCIETELNET` が拡張なのは宛先ポート 23/3003 を見る必要があるため）。

R23 の I/F 対応: Gi1 200.99.23.2/30（→SP_1, outside）/ Gi2 10.2.115.1/30（→SW211, inside）/
Gi3 10.2.215.1/30（→SW212, inside）/ Gi4 IP 無し（→cEdge21）/ Lo0 10.2.255.23/32。

## `rotary 3` の要点（ポート番号の導出）

rotary グループは **グループ番号にオフセットを足したポート**で LISTEN する。

| 接続方式 | 計算式 | `rotary 3` |
|---|---|---|
| **Telnet** | **3000 + n** | **3003** |
| Raw TCP | 5000 + n | 5003 |
| Telnet binary | 7000 + n | 7003 |

問題文の「ポート3003のみ」から `3003 − 3000 = 3` と**逆算**して決める。数字自体に意味はない。
（個別 line 指定は 2000/4000/6000 + line 番号。rotary グループは 3000/5000/7000 系列）

**役割分担**: `rotary 3` ＝ 口を開ける（listen）／ `access-class ... in` ＝ 通す落とすを決める（filter）。
VTY はデフォルトで 23 番しか LISTEN せず、rotary を足しても 23 番は開いたままなので**両方必要**。
rotary を忘れて ACL だけ入れると **23 は deny・3003 は connection refused で一切入れなくなる**。
打つ順番は `rotary 3` → 疎通確認 → `access-class` が安全。

**なぜ rotary でなければならないか**: 問題文の「この構成は、動作のために NAT へ依存しないこと」が
`ip nat inside source static tcp ... 3003 ...` での解法を封じているため。VTY ライン自身の機能で解く。

`rotary` は特定 I/F に紐づかず**全 IP で LISTEN** するので「有効なすべての Gi 経由」も自動的に満たす
（R23: Gi1 200.99.23.2 / Gi2 10.2.115.1 / Gi3 10.2.215.1。Gi4 は IP 未設定で対象外）。

`rotary 3` は **3 パターン共通**（解答 HTML が `row-common`）。

## 検証コマンド

```
R23# show tcp brief all | include 3003        ! 3003 で LISTEN しているか
R23# show line                                ! VTY の一覧
R23# show run | section line vty
R23# show ip nat translations                 ! static PAT の確認
R23# show ip nat statistics                   ! inside/outside I/F の割り当て確認

R24# telnet 200.99.23.2 3003                  ! ccieuser / CCIE!nfr4 で入れること
R24# telnet 200.99.23.2                       ! ★拒否されること（23 番）
```

⚠️ 解答 HTML のパスワードは `CC!E!nfr4`、問題文は `CCIE!nfr4`。実機では問題文を優先する。

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`（Task 1.12 — NAT / Telnet / HTTP セクション、R23）
- `EI_v2.yaml`（R23ノードの `interface Loopback0`）

最終更新: 2026-08-11（`rotary 3` のポート導出 3000+n・ACL との役割分担・検証コマンド・CCIENAT のワイルドカードマスク解説を追記）
