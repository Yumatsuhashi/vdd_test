# Pattern 2 Task 1.5 — `show ip ospf interface brief` で設定済みに見えるのに解答に Gi0/0-1 の設定がある理由（brief に認証は出ない）

## 質問

SW101では

```
SW101#sh ip ospf int b
Interface    PID   Area            IP Address/Mask    Cost  State Nbrs F/C
Lo0          1     0               10.1.255.101/32    1     LOOP  0/0
Gi0/2        1     0               10.2.241.2/30      1     DR    1/1
Gi0/1        1     0               10.1.12.2/30       1     DR    0/0
Gi0/0        1     0               10.1.10.2/30       1     DR    0/0

SW101#sh ip int b
Interface              IP-Address      OK? Method Status                Protocol
GigabitEthernet0/0     10.1.10.2       YES TFTP   up                    up
GigabitEthernet0/1     10.1.12.2       YES TFTP   up                    up
GigabitEthernet0/2     10.2.241.2      YES TFTP   up                    up
GigabitEthernet0/3     unassigned      YES unset  down                  down
GigabitEthernet1/0     unassigned      YES unset  down                  down
GigabitEthernet1/1     unassigned      YES unset  down                  down
GigabitEthernet1/2     unassigned      YES unset  up                    up
GigabitEthernet1/3     unassigned      YES unset  up                    up
GigabitEthernet2/0     unassigned      YES unset  up                    up
GigabitEthernet2/1     unassigned      YES unset  up                    up
GigabitEthernet2/2     unassigned      YES unset  down                  down
GigabitEthernet2/3     unassigned      YES unset  down                  down
Loopback0              10.1.255.101    YES TFTP   up                    up
Port-channel1          unassigned      YES unset  up                    up
Port-channel3          unassigned      YES unset  up                    up
Vlan2000               10.1.100.2      YES TFTP   up                    up
Vlan2001               10.1.101.2      YES TFTP   up                    up
```

この結果からint ran gi0/0-2にはすでにospfがあるから設定はいらないかと思っていたが回答を見るとあった　それはなぜ　どうやって見極めたらいいと思う

## 回答

### 結論: あの `interface range Gi0/0-1` は OSPF を有効化するためのブロックではない

```ios
interface range GigabitEthernet0/0-1
 ip ospf 1 area 0                              ← 既にある（冗長・無害）
 ip ospf authentication message-digest         ← ★本命
 ip ospf message-digest-key 1 md5 CC!E!nfr4    ← ★本命
```

**`show ip ospf interface brief` には認証の欄がない。** brief が答えるのは「OSPF が有効か / どの area か /
ネイバー数」までで、**認証・コスト・network type・hello timer といった属性は一切表示されない**。

ユーザーの判断「Gi0/0-2 は OSPF 済みだから不要」は、**OSPF 有効化という軸だけを見れば 100% 正しい**。
実際、追加すべき `ip ospf 1 area 0` は Vlan2000/2001 の 2 本だけで、差分の取り方は正しかった。
見落としたのは「認証」という別の軸。

### 実機出力に既に写っていた証拠 — `Nbrs F/C` 列

```
Gi0/2   1  0  10.2.241.2/30   1  DR  1/1   ← SW201 と確立済み
Gi0/1   1  0  10.1.12.2/30    1  DR  0/0   ← ★ネイバー ゼロ
Gi0/0   1  0  10.1.10.2/30    1  DR  0/0   ← ★ネイバー ゼロ
```

`Nbrs F/C` = **Full 状態のネイバー数 / 検出したネイバー総数**。

- Gi0/2（→SW201）は `1/1` = 正常に確立
- Gi0/0（→R11）・Gi0/1（→R12）は `0/0` = 相手が見えてすらいない

問題文の要件「データセンターおよび本社内のすべての OSPF ネイバーを正常に確立しなければならない」
に照らすと、この時点で**明確な要件違反**。「このリンクにはまだ作業が残っている」とコマンド出力だけで
断定できた。

