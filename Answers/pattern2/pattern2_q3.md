# Pattern 2 — 問題3 本社（HQ）のレイヤー2技術（EtherChannel/STP）

## 解答 config（デバイス別）

### SW101

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

spanning-tree mode rapid-pvst
spanning-tree portfast edge default
spanning-tree vlan 1,2000,2001 priority 0

interface range GigabitEthernet1/0-3, GigabitEthernet2/0-1, GigabitEthernet0/3
spanning-tree guard root

interface range port-channel 1, port-channel 3
spanning-tree guard root
```

### SW102

```
no interface port-channel 2
no interface port-channel 3

interface range GigabitEthernet1/2-3
switchport
switchport trunk encapsulation dot1q
switchport mode trunk
switchport trunk allowed vlan 1,2000,2001
channel-group 2 mode active
no shutdown

interface range GigabitEthernet2/0-1
switchport
switchport trunk encapsulation dot1q
switchport mode trunk
switchport trunk allowed vlan 1,2000,2001
channel-group 3 mode active
no shutdown

spanning-tree mode rapid-pvst
spanning-tree portfast edge default
spanning-tree vlan 1,2000,2001 priority 4096

interface range GigabitEthernet1/0-3, GigabitEthernet0/3
spanning-tree guard root

interface range port-channel 2
spanning-tree guard root
```

注意: SW101へ繋がるGi2/0-1（Po3）はroot-guard対象から**意図的に除外**されている（SW101が真のルートブリッジであり、Po3はSW102にとって正当なルートポートになるべきリンクのため）。

### SW110

```
no interface port-channel 1
no interface port-channel 2

interface range GigabitEthernet1/0-1
switchport
switchport trunk encapsulation dot1q
switchport mode trunk
switchport trunk allowed vlan 1,2000,2001
channel-group 1 mode active
no shutdown

interface range GigabitEthernet1/2-3
switchport
switchport trunk encapsulation dot1q
switchport mode trunk
switchport trunk allowed vlan 1,2000,2001
channel-group 2 mode active
no shutdown

