# Task 1.2 `show vlan brief` の出力だけで題意を満たしたと判定できるか＋検証コマンド一式

## 質問

（SW610 / SW602 / SW601 / SW101 / SW110 の `show vlan brief` 出力を貼付）

task2 をおえて sh の出力結果です。
題意を満たすように設定されているかこれからわかる？
また、題意を満たしてるか確認するコマンドを教えて

## 回答

### 結論（先に3行）

1. **`show vlan brief` だけでは題意の 1/3 しか判定できない。** 要件表 16 行のうち「802.1Q タグあり（トランク）」が 12 行を占めるが、**トランクポートは `show vlan brief` に一切表示されない**仕様なので、この出力では原理的に検証不能。
2. 判定できる「タグなし（アクセス）」4 行のうち、**SW610 は OK / SW110 は NG**。
3. 本命の検証コマンドは **`show interfaces trunk`**。加えて SW110 は要再設定、SW102 は出力が未提出。

---

### なぜ `show vlan brief` では足りないのか

`show vlan brief` の Ports 列に載るのは **「そのVLANに所属するアクセスポート」だけ**。
トランクポートは（複数VLANを運ぶので特定の1行に属せず）**どのVLANの行にも出てこない**。
EtherChannel のメンバー物理ポートも、束ねられると個別には出てこない。

つまりこの出力から読めるのは次の2つだけ：

- **VLAN 2000 / 2001 が VLAN データベースに存在し active か** → 5台とも ✓
- **どのポートがアクセスポートとしてどのVLANに入っているか** → 下表

逆に「VLAN 1 の行から消えている＝アクセスポートではない」ことは分かるので、
**「トランクになっているらしい」という間接的な状況証拠**までは取れる（許可VLANまでは分からない）。

---

### 出力から読み取れる判定表

| 機器 | 要件 | 出力から言えること | 判定 |
|---|---|---|---|
| **SW610** | Gi0/0 タグなし 2000 | `2000 VLAN2000 active Gi0/0` | **✓ OK** |
| **SW610** | Gi0/1 タグなし 2001 | `2001 VLAN2001 active Gi0/1` | **✓ OK** |
| **SW610** | Gi2/0〜1 タグあり 2000/2001 | VLAN1 行に Gi2/0・Gi2/1 が無い＝トランク化済み。ただし許可VLANは不明 | **△ 要 `show int trunk`** |
| **SW601** | Gi2/0 タグあり 2000/2001 | VLAN1 行に Gi2/0 が無い（Gi2/1〜3 はある）＝トランク化済み。許可VLAN不明 | **△ 要 `show int trunk`** |
| **SW602** | Gi2/0 タグあり 2000/2001 | 同上 | **△ 要 `show int trunk`** |
| **SW101** | Po1(Gi1/2-3)・Po3(Gi2/0-1) タグあり | VLAN1 行に Gi1/2・Gi1/3・Gi2/0・Gi2/1 が無い＝トランク／Po メンバー。許可VLAN不明 | **△ 要 `show int trunk`** |
| **SW102** | Po2・Po3 タグあり | **出力が提出されていない** | **? 未確認** |
| **SW110** | Gi0/0 タグなし 2000 | **`1 default` の行に Gi0/0 が居る** | **✗ NG** |
| **SW110** | Gi0/1 タグなし 2001 | **`1 default` の行に Gi0/1 が居る** | **✗ NG** |
| **SW110** | Po1(Gi1/0-1)・Po2(Gi1/2-3) タグあり | **Gi1/0〜Gi1/3 が全部 `1 default` に居る**＝トランクでもPoメンバーでもない | **✗ NG の疑い濃厚** |

---

### ⚠️ SW110 が最大の問題

`EI_v2.yaml` の SW110 初期コンフィグは本来こうなっている：

```
vlan 2000-2001
!
interface Port-channel1
 switchport trunk encapsulation dot1q
 switchport mode trunk
!
interface Port-channel2
 switchport trunk encapsulation dot1q
 switchport mode trunk
!
interface GigabitEthernet1/0   ← Gi1/0-1 が Po1
 switchport trunk encapsulation dot1q
 switchport mode trunk
 channel-group 1 mode on
...
interface GigabitEthernet1/2   ← Gi1/2-3 が Po2
 switchport trunk encapsulation dot1q
 switchport mode trunk
 channel-group 2 mode passive
```

