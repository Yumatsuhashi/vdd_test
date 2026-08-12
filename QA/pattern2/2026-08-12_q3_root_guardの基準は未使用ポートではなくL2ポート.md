# Task 1.3 root guard の選定基準は「STP に使っていないポート」ではなく「L2 ポートかどうか」

## 質問

SW0101で

```
interface range GigabitEthernet1/0-3, GigabitEthernet2/0-1, GigabitEthernet0/3
```

ここを spanning-tree guard root としているがこれはなぜ
spanning-tree に使っていないインターフェースを spanning-tree guard root としているから
gi0/0-3, gi1/0-1, gi2/3 などじゃないの？

## 回答

### 結論

選定基準は「**STP に使っていないポート**」ではなく「**L2 ポートかどうか（＝STP が動きうるか）**」。
そして root guard の**本命はむしろ「使っているポート」の方**（Gi1/2-3 と Gi2/0-1）。前提が逆になっている。

---

### 前提のズレ①: Gi0/0-0/2 は「使っていない」どころか主力リンク

`EI_v2.yaml` の SW101 初期コンフィグ:

```
interface GigabitEthernet0/0
 no switchport
 ip address 10.1.10.2 255.255.255.252     ← R11 への L3 リンク
!
interface GigabitEthernet0/1
 no switchport
 ip address 10.1.12.2 255.255.255.252     ← R12 への L3 リンク
!
interface GigabitEthernet0/2
 no switchport
 ip address 10.2.241.2 255.255.255.252    ← SW201(DC) への L3 リンク
```

この3本は**バリバリ使われている**。範囲から外れているのは「使っていないから」ではなく、
**`no switchport` の L3 ルーテッドポートで STP というプロトコル自体が存在しないから**。
BPDU を受け取る口がないので root guard をかける対象がない。

Gi0 モジュール4本のうち3本が L3 化され、**Gi0/3 だけが L2 のまま取り残された**。
「Gi0/3」という一見唐突な指定はこの消去法の結果。

### 前提のズレ②: Gi1/2-3・Gi2/0-1 こそ root guard の主目的

要件文:

> SW101およびSW102は、**本社内の他のスイッチから受信する**、より優先度の高いBPDUの
> 影響を受けないようにしてください。

SW101 にとっての「本社内の他のスイッチ」は **SW110（Gi1/2-3 = Po1）と SW102（Gi2/0-1 = Po3）** の2つだけ。
**実際に superior BPDU が飛んでくる可能性があるのはこの2組だけ**であり、ここを外したら要件そのものを満たさない。

未接続の Gi0/3・Gi1/0-1 は「ついでに掛けた保険」であって主役ではない。

---

### 正しい導出法: `show interfaces status` の Vlan 列を1回見るだけ

| Vlan 列の表示 | 意味 | root guard |
|---|---|---|
| `routed` | `no switchport` の L3 ポート | **対象外**（STP が動かない） |
| 数字（`1` など） | L2 アクセスポート | 対象 |
| `trunk` | L2 トランクポート | 対象（本命） |

SW101 で打つとこうなる:

```
Gi0/0  routed   ← 除外（R11）
Gi0/1  routed   ← 除外（R12）
Gi0/2  routed   ← 除外（SW201）
Gi0/3  1        ← 対象
Gi1/0  1        ← 対象
Gi1/1  1        ← 対象
Gi1/2  trunk    ← 対象 ★本命（SW110）
Gi1/3  trunk    ← 対象 ★本命（SW110）
Gi2/0  trunk    ← 対象 ★本命（SW102）
Gi2/1  trunk    ← 対象 ★本命（SW102）
Gi2/2  1        ← 対象
Gi2/3  1        ← 対象
```

#### 実機の `show vlan brief` が裏付けになる

2026-08-11 に実機で取得した SW101 の出力:

```
1  default  active  Gi0/3, Gi1/0, Gi1/1, Gi2/2, Gi2/3
```

- VLAN 1 に並んだ5本 ＝ **L2 だがトランクでもない素のポート**
- そこに載っていない Gi1/2-3・Gi2/0-1 ＝ **トランク**（トランクは `show vlan brief` に載らない）
- Gi0/0-0/2 ＝ **L3 なので `show vlan brief` にすら現れない**

**この出力自体が L2 ポートの棚卸しになっている。** L2 ポート = VLAN1 の5本 + トランク4本 = 9本。

---

### Gi2/3 についての指摘は正しい

`Gi2/2` と `Gi2/3` は L2 ポートなのに解答の範囲から**漏れている**
（原本 HTML でも Pattern 1/2/3 すべて同一範囲＝`row-common`）。

実害はない（実際に他スイッチと繋がる Gi1/2-3・Gi2/0-1・Po1・Po3 は押さえてあるので要件は満たす）が、
**厳密に書くなら `Gi0/3, Gi1/0-3, Gi2/0-3` が要件文に忠実**。自分で解くときはこちらを推奨。

### 未接続ポートにも掛ける理由

- **副作用がゼロ**: root guard は superior BPDU を受信したときだけ発動する。何も繋がっていないポートでは一生発動しない
- **空きポートこそ本来の防御対象**: この解答は `spanning-tree portfast edge default` を入れているので
  空きポートは全部 edge 扱いになる。「エッジのつもりのポートに勝手にスイッチを挿された」瞬間に
  遮断する、という組み合わせで意味を持つ

### Po1/Po3 にも別途打っている理由

バンドル中の EtherChannel では **STP は Po 論理インターフェース単位で動く**ため、実効的に効くのは
`interface port-channel` 側。物理メンバーにも打っているのは、バンドルが解けて単独ポートに戻ったときの保険。

### 確認コマンド

```
show interfaces status                        ← Vlan 列で routed / trunk / 数字 を仕分け（範囲の導出）
show running-config | include guard           ← 適用漏れの洗い出し
show spanning-tree interface Gi0/3 detail     ← "Root guard is enabled" の表示
show spanning-tree inconsistentports          ← root-inconsistent で止まっているポート
```

## 参照

- `Questions/pattern2/pattern2_q3.md`（STP 要件文「本社内の他のスイッチから受信する、より優先度の高いBPDU」）
- `Answers/pattern2/pattern2_q3.md`（SW101/SW102 のポート棚卸し表、root-guard 適用範囲の設計ロジック）
- `EI_v2.yaml` SW101 ノード（Gi0/0 `no switchport` 10.1.10.2/30 → R11、Gi0/1 10.1.12.2/30 → R12、Gi0/2 10.2.241.2/30 → SW201、Gi1/2-3 trunk → SW110、Gi2/0-1 trunk + `channel-group 3 mode active` → SW102、Gi0/3・Gi1/0-1・Gi2/2-3 は stanza なし＝既定の L2）
- 実機 `show vlan brief`（2026-08-11 取得。SW101 の VLAN 1 に Gi0/3, Gi1/0, Gi1/1, Gi2/2, Gi2/3）
- `QA/pattern2/2026-07-31_q3_spanning-tree_guard_rootの適用範囲と役割.md`（この設定がどの要件を満たすか）
- `QA/pattern2/2026-08-03_q3_root_guardのポート範囲とGi0-3の理由.md`（Gi0/3 の正体、SW102 での Po3 除外理由、BPDU guard との違い）
