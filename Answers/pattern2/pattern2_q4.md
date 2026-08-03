# Pattern 2 — 問題4 FHRP（HSRP v2 + IP SLA tracking + DHCP リレー）

## 解答 config（デバイス別）

### SW101（Active 側）

```
ip dhcp relay information option
ip dhcp relay information trust

ip sla 1
icmp-echo 10.2.255.211

ip sla schedule 1 start-time now life forever
track 1 ip sla 1 reachability

interface vlan 2000
ip helper-address 10.2.255.211
standby version 2
standby 210 ip 10.1.100.1
standby 210 timers 1 5
standby 210 authentication md5 key-string CC!E!nfr4
standby 210 priority 110
standby 210 preempt delay minimum 15
standby 210 track 1 decrement 20

interface vlan 2001
ip helper-address 10.2.255.211
standby version 2
standby 220 ip 10.1.101.1
standby 220 timers 1 5
standby 220 authentication md5 key-string CC!E!nfr4
standby 220 priority 110
standby 220 preempt delay minimum 15
standby 220 track 1 decrement 20
```

### SW102（Standby 側）

```
ip dhcp relay information option
ip dhcp relay information trust

ip sla 1
icmp-echo 10.2.255.211

ip sla schedule 1 start-time now life forever
track 1 ip sla 1 reachability

interface vlan 2000
ip helper-address 10.2.255.211
standby version 2
standby 210 ip 10.1.100.1
standby 210 authentication md5 key-string CC!E!nfr4
standby 210 preempt delay minimum 15
standby 210 track 1 decrement 20

interface vlan 2001
ip helper-address 10.2.255.211
standby version 2
standby 220 ip 10.1.101.1
standby 220 authentication md5 key-string CC!E!nfr4
standby 220 preempt delay minimum 15
standby 220 track 1 decrement 20
```

**SW102 に無いもの**: `priority`（既定100を使う要件のため）、`timers`（Active が Hello で広告した hello/hold を学習するため。要件も「**Active** ゲートウェイは…」と限定している）。

## 要件と config の対応

| 問題文の要件 | 対応コマンド |
|---|---|
| VLAN2000 の vMAC `0000.0c9f.f0d2` | `standby version 2` ＋ `standby 210 ip 10.1.100.1`（HSRPv2 の vMAC は `0000.0C9F.F`＋グループ番号16進。`0x0D2` = **210**） |
| VLAN2001 の vMAC `0000.0c9f.f0dc` | `standby 220 ip 10.1.101.1`（`0x0DC` = **220**） |
| デフォルトの3倍の頻度で定期パケット | `standby 210 timers 1 5` の hello=1（既定3秒 → 1秒） |
| デフォルトの2倍の速さで障害検出 | 同 holdtime=5（既定10秒 → 5秒） |
| 最も安全な方式で認証＋単純なキーストリング | `authentication md5 key-string CC!E!nfr4`（text ではなく md5、key-chain ではなく key-string） |
| SW101 を Active、既定より10高く | SW101 のみ `standby 210 priority 110` |
| SW102 を Standby、既定プライオリティ | SW102 は priority コマンドなし（＝100） |
| 自分の方が高くなったら Active へ移行 | 両機 `preempt`（下記コマンドに内包） |
| Active 移行まで最低15秒の遅延 | `standby 210 preempt delay minimum 15` |
| ICMP Echo で DHCP サーバ到達性を監視 | `ip sla 1` / `icmp-echo 10.2.255.211` / `ip sla schedule 1 start-time now life forever` / `track 1 ip sla 1 reachability` |
| 利用不可時にフェイルオーバー、20減少 | **両機**の `standby 210 track 1 decrement 20` |
| DHCP要求が両方のFHGWで受信されるように | **両機の両SVIに `ip helper-address` ＋ `ip dhcp relay information option` ＋ `ip dhcp relay information trust`** |

### 仮想MACからグループ番号を逆算する

HSRPv2 IPv4 の仮想MAC = `0000.0C9F.Fxxx`（xxx = グループ番号の16進3桁）。

- `0000.0c9f.f0d2` → `0x0D2` = 210 → `standby 210`
- `0000.0c9f.f0dc` → `0x0DC` = 220 → `standby 220`