spanning-tree mode rapid-pvst
spanning-tree portfast edge default
```

SW110はroot/secondary rootではないため、priority指定・root-guardともになし（Po1/Po2どちらも正当なルートポートになり得るため）。

## 要件とconfigの対応

| 問題文の要件 | 対応するコマンド |
|---|---|
| VLANごとに個別インスタンスをサポート＋3状態のみサポートするプロトコル | `spanning-tree mode rapid-pvst`（Rapid PVST+ = per-VLAN instance + RSTPの3状態モデル） |
| エンドポイントポートは個別設定なしでフォワーディング遅延を省略 | `spanning-tree portfast edge default`（全アクセスポートへのデフォルト適用） |
| SW101=ルート、SW102=セカンダリルート（VLAN2000/2001/デフォルトVLAN）、最小プライオリティ値を使用 | SW101: `spanning-tree vlan 1,2000,2001 priority 0`（0=設定可能な最小値）／SW102: `priority 4096` |
| 他スイッチからの優先度の高いBPDUの影響を受けない・受信ポートで転送しない | `spanning-tree guard root`（ルートガード） |

### SW101/SW102 のポート棚卸し（root-guard 範囲の根拠）

両機とも CML 上は Gi0/0-0/3, Gi1/0-1/3, Gi2/0-2/3 の12ポート構成。

| ポート | SW101 の状態 | SW102 の状態 | root guard |
|---|---|---|---|
| Gi0/0 | L3 → R11 Gi0/3 | L3 → R12 Gi0/3 | なし（STP対象外） |
| Gi0/1 | L3 → R12 Gi0/2 | L3 → R11 Gi0/2 | なし（STP対象外） |
| Gi0/2 | L3 → SW201 Gi1/2 | L3 → SW202 Gi1/2 | なし（STP対象外） |
| Gi0/3 | **L2・未接続** | **L2・未接続** | **両機ともあり** |
| Gi1/0-1 | L2・未接続 | L2・未接続 | 両機ともあり |
| Gi1/2-3 | Po1 → SW110 | Po2 → SW110 | 両機ともあり |
| Gi2/0-1 | Po3 → SW102 | Po3 → SW101 | SW101のみあり（SW102は除外） |
| Gi2/2-3 | L2・未接続 | L2・未接続 | 両機ともなし（解答の漏れ。実害なし） |

- `Gi0/3` が範囲に入るのは、Gi0 モジュール4本のうち Gi0/0-0/2 が `no switchport`（L3ルーテッド）にされていて **Gi0/3 だけが L2 のまま残っている**ため。「未接続だから不要」ではなく「STP が動きうる L2 ポートだから対象」という選定基準。
- 未接続ポートに root guard をかけても superior BPDU を受けない限り発動しないため無害。`spanning-tree portfast edge default` と組み合わせて「空きポートに不正スイッチが挿された瞬間に遮断する」保険になる。
- 厳密に全 L2 ポートを網羅するなら `Gi0/3, Gi1/0-3, Gi2/0-3` が正確（Gi2/2-3 は原本の範囲から漏れている。Pattern 1/2/3 すべて同一）。

### root-guardの適用範囲の設計ロジック

- **SW101**（真のルート、priority 0）: 他スイッチへ繋がる全L2ポート（Gi1/0-3, Gi2/0-1, Gi0/3, Po1, Po3）にroot-guardを適用。ルートブリッジ自身にはルートポートが存在しないため、全ポートに適用しても問題ない。Gi0/0-0/2はL3ルーテッド（`no switchport`）のためSTP非対象で除外。
- **SW102**（セカンダリルート、priority 4096）: SW101へ繋がるGi2/0-1・Po3を**除外**し、それ以外（Gi1/0-3, Gi0/3, Po2）にのみ適用。SW101方向は正当なルートポートになるべきリンクのため、root-guardをかけると自分の正しいルートパスを塞いでしまう。
- **SW110**（非ルート）: root-guardなし。Po1（SW101経由）・Po2（SW102経由）のどちらも正当なルートポートになり得るため。

## 初期コンフィグとの差分（何が本当に「必要」か）

`EI_v2.yaml` の初期状態と突き合わせると、必要な差分は以下だけ:

| デバイス | 初期状態 | 必要な差分 |
|---|---|---|
| SW101 Gi1/2-3（Po1） | trunk/dot1q 済み、**`channel-group` なし** | `channel-group 1 mode active` ＋ allowed vlan |
| SW101 Gi2/0-1（Po3） | **`channel-group 3 mode active` 済み** | allowed vlan のみ（EtherChannel 自体は成立済み） |
| SW102 Gi1/2-3（Po2） | `channel-group 2 mode passive` | 対向 SW110 も passive のため**バンドル不成立** → `mode active` へ |
| SW102 Gi2/0-1（Po3） | `channel-group 3 mode active` 済み | allowed vlan のみ |
| SW110 Gi1/0-1（Po1） | **`channel-group 1 mode on`**（静的＝LACPでない） | 802.3ad 要件違反 → `mode active` へ |
| SW110 Gi1/2-3（Po2） | `channel-group 2 mode passive` | `mode active` へ |
| 全スイッチ | `spanning-tree mode pvst` | `rapid-pvst` へ |

`no interface port-channel N` から始まるのは、初期コンフィグの Po に残る設定（許可VLAN未制限など）を消して物理ポート側から再生成するため。

## 検証コマンド

### 事前チェック（この設定が必要だと判断するため）

| コマンド | 見るポイント | 「必要」と判断する出力 |
|---|---|---|
| `show etherchannel summary` | Ports 欄・Protocol 欄 | Ports が空 / `Po1(SD)` ＝ メンバー未割当。Protocol が `-` ＝ `mode on` で LACP でない。`(I)`/`(s)` ＝ バンドル不成立 |
| `show lacp neighbor` | ネイバーの有無 | 空 ＝ 対向が `mode on` か passive-passive で LACPDU が来ていない |
| `show run \| section GigabitEthernet` | `channel-group` 行と mode | 行がない、または mode が `on`/`passive` |
| `show interfaces trunk` | Vlans allowed on trunk | `1-4094` ＝ 未制限（allowed vlan 要）／`1,2000-2001` ＝ 投入済み |
| `show interfaces Gi1/2 switchport` | Switchport / Administrative Mode / Encapsulation | Disabled ＝ `switchport` 要、dynamic auto ＝ `mode trunk` 要 |
| `show interfaces status` | 状態 | `disabled` ＝ `no shutdown` 要 |
| `show cdp neighbors` | 対向ポート | 問題文の表と実配線の一致確認 |
| `show spanning-tree summary` | STP モード | `pvst` ＝ `rapid-pvst` へ変更要 |

LACP モード組み合わせ: active↔active/passive は成立、**passive↔passive は不成立**、`on` は LACP でないため 802.3ad 要件を満たさない。

### 事後確認

`show etherchannel summary`（`Po1(SU)` ＋ Protocol `LACP` ＋ 全メンバー `(P)`）、`show interfaces trunk`、`show spanning-tree vlan 2000`、`show spanning-tree interface <if> detail`、`show spanning-tree summary`

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`（Task 1.3 — EtherChannel/STP セクション、Pattern 2、SW101/SW102/SW110）
- `EI_v2.yaml`（SW101ノードのリンク構成: R11/R12/SW201/SW102/SW110との接続関係）

最終更新: 2026-07-31
