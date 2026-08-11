# Task 1.13 なぜここまで設定しないと `show mac address-table` にエントリが出ないのか（学習 vs 登録）

## 質問

int vlan 100,114 int gi0/0, gi0/1 sw mode access sw access vlan 100/114 sw port-security sw port-security maxi 1 sw port-security vilolation shutdown sw port-security mac-address #この時点でmacaddress-tableが見れる do sh mac-address table

ここまでしないとmac address tableが見えるようにならないんだけどどうして？　どうして見えるようになる？原理を解説して

## 回答

### 前提の訂正

- VLAN は **100 と 414**（`114` ではない）。114 で作ると要件を落とす
- これは **Task 1.13 / SW700**（Branch4）

### 結論：MAC アドレステーブルには「学習」と「登録」の 2 種類がある

| Type | 出どころ | 出るタイミング |
|---|---|---|
| **DYNAMIC** | 受信フレームの送信元 MAC | **トラフィックが届いた瞬間**（データ駆動） |
| **STATIC（セキュア）** | `switchport port-security mac-address <MAC>` | **コマンドを打った瞬間**（設定駆動・**トラフィック不要**） |

最後に打った `switchport port-security mac-address <MAC>` は **「学習」ではなく「登録」**。
この行を入れた瞬間、指定した MAC が STATIC エントリとしてテーブルに書き込まれる。
だから「この時点で見えるようになった」。

```
SW700# show mac address-table interface Gi0/0
Vlan    Mac Address       Type        Ports
100     aabb.cc00.7100    STATIC      Gi0/0     ← 1 フレームも通っていなくても出る
```

---

### 原理① MAC 学習はデータ駆動 —— 設定では 1 行も増えない

スイッチが MAC を覚える方法は 1 つだけ。
**受信したフレームの送信元 MAC を、入ってきたポートと VLAN に紐付けて記録する。**

DYNAMIC エントリができる条件（**全部**必要）:

1. **L2 ポートであること**（`switchport`）— routed port は永久にテーブルに載らない
2. **VLAN が存在してアクティブ**であること — VLAN が無い/suspend だとポートは inactive になり学習しない
3. ポートが **up/up** かつ STP が **Learning または Forwarding**
4. **フレームが実際に 1 枚以上届くこと** ← 今回の肝

「設定を書く」ことでは 1 件も増えない。**テーブルはトラフィックが作る。**

### 原理② なぜ今まで空だったか —— HOST71/72 が黙っているから

`EI_v2.yaml` を確認すると HOST71/HOST72 は **Linux PC ではなく IOL の Cisco ルータノード**
（`node_definition: iol-xe`）で、設定は IP を振っただけ。

```
hostname host71
interface Ethernet 0/0
 ip address 192.168.0.123 255.255.255.0
 no shutdown
```

**ルータは誰にも話しかけられなければユニキャストを 1 枚も出さない。**
ping も無い、ルーティングプロトコルも無い、上位に向かう通信も無い。
だから SW700 には学習材料が届かず、テーブルが空のままだった。

**設定が足りなかったのではなく、トラフィックが無かった** ——これが本質。

### 原理③ 設定の順序が強制される理由

`switchport port-security` は **static access / static trunk のポートにしか設定できない**。
IOSvL2 のデフォルトは `switchport mode dynamic auto` なので、いきなり打つと:

```
SW700(config-if)# switchport port-security
Command rejected: GigabitEthernet0/0 is a dynamic port.
```

`switchport mode access` が**構文上の前提条件**。「ここまでやらないと」の一因はこれ。

（補足: `switchport access vlan 100` でポートの VLAN が 1 → 100 に変わると、
VLAN 1 で学習していたエントリはフラッシュされ VLAN 100 で学習し直しになる。
設定前に `show mac address-table vlan 100` を見ても何も出ないのはこのため）

---

### 実務：`{}` の MAC をどこから調べるか

Task 1.13 の要件は「HOST71およびHOST72のMACアドレスを**スタティックに設定**すること」。
テーブルが空なので鶏と卵になる。**HOST 側から取るのが確実。**

