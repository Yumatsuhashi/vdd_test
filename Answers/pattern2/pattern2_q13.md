# Pattern 2 — 問題13 レイヤ2ポートセキュリティ（SW700）

## 解答 config（デバイス別）

### SW700

```
vlan 100,414

interface GigabitEthernet0/0
switchport mode access
switchport access vlan 100
switchport port-security
switchport port-security max 1
switchport port-security mac-address {}
switchport port-security violation restrict

interface GigabitEthernet0/1
switchport mode access
switchport access vlan 414
switchport port-security
switchport port-security max 1
switchport port-security mac-address {}
switchport port-security violation shutdown
switchport port-security aging time 1
switchport port-security aging type absolute

interface GigabitEthernet2/1
switchport trunk encapsulation dot1q
switchport mode trunk

errdisable recovery cause psecure-violation
errdisable recovery interval 180
```

`{}` は **HOST71 / HOST72 の実 MAC アドレス**を入れる（後述の手順で取得）。
**SW700 自身の MAC ではない。** ポートセキュリティが見るのは「そのポートに入ってくるフレームの
送信元 MAC」であり、Gi0/0 に届くフレームは必ず host71 が送ったものだから。
SW700 の MAC を書くと全フレームが違反になり、Gi0/0 は restrict で通信不能・Gi0/1 は err-disabled になる。

| ポート | 繋がっている機器 | VLAN | 書く MAC |
|---|---|---|---|
| Gi0/0 | **host71** | 100 | host71 の MAC |
| Gi0/1 | **host72** | 414 | host72 の MAC |

書式は `H.H.H`（4桁×3組のドット区切り。例 `aabb.cc00.7100`）。

**⚠️ `sticky` は使わない**。`switchport port-security mac-address sticky` だと
`show port-security address` の Type が `SecureSticky` になり、問題文の「スタティックに設定」の
要件を満たさない。MAC を明示入力して `SecureConfigured` にすること。

## 要件との対応

| 問題文の要件 | config |
|---|---|
| HOST71→VLAN100 / HOST72→VLAN414 | `vlan 100,414` ＋ `switchport access vlan 100` / `414` |
| 学習できる MAC を 1 つだけに制限 | `switchport port-security max 1` |
| MAC をスタティックに設定 | `switchport port-security mac-address {}` |
| HOST71 側: 破棄＋syslog＋違反カウンタ増加 | `violation restrict` |
| HOST72 側: err-disabled にする | `violation shutdown` |
| HOST72 に絶対エージング 60 秒 | `aging time 1` ＋ `aging type absolute` |
| 3 分ごとに自動復旧 | `errdisable recovery cause psecure-violation` ＋ `interval 180` |

## ⚠️ 罠

### 単位が同じブロック内で違う

- `switchport port-security aging time` は **分単位** → 60 秒 = **`1`**
- `errdisable recovery interval` は **秒単位** → 3 分 = **`180`**

### VLAN 番号は 100 と 414（114 ではない）

### errdisable recovery の cause 名を間違えない

| cause 名 | 何の違反か |
|---|---|
| **`psecure-violation`** | **ポートセキュリティ** ← これ |
| `security-violation` | 802.1x の認証違反 |

`security-violation` を選ぶと**エラーも出ないのに永久に復旧しない**。

`errdisable recovery` は **グローバルコマンド**（interface 配下ではない）で、`interval` は
**全 cause 共通で 1 つ**しか持てない。デフォルトは全 cause が `Disabled`・interval は `300` 秒。
`cause` が ON/OFF スイッチ、`interval` がタイマーなので**両方必要**（片方だけでは要件未達）。

err-disabled はデフォルトで自動復帰しない（config は `no shutdown` のまま line protocol が down）。
また自動復旧は「回復」であって「予防」ではなく、原因が残っていれば 180 秒ごとに落ちては戻るを繰り返す。

### violation 3 種類の切り分け

| モード | 破棄 | syslog | 違反カウンタ | ポート状態 |
|---|---|---|---|---|
| `protect` | ○ | ✗ | ✗ | up のまま |
| **`restrict`** | ○ | **○** | **○** | up のまま |
| **`shutdown`** | ○ | ○ | ○ | **err-disabled** |

問題文が「破棄・syslog・カウンタ増加」でポート停止に触れていない → `restrict`。

### パターン間で violation が逆

| | Gi0/0 (HOST71/VLAN100) | Gi0/1 (HOST72/VLAN414) | errdisable interval | aging |
|---|---|---|---|---|
| **Pattern 2** | **restrict** | **shutdown** | **180** | Gi0/1 に `time 1` + `type absolute` |
| Pattern 1 | shutdown | protect | 120 | Gi0/0 に `time 1` のみ |
| Pattern 3 | （このタスク無し。Pattern 3 の 1.13 は AAA） | | | |

Pattern 1 の記憶で解くと全部逆になるので注意。

### `switchport mode access` が構文上の前提

IOSvL2 のデフォルトは `switchport mode dynamic auto`。先に `switchport port-security` を打つと:

```
Command rejected: GigabitEthernet0/0 is a dynamic port.
```

## `{}` の MAC を調べる手順

SW700 の MAC アドレステーブルは初期状態では空。HOST71/72 は **Linux ではなく IOL の
Cisco ルータノード**（`node_definition: iol-xe`、IP を振っただけ）なので、
**誰にも話しかけられないとフレームを 1 枚も出さない** ＝ 学習材料が無い。

