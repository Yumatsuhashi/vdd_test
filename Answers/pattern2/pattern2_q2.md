# Pattern 2 — 問題2 VLAN / Access / Trunk

## 解答 config（デバイス別）

Pattern 2 の Task 1.2 解答に明示的に登場するのは SW110 / SW601 / SW602 / SW610 のみ。SW101 / SW102 は登場しない（理由は下記「初期コンフィグとの関係」参照）。

### SW110

```
interface GigabitEthernet0/0
switchport
switchport mode access
switchport access vlan 2000

interface GigabitEthernet0/1
switchport
switchport mode access
switchport access vlan 2001
```

### SW601

```
interface GigabitEthernet2/0
switchport
switchport trunk encapsulation dot1q
switchport mode trunk
switchport trunk allowed vlan 1,2000,2001
```

### SW602

```
interface GigabitEthernet2/0
switchport
switchport trunk encapsulation dot1q
switchport mode trunk
switchport trunk allowed vlan 1,2000,2001
```

### SW610

```
interface GigabitEthernet0/0
switchport mode access
switchport access vlan 2000

interface GigabitEthernet0/1
switchport
switchport mode access
switchport access vlan 2001

interface range GigabitEthernet2/0-1
switchport
switchport trunk encapsulation dot1q
switchport mode trunk
switchport trunk allowed vlan add 2001
```

### SW101 / SW102（Task 1.2には未登場。Task 1.3のEtherChannel設定に統合）

Task 1.3（EtherChannel/STP）のSW101解答に、Po1/Po3のVLANタグ付け要件も含まれている:

```
no interface port-channel 1
no interface port-channel 3

interface range GigabitEthernet1/2-3
switchport
switchport trunk encapsulation dot1q
switchport mode trunk
switchport trunk allowed vlan 1,2000,2001
channel-group 1 mode active
no shutdown

interface range GigabitEthernet2/0-1
switchport
switchport trunk encapsulation dot1q
switchport mode trunk
switchport trunk allowed vlan 1,2000,2001
channel-group 3 mode active
no shutdown
```

SW102も同様（`channel-group 2 mode active` / `channel-group 3 mode active`、`switchport trunk allowed vlan 1,2000,2001`）。

## 初期コンフィグとの関係（重要）

`EI_v2.yaml` の初期コンフィグで、以下がすでに設定済み:

| デバイス | 初期状態で既に完了している内容 |
|---|---|
| SW101 | `vlan 2000-2001` 作成済み。Po1/Po3ともトランクモード（許可VLAN制限なし＝デフォルト全VLAN許可）。**Po3**（Gi2/0-1）は`channel-group 3 mode active`で既にメンバー割当済み＝要件を完全に満たす。**Po1**（Gi1/2-3）はchannel-group未設定＝メンバーなし。Task 1.3で追加が必要 |
| SW102 | 同様に`vlan 2000-2001`済み。**Po2**（Gi1/2-3, `channel-group 2 mode passive`）と**Po3**（Gi2/0-1, `channel-group 3 mode active`）ともにメンバー割当済み。ただしPo2はSW110側も`mode passive`のためpassive-passive同士でLACPバンドル不成立（Task 1.3で`mode active`に修正） |
| SW110 | `vlan 2000-2001`済み。**Po1**（Gi1/0-1, `channel-group 1 mode on`）と**Po2**（Gi1/2-3, `channel-group 2 mode passive`）ともにメンバー割当済み、トランクで許可VLAN制限なし＝Task1.2の表の「Po1/Po2 タグあり」要件はゼロ追加設定で満たされる。Gi0/0・Gi0/1は初期コンフィグに登場せず、これらのみ新規設定が必要 |

Ciscoのトランクポートは`switchport trunk allowed vlan`を明示しない限りデフォルトで全VLAN（1-4094）をタグ付きで許可するため、VLANが既に作成済み＋トランクが既に組まれていれば、追加コマンドなしでタグ付き転送要件を満たす。

### SW601/SW602は初期状態では未制限（要注意）

