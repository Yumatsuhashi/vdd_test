# Pattern2 問題6 — R61のEIGRP passive-interfaceデフォルト設計理由

## 質問

key chain CCIE_MD5

key 1

key-string CC!E!nfr4



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





R61の設定について質問がある

・af-interface defaultで一旦全てのインターフェースをpassiveにしてからaf-interfaceでno passiveとして起こしている意味がわからない　またgi0/1-3ごとにaf interfaceしている意味もわからない　rangeみたいな便利なコマンドないの？

## 回答

R61のインターフェース構成（EI_v2.yamlより）:

| I/F | IPアドレス | 接続先 | 役割 |
|---|---|---|---|
| Lo0 | 10.6.255.61/32 | 自身 | Router-ID/BGP広報用 |
| Gi0/0 | 100.5.61.2/30 | R5（SP側） | WANアップリンク（BGP AS10000） |
| Gi0/1 | 10.6.99.1/30 | R62 | LAN内（ルータ間） |
| Gi0/2 | 10.6.12.1/30 | SW602 | LAN内（スイッチ） |
| Gi0/3 | 10.6.10.1/30 | SW601 | LAN内（スイッチ） |
| Gi0/4 | 200.99.61.2/30 (vrf WAN) | SP_1 | WAN（BGP AS19999） |
| Tunnel0 | 10.200.0.61/24 | HQ hub 10.200.0.1 | DMVPN（Xander WAN方向のオーバーレイ） |

topology2.png でもGi0/1→R62、Gi0/2→SW602（クロス配線）、Gi0/3→SW601（クロス配線）とLAN側のみに刺さっていることを確認済み。

### なぜ `af-interface default` で全passiveにしてから起こすのか

設問には「すべてのサブネットをアドバタイズするために、1つのコマンドのみを使用すること」という制約があり、これを満たす最も簡単な方法は10.6.x.xを丸ごとカバーするクラスフルな `network 10.0.0.0` 1行。

しかしこの1行は「広報（advertise）」の役割であり「隣接を張る相手（peer）」までは指定できない。`network 10.0.0.0` は10.0.0.0/8に属する全インターフェース——Lo0、Gi0/1〜0/3、さらにTunnel0（10.200.0.61）——をEIGRPプロセスの対象に巻き込む。

設問要件は「LAN側のすべてのEIGRPピアリングにMD5認証」であり、ピアリング対象はLANの3本（Gi0/1〜0/3）だけ。Tunnel0はXanderのWAN側に向かうDMVPNオーバーレイであり、この設計ではEIGRPネイバーを張る対象ではない（Loopback0もそもそも対向ネイバーが存在しないので張る必要がない）。

そこで:
1. `af-interface default` + `passive-interface` で「network文に拾われた全インターフェースを一旦黙らせる」
2. LAN側3本だけ `no passive-interface` で個別に起こす

という「デフォルト拒否・明示許可」の構成にすることで、network文というクラスフルな広い網をかけつつ、実際にhelloを出す＝隣接を張る範囲だけをGi0/1〜0/3に厳密に絞り込んでいる。この安全策がないと、Tunnel0側で意図しないEIGRP隣接がDMVPNハブ（HQ）との間で確立されてしまい、「LAN側のみ」という要件を満たせなくなる（WAN側のルート伝播はBGP側で別途処理する設計）。

### `af-interface` にrangeコマンドがない理由

これは仕様上の制約で、正しい理解。EIGRP Named ModeのAF-interfaceサブモード（`router eigrp ccie` → `address-family ...` → `af-interface <IF名>`）は単一インターフェース名か `default` キーワードしか受け付けず、range構文はサポートされていない。

pattern2_q5（OSPF）の `interface range GigabitEthernet0/1-3` と対比すると分かりやすい。OSPFの `ip ospf 1 area 0` や認証コマンドはinterface configモードのコマンドなので、IOS標準の `interface range` マクロが使える。対してEIGRP Named Modeの `passive-interface` や `authentication mode md5` は、interface configモードではなく `router eigrp` 配下のaf-interfaceサブモードのコマンドであるため、`interface range` マクロの対象外。したがってGi0/1・Gi0/2・Gi0/3を個別に書くのが正しい（省略できない）実装。

## 参照

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` — Task 1.6（939行目付近、R61の3パターン比較）
- `EI_v2.yaml` — R61ノードの初期コンフィグ、リンク定義（4665〜4784行目）
- `topology2.png` — Branch3内のR61配線
- 関連QA: `QA/pattern2/2026-07-17_q5_OSPF設計と設定理由.md`
