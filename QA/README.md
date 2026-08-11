# QA 索引

CCIE 学習中の質問と回答の蓄積。運用ルールは `.claude/skills/ccie-qa/SKILL.md` を参照。

## pattern1

（まだなし）

## pattern2

- [Task 1.2 SW101が解答に出てこない理由 / SW110で既に設定済みに見える理由（初期コンフィグとの関係）](pattern2/2026-07-30_q2_SW101とSW110のVLAN設定が空白の理由.md) — 2026-07-30
- [Task 1.2 表のPo行とGi行は別要件（PoはSW110の解答に出てこない理由の続き）](pattern2/2026-07-30_q2_PoとGiは別要件でありPoは初期設定済み.md) — 2026-07-30
- [Task 1.5 OSPF Q&A — 設計意図と設定対象の理由](pattern2/2026-07-17_q5_OSPF設計と設定理由.md) — 2026-07-17
- [Task 1.5 SW101 の interface range GigabitEthernet0/0-1 の選定理由](pattern2/2026-07-17_q5_SW101のGi0-0-1選定理由.md) — 2026-07-17
- [Task 1.5 R21 の BGP→OSPF 再配布の設計意図（HQ-DC 接続との関係）](pattern2/2026-07-17_q5_R21のBGP再配布とHQ-DC接続の関係.md) — 2026-07-17
- [Task 1.5 SW102 で「OSPF will not operate...」が出た件](pattern2/2026-07-17_q5_SW102のOSPFエラーの原因.md) — 2026-07-17
- [Task 1.5 R23/R24 で router-id を明示している理由](pattern2/2026-07-17_q5_R23R24のrouter-id明示理由.md) — 2026-07-17
- [Task 1.6 R61 の passive-interface デフォルト設計理由（af-interface に range がない理由）](pattern2/2026-07-17_q6_R61のpassive-interfaceデフォルト設計理由.md) — 2026-07-17
- [Task 1.6 R62 に EIGRP 設定がない（ように見える）理由 — 初期コンフィグ投入済みの罠](pattern2/2026-07-17_q6_R62にEIGRP設定がない理由.md) — 2026-07-17
- [Task 1.6 SW610 に EIGRP 設定がない理由（L2アクセススイッチはルーテッドI/Fを持たない）](pattern2/2026-07-17_q6_SW610にEIGRP設定がない理由.md) — 2026-07-17
- [Task 1.7 MPLS アンダーレイ 各コマンドの意味と PE/P 役割](pattern2/2026-07-20_q7_MPLSアンダーレイ各コマンドの意味とPE-P役割.md) — 2026-07-20
- [Task 1.7 MPLS アンダーレイ 設計理由の深掘り（ACL/prefix-suppression/autoconfig/range/required）](pattern2/2026-07-20_q7_MPLSアンダーレイ設計理由の深掘り.md) — 2026-07-20
- [Task 1.8 R3 だけ vrf forwarding + ip address が必要な理由と「アクティブな BGP ピア 5 つ」の正体](pattern2/2026-07-26_q8_R3だけVRF設定が必要な理由とアクティブBGPピア5つの正体.md) — 2026-07-26
- [Task 1.8 `route-target export 10000:1` の設定先（R1 ではない）と値 10000:1 の根拠 / RD と RT の違い](pattern2/2026-07-26_q8_RT10000対1の設定先と値の根拠.md) — 2026-07-26
- [Task 1.9 「クラスフルな状態で広報されないようにすること」を満たすコマンドは？（`subnets` と `metric-type 1` の役割分担）](pattern2/2026-07-27_q9_クラスフル広報禁止を満たすコマンド.md) — 2026-07-27
- [Task 1.11 `crypto isakmp policy` の番号がなぜ「10」なのか（初期コンフィグ流用の理由）](pattern2/2026-07-27_q11_isakmppolicy10の番号の理由.md) — 2026-07-27
- [Task 1.11 `vrf forwarding WAN` が Task 1.11 で初めて出てくる理由（R61は既存/R70は新規という非対称性）](pattern2/2026-07-27_q11_vrfforwardingWANが必要な理由.md) — 2026-07-27
- [Task 1.12 `ip http server` とは何か（スタティックPATの変換先ポート80との関係）](pattern2/2026-07-29_q12_ip_http_serverの役割.md) — 2026-07-29
- [Task 1.12 static PAT コマンドの文法解説（`ip nat inside source static tcp ...`）と問題文との対応](pattern2/2026-07-29_q12_staticPATコマンドの文法解説.md) — 2026-07-29
- [Task 1.12 Telnet ACL / rotary 設定が問題文のどの要件を満たすか（listenとfilterの役割分担）](pattern2/2026-07-30_q12_TelnetACLとrotaryの役割分担.md) — 2026-07-30
- [Task 1.14 dynamic-author / line vty / 認証と認可を2種類設定する理由](pattern2/2026-07-30_q14_dynamic-authorとAAA認証認可2種類の理由.md) — 2026-07-30
- [Task 1.14 コンソール無認証とVTY(RADIUS)認証必須の設計理由](pattern2/2026-07-30_q14_コンソール無認証とVTY認証必須の設計理由.md) — 2026-07-30
- [Pattern 2全体 `CCIE!nfr4`(`CC!E!nfr4`)が使われる7タスクの整理と事前鍵設定の要否（q5/q6/q7/q8/q10/q11/q12/q14）](pattern2/2026-07-30_q5-14_CCIEnfr4パスワード使用タスクと事前鍵設定要否.md) — 2026-07-30
- [Task 1.2 SW602の show interfaces trunk が既に絞られている＝設定済みの証拠（allowed on trunkセクションの読み方）](pattern2/2026-07-31_q2_SW602で既に絞られたトランクは適用済みの証拠.md) — 2026-07-31
- [Task 1.2 SW601をwipeして初期コンフィグ確認したらtrunkが既に入っていた件（SW602の裏付け）](pattern2/2026-07-31_q2_SW601wipe後の初期コンフィグ確認とSW602の裏付け.md) — 2026-07-31
- [Task 1.3 spanning-tree guard root がどの要件を満たすか、なぜこの範囲に適用するか（SW101は全ポート／SW102はSW101向けリンクを除外）](pattern2/2026-07-31_q3_spanning-tree_guard_rootの適用範囲と役割.md) — 2026-07-31
- [Task 1.3 spanning-tree portfast edge default とは何か・対応する要件（個別設定なしの制約との関係）](pattern2/2026-07-31_q3_portfast_edge_defaultの意味と対応要件.md) — 2026-07-31
- [Task 1.3 「この設定が必要だ」と判断するための確認コマンド（Gi1/2-3はchannel-group無し／Gi2/0-1は設定済み・SW110はmode on）](pattern2/2026-08-01_q3_この設定が必要と判断するための確認コマンド.md) — 2026-08-01
- [Task 1.3 root guard をこのポート範囲にかける理由（Gi0/3の正体＝モジュール0で唯一残ったL2ポート／SW102はGi2/0-1・Po3を除外）](pattern2/2026-08-03_q3_root_guardのポート範囲とGi0-3の理由.md) — 2026-08-03
- [Task 1.4 `ip dhcp relay information option/trust` が満たす要件と、SW102 にも decrement が必要な理由（Standby側trackingは切替の抑止装置）](pattern2/2026-08-03_q4_DHCPリレー2行の役割とSW102にdecrementが必要な理由.md) — 2026-08-03
- [Task 1.4 HSRP 仮想 IP が問題文のデフォルト GW IP である理由（実IPは.2/.3で.1は意図的に空き）と `ip helper-address` の役割（giaddr でスコープ選択・両機に入れる理由）](pattern2/2026-08-03_q4_HSRP仮想IPがデフォルトGWである理由とhelper-addressの役割.md) — 2026-08-03
- [Task 1.5 OSPF 設定済み I/F の確認コマンド（`show ip int brief` と `show ip ospf int brief` の差分）と SW101 で追加が要るのは Vlan2000/2001 だけである理由](pattern2/2026-08-03_q5_OSPF設定済みIFの確認コマンドと追加設定の見分け方.md) — 2026-08-03
- [Task 1.5 SW201/SW202 が解答に出てこない理由（全L3 I/F が初期投入済みで差分ゼロ／L2トランクの先は cEdge＝SD-WAN）と HQ/DC 全機の初期OSPF状態一覧](pattern2/2026-08-04_q5_SW201とSW202が解答に出てこない理由.md) — 2026-08-04
- [Task 1.5 `sh ip ospf int b` で設定済みに見えるのに解答に Gi0/0-1 がある理由（brief に認証欄はない／`Nbrs F/C` 0-0 は対向未設定のサイン）と要件別コマンド割り当て](pattern2/2026-08-04_q5_ospf_int_briefで済に見えるのに解答に設定がある理由.md) — 2026-08-04
- [Task 1.6 `key chain CCIE_MD5` のお手本は実機にあるか（ラボ内に実例0件＝ここだけ暗記／`sec eigrp` では出ない／R62 コピペが効く範囲と SW601·SW602 は全量必要）](pattern2/2026-08-04_q6_key_chainのお手本が実機にあるか.md) — 2026-08-04
- [Task 1.6 SW610 に何も設定しない理由（ルーテッドI/F 0本・SVI は上位と同一サブネット／ただし Task 1.2 では設定対象）](pattern2/2026-08-04_q6_SW610に何も設定しない理由.md) — 2026-08-04
- [Task 1.6 ISAKMP の PSK と EIGRP の key chain は無関係（鍵を Key ID で引くか ピアIP で引くかの違い／ラボで `CC!E!nfr4` が出る6形式の対比）](pattern2/2026-08-04_q6_isakmpのPSKとeigrpのkey-chainの関係.md) — 2026-08-04
- [Task 1.7 事前設定で OSPF ネイバーが既にあるのに Gi0/0-2 と Lo0 に設定する理由（`FULL/DR` 自体が Type 2 LSA 生成＝要件違反の証拠／ネイバー2行しかないのは R5 が OSPF 皆無だから）](pattern2/2026-08-06_q7_ospfネイバー済でも設定する理由.md) — 2026-08-06
- [Task 1.7 本番で最短で解く動き方（差分を探さず機器別6ブロックを貼る／順番は PE→P／検証は R1・R2 の2台だけ／R4 Lo0 の /31 罠）](pattern2/2026-08-07_q7_本番最短手順コピペ前提の動き方.md) — 2026-08-07
- [Task 1.7 R3 の Lo0 が OSPF 未参加だと見抜くコマンド（`sh ip ospf int b` に行が無い／RID に .3 が出るのは罠＝RID は参加有無と無関係）と、設定済みの Gi8 に3行打つ理由（本命は P2P・R3 が DR ＝ Type 2 の生成元）](pattern2/2026-08-07_q7_R3のLo0未参加を見抜くコマンドとGi8に打ち直す理由.md) — 2026-08-07
- [Task 1.7 `access-list` が 11 番である理由（数字に必然性なし＝Pattern 3 は同じ役割で 10／制約は標準 ACL であることだけ／`option 1 for 11` の 1 は ACL 番号ではない／番号ズレはエラーが出ず無言で認証が効かなくなる）](pattern2/2026-08-07_q7_access-listが11番である理由.md) — 2026-08-07
- [Task 1.8 `address-family ipv4 vrf fabd2` の neighbor IP の正体（100.3.11.2=R11・100.3.21.2=R21 の直結 I/F＝CE 側／vpnv4 は Loopback で iBGP という使い分け／`.1`=PE・`.2`=CE の命名規則／CE 側は初期設定済みで R3 だけで上がる／maximum-prefix は P2 のみ・行頭が全角スペース）](pattern2/2026-08-07_q8_af_ipv4_vrf内のneighborIPの正体.md) — 2026-08-07
- [Task 1.8 本番で最短で解く動き方（貼るのは4ブロックのみ・R1R2 は作業ゼロ／**Task 1.7 が絶対前提**＝R3R5 の Lo0 が OSPF 未参加で iBGP が上がらない／**問題文 80,000 と解答資料 90 の矛盾**／R4 に af ipv4 vrf が無いのは IaaS 対象外だから／検証は 3台5コマンド）](pattern2/2026-08-07_q8_本番最短手順コピペ前提の動き方.md) — 2026-08-07
- [Task 1.8 R3 の iBGP neighbor に R1/R2 が入らない理由（P ルータは問題文で BGP 禁止＝BGP-free core／転送は外側ラベル1枚で完結するので VRF も BGP も不要／**「経路上にいる」≠「ピアである」**＝R1R2 は OSPF/LDP では不可欠／RR 禁止でフルメッシュ3台／3+2=5 がピア数要件の検算）](pattern2/2026-08-07_q8_R3のiBGPにR1R2が入らない理由.md) — 2026-08-07
- [Task 1.8 問題文の3要件がどのコマンドで満たされるか（`maximum-prefix 100000 80 restart 5` の1行が3要件を全部満たす・第2引数は%であり本数ではない・`warning-only` は付けない／`send-community extended` は解答HTMLに0件・ラボに9件で全て vpnv4 AF＝IOS 自動付加だが打つのが安全／`neighbor password` の根拠は問題文3章のみで 6セッション=12行・CE は範囲外）](pattern2/2026-08-07_q8_maximum-prefixとsend-communityとpasswordの根拠.md) — 2026-08-07
- [Task 1.9 `distribute-list` に隠れた事前設定はあるか（前提は3つで2つは同じブロック内／`router ospf 1` が唐突に見えるのは Task 1.5 がインターフェース直付け方式でプロセスを暗黙生成しているから／存在しない prefix-list 参照は**無言で全 permit**／`permit 0.0.0.0/0 le 32` の暗黙 deny／R12 だけ connected 再配布なのは BGP neighbor が 0 本だから／**101.22.0.0/30 は Pattern 2 では経路源が無い＝予防フィルタ**・注入は Pattern 3 の Task 2.1）と Task 1.9 時点の R11·R12 積み上げ全体像](pattern2/2026-08-07_q9_distribute-listの前提設定とTask1.9時点の全体像.md) — 2026-08-07
- [Task 1.10 `router bgp 10000 / address-family ipv4 vrf fabd2` に降りる理由（R61 という neighbor が**VRF の中にしか存在しない**／グローバルで打つと**別人格の neighbor が無言で新規作成**され Idle 放置＝一番危険／**PE 側は AF 配下・CE 側はグローバル**の非対称／`af vpnv4` は neighbor がグローバルにも居るので Task 1.8 の password はグローバル直下＝同じコマンドで置き場所が違う理由／`bfd interval` が I/F にあるのは BFD が別プロトコルだから・`fall-over bfd` はクライアント登録で片方だけでは動かない）](pattern2/2026-08-07_q10_PE側だけaddress-family_ipv4_vrf配下に打つ理由.md) — 2026-08-07
- [Task 1.11 「R5 で標準 ACL」がなぜ R5 なのか（**R61 だけ MPLS 側 PE-CE がグローバル RIB＝EIGRP と衝突**／R70 は Gi0/0.100 が vrf WAN で隔離・R62 は問題文で除外／**eBGP AD20 が EIGRP AD90 に勝つ**ので暗号化トンネルが未使用になる）と、なぜ interface 適用ではダメか（`ip access-group` はデータプレーンで NLRI は TCP179 ペイロード＝見えない／貼ると経路が残ったまま落ちて**ブラックホール**／`distribute-list` は ACL を「プレフィックスのマッチ条件」として使う・`permit any` 必須／問題文 `10.255.5.24/32` は `10.2.255.24/32` の誤記）](pattern2/2026-08-09_q11_R5にACLを置く理由とint適用ではダメな理由.md) — 2026-08-09
- [Task 1.11 「R61 だけ同じグローバル RIB」の意味を噛み砕く（**EIGRP は SP には無い＝トンネルの中だけ**／R61 は DC への道が MPLS と DMVPN の2本あり AD 20 vs 90 で BGP が勝つ／**VRF＝独立した別のルーティングテーブル＝別の箱**なので R70 は BGP が VRF WAN・EIGRP がグローバルで比較すら起きない／**`tunnel vrf WAN` は外側の封筒の配送先を決めるだけでトンネルの中身はグローバル**）](pattern2/2026-08-09_q11_なぜR61だけ衝突するのかVRFは別テーブルという話.md) — 2026-08-09
- [Task 1.11 「入口は R5 だけ？R6 は？」と「インターネット経路は SP_1/SP_2 を通るのか」（**CE は 1 台につき PE 1 台**＝R61 の扉は R5 のみ・R6 は R62/R70 の扉／入口は複数あるが**塞ぐ必要があるのは R5 の扉だけ**／R61↔R62 直結の裏道は R62 に BGP→EIGRP 再配布が無いので成立しない／**CML ノード「SP_1」は Global SP #1 と別物**＝hostname SP1・AS 19999 のインターネットで `ip route 0.0.0.0 Null0` + `default-information originate` を全員に配る／SP_2 は R22 の WAN 対向専用で Pattern 2 では出番なし／R61→R24 の二重の袋（外側=VRF WAN・中身=global）／**R61 の EIGRP に network 文が無い**ラボの穴）](pattern2/2026-08-09_q11_R6も入口では_と_インターネット経路はSP_1ノードを通る話.md) — 2026-08-09
- [Task 1.11 理解の答え合わせ＋**AD 比較の基礎原理**（**Branch3 の IGP は OSPF ではなく EIGRP AS 65006**＝R61 に `router ospf` は 0 行／R61 は BGP セッションを 2 本持つ（R5=AS10000 グローバル／SP1=AS19999 VRF WAN でデフォルトのみ）／**横取りするのは SP1 側ではなく R5 側**＝R61→SP1→R24 は使いたい正解の道／解答は AD を変えず**経路そのものを消す**／AD 比較 4 原則＝**プレフィックス＋マスク長が完全一致した時だけ**・**同じ VRF の中だけ**・AD はローカル値で広告されない・負けた経路は DB には残る／AD 一覧表と R61 の具体例）](pattern2/2026-08-09_q11_理解の答え合わせとAD比較の基礎原理.md) — 2026-08-09
- [Task 1.11 スポークの BGP neighbor を「ハブ側の Gi」の対向にする理由（**その Gi の先はハブではなく ISP＝SP_1**・R24 とは直結していない／`tunnel vrf WAN` により**外側ヘッダの宛先 200.99.24.2 を VRF WAN で引く**が VRF WAN は connected の /30 しか無い＝**`%TUN-5-RECURDOWN` で DMVPN 全滅**／供給源は SP_1 の `ip route 0.0.0.0 Null0` ＋ `default-information originate` のみ／**eBGP 直結は TTL 1** で SP_1 が `neighbor 200.99.61.2` 決め打ち＝Loopback ピア不可・そもそも VRF WAN に Loopback は 0 本／**この BGP は業務経路を運ばない＝アンダーレイ専用**でオーバーレイは EIGRP AS 65006／**R61 は初期設定済み・R70 は新規入力が必要**）](pattern2/2026-08-11_q11_スポークのBGPネイバーをISP向けGiにする理由.md) — 2026-08-11
- [Task 1.11 `ip nhrp map` で対応づけている IP は誰のものか（**2 つとも R24 のもの**＝`10.200.0.1`=Tunnel0・`200.99.24.2`=Gi1 で「トンネル内の顔」と「インターネット上の顔」を結ぶ行／`ip nhrp nhs 10.200.0.1` と map 第1引数は同じ物／**初期設計は NBMA＝両端の Lo0** で問題文がそれを禁じるので総取っ替え・旧 `10.2.255.24` は VRF WAN から届かない／**⚠️ 初期コンフィグの map は引数の順序が逆**（`ip nhrp map 10.2.255.24 10.200.0.1`）で解答は順序も直している／**`10.2.255.24` は外側の NBMA から中身の EIGRP 広報経路へ役割が引っ越す**／ハブに map が無いのは**スポークが自分から登録しに来るから**で `multicast dynamic` の 1 行だけ／R24 の初期 `tunnel source Ethernet0/3` は存在しない I/F）](pattern2/2026-08-11_q11_nhrp_mapのIPは誰のものか.md) — 2026-08-11
- [Task 1.11 `ip nhrp map 10.200.0.1 200.99.24.2` の 2 つの IP の意味と**本番でどこから確認するか**（**mGRE は `tunnel destination` が書けない**のでその埋め合わせが NHRP／**構造は ARP と同じで「論理→物理」の順**／`10.200.0.1` は **R61 自身の `ip nhrp nhs` 行にそのまま書いてある**＝`show run int Tunnel0`／`200.99.24.2` は R61 のどこにも無く **R24 で `show ip int brief`** を見る（問題文が Gi1 と名指し）／**⚠️ SP_1 は connected を広報せず `0.0.0.0/0` しか来ないのでルーティングテーブルからは絶対に分からない**・CDP も 2 ホップ先で不可／`200.99.<機器番号>.2/30` の規則は検算用／`show ip nhrp` と `show dmvpn` で答え合わせ・**`show dmvpn` は config と左右が逆順**／**topology2.png には IP の記載が無い**）](pattern2/2026-08-11_q11_nhrp_mapの2つのIPを本番でどこから確認するか.md) — 2026-08-11
- [Task 1.12 `rotary 3` を入れる理由とポート番号 3003 の導出（**rotary＝3003 番で LISTEN させる設定**で ACL は開いていない口を開けられない／**ポートは 3000+グループ番号**（Raw は 5000+n・binary は 7000+n）なので **3003−3000＝3 と逆算**して決める・数字自体に意味はない／名前の由来は**空いている line を順繰りに割り当てる**リバース Telnet 機能の流用／**「NATへ依存しないこと」が `ip nat ... 3003` での解法を封じている**からこそ rotary が正解／**rotary 忘れ＋ACL だけだと 23 は deny・3003 は refused で完全に入れなくなる**／`rotary`＝listen・`access-class`＝filter の役割分担／全 IP で待ち受けるので「すべての Gi 経由」も自動的に満たす／3パターン共通 `row-common`）](pattern2/2026-08-11_q12_rotaryを入れる理由とポート3003の導出.md) — 2026-08-11

## pattern3

（まだなし）

## pattern4

（まだなし）

## general

（まだなし）