SW602の初期コンフィグ（`EI_v2.yaml`）は次の通りで、`switchport trunk allowed vlan`による制限が**一切ない**（SW101/SW110と違い、こちらは「制限なし＝全VLAN許可」止まりで、明示的なVLAN絞り込みは初期コンフィグに含まれない）:

```
interface GigabitEthernet2/0
 switchport trunk encapsulation dot1q
 switchport mode trunk
```

`show interfaces trunk`の「Vlans allowed on trunk」セクションは、制限コマンドが無ければ常に`1-4094`と表示される（実在VLANだけに絞られるのは「allowed and active in management domain」以降のセクション）。もしこのセクションで既に`1,2000-2001`のように絞られて表示される場合、それは初期状態ではなく**`switchport trunk allowed vlan 1,2000,2001`が既に投入済み**であることを意味する。SW602はSW101/SW110と違い「初期コンフィグだけで要件を満たす」パターンではないため、混同注意。

### ⚠️ 上表の「ゼロ追加設定で満たされる」は初期コンフィグが生きている場合のみ

wipe / `default interface range` 等で初期コンフィグが飛んでいると前提が崩れる。
判定法: `show vlan brief` で **SW110 の Gi1/0〜Gi1/3 が `1 default` の行に出ていたら初期コンフィグは失われている**
（本来はトランク＋channel-group なので `show vlan brief` には出てこない）。その場合は Po1/Po2 とメンバーを自分で作り直す。

## 検証コマンド

**大前提: `show vlan brief` ではタグあり（トランク）要件を検証できない。** Ports 列に載るのはアクセスポートのみで、
トランクポートと Po メンバー物理ポートは表示されない。要件表16行のうち12行が「タグあり」なので、
`show vlan brief` だけで判定できるのは実質「VLAN 2000/2001 の存在」と「タグなし4行」だけ。
ただし「VLAN 1 の行から消えている＝アクセスポートではない＝トランクらしい」という間接判定には使える。

| 目的 | コマンド | 合格条件 |
|---|---|---|
| VLAN 存在 + タグなし要件 | `show vlan brief` | 2000/2001 が active、SW110 Gi0/0→2000・Gi0/1→2001、SW610 Gi0/0→2000・Gi0/1→2001 |
| タグなし要件（高速） | `show interfaces status` | Vlan 列が数字。`inactive`=VLAN未作成、`1`=手つかず、`trunk`=トランク |
| **タグあり要件（本命）** | `show interfaces trunk` | 4段目 **Vlans in spanning tree forwarding state and not pruned** に 2000 と 2001 が両方出る |
| ポート単位の断定 | `show interfaces <if> switchport` | `Operational Mode` / `Access Mode VLAN` / `Trunking VLANs Enabled` |
| VLAN 単位で一望 | `show spanning-tree vlan 2000` / `2001` | アクセス・トランク両方が並び Sts が FWD。答え合わせに最強 |
| EtherChannel（HQ のみ） | `show etherchannel summary` | Po が `SU`、メンバーが `(P)` |
| 最終確認 | `show running-config interface <if>` | — |

`show interfaces trunk` の4セクションの読み分け:

1. Port/Mode/Encapsulation/Status — `Encapsulation: 802.1q` かつ `Status: trunking`
2. **Vlans allowed on trunk** — 設定上の許可。`switchport trunk allowed vlan` 未設定なら常に `1-4094`
3. **Vlans allowed and active in management domain** — VLAN が実在するか（未作成ならここから消える）
4. **Vlans in spanning tree forwarding state and not pruned** — 実際に転送中か（STP Blocking ならここから消える）

### 一発で判定したい場合

**設定面（全機器共通）** — タグあり・タグなし・リンクダウンポートを同時に満たす唯一のコマンド:

```
show interfaces switchport | include Name:|Administrative Mode|Operational Mode|Access Mode VLAN|Trunking VLANs Enabled
```

**機能面（Branch #3 のみ）** — SW601 で:

```
ping 10.6.100.3     ← VLAN2000
ping 10.6.101.3     ← VLAN2001（SW610 の 2001 欠落を一撃で炙り出す）
```