```
host71# show interface Ethernet0/0 | include address
  Hardware is ..., address is aabb.cc00.7100 (bia aabb.cc00.7100)   ← これを使う
```

先に喋らせてスイッチに学習させる方法もある。

```
host71# ping 192.168.0.1                        ← 何でもいいのでフレームを出させる
SW700# show mac address-table interface Gi0/0   ← DYNAMIC で出てくる
```

⚠️ MAC を間違えて登録すると `maximum 1` のため本物のフレームが届いた瞬間に違反になる。
Gi0/1 は `violation shutdown` なので **err-disable に落ちる**。

### Pattern 2 の解答と要件の対応

| 問題文の要件 | config |
|---|---|
| HOST71→VLAN100 / HOST72→VLAN414 | `vlan 100,414` ＋ `switchport access vlan 100` / `414` |
| 学習できる MAC を 1 つだけに制限 | `switchport port-security max 1` |
| MAC をスタティックに設定 | `switchport port-security mac-address {}` |
| HOST71 側: 破棄＋syslog＋違反カウンタ | `violation restrict` |
| HOST72 側: err-disabled にする | `violation shutdown` |
| HOST72 に絶対エージング **60 秒** | `aging time 1` ＋ `aging type absolute` |
| **3 分**ごとに自動復旧 | `errdisable recovery cause psecure-violation` ＋ `interval 180` |

**⚠️ 単位の罠（同じブロック内で単位が違う）**

- `port-security aging time` は **分単位** → 60 秒 = **`1`**
- `errdisable recovery interval` は **秒単位** → 3 分 = **`180`**

**`violation` 3 種類の対応表**

| モード | 破棄 | syslog | 違反カウンタ | ポート状態 |
|---|---|---|---|---|
| `protect` | ○ | ✗ | ✗ | up のまま |
| **`restrict`** | ○ | **○** | **○** | up のまま |
| **`shutdown`** | ○ | ○ | ○ | **err-disabled** |

HOST71 の要件は「破棄・syslog・カウンタ増加」でポート停止に触れていない → **`restrict`** が正解。
（Pattern 1 は同じ Gi0/0 が `shutdown`、Gi0/1 が `protect` で逆。パターンを取り違えないこと）

### 検証コマンド

```
SW700# show port-security                       ! 全体サマリ
SW700# show port-security address               ! ★セキュアMACの一覧（判定はここ。Type=SecureConfigured）
SW700# show port-security interface Gi0/0       ! violation mode / aging / カウンタ
SW700# show mac address-table interface Gi0/0
SW700# show interfaces status                   ! err-disable の確認
SW700# show errdisable recovery                 ! 復旧タイマ
```

Task 1.13 の判定は `show mac address-table` より **`show port-security address`** の方が直接的。

## 参照

- `Questions/pattern2/pattern2_q13.md` — 「HOST71およびHOST72のMACアドレスをスタティックに設定すること」
  「絶対エージング時間を60秒」「3分ごとに自動復旧」
- `original/RS コンフィグ パターン比較 (Task 1.2〜1.14).html`
  - 1874〜1922行 — Task 1.13 SW700 の 3 パターン比較表（`diff-badge diff-lg` = 差分大）
  - 4050〜4083行 — Pattern 2 単体解答ブロック（`violation restrict` / `shutdown`、`aging time 1` +
    `aging type absolute`、`errdisable recovery interval 180`）
  - 3040〜3064行 — Pattern 1 は violation が逆（Gi0/0 `shutdown` / Gi0/1 `protect`）、`interval 120`
- `EI_v2.yaml`
  - SW700 — 初期コンフィグは hostname / spanning-tree pvst / line con のみ。**VLAN もインターフェース設定も皆無**
  - host71 — `node_definition: iol-xe`、`interface Ethernet 0/0 / ip address 192.168.0.123 255.255.255.0`
    （**Linux ではなく IOS ルータ＝黙っているとフレームを出さない**）
  - links — `SW700-Gi0/0<->host71-Ethernet0/0`(4812行) / `SW700-Gi0/1<->host72-Ethernet0/0`(4819行) /
    `SW700-Gi2/1<->R70-Gi0/2`(4763行)