原因: **R11 と R12 は初期コンフィグに OSPF が 1 行も入っていない**（EI_v2.yaml で確認済み。対して
SW201 は全 L3 I/F 投入済みなので Gi0/2 だけ上がっている）。R11/R12 側を設定し、要件どおり MD5 を
入れると、SW101 側にも同じ鍵が無い限りネイバーは上がらない。だから SW101 の Gi0/0-1 にも認証が必要。

→ **`Nbrs F/C` が 0/0 のインターフェースは「対向機器を見に行け」のサイン**。

### 見極め方: 要件を軸に分解してコマンドを割り当てる

「機器の現状」から入ると漏れる。**問題文の要件 1 行 = 確認コマンド 1 つ**に割り付けるのが正しい順序。

| 問題文の要件 | 確認コマンド | brief で見えるか |
|---|---|---|
| すべての I/F で OSPF 有効化 | `sh ip int b \| ex unassigned` と `sh ip ospf int b` の**差分** | ✅ 見える |
| すべての OSPF ネイバーを確立 | `sh ip ospf neighbor` / brief の **Nbrs F/C 列** | ✅ 見える |
| **R11/R12 は MD5 認証** | `sh ip ospf int Gi0/0` / `sh run int Gi0/0` | ❌ **見えない** |
| R21 で BGP を再配布 | `sh ip protocols` / `sh run \| sec router ospf` | ❌ 見えない |

認証の一括監査:

```ios
show ip ospf interface | include is up|Message digest|authentication
```

認証が入っていないインターフェースには `Message digest authentication enabled` の行が**そもそも出ない**。
設定後は Gi0/0・Gi0/1 だけに

```
  Message digest authentication enabled
    Youngest key id is 1
```

が現れ、Gi0/2 には出ない（要件範囲外なので入れない）のが正解の形。

迷ったときの最終手段は `show run interface <if>`（生の設定なので解釈の余地がない）。

### 一般則

1. **`brief` 系は「有無」しか答えない。「属性」は個別コマンドか `show run`**
   - `sh ip ospf int b` → 有効/area/ネイバー数
   - `sh ip ospf int <if>` → 認証・cost・network type・timer・priority
2. **要件は複数の軸を持つ**。「有効化」「隣接確立」「認証」「再配布」「router-id」は別々に検査する
3. **`Nbrs F/C` = 0/0 は対向未設定のサイン**。自分側だけ見ていても原因は分からない
4. **解答の `ip ospf 1 area 0` 再入力は無害な冗長**。解答資料は「そのインターフェースのあるべき完成形」を
   書くので既存分も含む。本番では差分だけ打てば十分（冪等で減点なし）

### 設定後の期待値

```
Interface  PID  Area  IP Address/Mask   Cost  State  Nbrs F/C
Lo0        1    0     10.1.255.101/32   1     LOOP   0/0
Gi0/0      1    0     10.1.10.2/30      1     DR/BDR 1/1   ← R11 と確立
Gi0/1      1    0     10.1.12.2/30      1     DR/BDR 1/1   ← R12 と確立
Gi0/2      1    0     10.2.241.2/30     1     DR     1/1
Vl2000     1    0     10.1.100.2/24     1     DR/BDR 1/1   ← 新規（SW102 と隣接）
Vl2001     1    0     10.1.101.2/24     1     DR/BDR 1/1   ← 新規
```

## 参照

- ユーザー実機出力（SW101 `show ip ospf interface brief` / `show ip interface brief`）
- `Questions/pattern2/pattern2_q5.md` — 要件（すべての I/F で有効化／すべてのネイバー確立／R11・R12 は MD5）
- `Answers/pattern2/pattern2_q5.md` — SW101 の `interface range Gi0/0-1` ブロック（認証2行が本命）
- `EI_v2.yaml` — R11/R12 に OSPF 設定が一切ないこと（Gi0/0-1 が 0/0 である原因）、SW201 は全 L3 I/F 投入済み
- 関連: `QA/pattern2/2026-08-03_q5_OSPF設定済みIFの確認コマンドと追加設定の見分け方.md`（差分2コマンドの基本形）、`QA/pattern2/2026-08-04_q5_SW201とSW202が解答に出てこない理由.md`、`QA/pattern2/2026-07-17_q5_SW101のGi0-0-1選定理由.md`