**この状態なら Gi1/0〜1/3 は `show vlan brief` に出てこないはず。**
それが 4 本とも `1 default` に並んでいるということは、**SW110 の Gi1/0〜1/3 のトランク／channel-group 設定が消えている**（wipe した／`default interface range` した／初期コンフィグが流れていない）。
VLAN 2000/2001 だけが存在しているので、「wipe 後に VLAN だけ手で作った」状態と整合する。

これが重要なのは、`Answers/pattern2/pattern2_q2.md` に **「SW110 の Po1/Po2 はゼロ追加設定で要件を満たす」** と書いてあるためで、
**その前提は初期コンフィグが生きている場合にのみ成立する。今の SW110 では Po1/Po2 を自分で作り直す必要がある。**

SW110 で追加すべき設定：

```
! --- タグなし要件（表の SW110 Gi0/0 / Gi0/1）---
interface GigabitEthernet0/0
 switchport mode access
 switchport access vlan 2000
!
interface GigabitEthernet0/1
 switchport mode access
 switchport access vlan 2001
!
! --- タグあり要件（Po1/Po2 が消えている場合のみ）---
interface Port-channel1
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 1,2000,2001
!
interface Port-channel2
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 1,2000,2001
!
interface range GigabitEthernet1/0-1
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 1,2000,2001
 channel-group 1 mode active
!
interface range GigabitEthernet1/2-3
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 1,2000,2001
 channel-group 2 mode active
```

（`channel-group` のモードは対向 SW101/SW102 側と合わせること。Task 1.3 で `mode active` に揃える設計。Po1/Po2 が既に存在するなら `interface Port-channel` 部分は不要）

**もう1つの罠**：Gi0/0・Gi0/1 が `1 default` に出ている＝すでに L2 スイッチポートなので、`switchport` コマンドは不要。逆に SW110 が完全 wipe されていて Gi0/0 が L3 ポートだった場合は先に `switchport` が要る（その場合は `show vlan brief` に出てこないので、今回は L2 で確定）。

---

### ⚠️ SW610 のトランクは「未達の可能性が高い」

SW610 の初期コンフィグは：

```
vlan 2001
!
interface GigabitEthernet2/0
 switchport trunk allowed vlan 1,2000      ← 2001 が入っていない！
 switchport trunk encapsulation dot1q
 switchport mode trunk
!
interface GigabitEthernet2/1
 switchport trunk allowed vlan 1,2000      ← 同上
 switchport trunk encapsulation dot1q
 switchport mode trunk
```

**5台の中で SW610 だけが「明示的に許可VLANを絞られていて、しかも 2001 が抜けている」**。
だから解答も SW610 だけ `switchport trunk allowed vlan add 2001`（`add` 付き）になっている。
`show vlan brief` からは絶対に見えない差分なので、**SW610 の `show interfaces trunk` は必ず確認すること。**

---

### 題意を確認するコマンド

#### ① 本命 — タグあり要件の検証（SW101 / SW102 / SW110 / SW601 / SW602 / SW610）

```
show interfaces trunk
```

読み方（4セクションある）：

| セクション | 見るポイント |
|---|---|
| 1段目（Port / Mode / Encapsulation / Status / Native vlan） | 対象ポートが載っているか。`Encapsulation` が **802.1q**、`Status` が **trunking**（`not-trunking` なら失格） |
| **Vlans allowed on trunk** | **設定として** 2000 / 2001 が許可されているか。`switchport trunk allowed vlan` を打っていなければ常に `1-4094` と出る |
| **Vlans allowed and active in management domain** | **VLAN が実在して**いるか。VLAN 未作成だとここから消える |
| **Vlans in spanning tree forwarding state and not pruned** | **実際に転送されて**いるか。STP Blocking だとここから消える |

**合格ライン：4段目に 2000 と 2001 の両方が出ていること。**
（1段目に載っていても 4段目に無ければ、そのポートで VLAN 2000/2001 は流れていない）

SW601/SW602/SW101/SW102 は解答が `allowed vlan 1,2000,2001` なので、
「Vlans allowed on trunk」が `1-4094` のままだと**「絞る」という題意を満たしていない**と判断される可能性がある点に注意
（`1-4094` でも 2000/2001 はタグ付きで流れるので機能的には通るが、解答は明示的に絞っている）。

