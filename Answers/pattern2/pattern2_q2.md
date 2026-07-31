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

## 検証コマンド

- `show vlan brief`（VLANが既に存在するか）
- `show interfaces trunk`（Po1/Po2/Po3の許可VLAN・アクティブVLANの確認）
- `show etherchannel summary`（メンバーポート割当・バンドル状態。Task 1.3着手前はPo1(SW101)がメンバーなし、Po2(SW102↔SW110)がpassive-passiveで非バンドルのはず）

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`（Task 1.2 — VLAN/Access/Trunk セクション、Pattern 2、および Task 1.3 — EtherChannel/STP セクション、SW101/SW102）
- `EI_v2.yaml`（SW101, SW102, SW110 各ノードの初期コンフィグ）

最終更新: 2026-07-31
