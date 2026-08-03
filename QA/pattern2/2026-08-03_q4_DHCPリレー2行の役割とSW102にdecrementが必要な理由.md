# Task 1.4 `ip dhcp relay information option/trust` が満たす要件と、SW102 にも decrement が必要な理由

## 質問

CCIE_train_hub/Questions/pattern2/pattern2_q4.md
この問題について質問がある

```
ip dhcp relay information option
ip dhcp relay information trust
```

はなんのために入れているのか？問題文のどの部分を満たすために入れているのか？

SW102においてdecrementを入れているがこれはなぜ？SW101がdown→upしてpreemptでsw102からactiveを奪う　sw101がup→downしたらsw102にpreemptを入れているからactiveがsw101にうつる　sw102にdecrementを入れいている必要なくない？

## 回答

### 質問1: DHCP リレー2行が満たす要件

対応するのは問題文の**最後の1行**。

> DHCP要求メッセージが、両方のファーストホップゲートウェイスイッチで受信されるようにすること

この要件は3つの設定の組み合わせで満たしている。

**(a) 両スイッチの両 SVI に `ip helper-address 10.2.255.211`**

SW101 だけでなく SW102 の Vlan2000/2001 にも入っている。クライアントの DHCPDISCOVER は L2 ブロードキャストなので HSRP の Active/Standby に関係なく両スイッチが受信するが、**リレー（ユニキャストでサーバへ転送）するのは helper-address を持つスイッチだけ**。両方に入れることで Standby 側の SW102 も要求を処理する状態になる。

**(b) `ip dhcp relay information option`（グローバル）**

リレーエージェントが転送時に **Option 82（Relay Agent Information）** を挿入する。同一クライアントの要求が SW101 経由・SW102 経由の2つ届くため、サーバ側が「どのリレー / どのインターフェース経由か」を識別できる必要がある。二重リレー構成を成立させるための識別子。

**(c) `ip dhcp relay information trust`（同じくグローバル）**

これが「**受信されるように**」に直接効く部分。

IOS のリレーエージェントは、**Option 82 が既に付いていて giaddr = 0 の DHCP パケットを受信すると既定で破棄する**（RFC 3046 の untrusted 判定）。`option` を有効にするとこの検査も働くため、trust を入れないと「両方のスイッチで受信させる」要件に対して取りこぼしが発生しうる。trust はこの破棄動作を解除してパケットを信頼して受け入れさせる。

実機の正確なコマンド名は、グローバルなら `ip dhcp relay information trust-all`、インターフェース単位なら `ip dhcp relay information trusted`。解答の `ip dhcp relay information trust` はグローバル位置にあるので `trust-all` の省略形として通る。

なお原本 HTML にはこの2行に関する解説文が一切なく（Pattern 1/2/3 で完全に同一の `row-common`）、上記は要件文と IOS の既定動作からの読み解き。

### 問題文と config の完全な対応表

| 問題文の要件 | 対応コマンド |
|---|---|
| VLAN2000 の vMAC `0000.0c9f.f0d2` | `standby version 2` ＋ `standby 210 ip 10.1.100.1`（HSRPv2 の vMAC は `0000.0C9F.F`＋グループ番号16進。`0x0D2` = **210**） |
| VLAN2001 の vMAC `0000.0c9f.f0dc` | `standby 220 ip 10.1.101.1`（`0x0DC` = **220**） |
| デフォルトの3倍の頻度で定期パケット | `standby 210 timers 1 5` の hello=1（既定3秒 → 1秒） |
| デフォルトの2倍の速さで障害検出 | 同 holdtime=5（既定10秒 → 5秒） |
| 最も安全な方式で認証＋単純なキーストリング | `authentication md5 key-string CC!E!nfr4`（text ではなく md5、key-chain ではなく key-string） |
| SW101 を Active、既定より10高く | SW101 のみ `standby 210 priority 110` |
| SW102 を Standby、既定プライオリティ | SW102 は priority コマンドなし（＝100） |
| 自分の方が高くなったら Active へ移行 | 両機 `preempt`（下記に内包） |
| Active 移行まで最低15秒の遅延 | `standby 210 preempt delay minimum 15` |
| ICMP Echo で DHCP サーバ到達性を監視 | `ip sla 1` / `icmp-echo 10.2.255.211` / `ip sla schedule 1 start-time now life forever` / `track 1 ip sla 1 reachability` |
| 利用不可時にフェイルオーバー、20減少 | **両機**の `standby 210 track 1 decrement 20` |
| DHCP要求が両方のFHGWで受信されるように | 上記 (a)(b)(c) |

