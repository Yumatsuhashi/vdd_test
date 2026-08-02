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

## pattern3

（まだなし）

## pattern4

（まだなし）

## general

（まだなし）