**host71 / host72 の IP は初期コンフィグ済み**: host71 `Ethernet0/0` 192.168.0.123/24 ／
host72 `Ethernet0/0` 172.31.70.123/24。**I/F 名は `Ethernet0/0`（Gi ではない）**で、
Et0/1〜0/3 は unassigned なので見る行を間違えると「IP なし」に見える。

**方法A（確実・IP 不要）**: HOST 側で直接読む。MAC はハードウェアの値なので IP の有無と無関係。

```
host71# show interfaces Ethernet0/0 | include address is
  Hardware is iol, address is aabb.cc00.7100 (bia aabb.cc00.7100)
```

**方法B（本命）**: ゲートウェイの R70 から ping。MAC 取得と SW700 の学習が同時に起きる。

```
R70# ping vrf WAN   192.168.0.123        ← host71
R70# ping vrf kiosk 172.31.70.123        ← host72
R70# show ip arp vrf WAN   | include 192.168.0.123
R70# show ip arp vrf kiosk | include 172.31.70.123
SW700# show mac address-table interface GigabitEthernet0/0
```

**⚠️ VRF 指定が必須**（R70 Gi0/2.100 は `vrf forwarding WAN`、Gi0/2.414 は `vrf forwarding kiosk`）。
素の `ping 192.168.0.123` はグローバルテーブルに経路が無く失敗する。両サブ I/F は `no cdp enable`。

**⚠️ 前提**: R70 は SW700 の Gi2/1 トランク越しにしか host に届かない。したがって
`vlan 100,414` ＋ Gi2/1 トランク ＋ Gi0/0・Gi0/1 の access vlan を**先に入れないと ping も通らない**。
「MAC テーブルが空」の真因はホストが黙っていること以上に **L2 の道が無かったこと**。

MAC を間違えると `maximum 1` のため本物のフレーム到着時に即違反（Gi0/1 は err-disable）。

**⚠️ ハマりどころ**: `switchport port-security` を先に有効化すると学習済み MAC が
動的セキュア MAC として 1 枠を占有し、静的 MAC 追加時に
`Total secure mac-addresses on interface ... has reached maximum limit.` になる。
→ `clear port-security dynamic interface GigabitEthernet0/0` で枠を空けてから入れ直す。

**判定**: `show port-security address` の Type が **`SecureConfigured`** なら要件充足。
`SecureDynamic` は自動学習なので「スタティックに設定」の要件未達。

## MAC アドレステーブルの原理（学習 vs 登録）

| Type | 出どころ | 出るタイミング |
|---|---|---|
| DYNAMIC | 受信フレームの送信元 MAC | トラフィックが届いた瞬間（データ駆動） |
| **STATIC（セキュア）** | `switchport port-security mac-address <MAC>` | **コマンドを打った瞬間**（トラフィック不要） |

DYNAMIC が載る条件（全部必要）: ①L2 ポート（`switchport`） ②VLAN が存在しアクティブ
③up/up かつ STP Learning/Forwarding ④実際にフレームが届く。

## トポロジ

```
R70 Gi0/2.100 (dot1q 100, vrf WAN,   192.168.0.1/24) ─┐
                                                       ├─ Gi2/1 [SW700] Gi0/0 ─ Eth0/0 host71
R70 Gi0/2.414 (dot1q 414, vrf kiosk, 172.31.70.1/24) ─┘     (trunk)     Gi0/1 ─ Eth0/0 host72
                                                                        VLAN 100 / VLAN 414
```

host71 `Ethernet0/0` = 192.168.0.123/24（VLAN 100）／host72 `Ethernet0/0` = 172.31.70.123/24（VLAN 414）。
両ノードとも `node_definition: iol-xe` ＝ **Linux PC ではなく IOL の Cisco ルータ**。
R70 が唯一のゲートウェイで、SW700 のトランク越しにしか届かない。

SW700 の初期コンフィグは hostname / `spanning-tree mode pvst` / line con のみ。
**VLAN もインターフェース設定も一切入っていない**（全部このタスクで入れる）。

## 検証コマンド

```
SW700# show port-security                       ! 全体サマリ
SW700# show port-security address               ! ★セキュアMAC一覧（Type=SecureConfigured）
SW700# show port-security interface Gi0/0       ! violation mode / aging / 違反カウンタ
SW700# show mac address-table interface Gi0/0
SW700# show interfaces status                   ! err-disable の確認
SW700# show errdisable recovery                 ! 復旧タイマ（psecure-violation が Enabled、180秒）
SW700# show vlan brief                          ! VLAN 100/414 の存在とポート所属
```

## 出典

- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`
  - 1874〜1922行 — Task 1.13 SW700 の 3 パターン比較表（差分: 大）
  - 4050〜4083行 — Pattern 2 単体解答ブロック
  - 3040〜3064行 — Pattern 1 単体解答ブロック（violation が逆・interval 120）
- `Questions/pattern2/pattern2_q13.md`
- `EI_v2.yaml`
  - SW700 — 初期コンフィグは hostname / spanning-tree pvst / line con のみ
  - host71 — `node_definition: iol-xe`、`Ethernet 0/0 / ip address 192.168.0.123 255.255.255.0`
  - links — `SW700-Gi0/0<->host71-Ethernet0/0`(4812行) / `SW700-Gi0/1<->host72-Ethernet0/0`(4819行) /
    `SW700-Gi2/1<->R70-Gi0/2`(4763行)

最終更新: 2026-08-11（host71/72 の IP・MAC 取得手順、R70 からの VRF 付き ping、port-security の枠エラー対処を追記）