VLAN 番号（2000/2001）をそのままグループ番号にすると不正解。`standby version 2` が無いと vMAC が HSRPv1 形式（`0000.0C07.ACxx`）になるため必須。

### 仮想 IP と実 IP のアドレス割り当て

| | Vlan2000 | Vlan2001 |
|---|---|---|
| SW101 実 IP（初期コンフィグ） | 10.1.100.2 | 10.1.101.2 |
| SW102 実 IP（初期コンフィグ） | 10.1.100.3 | 10.1.101.3 |
| 仮想 IP（`standby ip`） | 10.1.100.1（grp 210） | 10.1.101.1（grp 220） |

`.1` はどちらの機器にも実 IP として振られていない（HSRP 仮想 IP はサブネット内の未使用アドレスを使う）。
問題文の表の「デフォルトゲートウェイ」列がそのまま仮想 IP になる。DHCP が配る GW も 10.1.100.1 のため、
仮想 IP は表と一致させる必要がある。

DHCP サーバ 10.2.255.211 は **SW211 の Loopback0**（DC 側）。VLAN2000/2001 とは別サブネットのため
リレーが必須で、giaddr には受信 SVI の実 IP（.2 / .3）が入る。同じアドレスが `icmp-echo` の監視先でもある。

### DHCP リレー2行の役割

- `ip dhcp relay information option`（グローバル）: 転送時に **Option 82** を挿入。SW101/SW102 の両方がリレーするため、サーバ側が「どのリレー経由か」を識別できるようにする
- `ip dhcp relay information trust`（グローバル）: IOS は **Option 82 付き かつ giaddr=0** の DHCP パケットを既定で**破棄**する（RFC 3046 の untrusted 判定）。`option` を有効にするとこの検査も働くため、trust で破棄を解除して「両方のスイッチで受信される」状態を担保する
  - 実機の正確な形は グローバル `ip dhcp relay information trust-all` / インターフェース `ip dhcp relay information trusted`。解答の `trust` はグローバル位置なので `trust-all` の省略形

### SW102 にも decrement が必要な理由

track が見ているのは相手スイッチの生死ではなく「DHCP サーバ 10.2.255.211 への到達性」で、各スイッチが独立に失いうる。

| | 正常 | SLA down |
|---|---|---|
| SW101 | 110 | 90 |
| SW102 | 100 | 80 |

- 片側障害: `110-20=90` < `100` → 順位が入れ替わる（フェイルオーバーする）
- 両側障害（サーバ自体のダウン等）: `90` > `80` → 順位が保たれる（**フェイルオーバーしない**）

SW102 に decrement が無いと、SW102 自身もサーバに到達できない状況でも SW102（100）が Active を奪ってしまう。**Standby 側の tracking は切替の発火装置ではなく切替の抑止装置**。decrement=20 という値は両機に同じ値が入って初めてこの対称性が成立する。

## 検証コマンド

```
show standby brief                              ← Active/Standby、優先度、preempt
show standby vlan 2000 | include priority|Track|authentication
show track brief                                ← track 1 の Up/Down
show ip sla summary / show ip sla statistics     ← ICMP Echo の結果
show ip dhcp relay information trusted-sources   ← trust の適用確認
debug ip dhcp server packet                     ← Option 82 挿入と giaddr の確認
```

原本の Troubleshoot メモ: `show vlan`（VLAN が消えていないか）、duplicate address 警告（HSRP グループ番号の重複）。

## 注意

認証キーは問題文が `CCIE!nfr4`、解答 config が `CC!E!nfr4` と食い違っている（`QA/pattern2/2026-07-30_q5-14_CCIEnfr4パスワード使用タスクと事前鍵設定要否.md` 参照）。問題文側を優先する。

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html` 3277〜3345行目（Pattern 2 セクション Task 1.4 SW101/SW102）、601行目〜（Pattern 1/2/3 比較表）、5295行目〜（検証コマンド）
- `Questions/pattern2/pattern2_q4.md`（要件12項目）
- `EI_v2.yaml`（SW101 Vlan2000=10.1.100.2 / Vlan2001=10.1.101.2、SW102 も同 VLAN に SVI あり）

最終更新: 2026-08-03
