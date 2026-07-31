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

### root-guardの適用範囲の設計ロジック

- **SW101**（真のルート、priority 0）: 他スイッチへ繋がる全L2ポート（Gi1/0-3, Gi2/0-1, Gi0/3, Po1, Po3）にroot-guardを適用。ルートブリッジ自身にはルートポートが存在しないため、全ポートに適用しても問題ない。Gi0/0-0/2はL3ルーテッド（`no switchport`）のためSTP非対象で除外。
- **SW102**（セカンダリルート、priority 4096）: SW101へ繋がるGi2/0-1・Po3を**除外**し、それ以外（Gi1/0-3, Gi0/3, Po2）にのみ適用。SW101方向は正当なルートポートになるべきリンクのため、root-guardをかけると自分の正しいルートパスを塞いでしまう。
- **SW110**（非ルート）: root-guardなし。Po1（SW101経由）・Po2（SW102経由）のどちらも正当なルートポートになり得るため。

## 検証コマンド

（原本に明記なし。`show spanning-tree vlan 2000`、`show spanning-tree interface <if> detail`、`show spanning-tree summary`等で確認可能）

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`（Task 1.3 — EtherChannel/STP セクション、Pattern 2、SW101/SW102/SW110）
- `EI_v2.yaml`（SW101ノードのリンク構成: R11/R12/SW201/SW102/SW110との接続関係）

最終更新: 2026-07-31