SW601 Gi0/0 ↔ SW602 Gi0/0 は `no switchport` + 10.6.109.1/30 の **L3 ルーテッドリンク**なので、
VLAN 2000/2001 の L2 経路は SW601 Gi2/0 → SW610 Gi2/0 → SW610 Gi2/1 → SW602 Gi2/0 の**1本道**。
この2発でトランク4ポート × 2VLAN ＝ 要件表8行が証明できる。

同一セグメントの点呼は `ping 224.0.0.1 source Vlan2000 repeat 2`（IOS 機器が全員返事する。`ip multicast-routing` 不要）。
VLAN2000 は SW602(.3) と SW610(.10)、VLAN2001 は SW602(.3) のみ返るのが正解。

**HQ は素の ping では検証できない**: SW101 Gi2/0-1 ↔ SW102 Gi2/0-1（Po3）で直結しているため
`ping 10.1.100.3` は Po3 を通り Po1/Po2/SW110 を検証しない。SW110 は SVI 無しで ping 先にもできない。
対処は2つ:

- **手A（推奨）**: SW110 に検証用 SVI（`interface Vlan2000` 10.1.100.10 / `interface Vlan2001` 10.1.101.10）を
  一時作成し、`ping 224.0.0.1 source Vlan2000` で SW101(.2)・SW102(.3) の**両方から返るか**を見る＝Po1/Po2 を一撃で証明。
  **確認後は `no interface Vlan2000` / `no interface Vlan2001` で必ず削除**（SW110 は純 L2 が題意）
- **手B（無変更）**: 3台で `show spanning-tree vlan 2000 | include Root ID|Address` の Root Bridge ID が一致するか。
  一致＝その VLAN の L2 ドメインが3台に跨っている＝BPDU が流れている証拠

### 配線と SVI（`EI_v2.yaml` links / ノード実測）

```
HQ:        SW110 Gi1/0-1 ── SW101 Gi1/2-3   (SW110 Po1 ⇔ SW101 Po1)
           SW110 Gi1/2-3 ── SW102 Gi1/2-3   (SW110 Po2 ⇔ SW102 Po2)
           SW101 Gi2/0-1 ── SW102 Gi2/0-1   (Po3・直結)
Branch#3:  SW601 Gi0/0 ── SW602 Gi0/0       (L3 ルーテッド 10.6.109.0/30・VLANは通らない)
           SW601 Gi2/0 ── SW610 Gi2/0
           SW602 Gi2/0 ── SW610 Gi2/1
```

| 機器 | Vlan2000 | Vlan2001 |
|---|---|---|
| SW101 | 10.1.100.2 | 10.1.101.2 |
| SW102 | 10.1.100.3 | 10.1.101.3 |
| SW601 | 10.6.100.2（`standby version 2` / `standby 100`） | 10.6.101.2（`standby 101`） |
| SW602 | 10.6.100.3（`standby 100`） | 10.6.101.3（`standby 0`） |
| SW610 | 10.6.100.10 | SVI なし |

**⚠️ SW110 Gi0/0・Gi0/1 と SW610 Gi0/0・Gi0/1 は links に定義が無く未接続**。
よってタグなし4行は STP にも ping にも載らず、`show vlan brief` / `show int switchport` で設定を読むしか検証手段がない。

**⚠️ HSRP は初期状態で壊れている**（Vlan2000 は version 不一致、Vlan2001 は group 101 vs 0 の不一致）。
`show standby` は Task 1.2 の判定に使わないこと。実IP同士の ping には影響しない。

チェック順の勘所:

- **SW610 の Gi2/0-1 が最も落としやすい**。初期値が `switchport trunk allowed vlan 1,2000` で 2001 が抜けており、
  `show vlan brief` からは絶対に見えない。必ず `show interfaces trunk` で 2001 を確認する
- Task 1.3 着手前は Po1(SW101) がメンバーなし、Po2(SW102↔SW110) が passive-passive で非バンドルのはず

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`（Task 1.2 — VLAN/Access/Trunk セクション、Pattern 2、および Task 1.3 — EtherChannel/STP セクション、SW101/SW102）
- `EI_v2.yaml`（SW101, SW102, SW110 各ノードの初期コンフィグ）

最終更新: 2026-07-31