SW102 に `timers` が無いのは、HSRP の hello/hold は Active が Hello パケットで広告し、**明示設定していないルータは Active から学習する**ため。要件も「**Active** ゲートウェイは…」と限定している。

### 質問2: SW102 の decrement は不要ではないか

**「SW101 の down→up / up→down に対応するため」という用途に限れば指摘は完全に正しい。** その動きは preempt だけで成立する。

ただし track が監視しているのは **SW101/SW102 の生死ではなく「DHCP サーバ 10.2.255.211 への到達性」**。これは各スイッチが**独立に**失いうる状態で、しかも SLA は各スイッチが自分で打っている。ここが分かれ目。

プライオリティの遷移:

| | 正常 | SLA down |
|---|---|---|
| SW101 | 110 | 90 |
| SW102 | 100 | **80** |

#### シナリオ①: SW101 だけが到達性を失う（要件が想定する主ケース）

SW101=90 < SW102=100 → SW102 が preempt して Active。
→ **たしかに SW102 の decrement は関与しない。指摘どおり。**

#### シナリオ②: SW102 が先に到達性を失い、その後 SW101 も失う

- **decrement あり**: SW101=90、SW102=80 → SW101 が Active のまま
- **decrement なし**: SW101=90、SW102=**100** → SW102 が Active を奪う。**しかし SW102 もサーバに到達できない**

decrement が無いと、HSRP は「引き継ぎ先が健全かどうか」を一切考慮せずに Active を渡す。SLA が落ちているということはそのスイッチの上流経路（Gi0/0→R11 / Gi0/1→R12 / Gi0/2→SW202）や OSPF が壊れている可能性が高く、**壊れている方をゲートウェイにする**ことになる。DHCP どころか一般トラフィックまでブラックホールになりかねない。

#### シナリオ③: DHCP サーバ自体のダウン／DC 全体の障害（共通障害）

- **decrement あり**: SW101=90、SW102=80 → 順位が保たれ、**Active は動かない**
- **decrement なし**: SW101=90、SW102=100 → SW102 へフェイルオーバー。サーバは両方から見えないので**何も改善せず、ゲートウェイ切替の通信断だけが発生する**

#### decrement = 20 という数字の設計

この値は「両機に同じ decrement が入っていること」を前提に選ばれている。

- 片側障害: `110 - 20 = 90` < `100` → **順位が入れ替わる**（フェイルオーバーする）
- 両側障害: `90` > `80` → **順位が保たれる**（フェイルオーバーしない）

SW102 に入れないとこの対称性が崩れ、「片側なら切り替わり、両側なら動かない」という望ましい挙動が成立しない。

#### まとめ

**SW102 の decrement は「フェイルオーバーさせるため」ではなく、「フェイルオーバーすべきでない場面でフェイルオーバーさせないため」に効く。Standby 側の tracking は切替の発火装置ではなく切替の抑止装置。**

加えて採点面でも、問題文は「**ファーストホップゲートウェイは**、ICMP Echo を使用して…」「…プライオリティを自動的に 20 減少させること」と両機を主語にしているため、片側だけの実装は要件を満たさない。

### 検証コマンド

```
show standby brief                              ← Active/Standby、優先度、preempt
show standby vlan 2000 | include priority|Track|authentication
show track brief                                ← track 1 の Up/Down
show ip sla summary / show ip sla statistics     ← ICMP Echo の結果
show ip dhcp relay information trusted-sources   ← trust の適用確認
debug ip dhcp server packet                     ← Option 82 挿入と giaddr の確認
```

## 参照

- `Questions/pattern2/pattern2_q4.md`（要件12項目。最終行が DHCP リレーに対応）
- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` 3277〜3345行目（Pattern 2 Task 1.4 SW101/SW102）、601〜665行目（Pattern 1/2/3 比較表。relay 2行は全パターン共通）、5295行目〜（検証コマンド）
- `Answers/pattern2/pattern2_q4.md`（本回答で新規作成したキャッシュ）
- `EI_v2.yaml`（SW101 Vlan2000=10.1.100.2 / Vlan2001=10.1.101.2）
- `QA/pattern2/2026-07-30_q5-14_CCIEnfr4パスワード使用タスクと事前鍵設定要否.md`（キー文字列の食い違い `CCIE!nfr4` vs `CC!E!nfr4`）