#### ② タグなし要件の検証（SW110 Gi0/0-0/1 / SW610 Gi0/0-0/1）

```
show vlan brief
show interfaces status
```

`show interfaces status` の **Vlan 列**が一番速い：

- 数字（`2000`）＝アクセスポートでそのVLAN → 合格
- `trunk` ＝トランクポート
- **`inactive`** ＝ `switchport access vlan` は打ったが **VLAN が存在しない**（q13 の `% Access VLAN does not exist` と同じ状態）
- `1` ＝まだ手つかず ← 今の SW110 Gi0/0・Gi0/1

#### ③ ポート単位で断定したいとき

```
show interfaces GigabitEthernet0/0 switchport
```

見る行：

```
Administrative Mode: static access / trunk     ← 設定した意図
Operational Mode:    static access / trunk     ← 実際の姿（ここが本物）
Administrative Trunking Encapsulation: dot1q
Access Mode VLAN: 2000 (VLAN2000)              ← タグなし要件
Trunking VLANs Enabled: 1,2000,2001            ← タグあり要件
```

**`Administrative` と `Operational` がズレていたら要注意**（対向が access でトランクが上がっていない等）。

#### ④ VLAN 単位で「どのポートで流れているか」を一望する

```
show spanning-tree vlan 2000
show spanning-tree vlan 2001
```

`show vlan brief` と違い、**アクセスポートもトランクポートも両方**が Interface 欄に並び、
Role（Root/Desg/Altn）と Sts（**FWD**/BLK）まで出る。
**「そのスイッチで VLAN 2000 が実際に転送されているポート一覧」＝題意そのもの**なので、答え合わせに一番強い。

#### ⑤ HQ の EtherChannel（Po1/Po2/Po3）が生きているか

```
show etherchannel summary
```

- Po の Flags が **`SU`**（S=Layer2, U=in use）
- メンバー物理ポートが **`(P)`**（bundled）
- `(D)` down / `(I)` stand-alone / `(s)` suspended は失格
- **Po が存在しない／メンバーが空**なら、そもそもトランク要件を満たすガワが無い ← 今の SW110 の疑い

#### ⑥ 最後の答え合わせ（config そのもの）

```
show running-config interface GigabitEthernet2/0
show running-config | section ^interface
show vlan id 2000
```

#### ⑦ 一発サマリ（時短用・1台あたり4コマンド）

```
show vlan brief
show interfaces status
show interfaces trunk
show etherchannel summary
```

Branch #3（SW601/602/610）は Po が無いので ④ は不要。HQ（SW101/102/110）は 4 つ全部。

---

### 今すぐやるべきこと（優先順）

1. **SW110** に `show interfaces trunk` / `show etherchannel summary` / `show run | section ^interface Gi1` を打ち、Po1/Po2 が消えているのか確認 → 消えていれば上記 config を投入
2. **SW110** の Gi0/0 / Gi0/1 にアクセスVLAN を設定（現状 VLAN 1 で確実に未達）
3. **SW610** の `show interfaces trunk` で Gi2/0・Gi2/1 の許可VLANに **2001** が入っているか確認（初期値が `1,2000` なので抜けている可能性大）
4. **SW102** の `show vlan brief` / `show interfaces trunk` を取得（未提出）
5. SW601 / SW602 / SW101 の `show interfaces trunk` で `1,2000,2001` に絞られているか確認

## 参照

- `Questions/pattern2/pattern2_q2.md`（Task 1.2 要件表。タグあり=トランク／タグなし=アクセスの定義）
- `Answers/pattern2/pattern2_q2.md`（解答 config、初期コンフィグとの関係、SW601/602 は初期状態では未制限の注意）
- `EI_v2.yaml`（SW110 ノード: `vlan 2000-2001` / Po1・Po2 と Gi1/0-3 のトランク+channel-group、SW610 ノード: `switchport trunk allowed vlan 1,2000` で 2001 欠落）
- `QA/pattern2/2026-07-30_q2_SW101とSW110のVLAN設定が空白の理由.md`
- `QA/pattern2/2026-07-31_q2_SW602で既に絞られたトランクは適用済みの証拠.md`
- `QA/pattern2/2026-08-11_q13_Access_VLAN_does_not_existが出る理由.md`（`inactive` 表示の意味）
